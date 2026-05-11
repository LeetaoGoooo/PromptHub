import Combine
import Foundation
import PromptHubSkillKit

extension Notification.Name {
    static let skillInstallationsDidChange    = Notification.Name("skillInstallationsDidChange")
    static let skillProjectSelectionDidChange = Notification.Name("skillProjectSelectionDidChange")
}

final class SkillWorkspaceService {
    static let shared = SkillWorkspaceService()

    enum WorkspaceError: LocalizedError {
        case projectRootRequired
        var errorDescription: String? {
            switch self {
            case .projectRootRequired: return "Choose a project folder before using project scope."
            }
        }
    }

    // Internal so cross-file extensions can access them.
    let cliService: SkillCLIService
    let projectSelectionStore: SkillProjectSelectionStore

    init(
        cliService: SkillCLIService = .shared,
        projectSelectionStore: SkillProjectSelectionStore = .shared
    ) {
        self.cliService = cliService
        self.projectSelectionStore = projectSelectionStore
    }

    var selectedProjectRootURL: URL? { projectSelectionStore.selectedProjectRootURL }
    var selectedProjectDisplayName: String { selectedProjectRootURL?.lastPathComponent ?? "Choose Project" }

    func setSelectedProjectRootURL(_ url: URL?) {
        projectSelectionStore.setSelectedProjectRootURL(url)
        NotificationCenter.default.post(name: .skillProjectSelectionDidChange, object: nil)
    }

    // MARK: - Queries

    func loadSkillStore(query: String = "", authoredDraftCount: Int = 0) async throws -> SkillStoreWorkspaceSnapshot {
        let projectRootURL = selectedProjectRootURL
        async let availableTask = cliService.findSkills(query: query, projectRootURL: projectRootURL)
        async let installedTask = cliService.listInstalledSkills(projectRootURL: projectRootURL)

        let availableSkills = try await availableTask
        let installedInfos  = try await installedTask
        let installedSkills = installedInfos.map(Self.makeInstalledSnapshot).sorted(by: Self.sortInstalledSnapshots)
        let registry        = makeInstallationRegistry(from: installedSkills)
        let catalogSkills   = availableSkills.map(Self.makeCatalogSkill)

        return SkillStoreWorkspaceSnapshot(
            catalogSkills: catalogSkills,
            installedSkills: installedSkills,
            installationRegistry: registry,
            summary: makeSummary(catalogCount: catalogSkills.count, installedSkills: installedSkills, authoredDraftCount: authoredDraftCount)
        )
    }

    func listInstalledSkills() async throws -> [InstalledSkillSnapshot] {
        let infos = try await cliService.listInstalledSkills(projectRootURL: selectedProjectRootURL)
        return infos.map(Self.makeInstalledSnapshot).sorted(by: Self.sortInstalledSnapshots)
    }

    func loadInstalledWorkspace(authoredDraftCount: Int = 0) async throws -> InstalledSkillsWorkspaceSnapshot {
        let installedSkills = try await listInstalledSkills()
        return makeInstalledWorkspace(from: installedSkills, authoredDraftCount: authoredDraftCount)
    }

    // MARK: - Audits

    func auditAgentVisibility(for skill: InstalledSkillSnapshot) async -> [SkillAgentVisibility] {
        await cliService.checkAgentVisibility(skillName: skill.package.rawValue, isGlobal: skill.isGlobal, projectRootURL: selectedProjectRootURL)
    }

    func auditSourceIntegrity(for skill: InstalledSkillSnapshot) async -> SkillSourceIntegrity {
        await cliService.checkSourceIntegrity(skillName: skill.package.rawValue, isGlobal: skill.isGlobal, projectRootURL: selectedProjectRootURL)
    }

    func auditEffectiveness(for skill: InstalledSkillSnapshot) async -> SkillEffectivenessReport {
        await cliService.checkEffectiveness(skillName: skill.package.rawValue, isGlobal: skill.isGlobal, projectRootURL: selectedProjectRootURL)
    }

    func previewUpdate(for skill: InstalledSkillSnapshot) async -> SkillUpdatePreview {
        await cliService.previewUpdate(skillName: skill.package.rawValue, isGlobal: skill.isGlobal, projectRootURL: selectedProjectRootURL)
    }

