import Foundation
import PromptHubSkillKit

final class SkillCLIService {
    static let shared = SkillCLIService()

    enum CLIError: LocalizedError, Equatable {
        case commandFailed(String)
        case decodingError
        case envNotFound
        case invalidResponse
        case invalidSkillPackage
        case fileIOError(String)
        case networkError(String)

        var errorDescription: String? {
            switch self {
            case .commandFailed(let msg):
                return msg.isEmpty ? "Command execution failed" : msg
            case .decodingError:
                return "Failed to decode skills data"
            case .envNotFound:
                return "Required environment is not available"
            case .invalidResponse:
                return "Unexpected response from skills API"
            case .invalidSkillPackage:
                return "Invalid skill package, expected owner/repo@skill-name"
            case .fileIOError(let msg):
                return msg.isEmpty ? "Failed to read or write skill files" : msg
            case .networkError(let msg):
                return msg.isEmpty ? "Network request failed" : msg
            }
        }
    }

    typealias AgentWorkflow = PromptHubSkillKit.AgentWorkflow

    struct SkillInfo: Codable, Identifiable, Equatable {
        var id: String { "\(name)-\(isGlobal)" }
        let name: String
        let description: String
        var isInstalled: Bool = false
        var isGlobal: Bool = false
        var url: String?
        var installedAgents: [AgentWorkflow] = []
        var installedScopes: [SkillInstallScope] = []
        var isManagedByPromptHub: Bool = true
    }

    private let session: URLSession
    private let fileManager: FileManager
    private let apiBaseURL: URL?
    private let installRootURL: URL?
    private var cliAccessManager: CLIDirectoryAccessManager { .shared }

    init(
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        apiBaseURL: URL? = nil,
        installRootURL: URL? = nil
    ) {
        self.session = session
        self.fileManager = fileManager
        self.apiBaseURL = apiBaseURL
        self.installRootURL = installRootURL
    }

    private func makeCatalog(projectRootURL: URL? = nil) -> SkillCatalogService {
        cliAccessManager.makeCatalog(
            session: session,
            fileManager: fileManager,
            apiBaseURL: apiBaseURL,
            installRootURL: installRootURL,
            projectRootURL: projectRootURL
        )
    }

    func findSkills(query: String = "", projectRootURL: URL? = nil) async throws -> [SkillInfo] {
        do {
            let skills = try await cliAccessManager.withAccess {
                try await self.makeCatalog(projectRootURL: projectRootURL).findSkills(query: query)
            }
            return skills.map(Self.convert)
        } catch {
            throw mapError(error)
        }
    }

    func listInstalledSkills(projectRootURL: URL? = nil) async throws -> [SkillInfo] {
        do {
            let skills = try await cliAccessManager.withAccess {
                try await self.makeCatalog(projectRootURL: projectRootURL).listInstalledSkills()
            }
            return skills.map(Self.convert)
        } catch {
            throw mapError(error)
        }
    }

    func addSkill(
        package: String,
        isGlobal: Bool = true,
        targetAgents: [AgentWorkflow] = AgentWorkflow.defaultTargets,
        projectRootURL: URL? = nil
    ) async throws {
        do {
            let parsed = SkillPackageReference(rawValue: package).remoteInstallDescriptor
            guard let parsed else {
                throw CLIError.invalidSkillPackage
            }
            let request = SkillInstallRequest(
                source: parsed.source,
                skillNames: [parsed.skillName],
                targetAgents: targetAgents,
                isGlobal: isGlobal
            )
            try await cliAccessManager.withAccess {
                try await self.makeCatalog(projectRootURL: projectRootURL).install(request: request)
            }
        } catch {
            throw mapError(error)
        }
    }

    func addSkills(
        source: String,
        skillNames: [String],
        targetAgents: [AgentWorkflow] = AgentWorkflow.defaultTargets,
        isGlobal: Bool = true,
        projectRootURL: URL? = nil
    ) async throws {
        do {
            let request = SkillInstallRequest(
                source: source,
                skillNames: skillNames,
                targetAgents: targetAgents,
                isGlobal: isGlobal
            )
            try await cliAccessManager.withAccess {
                try await self.makeCatalog(projectRootURL: projectRootURL).install(request: request)
            }
        } catch {
            throw mapError(error)
        }
    }

