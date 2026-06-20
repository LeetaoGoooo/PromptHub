import Foundation
import PromptHubSkillKit

public enum DoctorSeverity: String, Codable, Sendable, Comparable {
    case ok
    case warning
    case error

    private var weight: Int {
        switch self {
        case .ok: return 0
        case .warning: return 1
        case .error: return 2
        }
    }

    public static func < (lhs: DoctorSeverity, rhs: DoctorSeverity) -> Bool {
        lhs.weight < rhs.weight
    }
}

public struct DoctorPathCheck: Codable, Equatable, Sendable {
    public let path: String
    public let exists: Bool
    public let isDirectory: Bool
    public let isReadable: Bool
    public let isWritable: Bool

    public init(
        path: String,
        exists: Bool,
        isDirectory: Bool,
        isReadable: Bool,
        isWritable: Bool
    ) {
        self.path = path
        self.exists = exists
        self.isDirectory = isDirectory
        self.isReadable = isReadable
        self.isWritable = isWritable
    }
}

public struct DoctorAgentReport: Codable, Equatable, Sendable {
    public let agent: String
    public let globalPath: DoctorPathCheck
    public let projectPath: DoctorPathCheck
    public let visibleSkillCount: Int

    public init(
        agent: String,
        globalPath: DoctorPathCheck,
        projectPath: DoctorPathCheck,
        visibleSkillCount: Int
    ) {
        self.agent = agent
        self.globalPath = globalPath
        self.projectPath = projectPath
        self.visibleSkillCount = visibleSkillCount
    }
}

public struct DoctorFinding: Codable, Equatable, Sendable {
    public let severity: DoctorSeverity
    public let code: String
    public let message: String
    public let path: String?

    public init(severity: DoctorSeverity, code: String, message: String, path: String? = nil) {
        self.severity = severity
        self.code = code
        self.message = message
        self.path = path
    }
}

public struct DoctorReport: Codable, Equatable, Sendable {
    public let homeDirectory: DoctorPathCheck
    public let exportsRoot: DoctorPathCheck
    public let promptsRoot: DoctorPathCheck
    public let skillsRoot: DoctorPathCheck
    /// Present only when PROMPTHUB_INSTALL_ROOT is set; otherwise PromptHub uses its own
    /// app-managed sandbox path which the CLI cannot inspect.
    public let installRoot: DoctorPathCheck?
    public let projectRoot: DoctorPathCheck
    public let githubTokenPresent: Bool
    public let agents: [DoctorAgentReport]
    public let findings: [DoctorFinding]

    public var topSeverity: DoctorSeverity {
        findings.map(\.severity).max() ?? .ok
    }

    public init(
        homeDirectory: DoctorPathCheck,
        exportsRoot: DoctorPathCheck,
        promptsRoot: DoctorPathCheck,
        skillsRoot: DoctorPathCheck,
        installRoot: DoctorPathCheck?,
        projectRoot: DoctorPathCheck,
        githubTokenPresent: Bool,
        agents: [DoctorAgentReport],
        findings: [DoctorFinding]
    ) {
        self.homeDirectory = homeDirectory
        self.exportsRoot = exportsRoot
        self.promptsRoot = promptsRoot
        self.skillsRoot = skillsRoot
        self.installRoot = installRoot
        self.projectRoot = projectRoot
        self.githubTokenPresent = githubTokenPresent
        self.agents = agents
        self.findings = findings
    }
}

