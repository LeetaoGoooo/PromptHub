import Foundation
import PromptHubSkillKit

public struct PromptHubCLIEnvironment {
    public let homeDirectoryURL: URL
    public let installRootURL: URL?
    public let projectRootURL: URL?
    public let githubToken: String?
    public let agentSkillRoots: [AgentWorkflow: AgentSkillRoots]?
    public let localSkillRoots: [URL]?
    public let sharedLocalRoots: [URL]?
    public let skillLockFileURLs: [URL]?

    public init(
        homeDirectoryURL: URL,
        installRootURL: URL? = nil,
        projectRootURL: URL? = nil,
        githubToken: String? = nil,
        agentSkillRoots: [AgentWorkflow: AgentSkillRoots]? = nil,
        localSkillRoots: [URL]? = nil,
        sharedLocalRoots: [URL]? = nil,
        skillLockFileURLs: [URL]? = nil
    ) {
        self.homeDirectoryURL = homeDirectoryURL
        self.installRootURL = installRootURL
        self.projectRootURL = projectRootURL
        self.githubToken = Self.sanitizedToken(githubToken)
        self.agentSkillRoots = agentSkillRoots
        self.localSkillRoots = localSkillRoots
        self.sharedLocalRoots = sharedLocalRoots
        self.skillLockFileURLs = skillLockFileURLs
    }

    public static func live(fileManager: FileManager = .default) -> PromptHubCLIEnvironment {
        let environment = ProcessInfo.processInfo.environment
        let homeDirectoryURL = resolvedDirectory(path: environment["PROMPTHUB_HOME"])
            ?? fileManager.homeDirectoryForCurrentUser
        let installRootURL = resolvedDirectory(path: environment["PROMPTHUB_INSTALL_ROOT"])
        let projectRootURL = resolvedDirectory(path: environment["PROMPTHUB_PROJECT_ROOT"])
            ?? URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        let githubToken = sanitizedToken(environment["PROMPTHUB_GITHUB_TOKEN"] ?? environment["GITHUB_TOKEN"])

        return PromptHubCLIEnvironment(
            homeDirectoryURL: homeDirectoryURL,
            installRootURL: installRootURL,
            projectRootURL: projectRootURL,
            githubToken: githubToken
        )
    }

    public var exportsRootURL: URL {
        homeDirectoryURL.appendingPathComponent(".prompthub", isDirectory: true)
    }

    public var promptsURL: URL {
        exportsRootURL.appendingPathComponent("prompts", isDirectory: true)
    }

    public var skillsURL: URL {
        exportsRootURL.appendingPathComponent("skills", isDirectory: true)
    }

    public func makeCatalog(
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        projectRootURL: URL? = nil
    ) -> SkillCatalogService {
        let effectiveProjectRoot = projectRootURL
            ?? self.projectRootURL
            ?? URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)

        let resolvedAgentSkillRoots = agentSkillRoots
            ?? Self.defaultAgentSkillRoots(homeDirectoryURL: homeDirectoryURL, projectRootURL: effectiveProjectRoot)

