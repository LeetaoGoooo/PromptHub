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
    case prompt(Prompt)
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
        case (.skillStore, .skillStore): return true
        case (.installedSkills, .installedSkills): return true
        case (.settings, .settings): return true
        case (.prompt(let lhsPrompt), .prompt(let rhsPrompt)):
            return lhsPrompt.id == rhsPrompt.id
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
        case .skillStore: hasher.combine("skillStore")
        case .installedSkills: hasher.combine("installedSkills")
        case .settings: hasher.combine("settings")
        case .prompt(let prompt):
            hasher.combine("prompt")
            hasher.combine(prompt.id)
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    
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
    
    var body: some View {
        NavigationSplitView {
            PromptSideBar(
                promptSelection: $promptSelection,
                onCreateNewPrompt: createNewPrompt
            ).frame(minWidth: 200)
        } detail: {
            NavigationStack {
                switch promptSelection {
                case .settings:
                    SettingsView()
                case .skillStore:
                    SkillStoreView()
                case .installedSkills:
                    InstalledSkillsView()
                        .navigationTitle("Installed Skills")
                case .prompt(let selectedPrompt):
                    PromptDetail(prompt: selectedPrompt)
                        .navigationTitle(selectedPrompt.name)
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
                            .navigationTitle("All Prompts")
                            
                        case .mine:
                            MyPromptsView(
                                searchText: searchText,
                                showToastMsg: showToastMessage,
                                copyPromptToClipboard: copyToClipboard,
                                onSelectPrompt: { prompt in
                                    promptSelection = .prompt(prompt)
                                }
                            )
                            .navigationTitle("My Prompts")
                            
                        case .shared:
                            SharedCreationsView(
                                searchText: searchText,
                                showToastMsg: showToastMessage,
                                copyPromptToClipboard: copyToClipboard
                            )
                            .navigationTitle("Shared with Me")
                            
                        case .explore:
                            ExploreView(
                                searchText: searchText,
                                galleryPrompts: galleryPrompts,
                                isLoading: isLoading,
                                showToastMsg: showToastMessage,
                                copyPromptToClipboard: copyToClipboard
                            )
                            .navigationTitle("Explore Gallery")
                            
                        default:
                            EmptyView()
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .toolbar, prompt: "Search...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createNewPrompt) {
                        Label("New Prompt", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    .help("Create a new prompt (Cmd+N)")
                }
            }
            .onKeyPress(.escape) {
                if case .prompt(_) = promptSelection {
                    promptSelection = .allPrompts
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
                        image: .init(systemName: "sidebar.left"),
                        title: WhatsNew.Text("New Pro Navigation"),
                        subtitle: WhatsNew.Text("A completely redesigned sidebar organization for better workflow.")
                    ),
                    .init(
                        image: .init(systemName: "magnifyingglass"),
                        title: WhatsNew.Text("Native Search"),
                        subtitle: WhatsNew.Text("Search efficiently using the native toolbar search.")
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
}

#Preview {
    ContentView()
        .modelContainer(for: [Prompt.self, PromptHistory.self], inMemory: true)
}
