import AlertToast
import PromptHubSkillKit
import SwiftData
import SwiftUI
import WhatsNewKit

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Query var prompts: [Prompt]
    @Query var skillDrafts: [Skill]
    let skillDraftService = SkillDraftService.shared
    @StateObject private var installedWorkspaceStore = InstalledSkillsWorkspaceStore()

    @State var navigationState = WorkspaceNavigationState()
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State var searchText = ""
    @State var galleryPrompts: [GalleryPrompt] = []
    @State var isLoading = true
    @State var showToast = false
    @State var toastMessage = ""
    @State var toastType: AlertToast.AlertType = .regular
    @State private var skillsScopeFilter: SkillsSidebarScopeFilter = .allInstalled
    @State private var skillsSourceFilter: SkillsSidebarSourceFilter = .all
    @State private var skillsAgentFilter: AgentWorkflow?
    @State var whatsNew: WhatsNew? = nil
    @EnvironmentObject var appSettings: AppSettings
    var currentAppVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown" }

    private var currentPrompt: Prompt? {
        guard case .prompt(let promptID) = navigationState.detailSelection else { return nil }
        return prompts.first(where: { $0.id == promptID })
    }

    private var currentSkill: Skill? {
        guard let skillID = navigationState.selectedSkillDraftID else { return nil }
        return skillDrafts.first(where: { $0.id == skillID })
    }

    private var searchPrompt: String {
        if navigationState.domain == .special {
            return ""
        }

        switch navigationState.domain {
        case .prompts:
            return "Search prompts..."
        case .skills:
            switch navigationState.skillLens {
            case .installed: return "Search installed skills..."
            case .drafts:    return "Search skills..."
            case .store:     return "Search skill catalog..."
            }
        case .agents:
            return "Search workspaces..."
        case .special:
            return ""
        }
    }

    private var showsToolbarSearch: Bool {
        switch navigationState.domain {
        case .prompts:
            return currentPrompt == nil
        case .skills:
            return true
        case .agents, .special:
            return false
        }
    }

    private var navigationTitle: String {
        switch navigationState.domain {
        case .special:
            switch navigationState.specialPage {
            case .settings:     return "Settings"
            case .onboarding:   return "Get Started"
            case nil:           return ""
            }
        case .prompts:
            if currentPrompt != nil { return "" }
            switch navigationState.promptLens {
            case .all:     return "All Prompts"
            case .mine:    return "My Prompts"
            case .shared:  return "Shared with Me"
            case .explore: return "Explore Gallery"
            }
        case .skills:
            switch navigationState.skillLens {
                case .installed: return "Installed Skills"
                case .drafts:    return "My Skills"
                case .store:     return "Skill Store"
            }
        case .agents:
            return "Workspaces"
        }
    }

    private var minimumMainWindowContentSize: CGSize {
        switch navigationState.domain {
        case .special where navigationState.specialPage == .onboarding:
            return CGSize(width: PH.Layout.mainWindowOnboardingMinWidth, height: 480)
        case .prompts where currentPrompt != nil:
            return CGSize(width: PH.Layout.mainWindowPromptDetailMinWidth, height: PH.Layout.mainWindowMinHeightCap)
        case .skills where navigationState.skillLens == .drafts:
            return CGSize(width: PH.Layout.mainWindowSkillDetailMinWidth, height: PH.Layout.mainWindowMinHeightCap)
        case .skills:
            return CGSize(width: PH.Layout.mainWindowSkillsMinWidth, height: PH.Layout.mainWindowMinHeightCap)
        case .agents:
            return CGSize(width: PH.Layout.mainWindowSkillsMinWidth, height: PH.Layout.mainWindowMinHeightCap)
        case .prompts:
            return CGSize(width: PH.Layout.mainWindowPromptsMinWidth, height: PH.Layout.mainWindowMinHeightCap)
        case .special:
            return CGSize(width: PH.Layout.mainWindowPromptsMinWidth, height: PH.Layout.mainWindowMinHeightCap)
        }
    }

    private var windowSizingDebugName: String {
        switch navigationState.domain {
        case .prompts:
            switch navigationState.detailSelection {
            case .prompt:
                return "promptDetail"
            case nil:
                switch navigationState.promptLens {
                case .all:     return "allPrompts"
                case .mine:    return "myPrompts"
                case .shared:  return "sharedPrompts"
                case .explore: return "explorePrompts"
                }
            }
        case .skills:
            switch navigationState.skillLens {
            case .drafts where currentSkill != nil:
                return "skillDetail"
            case .installed:
                return "installedSkills"
            case .drafts:
                return "mySkills"
            case .store:
                return "skillStore"
            }
        case .agents:
            return "agents"
        case .special:
            switch navigationState.specialPage {
            case .settings:     return "settings"
            case .onboarding:   return "onboarding"
            case nil:           return "special"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            PromptSideBar(
                installedWorkspaceStore: installedWorkspaceStore,
                navigationState: $navigationState,
                skillsAgentFilter: $skillsAgentFilter,
                onCreateNewPrompt: createNewPrompt,
                onCreateNewSkill: createNewSkillDraft
            )
            .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 275)
            .frame(minWidth: 210)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
        } detail: {
            NavigationStack {
                detailContent
            }
            .navigationTitle(navigationTitle)
            .toolbar { toolbarContent }
            .onKeyPress(.escape) {
                if currentPrompt != nil {
                    navigationState.returnFromDetail()
                    return .handled
                }
                if navigationState.domain == .special {
                    navigationState.returnFromSpecial()
                    return .handled
                }
                return .ignored
            }
            .toast(isPresenting: $showToast) { AlertToast(type: toastType, title: toastMessage) }
            .onAppear {
                loadGalleryPrompts()
                checkForWhatsNew()
                refreshInstalledWorkspace()
                if !onboardingCompleted {
                    navigationState.showSpecial(.onboarding)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .skillInstallationsDidChange)) { _ in
                refreshInstalledWorkspace()
            }
            .onReceive(NotificationCenter.default.publisher(for: .skillProjectSelectionDidChange)) { _ in
                refreshInstalledWorkspace()
            }
            .onReceive(NotificationCenter.default.publisher(for: .searchNavigationRequested)) { notification in
                guard let target = SearchNavigationRequest.from(notification) else { return }
                handleSearchNavigation(target)
            }
            .sheet(whatsNew: self.$whatsNew, onDismiss: { appSettings.lastShownWhatsNewVersion = self.currentAppVersion })
        }
        .enforceWindowMinimumContentSize(minimumMainWindowContentSize, debugName: windowSizingDebugName)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch navigationState.domain {
        case .special:
            switch navigationState.specialPage {
            case .settings:
                SettingsView()
            case .onboarding:
                OnboardingView(
                    onFinish: { navigationState.showPrompts(.all) },
                    onCLI: { navigationState.showSpecial(.settings) },
                    onSettings: { navigationState.showSpecial(.settings) }
                )
            case nil:
                EmptyView()
            }
        case .prompts:
            if let currentPrompt {
                PromptDetail(
                    prompt: currentPrompt,
                    onPromoteToSkill: { skill in navigationState.showSkillDraftWorkspace(select: skill.id) },
                    onDeletePrompt: { prompt in deletePrompt(prompt) }
                )
            } else {
                promptsContent
            }
        case .skills:
            SkillsRootView(
                installedWorkspaceStore: installedWorkspaceStore,
                navigationState: $navigationState,
                searchText: $searchText,
                skillsScopeFilter: $skillsScopeFilter,
                skillsSourceFilter: $skillsSourceFilter,
                skillsAgentFilter: $skillsAgentFilter
            )
        case .agents:
            SettingsView()
        }
    }

    @ViewBuilder
    private var promptsContent: some View {
        switch navigationState.promptLens {
        case .all:
            AllPromptsView(
                searchText: searchText,
                galleryPrompts: galleryPrompts,
                isLoading: isLoading,
                showToastMsg: showToastMessage,
                copyPromptToClipboard: copyToClipboard,
                onCreatePrompt: createNewPrompt
            )
        case .mine:
            MyPromptsView(
                searchText: searchText,
                showToastMsg: showToastMessage,
                copyPromptToClipboard: copyToClipboard,
                onCreatePrompt: createNewPrompt
            )
        case .shared:
            SharedCreationsView(searchText: searchText, showToastMsg: showToastMessage, copyPromptToClipboard: copyToClipboard)
        case .explore:
            ExploreView(
                searchText: searchText,
                galleryPrompts: galleryPrompts,
                isLoading: isLoading,
                showToastMsg: showToastMessage,
                copyPromptToClipboard: copyToClipboard,
                onRefreshGallery: loadGalleryPrompts
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            // Tabs removed - navigation handled via sidebar
            EmptyView()
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if showsToolbarSearch {
                InlineSearchField(text: $searchText, prompt: searchPrompt)
                    .frame(width: 240)
            }

            switch navigationState.domain {
            case .skills:
                Button(action: createNewSkillDraft) { Label("New Skill Draft", systemImage: "plus") }
                    .keyboardShortcut("n", modifiers: .command)
                    .help("Create a new skill draft (Cmd+N)")
            case .special:
                EmptyView()
            default:
                Button(action: createNewPrompt) { Label("New Prompt", systemImage: "plus") }
                    .keyboardShortcut("n", modifiers: .command)
                    .help("Create a new prompt (Cmd+N)")
            }
        }
    }

    private func refreshInstalledWorkspace() {
        installedWorkspaceStore.refresh(
            authoredDraftCount: skillDrafts.count,
            hasCLIAccess: CLIDirectoryAccessManager.shared.anyAccessGranted
        )
    }
}

#Preview {
    ContentView().modelContainer(for: [Prompt.self, PromptHistory.self, Skill.self, SkillVersion.self], inMemory: true)
}