        return SkillCatalogService(
            session: session,
            fileManager: fileManager,
            githubToken: githubToken,
            installRootURL: installRootURL,
            projectRootURL: effectiveProjectRoot,
            agentSkillRoots: resolvedAgentSkillRoots,
            localSkillRoots: localSkillRoots ?? Self.defaultLocalSkillRoots(homeDirectoryURL: homeDirectoryURL, agentSkillRoots: resolvedAgentSkillRoots),
            sharedLocalRoots: sharedLocalRoots ?? Self.defaultSharedLocalRoots(homeDirectoryURL: homeDirectoryURL),
            skillLockFileURLs: skillLockFileURLs ?? Self.defaultSkillLockFileURLs(homeDirectoryURL: homeDirectoryURL)
        )
    }

    public static func defaultAgentSkillRoots(
        homeDirectoryURL: URL,
        projectRootURL: URL
    ) -> [AgentWorkflow: AgentSkillRoots] {
        let claudeURL = homeDirectoryURL.appendingPathComponent(".claude", isDirectory: true)
        let codexURL = homeDirectoryURL.appendingPathComponent(".codex", isDirectory: true)
        let cursorURL = homeDirectoryURL.appendingPathComponent(".cursor", isDirectory: true)
        let geminiURL = homeDirectoryURL.appendingPathComponent(".gemini", isDirectory: true)
        let iflowURL = homeDirectoryURL.appendingPathComponent(".iflow", isDirectory: true)
        let opencodeURL = homeDirectoryURL
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("opencode", isDirectory: true)
        let qwenURL = homeDirectoryURL.appendingPathComponent(".qwen", isDirectory: true)
        let qoderURL = homeDirectoryURL.appendingPathComponent(".qoder", isDirectory: true)

        return [
            .codex: AgentSkillRoots(
                global: codexURL.appendingPathComponent("skills", isDirectory: true),
                project: projectRootURL.appendingPathComponent(".agents/skills", isDirectory: true)
            ),
            .claudeCode: AgentSkillRoots(
                global: claudeURL.appendingPathComponent("skills", isDirectory: true),
                project: projectRootURL.appendingPathComponent(".claude/skills", isDirectory: true)
            ),
            .cursor: AgentSkillRoots(
                global: cursorURL.appendingPathComponent("skills", isDirectory: true),
                project: projectRootURL.appendingPathComponent(".cursor/skills", isDirectory: true)
            ),
            .geminiCLI: AgentSkillRoots(
                global: geminiURL.appendingPathComponent("skills", isDirectory: true),
                project: projectRootURL.appendingPathComponent(".agents/skills", isDirectory: true)
            ),
            .iflow: AgentSkillRoots(
                global: iflowURL.appendingPathComponent("skills", isDirectory: true),
                project: projectRootURL.appendingPathComponent(".iflow/skills", isDirectory: true)
            ),
            .opencode: AgentSkillRoots(
                global: opencodeURL.appendingPathComponent("skills", isDirectory: true),
                project: projectRootURL.appendingPathComponent(".agents/skills", isDirectory: true)
            ),
            .qwenCode: AgentSkillRoots(
                global: qwenURL.appendingPathComponent("skills", isDirectory: true),
                project: projectRootURL.appendingPathComponent(".qwen/skills", isDirectory: true)
            ),
            .qoder: AgentSkillRoots(
                global: qoderURL.appendingPathComponent("skills", isDirectory: true),
                project: projectRootURL.appendingPathComponent(".qoder/skills", isDirectory: true)
            )
        ]
    }

    public static func defaultLocalSkillRoots(
        homeDirectoryURL: URL,
        agentSkillRoots: [AgentWorkflow: AgentSkillRoots]
    ) -> [URL] {
        let agentsRoot = homeDirectoryURL.appendingPathComponent(".agents/skills", isDirectory: true)
        let configAgentsRoot = homeDirectoryURL.appendingPathComponent(".config/agents/skills", isDirectory: true)
        let discoveredRoots = agentSkillRoots.values.flatMap { [$0.global, $0.project] }
        return uniqueURLs([agentsRoot, configAgentsRoot] + discoveredRoots)
    }

    public static func defaultSharedLocalRoots(homeDirectoryURL: URL) -> [URL] {
        uniqueURLs([
            homeDirectoryURL.appendingPathComponent(".agents/skills", isDirectory: true),
            homeDirectoryURL.appendingPathComponent(".config/agents/skills", isDirectory: true)
        ])
    }

    public static func defaultSkillLockFileURLs(homeDirectoryURL: URL) -> [URL] {
        let agentsRoot = homeDirectoryURL.appendingPathComponent(".agents", isDirectory: true)
        let configAgentsRoot = homeDirectoryURL.appendingPathComponent(".config/agents", isDirectory: true)
        return uniqueURLs([
            agentsRoot.appendingPathComponent(".skill-lock.json"),
            configAgentsRoot.appendingPathComponent(".skill-lock.json"),
            agentsRoot.appendingPathComponent("skills/.skill-lock.json"),
            configAgentsRoot.appendingPathComponent("skills/.skill-lock.json")
        ])
    }

    private static func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { url in
            let path = url.standardizedFileURL.path
            return seen.insert(path).inserted
        }
    }

    private static func resolvedDirectory(path: String?) -> URL? {
        guard let path else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath, isDirectory: true)
    }

    private static func sanitizedToken(_ token: String?) -> String? {
        guard let token else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}