import Foundation
import PromptHubSkillKit

extension Notification.Name {
    static let skillInstallationsDidChange = Notification.Name("skillInstallationsDidChange")
    static let skillProjectSelectionDidChange = Notification.Name("skillProjectSelectionDidChange")
}

final class SkillWorkspaceService {
    static let shared = SkillWorkspaceService()

    enum WorkspaceError: LocalizedError {
        case projectRootRequired

        var errorDescription: String? {
            switch self {
            case .projectRootRequired:
                return "Choose a project folder before using project scope."
            }
        }
    }

    private let cliService: SkillCLIService
    private let projectSelectionStore: SkillProjectSelectionStore

    init(
        cliService: SkillCLIService = .shared,
        projectSelectionStore: SkillProjectSelectionStore = .shared
    ) {
        self.cliService = cliService
        self.projectSelectionStore = projectSelectionStore
    }

    var selectedProjectRootURL: URL? {
        projectSelectionStore.selectedProjectRootURL
    }

    var selectedProjectDisplayName: String {
        selectedProjectRootURL?.lastPathComponent ?? "Choose Project"
    }

    func setSelectedProjectRootURL(_ url: URL?) {
        projectSelectionStore.setSelectedProjectRootURL(url)
        NotificationCenter.default.post(name: .skillProjectSelectionDidChange, object: nil)
    }

    func loadSkillStore(
        query: String = "",
        authoredDraftCount: Int = 0
    ) async throws -> SkillStoreWorkspaceSnapshot {
        let projectRootURL = selectedProjectRootURL
        async let availableTask = cliService.findSkills(query: query, projectRootURL: projectRootURL)
        async let installedTask = cliService.listInstalledSkills(projectRootURL: projectRootURL)

        let availableSkills = try await availableTask
        let installedInfos = try await installedTask
        let installedSkills = installedInfos
            .map(Self.makeInstalledSnapshot)
            .sorted(by: Self.sortInstalledSnapshots)
        let registry = makeInstallationRegistry(from: installedSkills)

        let catalogSkills = availableSkills.map(Self.makeCatalogSkill)

        return SkillStoreWorkspaceSnapshot(
            catalogSkills: catalogSkills,
            installedSkills: installedSkills,
            installationRegistry: registry,
            summary: makeSummary(
                catalogCount: catalogSkills.count,
                installedSkills: installedSkills,
                authoredDraftCount: authoredDraftCount
            )
        )
    }

    func listInstalledSkills() async throws -> [InstalledSkillSnapshot] {
        let installedInfos = try await cliService.listInstalledSkills(projectRootURL: selectedProjectRootURL)
        return installedInfos
            .map(Self.makeInstalledSnapshot)
            .sorted(by: Self.sortInstalledSnapshots)
    }

    func loadInstalledWorkspace(
        authoredDraftCount: Int = 0
    ) async throws -> InstalledSkillsWorkspaceSnapshot {
        let installedSkills = try await listInstalledSkills()
        return makeInstalledWorkspace(
            from: installedSkills,
            authoredDraftCount: authoredDraftCount
        )
    }

    /// Performs a real-time filesystem scan for each agent's skill directory and returns the
    /// per-agent visibility status.  This is intentionally separate from `loadInstalledWorkspace`
    /// so the main list loads instantly while visibility results arrive asynchronously.
    func auditAgentVisibility(for skill: InstalledSkillSnapshot) async -> [SkillAgentVisibility] {
        await cliService.checkAgentVisibility(
            skillName: skill.package.rawValue,
            isGlobal: skill.isGlobal,
            projectRootURL: selectedProjectRootURL
        )
    }

    /// Computes a local SHA-256 hash of the installed SKILL.md and optionally compares it
    /// with the remote GitHub source.  Returns quickly when offline (remoteUnavailable status).
    func auditSourceIntegrity(for skill: InstalledSkillSnapshot) async -> SkillSourceIntegrity {
        await cliService.checkSourceIntegrity(
            skillName: skill.package.rawValue,
            isGlobal: skill.isGlobal,
            projectRootURL: selectedProjectRootURL
        )
    }

