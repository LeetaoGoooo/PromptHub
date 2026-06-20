import Foundation
import PromptHubSkillKit

/// Result row for `ph skill search`.
///
/// Designed so the `package` field can be copy-pasted directly into
/// `ph skill install <package>` — see `docs/cli-contract.md` for the
/// shape contract.
public struct PromptHubRemoteSkillSummary: Codable, Equatable, Identifiable, Sendable {
    public var id: String { package }
    public let package: String
    public let description: String
    public let url: String?
    public let isInstalled: Bool

    public init(package: String, description: String, url: String?, isInstalled: Bool) {
        self.package = package
        self.description = description
        self.url = url
        self.isInstalled = isInstalled
    }
}

extension PromptHubCLIService {
    /// Search the remote skill catalog for skills matching `query`.
    /// An empty query returns the catalog's default ordered listing
    /// (most-installed first).
    ///
    /// - Throws:
    ///   - `PromptHubCLIError.remoteCatalogUnavailable` if every registry
    ///     source (HTTP registry, crawler snapshot, GitHub fallback) failed.
    ///     The original failure description is preserved so scripts can grep
    ///     for "network", "auth", or specific HTTP codes.
    public func searchRemoteSkills(
        query: String = "",
        projectRootURL: URL? = nil
    ) async throws -> [PromptHubRemoteSkillSummary] {
        let catalog = environment.makeCatalog(
            session: session,
            fileManager: FileManager.default,
            projectRootURL: projectRootURL
        )

        let results: [SkillInfo]
        do {
            // Always fetch the catalog's full default listing and filter locally so
            // an empty result set returns [] cleanly. If we passed the query down
            // and it filtered to zero, the underlying SkillKit treats "0 results"
            // and "fetch failed" identically (both throw `.invalidResponse`), which
            // would surface as a misleading error here.
            results = try await catalog.findSkills(query: "")
        } catch {
            throw PromptHubCLIError.remoteCatalogUnavailable(
                description: error.localizedDescription
            )
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = trimmed.isEmpty
            ? results
            : results.filter { matches(query: trimmed, skill: $0) }

        return filtered.map { skill in
            PromptHubRemoteSkillSummary(
                package: skill.name,
                description: skill.description,
                url: skill.url,
                isInstalled: skill.isInstalled
            )
        }
    }

    private func matches(query: String, skill: SkillInfo) -> Bool {
        if skill.name.lowercased().contains(query) { return true }
        if skill.description.lowercased().contains(query) { return true }
        if let url = skill.url, url.lowercased().contains(query) { return true }
        return false
    }
}
