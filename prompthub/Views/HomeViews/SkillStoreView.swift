import AlertToast
import AppKit
import PromptHubSkillKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SkillStoreView: View {
    let workspaceService = SkillWorkspaceService.shared
    @Query(sort: \Skill.updatedAt, order: .reverse) var skillDrafts: [Skill]
    @Binding var navigationState: WorkspaceNavigationState

    struct PendingCatalogInstall: Identifiable {
        let id = UUID()
        let skill: CatalogSkill
        let installationState: CatalogSkillInstallationState
        let preferredScope: SkillInstallScope
    }

    @Binding var searchText: String
    @State var isLoading = false
    @State var workspaceSnapshot = SkillStoreWorkspaceSnapshot.empty
    @State var errorMessage: String?
    @State var selectedSkillID: String?
    @State var isInstallingLocalSkill = false
    @ObservedObject var cliAccessManager = CLIDirectoryAccessManager.shared
    @State var showingCLIAccessManager = false
    @State var showingPrivateSourceInstall = false
    @State var showingGitHubInstall = false
    @State var installingSkillIDs: Set<String> = []
    @State var recentlyInstalledIDs: Set<String> = []
    @State var showToast = false
    @State var toastMessage = ""
    @State var toastType: AlertToast.AlertType = .regular
    @State var pendingInstall: PendingCatalogInstall?

    var availableSkills: [CatalogSkill]          { workspaceSnapshot.catalogSkills }
    var filteredAvailableSkills: [CatalogSkill] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return availableSkills }
        return availableSkills.filter { skill in
            skill.displayName.localizedCaseInsensitiveContains(query) ||
            skill.package.rawValue.localizedCaseInsensitiveContains(query) ||
            skill.summary.localizedCaseInsensitiveContains(query) ||
            (skill.displaySource?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
    var installedSkills: [InstalledSkillSnapshot]  { workspaceSnapshot.installedSkills }
    var installationRegistry: [String: CatalogSkillInstallationState] { workspaceSnapshot.installationRegistry }

    var selectedSkill: CatalogSkill? {
        if let selectedSkillID, let matched = filteredAvailableSkills.first(where: { $0.id == selectedSkillID }) {
            return matched
        }
        return filteredAvailableSkills.first
    }

    private var headerMetrics: [SkillLibraryMetric] {
        [
            SkillLibraryMetric(value: "\(workspaceSnapshot.summary.catalogCount)",   title: "Discover",   systemImage: "sparkles"),
            SkillLibraryMetric(value: "\(workspaceSnapshot.summary.installedCount)", title: "Installed",  systemImage: "square.stack.3d.up"),
            SkillLibraryMetric(value: "\(skillDrafts.count)",                        title: "Drafts",     systemImage: "wand.and.stars")
        ]
    }

    var body: some View {
        SkillLibraryScreen {
            mainContent
        }
        .sheet(isPresented: $showingCLIAccessManager, onDismiss: { fetchSkills() }) {
            CLIAccessManagerView()
        }
        .sheet(isPresented: $showingPrivateSourceInstall, onDismiss: { fetchSkills() }) {
            PrivateSourceInstallSheet()
        }
        .sheet(isPresented: $showingGitHubInstall, onDismiss: { fetchSkills() }) {
            GitHubRepoInstallSheet()
        }
        .onAppear {
            fetchSkills()
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillInstallationsDidChange)) { _ in fetchSkills() }
        .onReceive(NotificationCenter.default.publisher(for: .skillProjectSelectionDidChange)) { _ in fetchSkills() }
        .onChange(of: workspaceSnapshot.catalogSkills.map(\.id)) { _, _ in
            syncSelection()
        }
        .onChange(of: searchText) { _, _ in
            syncSelection()
        }
        .alert("Skill Store", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .toast(isPresenting: $showToast) {
            AlertToast(type: toastType, title: toastMessage)
        }
        .sheet(item: $pendingInstall) { pending in
            CatalogSkillInstallSheet(
                skill: pending.skill,
                installationState: pending.installationState,
                initialScope: pending.preferredScope,
                initialProjectRootURL: workspaceService.selectedProjectRootURL
            ) { scope, agents, projectRootURL in
                if scope == .project { workspaceService.setSelectedProjectRootURL(projectRootURL) }
                pendingInstall = nil
                installSkill(pending.skill, scope: scope, targetAgents: agents)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    func syncSelection() {
        let ids = Set(filteredAvailableSkills.map(\.id))
        guard !ids.isEmpty else {
            selectedSkillID = nil
            return
        }
        if let selectedSkillID, ids.contains(selectedSkillID) {
            return
        }
        selectedSkillID = filteredAvailableSkills.first?.id
    }
}
