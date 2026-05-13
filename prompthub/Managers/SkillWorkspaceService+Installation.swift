import Foundation
import PromptHubSkillKit

// MARK: - Installation Mutations

extension SkillWorkspaceService {

    func installCatalogSkill(
        _ skill: CatalogSkill,
        query: String = "",
        scope: SkillInstallScope,
        targetAgents: [AgentWorkflow],
        authoredDraftCount: Int = 0,
        existingSnapshot: SkillStoreWorkspaceSnapshot? = nil
    ) async throws -> SkillStoreWorkspaceSnapshot {
        let projectRootURL = try projectRootURL(for: scope)
        try await cliService.addSkill(
            package: skill.package.rawValue, isGlobal: scope == .global,
            targetAgents: targetAgents, projectRootURL: projectRootURL
        )
        notifyInstallationsChanged()
        return try await reloadSkillStoreAfterMutation(query: query, authoredDraftCount: authoredDraftCount, existingSnapshot: existingSnapshot)
    }

    func removeCatalogSkill(
        _ skill: CatalogSkill,
        query: String = "",
        scope: SkillInstallScope,
        installedSkills: [InstalledSkillSnapshot],
        authoredDraftCount: Int = 0,
        existingSnapshot: SkillStoreWorkspaceSnapshot? = nil
    ) async throws -> SkillStoreWorkspaceSnapshot {
        let projectRootURL = try projectRootURL(for: scope)
        if let installed = installedSkills.first(where: { $0.scope == scope && $0.package.normalizedKey == skill.package.normalizedKey }) {
            try await cliService.removeSkill(name: installed.packageName, isGlobal: installed.isGlobal, projectRootURL: projectRootURL)
        }
        notifyInstallationsChanged()
        return try await reloadSkillStoreAfterMutation(query: query, authoredDraftCount: authoredDraftCount, existingSnapshot: existingSnapshot)
    }

    func installLocalSkill(
        at selectedURL: URL,
        query: String = "",
        scope: SkillInstallScope,
        targetAgents: [AgentWorkflow] = AgentWorkflow.defaultTargets,
        authoredDraftCount: Int = 0,
        existingSnapshot: SkillStoreWorkspaceSnapshot? = nil
    ) async throws -> SkillStoreWorkspaceSnapshot {
        let projectRootURL = try projectRootURL(for: scope)
        let localSkill = try loadLocalSkill(from: selectedURL)
        try await cliService.addLocalSkill(
            name: localSkill.name, markdown: localSkill.markdown,
            packageDirectoryURL: localSkill.packageDirectoryURL,
            isGlobal: scope == .global, targetAgents: targetAgents, projectRootURL: projectRootURL
        )
        notifyInstallationsChanged()
        return try await reloadSkillStoreAfterMutation(query: query, authoredDraftCount: authoredDraftCount, existingSnapshot: existingSnapshot)
    }

    func removeInstalledSkill(
        _ skill: InstalledSkillSnapshot,
        targetAgents: [AgentWorkflow]? = nil,
        authoredDraftCount: Int = 0
    ) async throws -> InstalledSkillsWorkspaceSnapshot {
        let projectRootURL = try projectRootURL(isGlobal: skill.isGlobal)
        try await cliService.removeSkill(
            name: skill.packageName, isGlobal: skill.isGlobal,
            targetAgents: targetAgents, projectRootURL: projectRootURL
        )
        notifyInstallationsChanged()
        return try await loadInstalledWorkspace(authoredDraftCount: authoredDraftCount)
    }

    func addInstalledSkillTargets(
        _ skill: InstalledSkillSnapshot,
        targetAgents: [AgentWorkflow],
        authoredDraftCount: Int = 0
    ) async throws -> InstalledSkillsWorkspaceSnapshot {
        let projectRootURL = try projectRootURL(isGlobal: skill.isGlobal)
        if skill.package.source != nil {
            try await cliService.addSkill(
                package: skill.package.rawValue, isGlobal: skill.isGlobal,
                targetAgents: targetAgents, projectRootURL: projectRootURL
            )
        } else {
            try await cliService.addInstalledSkill(
                name: skill.packageName, isGlobal: skill.isGlobal,
                targetAgents: targetAgents, projectRootURL: projectRootURL
            )
        }
        notifyInstallationsChanged()
        return try await loadInstalledWorkspace(authoredDraftCount: authoredDraftCount)
    }

    func userFacingErrorMessage(for error: Error) -> String {
        if let workspaceError = error as? WorkspaceError,
           let description = workspaceError.errorDescription {
            return description
        }
        return cliService.userFacingErrorMessage(for: error)
    }

    // MARK: - Private helpers

    func notifyInstallationsChanged() {
        NotificationCenter.default.post(name: .skillInstallationsDidChange, object: nil)
    }

    func projectRootURL(for scope: SkillInstallScope) throws -> URL? {
        try projectRootURL(isGlobal: scope == .global)
    }

    func projectRootURL(isGlobal: Bool) throws -> URL? {
        if isGlobal { return nil }
        guard let url = selectedProjectRootURL else { throw WorkspaceError.projectRootRequired }
        return url
    }

    func reloadSkillStoreAfterMutation(
        query: String,
        authoredDraftCount: Int,
        existingSnapshot: SkillStoreWorkspaceSnapshot?
    ) async throws -> SkillStoreWorkspaceSnapshot {
        do {
            return try await loadSkillStore(query: query, authoredDraftCount: authoredDraftCount)
        } catch {
            guard let existingSnapshot else { throw error }
            let installedSkills = (try? await listInstalledSkills()) ?? existingSnapshot.installedSkills
            return SkillStoreWorkspaceSnapshot(
                catalogSkills: existingSnapshot.catalogSkills,
                installedSkills: installedSkills,
                installationRegistry: makeInstallationRegistry(from: installedSkills),
                summary: makeSummary(
                    catalogCount: existingSnapshot.catalogSkills.count,
                    installedSkills: installedSkills,
                    authoredDraftCount: authoredDraftCount
                )
            )
        }
    }
}
