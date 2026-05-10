import AppKit
import PromptHubSkillKit
import SwiftData
import SwiftUI

struct InstalledSkillsView: View {
    @Environment(\.modelContext) var modelContext
    let workspaceService = SkillWorkspaceService.shared
    let draftService = SkillDraftService.shared
    @Query(sort: \Skill.updatedAt, order: .reverse) var skillDrafts: [Skill]
    let searchText: String
    let onSelectSkillDraft: (Skill) -> Void

    struct PendingRemoval: Identifiable {
        let id = UUID()
        let skill: InstalledSkillSnapshot
        let targetAgents: [AgentWorkflow]?
    }

    @State var workspaceSnapshot = InstalledSkillsWorkspaceSnapshot.empty
    @State var isLoading = false
    @State var errorMessage: String?
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
    @State var fetchTask: Task<Void, Never>?
    @ObservedObject var cliAccessManager = CLIDirectoryAccessManager.shared
    @State var showingCLIAccessManager = false
    @State var showingAuditReport = false

    var installedSkills: [InstalledSkillSnapshot] { workspaceSnapshot.installedSkills }

    var filteredSkills: [InstalledSkillSnapshot] {
        guard !searchText.isEmpty else { return installedSkills }
        return installedSkills.filter {
            $0.packageName.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.summary.localizedCaseInsensitiveContains(searchText)
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

    private var headerMetrics: [SkillLibraryMetric] {
        [
            SkillLibraryMetric(value: "\(workspaceSnapshot.summary.installedCount)",      title: "Installed", systemImage: "square.stack.3d.up"),
            SkillLibraryMetric(value: "\(workspaceSnapshot.summary.projectInstalledCount)", title: "Project",  systemImage: "folder"),
            SkillLibraryMetric(value: "\(workspaceSnapshot.summary.globalInstalledCount)", title: "Global",   systemImage: "globe"),
            SkillLibraryMetric(value: "\(skillDrafts.count)",                              title: "Drafts",   systemImage: "wand.and.stars")
        ]
    }

    var body: some View {
        SkillLibraryScreen(
            title: "Installed Skills",
            subtitle: "Audit what is live in each CLI environment, remove it cleanly by scope, and keep project and global installations explicit.",
            metrics: headerMetrics
        ) {
            HStack(spacing: 8) {
                Menu {
                    Button { chooseProjectRoot() }
                    label: { Label("Choose Project…", systemImage: "folder") }

                    if workspaceService.selectedProjectRootURL != nil {
                        Button(role: .destructive) { workspaceService.setSelectedProjectRootURL(nil) }
                        label: { Label("Clear Project", systemImage: "xmark.circle") }
                    }
                } label: {
                    Label(workspaceService.selectedProjectDisplayName, systemImage: "folder")
                }
                .menuStyle(.borderedButton)

                Divider().frame(height: 16)

                Button(action: fetchInstalledSkills) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .help("Refresh installed skills")

                Button(action: { showingAuditReport = true }) {
                    Image(systemName: "checklist")
                }
                .buttonStyle(.bordered)
                .help("Audit all installed skills")

                Divider().frame(height: 16)

                CLIStatusIndicator(manager: cliAccessManager) {
                    showingCLIAccessManager = true
                }
            }
        } content: {
            VStack(spacing: 0) {
                mainContentView
                nonFatalErrorBanner
            }
        }
        .sheet(isPresented: $showingAuditReport) {
            SkillAuditReportView(skills: installedSkills) { showingAuditReport = false }
        }
        .sheet(isPresented: $showingCLIAccessManager, onDismiss: { fetchInstalledSkills() }) {
            CLIAccessManagerView()
        }
        .onAppear { fetchInstalledSkills() }
        .onReceive(NotificationCenter.default.publisher(for: .skillInstallationsDidChange)) { _ in fetchInstalledSkills() }
        .onReceive(NotificationCenter.default.publisher(for: .skillProjectSelectionDidChange)) { _ in fetchInstalledSkills() }
        .onChange(of: searchText) { _, _ in syncSelection() }
        .task(id: selectedSkillID) {
            guard let skill = selectedSkill else {
                agentVisibility = []; sourceIntegrity = nil; effectiveness = nil
                return
            }
            isLoadingVisibility = true; isLoadingIntegrity = true; isLoadingEffectiveness = true
            agentVisibility = []; sourceIntegrity = nil; effectiveness = nil

            async let visTask = workspaceService.auditAgentVisibility(for: skill)
            async let intTask = workspaceService.auditSourceIntegrity(for: skill)
            async let effTask = workspaceService.auditEffectiveness(for: skill)

            let vis = await visTask
            guard !Task.isCancelled else { return }
            agentVisibility = vis; isLoadingVisibility = false

            let int = await intTask
            guard !Task.isCancelled else { return }
            sourceIntegrity = int; isLoadingIntegrity = false

            let eff = await effTask
            guard !Task.isCancelled else { return }
            effectiveness = eff; isLoadingEffectiveness = false
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