    func addLocalSkill(
        name: String,
        markdown: String,
        isGlobal: Bool = true,
        targetAgents: [AgentWorkflow] = AgentWorkflow.defaultTargets,
        projectRootURL: URL? = nil
    ) async throws {
        do {
            try await cliAccessManager.withAccess {
                try await self.makeCatalog(projectRootURL: projectRootURL).installLocal(
                    name: name,
                    markdown: markdown,
                    isGlobal: isGlobal,
                    targetAgents: targetAgents
                )
            }
        } catch {
            throw mapError(error)
        }
    }

    func addInstalledSkill(
        name: String,
        isGlobal: Bool = true,
        targetAgents: [AgentWorkflow] = AgentWorkflow.defaultTargets,
        projectRootURL: URL? = nil
    ) async throws {
        do {
            try await cliAccessManager.withAccess {
                try await self.makeCatalog(projectRootURL: projectRootURL).installExisting(
                    name: name,
                    isGlobal: isGlobal,
                    targetAgents: targetAgents
                )
            }
        } catch {
            throw mapError(error)
        }
    }

    func removeSkill(
        name: String,
        isGlobal: Bool = true,
        targetAgents: [AgentWorkflow]? = nil,
        projectRootURL: URL? = nil
    ) async throws {
        do {
            try await cliAccessManager.withAccess {
                try await self.makeCatalog(projectRootURL: projectRootURL).remove(
                    name: name,
                    isGlobal: isGlobal,
                    targetAgents: targetAgents
                )
            }
        } catch {
            throw mapError(error)
        }
    }

    func loadInstalledMarkdown(
        name: String,
        isGlobal: Bool = true,
        projectRootURL: URL? = nil
    ) async throws -> String? {
        do {
            return try await cliAccessManager.withAccess {
                try await self.makeCatalog(projectRootURL: projectRootURL).loadInstalledMarkdown(
                    name: name,
                    isGlobal: isGlobal
                )
            }
        } catch {
            throw mapError(error)
        }
    }

    /// Performs a synchronous filesystem scan to determine which agents can actually see
    /// the named skill.  Uses security-scoped bookmarks that are already active; call this
    /// inside a `withAccess` block when you need accurate results for sandboxed paths.
    func checkAgentVisibility(
        skillName: String,
        isGlobal: Bool,
        projectRootURL: URL? = nil
    ) async -> [SkillAgentVisibility] {
        await cliAccessManager.withAccess {
            await self.makeCatalog(projectRootURL: projectRootURL).checkAgentVisibility(
                skillName: skillName,
                isGlobal: isGlobal
            )
        }
    }

    /// Checks whether the local SKILL.md content matches the remote GitHub source.
    func checkSourceIntegrity(
        skillName: String,
        isGlobal: Bool,
        projectRootURL: URL? = nil
    ) async -> SkillSourceIntegrity {
        await cliAccessManager.withAccess {
            await self.makeCatalog(projectRootURL: projectRootURL).checkSourceIntegrity(
                skillName: skillName,
                isGlobal: isGlobal
            )
        }
    }

    /// Analyzes the local SKILL.md for structural quality signals (no network required).
    func checkEffectiveness(
        skillName: String,
        isGlobal: Bool,
        projectRootURL: URL? = nil
    ) async -> SkillEffectivenessReport {
        await cliAccessManager.withAccess {
            self.makeCatalog(projectRootURL: projectRootURL).checkEffectiveness(
                skillName: skillName,
                isGlobal: isGlobal
            )
        }
    }