extension PromptHubCLIService {
    /// Inspect the CLI environment and report on every directory the CLI relies on.
    /// Diagnostic only — never throws. Findings carry the actionable information.
    public func runDoctor(
        projectRootURL: URL? = nil
    ) -> DoctorReport {
        let env = self.environment
        let effectiveProjectRoot = projectRootURL
            ?? env.projectRootURL
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

        let home = check(env.homeDirectoryURL, expectDirectory: true)
        let exports = check(env.exportsRootURL, expectDirectory: true)
        let prompts = check(env.promptsURL, expectDirectory: true)
        let skills = check(env.skillsURL, expectDirectory: true)
        let install = env.installRootURL.map { check($0, expectDirectory: true) }
        let project = check(effectiveProjectRoot, expectDirectory: true)

        let agentRoots = env.agentSkillRoots
            ?? PromptHubCLIEnvironment.defaultAgentSkillRoots(
                homeDirectoryURL: env.homeDirectoryURL,
                projectRootURL: effectiveProjectRoot
            )

        let agentReports: [DoctorAgentReport] = agentRoots
            .map { (workflow, roots) in
                DoctorAgentReport(
                    agent: workflow.rawValue,
                    globalPath: check(roots.global, expectDirectory: true),
                    projectPath: check(roots.project, expectDirectory: true),
                    visibleSkillCount: countSkillPackages(in: roots.global) + countSkillPackages(in: roots.project)
                )
            }
            .sorted { $0.agent < $1.agent }

        var findings: [DoctorFinding] = []

        if !home.exists {
            findings.append(.init(severity: .error, code: "home_missing", message: "Home directory does not exist", path: home.path))
        }

        if !exports.exists {
            findings.append(.init(
                severity: .warning,
                code: "exports_root_missing",
                message: "PromptHub export directory is missing. Open the PromptHub app and sync to create it.",
                path: exports.path
            ))
        } else if !exports.isReadable {
            findings.append(.init(severity: .error, code: "exports_root_unreadable", message: "PromptHub export directory is not readable", path: exports.path))
        }

        if exports.exists && !prompts.exists {
            findings.append(.init(severity: .warning, code: "prompts_root_missing", message: "No exported prompts found at ~/.prompthub/prompts", path: prompts.path))
        }

        if exports.exists && !skills.exists {
            findings.append(.init(severity: .warning, code: "skills_root_missing", message: "No exported skills found at ~/.prompthub/skills", path: skills.path))
        }

        if let install, !install.exists {
            findings.append(.init(
                severity: .warning,
                code: "install_root_missing",
                message: "PROMPTHUB_INSTALL_ROOT points to a directory that does not exist",
                path: install.path
            ))
        }

        if !project.exists {
            findings.append(.init(
                severity: .error,
                code: "project_root_missing",
                message: "Project root does not exist. Use --project-root or set PROMPTHUB_PROJECT_ROOT to a valid directory.",
                path: project.path
            ))
        } else if !project.isDirectory {
            findings.append(.init(severity: .error, code: "project_root_not_directory", message: "Project root path exists but is not a directory", path: project.path))
        }

        let anyAgentVisible = agentReports.contains { $0.globalPath.exists || $0.projectPath.exists }
        if !anyAgentVisible {
            findings.append(.init(
                severity: .warning,
                code: "no_agent_paths",
                message: "No supported agent skill directories were found. Install at least one supported CLI agent to use ph skill install.",
                path: nil
            ))
        }

        for agent in agentReports {
            if !agent.globalPath.exists && !agent.projectPath.exists {
                findings.append(.init(
                    severity: .warning,
                    code: "agent_paths_missing",
                    message: "\(agent.agent): neither global nor project skill directory exists",
                    path: agent.globalPath.path
                ))
                continue
            }
            if agent.globalPath.exists && !agent.globalPath.isWritable {
                findings.append(.init(
                    severity: .error,
                    code: "agent_global_unwritable",
                    message: "\(agent.agent): global skill directory exists but is not writable; installs will fail",
                    path: agent.globalPath.path
                ))
            }
            if agent.projectPath.exists && !agent.projectPath.isWritable {
                findings.append(.init(
                    severity: .error,
                    code: "agent_project_unwritable",
                    message: "\(agent.agent): project skill directory exists but is not writable; installs will fail",
                    path: agent.projectPath.path
                ))
            }
        }

        if findings.isEmpty {
            findings.append(.init(severity: .ok, code: "healthy", message: "PromptHub CLI environment looks healthy.", path: nil))
        }

        return DoctorReport(
            homeDirectory: home,
            exportsRoot: exports,
            promptsRoot: prompts,
            skillsRoot: skills,
            installRoot: install,
            projectRoot: project,
            githubTokenPresent: env.githubToken != nil,
            agents: agentReports,
            findings: findings
        )
    }

    // MARK: - File-system probes

    private func check(_ url: URL, expectDirectory: Bool) -> DoctorPathCheck {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let readable = exists && FileManager.default.isReadableFile(atPath: url.path)
        let writable = exists && FileManager.default.isWritableFile(atPath: url.path)
        return DoctorPathCheck(
            path: url.path,
            exists: exists,
            isDirectory: isDir.boolValue,
            isReadable: readable,
            isWritable: writable
        )
    }

    private func countSkillPackages(in url: URL) -> Int {
        guard FileManager.default.fileExists(atPath: url.path) else { return 0 }
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        return entries.reduce(0) { count, entry in
            let skillFile = entry.appendingPathComponent("SKILL.md")
            return FileManager.default.fileExists(atPath: skillFile.path) ? count + 1 : count
        }
    }
}