    func applyUpdate(preview: SkillUpdatePreview) async throws {
        try await cliService.applyUpdate(preview: preview, projectRootURL: selectedProjectRootURL)
    }

    @discardableResult
    func rollbackUpdate(preview: SkillUpdatePreview) async throws -> Int {
        try await cliService.rollbackUpdate(preview: preview, projectRootURL: selectedProjectRootURL)
    }

    func hasRollbackBackup(for skill: InstalledSkillSnapshot) async -> Bool {
        await cliService.hasRollbackBackup(skillName: skill.package.rawValue, isGlobal: skill.isGlobal, projectRootURL: selectedProjectRootURL)
    }

    // MARK: - Installation State

    func installationState(for skill: CatalogSkill, registry: [String: CatalogSkillInstallationState]) -> CatalogSkillInstallationState {
        let explicitState = installationState(for: skill.package, registry: registry)
        guard !explicitState.isInstalled, skill.installedHint else { return explicitState }

        let hintedScopes = skill.hintedScopes.isEmpty ? [skill.hintedAgents.isEmpty ? SkillInstallScope.project : .global] : skill.hintedScopes
        let hintedAgentsByScope = Dictionary(uniqueKeysWithValues: hintedScopes.map { ($0, Self.sortAgents(skill.hintedAgents)) })

        return CatalogSkillInstallationState(
            isInstalled: true, scopes: hintedScopes, agents: skill.hintedAgents,
            removableScopes: hintedScopes, agentsByScope: hintedAgentsByScope
        )
    }
}

@MainActor
final class InstalledSkillsWorkspaceStore: ObservableObject {
    struct SkillAuditState {
        let agentVisibility: [SkillAgentVisibility]
        let sourceIntegrity: SkillSourceIntegrity
        let effectiveness: SkillEffectivenessReport
    }

    @Published private(set) var snapshot = InstalledSkillsWorkspaceSnapshot.empty
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var revision = 0

    private let workspaceService: SkillWorkspaceService
    private var refreshTask: Task<Void, Never>?
    private var auditCache: [String: SkillAuditState] = [:]
    private var auditTasks: [String: Task<SkillAuditState, Never>] = [:]

    init(workspaceService: SkillWorkspaceService = .shared) {
        self.workspaceService = workspaceService
    }

    var installedSkills: [InstalledSkillSnapshot] {
        snapshot.installedSkills
    }

    func refresh(authoredDraftCount: Int, hasCLIAccess: Bool) {
        refreshTask?.cancel()

        guard hasCLIAccess else {
            snapshot = .empty
            isLoading = false
            errorMessage = nil
            clearAuditCache()
            return
        }

        isLoading = true
        errorMessage = nil

        refreshTask = Task { [workspaceService] in
            do {
                let snapshot = try await workspaceService.loadInstalledWorkspace(
                    authoredDraftCount: authoredDraftCount
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.snapshot = snapshot
                    self.isLoading = false
                    self.errorMessage = nil
                    self.revision += 1
                    self.clearAuditCache()
                    self.refreshTask = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = workspaceService.userFacingErrorMessage(for: error)
                    self.refreshTask = nil
                }
            }
        }
    }

    func apply(snapshot: InstalledSkillsWorkspaceSnapshot) {
        self.snapshot = snapshot
        isLoading = false
        errorMessage = nil
        revision += 1
        clearAuditCache()
    }

    func setError(_ message: String?) {
        errorMessage = message
        isLoading = false
    }

    func loadAuditState(for skill: InstalledSkillSnapshot) async -> SkillAuditState {
        if let cached = auditCache[skill.id] {
            return cached
        }

        if let runningTask = auditTasks[skill.id] {
            return await runningTask.value
        }

        let task = Task { [workspaceService] in
            async let visTask = workspaceService.auditAgentVisibility(for: skill)
            async let intTask = workspaceService.auditSourceIntegrity(for: skill)
            async let effTask = workspaceService.auditEffectiveness(for: skill)

            return SkillAuditState(
                agentVisibility: await visTask,
                sourceIntegrity: await intTask,
                effectiveness: await effTask
            )
        }

        auditTasks[skill.id] = task
        let state = await task.value
        auditTasks[skill.id] = nil
        auditCache[skill.id] = state
        return state
    }

    private func clearAuditCache() {
        auditTasks.values.forEach { $0.cancel() }
        auditTasks.removeAll()
        auditCache.removeAll()
    }
}