    /// Installs a skill from a private GitHub repo (using an optional PAT) or from a
    /// team-shared local directory.
    ///
    /// For GitHub sources the catalog is rebuilt with the token so the private API calls
    /// are authenticated.  For local shared paths the SKILL.md is read directly from disk.
    func installFromPrivateSource(
        source: PrivateSkillSource,
        skillNames: [String],
        isGlobal: Bool = true,
        targetAgents: [AgentWorkflow] = AgentWorkflow.defaultTargets,
        projectRootURL: URL? = nil
    ) async throws {
        switch source.type {
        case .githubPrivate:
            guard let ownerRepo = source.githubOwnerRepo else {
                throw CLIError.invalidSkillPackage
            }
            let token = PrivateSkillSourceStore.shared.loadToken(for: source.id)
            // Build a catalog with the private token injected.
            let catalog = cliAccessManager.makeCatalog(
                session: session,
                fileManager: fileManager,
                apiBaseURL: apiBaseURL,
                installRootURL: installRootURL,
                projectRootURL: projectRootURL,
                githubToken: token
            )
            let request = SkillInstallRequest(
                source: "\(ownerRepo.owner)/\(ownerRepo.repo)",
                skillNames: skillNames,
                targetAgents: targetAgents,
                isGlobal: isGlobal
            )
            do {
                try await cliAccessManager.withAccess {
                    try await catalog.install(request: request)
                }
            } catch {
                throw mapError(error)
            }

        case .localShared:
            let sharedRoot = URL(fileURLWithPath: source.location, isDirectory: true)
            for skillName in skillNames {
                let skillDir = sharedRoot.appendingPathComponent(skillName, isDirectory: true)
                let skillFile = skillDir.appendingPathComponent("SKILL.md")
                guard let markdown = try? String(contentsOf: skillFile, encoding: .utf8),
                      !markdown.isEmpty else {
                    throw CLIError.fileIOError("SKILL.md not found at \(skillFile.path)")
                }
                do {
                    try await cliAccessManager.withAccess {
                        try await self.makeCatalog(projectRootURL: projectRootURL).installLocal(
                            name: skillName,
                            markdown: markdown,
                            isGlobal: isGlobal,
                            targetAgents: targetAgents
                        )
                    }
                } catch {
                    throw mapError(error)
                }
            }
        }
    }

    /// Lists skill directory names available inside a team-shared local path.
    func listSkillsInSharedPath(_ path: String) -> [String] {
        let root = URL(fileURLWithPath: path, isDirectory: true)
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return children
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("SKILL.md").path) }
            .map { $0.lastPathComponent }
            .sorted()
    }

    func userFacingErrorMessage(for error: Error) -> String {
        if let cliError = error as? CLIError,
           let description = cliError.errorDescription {
            return sanitizeErrorMessage(description)
        }
        return sanitizeErrorMessage(error.localizedDescription)
    }

    private static func convert(_ item: PromptHubSkillKit.SkillInfo) -> SkillInfo {
        SkillInfo(
            name: item.name,
            description: item.description,
            isInstalled: item.isInstalled,
            isGlobal: item.isGlobal,
            url: item.url,
            installedAgents: item.installedAgents,
            installedScopes: item.installedScopes,
            isManagedByPromptHub: item.isManagedByPromptHub
        )
    }


    private func mapError(_ error: Error) -> CLIError {
        if let cliError = error as? CLIError {
            return cliError
        }

        if let skillError = error as? SkillKitError {
            switch skillError {
            case .invalidResponse:
                return .invalidResponse
            case .invalidSkillPackage:
                return .invalidSkillPackage
            case .networkError(let message):
                return .networkError(sanitizeErrorMessage(message))
            case .fileIOError(let message):
                return .fileIOError(sanitizeErrorMessage(message))
            case .requestFailed(let code, let message):
                return .networkError("skills-api \(code): \(sanitizeErrorMessage(message))")
            }
        }

        return .commandFailed(sanitizeErrorMessage(error.localizedDescription))
    }

    private func sanitizeErrorMessage(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Unknown error"
        }

        let lower = trimmed.lowercased()
        if lower.contains("<!doctype html") || lower.contains("<html") {
            return "Received HTML from endpoint; please verify the skills catalog source"
        }

        if trimmed.count > 280 {
            return String(trimmed.prefix(280)) + "..."
        }
        return trimmed
    }
}
