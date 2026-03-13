import AlertToast
import SwiftData
import SwiftUI
import WhatsNewKit

// Define selection state that can handle both "All Prompts" and specific prompts
enum PromptSelection: Hashable, Equatable {
    case allPrompts
    case mine
    case shared
    case explore
    case mySkills
    case prompt(Prompt)
    case skill(Skill)
    case skillStore
    case installedSkills
    case settings
    
    // Custom equality implementation
    static func == (lhs: PromptSelection, rhs: PromptSelection) -> Bool {
        switch (lhs, rhs) {
        case (.allPrompts, .allPrompts): return true
        case (.mine, .mine): return true
        case (.shared, .shared): return true
        case (.explore, .explore): return true
        case (.mySkills, .mySkills): return true
        case (.skillStore, .skillStore): return true
        case (.installedSkills, .installedSkills): return true
        case (.settings, .settings): return true
        case (.prompt(let lhsPrompt), .prompt(let rhsPrompt)):
            return lhsPrompt.id == rhsPrompt.id
        case (.skill(let lhsSkill), .skill(let rhsSkill)):
            return lhsSkill.id == rhsSkill.id
        default:
            return false
        }
    }
    
    // Custom hash implementation
    func hash(into hasher: inout Hasher) {
        switch self {
        case .allPrompts: hasher.combine("allPrompts")
        case .mine: hasher.combine("mine")
        case .shared: hasher.combine("shared")
        case .explore: hasher.combine("explore")
        case .mySkills: hasher.combine("mySkills")
        case .skillStore: hasher.combine("skillStore")
        case .installedSkills: hasher.combine("installedSkills")
        case .settings: hasher.combine("settings")
        case .prompt(let prompt):
            hasher.combine("prompt")
            hasher.combine(prompt.id)
        case .skill(let skill):
            hasher.combine("skill")
            hasher.combine(skill.id)
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var prompts: [Prompt]
    @Query private var skillDrafts: [Skill]
    private let skillDraftService = SkillDraftService.shared
    
    @State private var promptSelection: PromptSelection = .allPrompts
    
    // Search & Data State
    @State private var searchText = ""
    @State private var galleryPrompts: [GalleryPrompt] = []
    @State private var isLoading = true
    
    // Toast State
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: AlertToast.AlertType = .regular
    
    @State var whatsNew: WhatsNew? = nil
    
    @EnvironmentObject var appSettings: AppSettings
    
    private var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var searchPrompt: String {
        switch promptSelection {
        case .mySkills, .skill:
            return "Search skills..."
        case .skillStore:
            return "Search skill catalog..."
        case .installedSkills:
            return "Search installed skills..."
        default:
            return "Search prompts..."
        }
    }

    private var isSkillsSelection: Bool {
        switch promptSelection {
        case .mySkills, .skillStore, .installedSkills, .skill:
            return true
        default:
            return false
        }
    }

    private var navigationTitle: String {
        switch promptSelection {
        case .settings:
            return "Settings"
        case .allPrompts:
            return "All Prompts"
        case .mine:
            return "My Prompts"
        case .shared:
            return "Shared with Me"
        case .explore:
            return "Explore Gallery"
        case .mySkills:
            return "My Skills"
        case .skillStore:
            return "Skill Store"
        case .installedSkills:
            return "Installed Skills"
        case .prompt(let selectedPrompt):
            return selectedPrompt.name
        case .skill(let selectedSkill):
            return selectedSkill.displayName
        }
    }
    
    var body: some View {
        NavigationSplitView {
            PromptSideBar(
                promptSelection: $promptSelection,
                onCreateNewPrompt: createNewPrompt,
                onCreateNewSkill: createNewSkillDraft
            )
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
            .frame(minWidth: 170)
        } detail: {
            Group {
                if isSkillsSelection {
                    SkillsRootView(
                        promptSelection: $promptSelection,
                        searchText: searchText
                    )
                } else {
                    NavigationStack {
                        switch promptSelection {
                        case .settings:
                            SettingsView()
                        case .prompt(let selectedPrompt):
                            PromptDetail(
                                prompt: selectedPrompt,
                                onPromoteToSkill: { skill in
                                    promptSelection = .skill(skill)
                                }
                            )
                        default:
                            Group {
                                switch promptSelection {
                                case .allPrompts:
                                    AllPromptsView(
                                        searchText: searchText,
                                        galleryPrompts: galleryPrompts,
                                        isLoading: isLoading,
                                        showToastMsg: showToastMessage,
                                        copyPromptToClipboard: copyToClipboard
                                    )
                                    
                                case .mine:
                                    MyPromptsView(
                                        searchText: searchText,
                                        showToastMsg: showToastMessage,
                                        copyPromptToClipboard: copyToClipboard,
                                        onSelectPrompt: { prompt in
                                            promptSelection = .prompt(prompt)
                                        }
                                    )
                                    
                                case .shared:
                                    SharedCreationsView(
                                        searchText: searchText,
                                        showToastMsg: showToastMessage,
                                        copyPromptToClipboard: copyToClipboard
                                    )
                                    
                                case .explore:
                                    ExploreView(
                                        searchText: searchText,
                                        galleryPrompts: galleryPrompts,
                                        isLoading: isLoading,
                                        showToastMsg: showToastMessage,
                                        copyPromptToClipboard: copyToClipboard
                                    )

                                default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .searchable(text: $searchText, placement: .toolbar, prompt: searchPrompt)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    switch promptSelection {
                    case .mySkills:
                        Button(action: createNewSkillDraft) {
                            Label("New Skill Draft", systemImage: "plus")
                        }
                        .keyboardShortcut("n", modifiers: .command)
                        .help("Create a new skill draft (Cmd+N)")

                    case .skillStore, .installedSkills:
                        EmptyView()

                    default:
                        Button(action: createNewPrompt) {
                            Label("New Prompt", systemImage: "plus")
                        }
                        .keyboardShortcut("n", modifiers: .command)
                        .help("Create a new prompt (Cmd+N)")
                    }
                }
            }
            .onKeyPress(.escape) {
                if case .prompt(_) = promptSelection {
                    promptSelection = .allPrompts
                    return .handled
                }
                if case .skill(_) = promptSelection {
                    promptSelection = .mySkills
                    return .handled
                }
                return .ignored
            }
            .toast(isPresenting: $showToast) {
                AlertToast(type: toastType, title: toastMessage)
            }
            .onAppear {
                loadGalleryPrompts()
                checkForWhatsNew()
            }
            .onReceive(NotificationCenter.default.publisher(for: .searchNavigationRequested)) { notification in
                guard let target = SearchNavigationRequest.from(notification) else {
                    return
                }
                handleSearchNavigation(target)
            }
            .sheet(whatsNew: self.$whatsNew, onDismiss: {
                appSettings.lastShownWhatsNewVersion = self.currentAppVersion
            })
        }
    }
    
    private func loadGalleryPrompts() {
        isLoading = true
        DispatchQueue.main.async {
            self.galleryPrompts = BuiltInAgents.agents.map { $0.toGalleryPrompt() }
            self.isLoading = false
        }
    }
    
    private func showToastMessage(_ message: String, _ type: AlertToast.AlertType) {
        toastMessage = message
        toastType = type
        showToast = true
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showToastMessage("Copied to clipboard", .complete(.green))
    }
    
    private func checkForWhatsNew() {
        let lastShownVersion = appSettings.lastShownWhatsNewVersion
        
        if lastShownVersion != currentAppVersion {
            self.whatsNew = WhatsNew(
                version: WhatsNew.Version(stringLiteral: currentAppVersion),
                title: WhatsNew.Title(stringLiteral: "What's New in PromptHub!"),
                features: [
                    .init(
                        image: .init(systemName: "wand.and.stars"),
                        title: WhatsNew.Text("Skill Library"),
                        subtitle: WhatsNew.Text("Browse, install, and manage AI skills from the new Skill Store with project & global scope support.")
                    ),
                    .init(
                        image: .init(systemName: "doc.text.magnifyingglass"),
                        title: WhatsNew.Text("Skill Drafts"),
                        subtitle: WhatsNew.Text("Create and edit skill drafts — promote any prompt into a reusable skill with one click.")
                    ),
                    .init(
                        image: .init(systemName: "magnifyingglass"),
                        title: WhatsNew.Text("Enhanced Search"),
                        subtitle: WhatsNew.Text("Search now covers skill drafts, supports navigation targets, and features a cleaner sectioned layout.")
                    ),
                    .init(
                        image: .init(systemName: "arrow.triangle.2.circlepath"),
                        title: WhatsNew.Text("Workspace Sync"),
                        subtitle: WhatsNew.Text("New workspace service keeps installed skills in sync across project and global scopes.")
                    )
                ],
                primaryAction: .init(
                    title: WhatsNew.Text("Got It"),
                    onDismiss: {
                        appSettings.lastShownWhatsNewVersion = self.currentAppVersion
                    }
                )
            )
        } else {
            self.whatsNew = nil
        }
    }
    
    private func createNewPrompt() {
        let newPrompt = Prompt(name: "Untitled Prompt")
        modelContext.insert(newPrompt)
        
        // Create initial history item version 1
        let initialHistory = newPrompt.createHistory(prompt: "", version: 1)
        modelContext.insert(initialHistory)
        
        do {
            try modelContext.save()
            // Navigate to the new prompt
            promptSelection = .prompt(newPrompt)
        } catch {
            showToastMessage("Failed to create new prompt", .error(.red))
        }
    }

    private func createNewSkillDraft() {
        do {
            let draft = try skillDraftService.createDraft(in: modelContext)
            promptSelection = .skill(draft)
        } catch {
            showToastMessage("Failed to create new skill draft", .error(.red))
        }
    }

    private func handleSearchNavigation(_ target: SearchNavigationTarget) {
        switch target {
        case .prompt(let promptID):
            if let prompt = prompts.first(where: { $0.id == promptID }) {
                promptSelection = .prompt(prompt)
            }
        case .skill(let skillID):
            if let skill = skillDrafts.first(where: { $0.id == skillID }) {
                promptSelection = .skill(skill)
            }
        }
    }

}

#Preview {
    ContentView()
        .modelContainer(for: [Prompt.self, PromptHistory.self, Skill.self, SkillVersion.self], inMemory: true)
}
