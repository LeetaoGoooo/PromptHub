import AlertToast
import SwiftData
import SwiftUI
import WhatsNewKit

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Query var prompts: [Prompt]
    @Query var skillDrafts: [Skill]
    let skillDraftService = SkillDraftService.shared

    @State var promptSelection: PromptSelection = .allPrompts
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var searchText = ""
    @State var galleryPrompts: [GalleryPrompt] = []
    @State var isLoading = true
    @State var showToast = false
    @State var toastMessage = ""
    @State var toastType: AlertToast.AlertType = .regular
    @State private var showingPromptRender = false
    @State var whatsNew: WhatsNew? = nil
    @EnvironmentObject var appSettings: AppSettings

    var currentAppVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown" }

    private var searchPrompt: String {
        switch promptSelection {
        case .mySkills, .skill:          return "Search skills..."
        case .skillStore:                return "Search skill catalog..."
        case .installedSkills:           return "Search installed skills..."
        case .cliDashboard, .settings, .onboarding:
            return ""
        default:                         return "Search prompts..."
        }
    }

    private var isSidebarSearchEnabled: Bool {
        switch promptSelection {
        case .cliDashboard, .settings, .onboarding:
            return false
        default:
            return true
        }
    }

    private var isSkillsSelection: Bool {
        if case .mySkills = promptSelection { return true }
        if case .skillStore = promptSelection { return true }
        if case .installedSkills = promptSelection { return true }
        if case .skill = promptSelection { return true }
        return false
    }

    private var navigationTitle: String {
        switch promptSelection {
        case .settings:          return "Settings"
        case .allPrompts:        return "All Prompts"
        case .mine:              return "My Prompts"
        case .shared:            return "Shared with Me"
        case .explore:           return "Explore Gallery"
        case .mySkills:          return "My Skills"
        case .skillStore:        return "Skill Store"
        case .installedSkills:   return "Installed Skills"
        case .cliDashboard:      return "CLI Integration"
        case .onboarding:        return "Get Started"
        case .prompt(let p):     return p.name
        case .skill(let s):      return s.displayName
        }
    }

    var body: some View {
        NavigationSplitView {
            PromptSideBar(
                promptSelection: $promptSelection,
                searchText: $searchText,
                searchPlaceholder: searchPrompt,
                isSearchEnabled: isSidebarSearchEnabled,
                onCreateNewPrompt: createNewPrompt,
                onCreateNewSkill: createNewSkillDraft
            )
            .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 275)
            .frame(minWidth: 210)
        } detail: {
            Group {
                if isSkillsSelection {
                    SkillsRootView(promptSelection: $promptSelection, searchText: searchText)
                } else {
                    NavigationStack {
                        switch promptSelection {
                        case .settings:
                            SettingsView()
                        case .cliDashboard:
                            CLIDashboardView()
                        case .onboarding:
                            OnboardingView(onFinish: { promptSelection = .allPrompts },
                                           onCLI: { promptSelection = .cliDashboard },
                                           onSettings: { promptSelection = .settings })
                        case .prompt(let selectedPrompt):
                            PromptDetail(prompt: selectedPrompt, onPromoteToSkill: { skill in promptSelection = .skill(skill) })
                        default:
                            contentForDefaultSelection
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar { toolbarContent }
            .onKeyPress(.escape) {
                if case .prompt = promptSelection { promptSelection = .allPrompts; return .handled }
                if case .skill = promptSelection  { promptSelection = .mySkills; return .handled }
                if case .cliDashboard = promptSelection { promptSelection = .allPrompts; return .handled }
                if case .onboarding = promptSelection  { promptSelection = .allPrompts; return .handled }
                if case .settings = promptSelection { promptSelection = .allPrompts; return .handled }
                return .ignored
            }
            .toast(isPresenting: $showToast) { AlertToast(type: toastType, title: toastMessage) }
            .onAppear {
                loadGalleryPrompts()
                checkForWhatsNew()
                if !onboardingCompleted {
                    promptSelection = .onboarding
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .searchNavigationRequested)) { notification in
                guard let target = SearchNavigationRequest.from(notification) else { return }
                handleSearchNavigation(target)
            }
            .sheet(whatsNew: self.$whatsNew, onDismiss: { appSettings.lastShownWhatsNewVersion = self.currentAppVersion })
            .sheet(isPresented: $showingPromptRender) { PromptRenderSheet { showingPromptRender = false } }
        }
    }

    @ViewBuilder
    private var contentForDefaultSelection: some View {
        switch promptSelection {
        case .allPrompts:
            AllPromptsView(searchText: searchText, galleryPrompts: galleryPrompts, isLoading: isLoading, showToastMsg: showToastMessage, copyPromptToClipboard: copyToClipboard, onSelectPrompt: { promptSelection = .prompt($0) }, onCreatePrompt: createNewPrompt, onRenderPrompt: { showingPromptRender = true })
        case .mine:
            MyPromptsView(searchText: searchText, showToastMsg: showToastMessage, copyPromptToClipboard: copyToClipboard, onSelectPrompt: { promptSelection = .prompt($0) }, onCreatePrompt: createNewPrompt, onRenderPrompt: { showingPromptRender = true })
        case .shared:
            SharedCreationsView(searchText: searchText, showToastMsg: showToastMessage, copyPromptToClipboard: copyToClipboard)
        case .explore:
            ExploreView(searchText: searchText, galleryPrompts: galleryPrompts, isLoading: isLoading, showToastMsg: showToastMessage, copyPromptToClipboard: copyToClipboard, onRefreshGallery: loadGalleryPrompts)
        default:
            EmptyView()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            switch promptSelection {
            case .mySkills:
                Button(action: createNewSkillDraft) { Label("New Skill Draft", systemImage: "plus") }
                    .keyboardShortcut("n", modifiers: .command).help("Create a new skill draft (Cmd+N)")
            case .skillStore, .installedSkills:
                EmptyView()
            default:
                Button(action: createNewPrompt) { Label("New Prompt", systemImage: "plus") }
                    .keyboardShortcut("n", modifiers: .command).help("Create a new prompt (Cmd+N)")
            }
        }
        ToolbarItem(placement: .secondaryAction) {
            switch promptSelection {
            case .allPrompts, .mine, .prompt:
                Button { showingPromptRender = true } label: { Label("Render Prompt…", systemImage: "play.rectangle") }
                    .help("Render a prompt with variable substitution")
            default:
                EmptyView()
            }
        }
    }
}

#Preview {
    ContentView().modelContainer(for: [Prompt.self, PromptHistory.self, Skill.self, SkillVersion.self], inMemory: true)
}
