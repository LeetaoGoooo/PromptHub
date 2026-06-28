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
    @Binding var navigationState: WorkspaceNavigationState
    @Binding var searchText: String
    @Binding var scopeFilter: SkillsSidebarScopeFilter
    @Binding var sourceFilter: SkillsSidebarSourceFilter
    @Binding var agentFilter: AgentWorkflow?

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
    @State var structuralQuality: SkillStructuralQualityReport?
    @State var isLoadingStructuralQuality = false
    @State var installedMarkdown: String = ""
    @State var isLoadingMarkdown = false
    @ObservedObject var cliAccessManager = CLIDirectoryAccessManager.shared
    @State var showingCLIAccessManager = false
    @State var showingAuditReport = false
    @State var skillsWithUpdates: Set<String> = []
    @State var isCheckingUpdates = false
    @State var updatingSkill: InstalledSkillSnapshot?
    @State var selectedUpdateSkillIDs: Set<String> = []
    @State var updatingSkillIDs: Set<String> = []
    @State var isApplyingBulkUpdates = false
    @State var listFilter: ListFilter = .all
    @State var skillsSortOrder: SkillsSortOrder = .nameAsc
    @State var editingDraftSheet: Skill?
    @State var editingInstalledSkillID: String?
    @State var openingDraftForSkillID: String?

    // MARK: - List filter
    enum ListFilter: String, CaseIterable {
        case all      = "All"
        case visible  = "Visible"
        case needsFix = "Needs Fix"
        case local    = "Local"
    }

    enum SkillsSortOrder: String, CaseIterable {
        case nameAsc  = "Name A–Z"
        case nameDesc = "Name Z–A"
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
            let sourceMatches: Bool
            switch sourceFilter {
            case .all, .discover:
                sourceMatches = true
            case .external:
                sourceMatches = skill.displaySource != nil
            case .localOnly:
                sourceMatches = skill.displaySource == nil
            }

            let agentMatches = agentFilter.map { skill.agents.contains($0) } ?? true

            return sourceMatches && agentMatches
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
        case .all:      return sorted(afterSearch)
        case .visible:  return sorted(afterSearch.filter { !$0.agents.isEmpty })
        case .needsFix: return sorted(afterSearch.filter { $0.agents.isEmpty })
        case .local:    return sorted(afterSearch.filter { !$0.isGlobal })
        }
    }

    private func sorted(_ skills: [InstalledSkillSnapshot]) -> [InstalledSkillSnapshot] {
        switch skillsSortOrder {
        case .nameAsc:  return skills.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .nameDesc: return skills.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedDescending }
        }
    }

    var selectedSkill: InstalledSkillSnapshot? {
        // First try to find the skill in the filtered list
        if let selectedSkillID,
           let matched = filteredSkills.first(where: { $0.id == selectedSkillID }) {
            return matched
        }
        
        // If not in filtered list, try to return the first filtered skill
        if let firstFiltered = filteredSkills.first {
            return firstFiltered
        }
        
        // If filtered list is empty but we had a selectedSkillID, try to find it in all skills
        // This prevents the details pane from disappearing when a filter hides the current selection
        if let selectedSkillID,
           let matched = installedSkills.first(where: { $0.id == selectedSkillID }) {
            return matched
        }
        
        return nil
    }

    private var auditLoadKey: String {
        "\(selectedSkill?.id ?? "none")-\(installedWorkspaceStore.revision)"
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
        SkillLibraryScreen {
            VStack(spacing: 0) {
                mainContentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                nonFatalErrorBanner
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear { syncSelection() }
        .onChange(of: selectedSkillID) { _, newValue in
            guard editingInstalledSkillID != newValue else { return }
            openingDraftForSkillID = nil
        }
        .sheet(isPresented: $showingAuditReport) {
            SkillAuditReportView(skills: installedSkills) { showingAuditReport = false }
        }
        .sheet(item: $editingDraftSheet, onDismiss: {
            editingInstalledSkillID = nil
        }) { draft in
            SkillDraftDetailView(skill: draft)
                .frame(minWidth: 960, minHeight: 640)
        }
        .sheet(item: $updatingSkill) { skill in
            SkillUpdateDiffSheet(skill: skill) { updatingSkill = nil }
        }
        .sheet(isPresented: $showingCLIAccessManager, onDismiss: { fetchInstalledSkills() }) {
            CLIAccessManagerView()
        }
        .onChange(of: installedWorkspaceStore.snapshot) { _, _ in syncSelection() }
        .onChange(of: searchText) { _, _ in syncSelection() }
        .onChange(of: listFilter) { _, _ in syncSelection() }
        .onChange(of: skillsSortOrder) { _, _ in syncSelection() }
        .toolbar { installedToolbarContent }
        .task(id: auditLoadKey) {
            guard let skill = selectedSkill else {
                agentVisibility = []
                sourceIntegrity = nil
                structuralQuality = nil
                isLoadingVisibility = false
                isLoadingIntegrity = false
                isLoadingStructuralQuality = false
                installedMarkdown = ""
                isLoadingMarkdown = false
                return
            }

            isLoadingVisibility = true
            isLoadingIntegrity = true
            isLoadingStructuralQuality = true
            isLoadingMarkdown = true

            let auditState = await installedWorkspaceStore.loadAuditState(for: skill)
            let markdown = try? await workspaceService.loadInstalledMarkdown(for: skill)
            guard !Task.isCancelled else { return }
            agentVisibility = auditState.agentVisibility
            sourceIntegrity = auditState.sourceIntegrity
            structuralQuality = auditState.structuralQuality
            isLoadingVisibility = false
            isLoadingIntegrity = false
            isLoadingStructuralQuality = false
            installedMarkdown = markdown ?? ""
            isLoadingMarkdown = false
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
