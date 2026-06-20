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
            case .commandFailed(let msg):   return msg.isEmpty ? "Command execution failed" : msg
            case .decodingError:            return "Failed to decode skills data"
            case .envNotFound:              return "Required environment is not available"
            case .invalidResponse:          return "Unexpected response from skills API"
            case .invalidSkillPackage:      return "Invalid skill package, expected owner/repo@skill-name"
            case .fileIOError(let msg):     return msg.isEmpty ? "Failed to read or write skill files" : msg
            case .networkError(let msg):    return msg.isEmpty ? "Network request failed" : msg
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
        var installedPaths: [String] = []
    }

    // Internal so extension files can access them.
    let session: URLSession
    let fileManager: FileManager
    let apiBaseURL: URL?
    let installRootURL: URL?
    let cliAccessManager: CLIDirectoryAccessManager

    init(
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        apiBaseURL: URL? = nil,
        installRootURL: URL? = nil,
        cliAccessManager: CLIDirectoryAccessManager = .shared
    ) {
        self.session          = session
        self.fileManager      = fileManager
        self.apiBaseURL       = apiBaseURL
        self.installRootURL   = installRootURL
        self.cliAccessManager = cliAccessManager
    }

    func makeCatalog(projectRootURL: URL? = nil) -> SkillCatalogService {
        cliAccessManager.makeCatalog(
            session: session, fileManager: fileManager,
            apiBaseURL: apiBaseURL, installRootURL: installRootURL,
            projectRootURL: projectRootURL
        )
    }

    // MARK: - Query

    func findSkills(query: String = "", projectRootURL: URL? = nil) async throws -> [SkillInfo] {
        do {
            let skills = try await cliAccessManager.withAccess {
                try await self.makeCatalog(projectRootURL: projectRootURL).findSkills(query: query)
            }
            return skills.map(Self.convert)
        } catch { throw mapError(error) }
    }

    func listInstalledSkills(projectRootURL: URL? = nil) async throws -> [SkillInfo] {
        do {
            let skills = try await cliAccessManager.withAccess {
                try await self.makeCatalog(projectRootURL: projectRootURL).listInstalledSkills()
            }
            return skills.map(Self.convert)
        } catch { throw mapError(error) }
    }

    // MARK: - Static helpers

    static func convert(_ item: PromptHubSkillKit.SkillInfo) -> SkillInfo {
        SkillInfo(name: item.name, description: item.description, isInstalled: item.isInstalled,
                  isGlobal: item.isGlobal, url: item.url, installedAgents: item.installedAgents,
                  installedScopes: item.installedScopes, isManagedByPromptHub: item.isManagedByPromptHub,
                  installedPaths: item.installedPaths)
    }

    // MARK: - Error handling

    func userFacingErrorMessage(for error: Error) -> String {
        if let cliError = error as? CLIError, let description = cliError.errorDescription {
            return sanitizeErrorMessage(description)
        }
        return sanitizeErrorMessage(error.localizedDescription)
    }

    func mapError(_ error: Error) -> CLIError {
        if let cliError = error as? CLIError { return cliError }
        if let skillError = error as? SkillKitError {
            switch skillError {
            case .invalidResponse:                   return .invalidResponse
            case .invalidSkillPackage:               return .invalidSkillPackage
            case .networkError(let msg):             return .networkError(sanitizeErrorMessage(msg))
            case .fileIOError(let msg):              return .fileIOError(sanitizeErrorMessage(msg))
            case .requestFailed(let code, let msg):  return .networkError("skills-api \(code): \(sanitizeErrorMessage(msg))")
            }
        }
        return .commandFailed(sanitizeErrorMessage(error.localizedDescription))
    }

    func sanitizeErrorMessage(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Unknown error" }
        let lower = trimmed.lowercased()
        if lower.contains("<!doctype html") || lower.contains("<html") {
            return "Received HTML from endpoint; please verify the skills catalog source"
        }
        return trimmed.count > 280 ? String(trimmed.prefix(280)) + "..." : trimmed
    }
}
