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
