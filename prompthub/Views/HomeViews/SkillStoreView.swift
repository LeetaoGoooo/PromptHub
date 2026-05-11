import AlertToast
import AppKit
import PromptHubSkillKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SkillStoreView: View {
    let workspaceService = SkillWorkspaceService.shared
    @Query(sort: \Skill.updatedAt, order: .reverse) var skillDrafts: [Skill]
    @Binding var promptSelection: PromptSelection

    struct PendingCatalogInstall: Identifiable {
        let id = UUID()
        let skill: CatalogSkill
        let installationState: CatalogSkillInstallationState
        let preferredScope: SkillInstallScope
    }

    let searchText: String
    @State var isLoading = false
    @State var workspaceSnapshot = SkillStoreWorkspaceSnapshot.empty
    @State var errorMessage: String?
    @State var selectedSkillID: String?
    @State var isInstallingLocalSkill = false
    @ObservedObject var cliAccessManager = CLIDirectoryAccessManager.shared
    @State var showingCLIAccessManager = false
    @State var showingPrivateSourceInstall = false
    @State var installingSkillIDs: Set<String> = []
    @State var recentlyInstalledIDs: Set<String> = []
    @State var showToast = false
    @State var toastMessage = ""
    @State var toastType: AlertToast.AlertType = .regular
    @State var pendingInstall: PendingCatalogInstall?
    @State var searchTask: Task<Void, Never>?

    var availableSkills: [CatalogSkill]          { workspaceSnapshot.catalogSkills }
    var installedSkills: [InstalledSkillSnapshot]  { workspaceSnapshot.installedSkills }
    var installationRegistry: [String: CatalogSkillInstallationState] { workspaceSnapshot.installationRegistry }

    var selectedSkill: CatalogSkill? {
        if let selectedSkillID, let matched = availableSkills.first(where: { $0.id == selectedSkillID }) {
            return matched
        }
        return availableSkills.first
    }

    private var headerMetrics: [SkillLibraryMetric] {
        [
            SkillLibraryMetric(value: "\(workspaceSnapshot.summary.catalogCount)",   title: "Discover",   systemImage: "sparkles"),
            SkillLibraryMetric(value: "\(workspaceSnapshot.summary.installedCount)", title: "Installed",  systemImage: "square.stack.3d.up"),
            SkillLibraryMetric(value: "\(skillDrafts.count)",                        title: "Drafts",     systemImage: "wand.and.stars")
        ]
    }

    var body: some View {
        SkillLibraryScreen(
            title: "Skill Store",
            subtitle: "Discover reusable skills, inspect installation coverage, and bring local SKILL.md packages into your workspace without leaving PromptHub.",
            metrics: headerMetrics
        ) {
            accessoryBar
        } content: {
            mainContent
        }
        .onChange(of: searchText) { _, newValue in debouncedSearch(query: newValue) }
        .sheet(isPresented: $showingCLIAccessManager, onDismiss: { fetchSkills(query: searchText) }) {
            CLIAccessManagerView()
        }
        .sheet(isPresented: $showingPrivateSourceInstall, onDismiss: { fetchSkills(query: searchText) }) {
            PrivateSourceInstallSheet()
        }
        .onAppear { fetchSkills() }
        .onReceive(NotificationCenter.default.publisher(for: .skillInstallationsDidChange)) { _ in fetchSkills(query: searchText) }
        .onReceive(NotificationCenter.default.publisher(for: .skillProjectSelectionDidChange)) { _ in fetchSkills(query: searchText) }
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
}
