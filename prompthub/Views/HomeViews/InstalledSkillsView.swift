import AppKit
import PromptHubSkillKit
import SwiftData
import SwiftUI

struct InstalledSkillsView: View {
    @Environment(\.modelContext) var modelContext
    let workspaceService = SkillWorkspaceService.shared
    let draftService = SkillDraftService.shared
    @Query(sort: \Skill.updatedAt, order: .reverse) var skillDrafts: [Skill]
    @ObservedObject var installedWorkspaceStore: InstalledSkillsWorkspaceStore
    @Binding var promptSelection: PromptSelection
    let searchText: String
    @Binding var scopeFilter: SkillsSidebarScopeFilter
    @Binding var sourceFilter: SkillsSidebarSourceFilter
    let onSelectSkillDraft: (Skill) -> Void

    struct PendingRemoval: Identifiable {
        let id = UUID()
        let skill: InstalledSkillSnapshot
        let targetAgents: [AgentWorkflow]?
    }

    @State var selectedSkillID: String?
    @State var pendingRemoval: PendingRemoval?
    @State var removingSkillIDs: Set<String> = []
    @State var addingSkillIDs: Set<String> = []
    @State var agentVisibility: [SkillAgentVisibility] = []
    @State var isLoadingVisibility = false
    @State var sourceIntegrity: SkillSourceIntegrity?
    @State var isLoadingIntegrity = false
    @State var effectiveness: SkillEffectivenessReport?
    @State var isLoadingEffectiveness = false
    @ObservedObject var cliAccessManager = CLIDirectoryAccessManager.shared
    @State var showingCLIAccessManager = false
    @State var showingAuditReport = false
    @State var skillsWithUpdates: Set<String> = []
    @State var isCheckingUpdates = false
    @State var updatingSkill: InstalledSkillSnapshot?
    @State var listFilter: ListFilter = .all
    @State var installedSkillsLens: InstalledSkillsLens = .activeProject

    // MARK: - List filter
    enum ListFilter: String, CaseIterable {
        case all      = "All"
        case visible  = "Visible"
        case needsFix = "Needs Fix"
        case local    = "Local"
    }

    var installedSkills: [InstalledSkillSnapshot] { installedWorkspaceStore.installedSkills }

    private var filteredBySidebar: [InstalledSkillSnapshot] {
        let scopeFiltered = installedSkills.filter { skill in
            switch scopeFilter {
            case .allInstalled, .drafts:
                return true
            case .global:
                return skill.isGlobal
            case .project:
                return !skill.isGlobal
            }
        }

        return scopeFiltered.filter { skill in
            switch sourceFilter {
            case .all, .discover:
                return true
            case .external:
                return skill.displaySource != nil
            case .localOnly:
                return skill.displaySource == nil
            }
        }
    }

    var filteredSkills: [InstalledSkillSnapshot] {
        let afterSearch: [InstalledSkillSnapshot]
        if searchText.isEmpty {
            afterSearch = filteredBySidebar
        } else {
            afterSearch = filteredBySidebar.filter {
                $0.packageName.localizedCaseInsensitiveContains(searchText) ||
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.summary.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch listFilter {
        case .all:      return afterSearch
        case .visible:  return afterSearch.filter { !$0.agents.isEmpty }
        case .needsFix: return afterSearch.filter { $0.agents.isEmpty }
        case .local:    return afterSearch.filter { !$0.isGlobal }
        }
    }

    var projectSkills: [InstalledSkillSnapshot] { filteredSkills.filter { !$0.isGlobal } }
    var globalSkills:  [InstalledSkillSnapshot] { filteredSkills.filter { $0.isGlobal } }

    var selectedSkill: InstalledSkillSnapshot? {
        if let selectedSkillID,
           let matched = filteredSkills.first(where: { $0.id == selectedSkillID }) {
            return matched
        }
        return filteredSkills.first
    }

    private var auditLoadKey: String {
        "\(selectedSkillID ?? "none")-\(installedWorkspaceStore.revision)"
    }

    private var headerMetrics: [SkillLibraryMetric] {
        [
            SkillLibraryMetric(value: "\(installedWorkspaceStore.snapshot.summary.installedCount)",      title: "Installed", systemImage: "square.stack.3d.up"),
            SkillLibraryMetric(value: "\(installedWorkspaceStore.snapshot.summary.projectInstalledCount)", title: "Project",  systemImage: "folder"),
            SkillLibraryMetric(value: "\(installedWorkspaceStore.snapshot.summary.globalInstalledCount)", title: "Global",   systemImage: "globe"),
            SkillLibraryMetric(value: "\(skillDrafts.count)",                              title: "Drafts",   systemImage: "wand.and.stars")
        ]
    }

    var body: some View {
        SkillLibraryScreen(
            title: "Installed Skills",
            subtitle: "Audit what is live in each CLI environment, remove it cleanly by scope, and keep project and global installations explicit.",
            metrics: headerMetrics
        ) {
            HStack(spacing: 6) {
                SkillsWorkspacePicker(promptSelection: $promptSelection)

                Divider().frame(height: 14)

                SkillProjectPickerPopover(workspaceService: workspaceService) {
                    chooseProjectRoot()
                }

                Divider().frame(height: 14)

                CLIStatusIndicator(manager: cliAccessManager) {
                    showingCLIAccessManager = true
                }
            }
        } content: {
            VStack(spacing: 0) {
                mainContentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                nonFatalErrorBanner
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear { syncSelection() }
        .sheet(isPresented: $showingAuditReport) {
            SkillAuditReportView(skills: installedSkills) { showingAuditReport = false }
        }
        .sheet(item: $updatingSkill) { skill in
            SkillUpdateDiffSheet(skill: skill) { updatingSkill = nil }
        }
        .sheet(isPresented: $showingCLIAccessManager, onDismiss: { fetchInstalledSkills() }) {
            CLIAccessManagerView()
        }
        .onChange(of: installedWorkspaceStore.snapshot) { _, _ in syncSelection() }
        .onChange(of: searchText) { _, _ in syncSelection() }
        .task(id: auditLoadKey) {
            guard let skill = selectedSkill else {
                agentVisibility = []
                sourceIntegrity = nil
                effectiveness = nil
                isLoadingVisibility = false
                isLoadingIntegrity = false
                isLoadingEffectiveness = false
                return
            }

            isLoadingVisibility = true
            isLoadingIntegrity = true
            isLoadingEffectiveness = true

            let auditState = await installedWorkspaceStore.loadAuditState(for: skill)
            guard !Task.isCancelled else { return }
            agentVisibility = auditState.agentVisibility
            sourceIntegrity = auditState.sourceIntegrity
            effectiveness = auditState.effectiveness
            isLoadingVisibility = false
            isLoadingIntegrity = false
            isLoadingEffectiveness = false
        }
        .alert("Remove Skill", isPresented: Binding(
            get: { pendingRemoval != nil },
            set: { if !$0 { pendingRemoval = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
            Button("Remove", role: .destructive) {
                if let pending = pendingRemoval {
                    removeSkill(pending.skill, targetAgents: pending.targetAgents)
                }
            }
        } message: {
            if let pending = pendingRemoval { Text(removalMessage(for: pending)) }
        }
    }
}
