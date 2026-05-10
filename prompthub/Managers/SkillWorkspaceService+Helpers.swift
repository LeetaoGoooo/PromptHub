import Foundation
import PromptHubSkillKit

// MARK: - Data Transformation Helpers

extension SkillWorkspaceService {

    func makeInstallationRegistry(from snapshots: [InstalledSkillSnapshot]) -> [String: CatalogSkillInstallationState] {
        guard !snapshots.isEmpty else { return [:] }
        var registry: [String: CatalogSkillInstallationState] = [:]
        for snapshot in snapshots {
            let key     = snapshot.package.normalizedKey
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

    func installationState(for package: SkillPackageReference, registry: [String: CatalogSkillInstallationState]) -> CatalogSkillInstallationState {
        registry[package.normalizedKey] ?? .notInstalled
    }

    func skillStoreInstallationInfo(
        for skill: SkillCLIService.SkillInfo,
        installedSkills: [SkillCLIService.SkillInfo],
        installedSnapshotLoaded: Bool
    ) -> CatalogSkillInstallationState {
        let package = SkillPackageReference(rawValue: skill.name)
        let matchedSnapshots = installedSkills
            .filter { matches(installedPackage: SkillPackageReference(rawValue: $0.name), against: package) }
            .map(Self.makeInstalledSnapshot)

        if !matchedSnapshots.isEmpty {
            return installationState(for: package, registry: makeInstallationRegistry(from: matchedSnapshots))
        }
        guard !installedSnapshotLoaded, skill.isInstalled else { return .notInstalled }

        let hintedScopes  = Self.normalizedScopes(from: skill.installedScopes, isGlobalFallback: skill.isGlobal)
        let hintedAgents  = Self.sortAgents(skill.installedAgents)
        return CatalogSkillInstallationState(
            isInstalled: true, scopes: hintedScopes, agents: hintedAgents,
            removableScopes: hintedScopes,
            agentsByScope: Dictionary(uniqueKeysWithValues: hintedScopes.map { ($0, hintedAgents) })
        )
    }

    func loadLocalSkill(from selectedURL: URL) throws -> (name: String, markdown: String) {
        let isDirectory  = (try? selectedURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let skillFileURL: URL
        let fallbackName: String
        if isDirectory {
            fallbackName = selectedURL.lastPathComponent
            skillFileURL = selectedURL.appendingPathComponent("SKILL.md")
        } else {
            fallbackName = selectedURL.deletingPathExtension().lastPathComponent
            skillFileURL = selectedURL
        }
        let markdown      = try String(contentsOf: skillFileURL, encoding: .utf8)
        let extractedName = extractSkillName(fromMarkdown: markdown) ?? fallbackName
        return (name: extractedName, markdown: markdown)
    }

    private func extractSkillName(fromMarkdown markdown: String) -> String? {
        SkillParser.stringValue(for: "name", in: markdown)
    }

    func makeInstalledWorkspace(from installedSkills: [InstalledSkillSnapshot], authoredDraftCount: Int) -> InstalledSkillsWorkspaceSnapshot {
        let projectSkills = installedSkills.filter { !$0.isGlobal }
        let globalSkills  = installedSkills.filter(\.isGlobal)
        return InstalledSkillsWorkspaceSnapshot(
            installedSkills: installedSkills,
            projectSkills: projectSkills,
            globalSkills: globalSkills,
            summary: makeSummary(catalogCount: 0, installedSkills: installedSkills, authoredDraftCount: authoredDraftCount)
        )
    }

    func makeSummary(catalogCount: Int, installedSkills: [InstalledSkillSnapshot], authoredDraftCount: Int) -> SkillLibrarySummary {
        SkillLibrarySummary(
            authoredDraftCount: authoredDraftCount,
            catalogCount: catalogCount,
            installedCount: installedSkills.count,
            projectInstalledCount: installedSkills.filter { !$0.isGlobal }.count,
            globalInstalledCount:  installedSkills.filter(\.isGlobal).count
        )
    }

    private func matches(installedPackage: SkillPackageReference, against targetPackage: SkillPackageReference) -> Bool {
        if targetPackage.source != nil { return installedPackage.normalizedKey == targetPackage.normalizedKey }
        if installedPackage.rawValue.compare(targetPackage.rawValue, options: [.caseInsensitive]) == .orderedSame { return true }
        return installedPackage.skillName.caseInsensitiveCompare(targetPackage.skillName) == .orderedSame
    }

    // MARK: - Static Sorting / Mapping Helpers

    static func makeInstalledSnapshot(_ item: SkillCLIService.SkillInfo) -> InstalledSkillSnapshot {
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

    static func makeCatalogSkill(_ item: SkillCLIService.SkillInfo) -> CatalogSkill {
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

    static func normalizedScopes(from scopes: [SkillInstallScope], isGlobalFallback: Bool) -> [SkillInstallScope] {
        let resolved = scopes.isEmpty ? [isGlobalFallback ? SkillInstallScope.global : .project] : scopes
        return Array(Set(resolved)).sorted(by: sortScopes)
    }

    static func sortInstalledSnapshots(_ lhs: InstalledSkillSnapshot, _ rhs: InstalledSkillSnapshot) -> Bool {
        lhs.scope != rhs.scope ? sortScopes(lhs.scope, rhs.scope) : lhs.packageName.localizedCaseInsensitiveCompare(rhs.packageName) == .orderedAscending
    }

    static func sortAgents(_ agents: [AgentWorkflow]) -> [AgentWorkflow] {
        Array(Set(agents)).sorted { $0.rawValue < $1.rawValue }
    }

    static func sortUniqueScopes(_ scopes: [SkillInstallScope]) -> [SkillInstallScope] {
        Array(Set(scopes)).sorted(by: sortScopes)
    }

    static func sortScopes(_ lhs: SkillInstallScope, _ rhs: SkillInstallScope) -> Bool {
        switch (lhs, rhs) {
        case (.project, .global): return true
        case (.global, .project): return false
        default: return lhs.rawValue < rhs.rawValue
        }
    }
}