    /// Analyzes the local SKILL.md for structural quality signals (no network required).
    func auditEffectiveness(for skill: InstalledSkillSnapshot) async -> SkillEffectivenessReport {
        await cliService.checkEffectiveness(
            skillName: skill.package.rawValue,
            isGlobal: skill.isGlobal,
            projectRootURL: selectedProjectRootURL
        )
    }

    func installationState(
        for skill: CatalogSkill,
        registry: [String: CatalogSkillInstallationState]
    ) -> CatalogSkillInstallationState {
        let explicitState = installationState(for: skill.package, registry: registry)
        guard !explicitState.isInstalled, skill.installedHint else {
            return explicitState
        }

        let hintedScopes = skill.hintedScopes.isEmpty
            ? [skill.hintedAgents.isEmpty ? .project : .global]
            : skill.hintedScopes
        let hintedAgentsByScope = Dictionary(
            uniqueKeysWithValues: hintedScopes.map { ($0, Self.sortAgents(skill.hintedAgents)) }
        )

        return CatalogSkillInstallationState(
            isInstalled: true,
            scopes: hintedScopes,
            agents: skill.hintedAgents,
            removableScopes: hintedScopes,
            agentsByScope: hintedAgentsByScope
        )
    }

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
            package: skill.package.rawValue,
            isGlobal: scope == .global,
            targetAgents: targetAgents,
            projectRootURL: projectRootURL
        )
        notifyInstallationsChanged()
        return try await reloadSkillStoreAfterMutation(
            query: query,
            authoredDraftCount: authoredDraftCount,
            existingSnapshot: existingSnapshot
        )
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
        if let installed = installedSkills.first(where: { snapshot in
            snapshot.scope == scope && snapshot.package.normalizedKey == skill.package.normalizedKey
        }) {
            try await cliService.removeSkill(
                name: installed.packageName,
                isGlobal: installed.isGlobal,
                projectRootURL: projectRootURL
            )
        }
        notifyInstallationsChanged()
        return try await reloadSkillStoreAfterMutation(
            query: query,
            authoredDraftCount: authoredDraftCount,
            existingSnapshot: existingSnapshot
        )
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
            name: localSkill.name,
            markdown: localSkill.markdown,
            isGlobal: scope == .global,
            targetAgents: targetAgents,
            projectRootURL: projectRootURL
        )
        notifyInstallationsChanged()
        return try await reloadSkillStoreAfterMutation(
            query: query,
            authoredDraftCount: authoredDraftCount,
            existingSnapshot: existingSnapshot
        )
    }

    func removeInstalledSkill(
        _ skill: InstalledSkillSnapshot,
        targetAgents: [AgentWorkflow]? = nil,
        authoredDraftCount: Int = 0
    ) async throws -> InstalledSkillsWorkspaceSnapshot {
        let projectRootURL = try projectRootURL(isGlobal: skill.isGlobal)
        try await cliService.removeSkill(
            name: skill.packageName,
            isGlobal: skill.isGlobal,
            targetAgents: targetAgents,
            projectRootURL: projectRootURL
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
                package: skill.package.rawValue,
                isGlobal: skill.isGlobal,
                targetAgents: targetAgents,
                projectRootURL: projectRootURL
            )
        } else {
            try await cliService.addInstalledSkill(
                name: skill.packageName,
                isGlobal: skill.isGlobal,
                targetAgents: targetAgents,
                projectRootURL: projectRootURL
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

    private func notifyInstallationsChanged() {
        NotificationCenter.default.post(name: .skillInstallationsDidChange, object: nil)
    }

    private func projectRootURL(for scope: SkillInstallScope) throws -> URL? {
        try projectRootURL(isGlobal: scope == .global)
    }

    private func projectRootURL(isGlobal: Bool) throws -> URL? {
        if isGlobal {
            return nil
        }
        guard let selectedProjectRootURL else {
            throw WorkspaceError.projectRootRequired
        }
        return selectedProjectRootURL
    }

    private func reloadSkillStoreAfterMutation(
        query: String,
        authoredDraftCount: Int,
        existingSnapshot: SkillStoreWorkspaceSnapshot?
    ) async throws -> SkillStoreWorkspaceSnapshot {
        do {
            return try await loadSkillStore(query: query, authoredDraftCount: authoredDraftCount)
        } catch {
            guard let existingSnapshot else {
                throw error
            }

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

    func makeInstallationRegistry(
        from snapshots: [InstalledSkillSnapshot]
    ) -> [String: CatalogSkillInstallationState] {
        guard !snapshots.isEmpty else {
            return [:]
        }

        var registry: [String: CatalogSkillInstallationState] = [:]
        for snapshot in snapshots {
            let key = snapshot.package.normalizedKey
            let current = registry[key] ?? .notInstalled
            var agentsByScope = current.agentsByScope
            agentsByScope[snapshot.scope] = Self.sortAgents((agentsByScope[snapshot.scope] ?? []) + snapshot.agents)
            registry[key] = CatalogSkillInstallationState(
                isInstalled: true,
                scopes: Self.sortUniqueScopes(current.scopes + [snapshot.scope]),
                agents: Self.sortAgents(current.agents + snapshot.agents),
                removableScopes: Self.sortUniqueScopes(current.removableScopes + [snapshot.scope]),
                agentsByScope: agentsByScope
            )
        }
        return registry
    }

    func installationState(
        for package: SkillPackageReference,
        registry: [String: CatalogSkillInstallationState]
    ) -> CatalogSkillInstallationState {
        registry[package.normalizedKey] ?? .notInstalled
    }

    func skillStoreInstallationInfo(
        for skill: SkillCLIService.SkillInfo,
        installedSkills: [SkillCLIService.SkillInfo],
        installedSnapshotLoaded: Bool
    ) -> CatalogSkillInstallationState {
        let package = SkillPackageReference(rawValue: skill.name)
        let matchedSnapshots = installedSkills
            .filter { entry in
                matches(
                    installedPackage: SkillPackageReference(rawValue: entry.name),
                    against: package
                )
            }
            .map(Self.makeInstalledSnapshot)

        if !matchedSnapshots.isEmpty {
            return installationState(
                for: package,
                registry: makeInstallationRegistry(from: matchedSnapshots)
            )
        }

        guard !installedSnapshotLoaded, skill.isInstalled else {
            return .notInstalled
        }

        let hintedScopes = Self.normalizedScopes(from: skill.installedScopes, isGlobalFallback: skill.isGlobal)
        let hintedAgents = Self.sortAgents(skill.installedAgents)
        return CatalogSkillInstallationState(
            isInstalled: true,
            scopes: hintedScopes,
            agents: hintedAgents,
            removableScopes: hintedScopes,
            agentsByScope: Dictionary(
                uniqueKeysWithValues: hintedScopes.map { ($0, hintedAgents) }
            )
        )
    }

    private func loadLocalSkill(from selectedURL: URL) throws -> (name: String, markdown: String) {
        let isDirectory = (try? selectedURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let skillFileURL: URL
        let fallbackName: String

        if isDirectory {
            fallbackName = selectedURL.lastPathComponent
            skillFileURL = selectedURL.appendingPathComponent("SKILL.md")
        } else {
            fallbackName = selectedURL.deletingPathExtension().lastPathComponent
            skillFileURL = selectedURL
        }

        let markdown = try String(contentsOf: skillFileURL, encoding: .utf8)
        let extractedName = extractSkillName(fromMarkdown: markdown) ?? fallbackName
        return (name: extractedName, markdown: markdown)
    }

    private func extractSkillName(fromMarkdown markdown: String) -> String? {
        SkillParser.stringValue(for: "name", in: markdown)
    }

    private static func normalizedScopes(
        from scopes: [SkillInstallScope],
        isGlobalFallback: Bool
    ) -> [SkillInstallScope] {
        let resolved = scopes.isEmpty ? [isGlobalFallback ? .global : .project] : scopes
        return Array(Set(resolved)).sorted(by: sortScopes)
    }

    private static func makeInstalledSnapshot(_ item: SkillCLIService.SkillInfo) -> InstalledSkillSnapshot {
        InstalledSkillSnapshot(
            package: SkillPackageReference(rawValue: item.name),
            packageName: item.name,
            summary: item.description,
            scope: item.isGlobal ? .global : .project,
            agents: sortAgents(item.installedAgents),
            url: item.url,
            isManagedByPromptHub: item.isManagedByPromptHub
        )
    }

    private static func makeCatalogSkill(_ item: SkillCLIService.SkillInfo) -> CatalogSkill {
        CatalogSkill(
            package: SkillPackageReference(rawValue: item.name),
            summary: item.description,
            url: item.url,
            installedHint: item.isInstalled,
            hintedScopes: normalizedScopes(from: item.installedScopes, isGlobalFallback: item.isGlobal),
            hintedAgents: sortAgents(item.installedAgents),
            isManagedByPromptHub: item.isManagedByPromptHub
        )
    }

    private static func sortInstalledSnapshots(_ lhs: InstalledSkillSnapshot, _ rhs: InstalledSkillSnapshot) -> Bool {
        if lhs.scope != rhs.scope {
            return sortScopes(lhs.scope, rhs.scope)
        }
        return lhs.packageName.localizedCaseInsensitiveCompare(rhs.packageName) == .orderedAscending
    }

    private static func sortAgents(_ agents: [AgentWorkflow]) -> [AgentWorkflow] {
        Array(Set(agents)).sorted { $0.rawValue < $1.rawValue }
    }

    private static func sortUniqueScopes(_ scopes: [SkillInstallScope]) -> [SkillInstallScope] {
        Array(Set(scopes)).sorted(by: sortScopes)
    }

    private static func sortScopes(_ lhs: SkillInstallScope, _ rhs: SkillInstallScope) -> Bool {
        switch (lhs, rhs) {
        case (.project, .global):
            return true
        case (.global, .project):
            return false
        default:
            return lhs.rawValue < rhs.rawValue
        }
    }

    private func makeInstalledWorkspace(
        from installedSkills: [InstalledSkillSnapshot],
        authoredDraftCount: Int
    ) -> InstalledSkillsWorkspaceSnapshot {
        let projectSkills = installedSkills.filter { !$0.isGlobal }
        let globalSkills = installedSkills.filter(\.isGlobal)

        return InstalledSkillsWorkspaceSnapshot(
            installedSkills: installedSkills,
            projectSkills: projectSkills,
            globalSkills: globalSkills,
            summary: makeSummary(
                catalogCount: 0,
                installedSkills: installedSkills,
                authoredDraftCount: authoredDraftCount
            )
        )
    }

    private func makeSummary(
        catalogCount: Int,
        installedSkills: [InstalledSkillSnapshot],
        authoredDraftCount: Int
    ) -> SkillLibrarySummary {
        SkillLibrarySummary(
            authoredDraftCount: authoredDraftCount,
            catalogCount: catalogCount,
            installedCount: installedSkills.count,
            projectInstalledCount: installedSkills.filter { !$0.isGlobal }.count,
            globalInstalledCount: installedSkills.filter(\.isGlobal).count
        )
    }

    private func matches(
        installedPackage: SkillPackageReference,
        against targetPackage: SkillPackageReference
    ) -> Bool {
        if targetPackage.source != nil {
            return installedPackage.normalizedKey == targetPackage.normalizedKey
        }

        if installedPackage.rawValue.compare(targetPackage.rawValue, options: [.caseInsensitive]) == .orderedSame {
            return true
        }

        return installedPackage.skillName.caseInsensitiveCompare(targetPackage.skillName) == .orderedSame
    }
}
