//
//  ContentView.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import SwiftData
import SwiftUI
import WhatsNewKit

// Define selection state that can handle both "All Prompts" and specific prompts
enum PromptSelection: Hashable, Equatable {
    case allPrompts
    case prompt(Prompt)
    
    // Custom equality implementation
    static func == (lhs: PromptSelection, rhs: PromptSelection) -> Bool {
        switch (lhs, rhs) {
        case (.allPrompts, .allPrompts):
            return true
        case (.prompt(let lhsPrompt), .prompt(let rhsPrompt)):
            return lhsPrompt.id == rhsPrompt.id
        default:
            return false
        }
    }
    
    // Custom hash implementation
    func hash(into hasher: inout Hasher) {
        switch self {
        case .allPrompts:
            hasher.combine("allPrompts")
        case .prompt(let prompt):
            hasher.combine("prompt")
            hasher.combine(prompt.id)
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isPresentingNewPromptDialog = false
    @State private var promptSelection: PromptSelection = .allPrompts

    @State private var isEditingPromptSheetPresented = false

    @State var whatsNew: WhatsNew? = nil

    @EnvironmentObject var appSettings: AppSettings

    private var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var body: some View {
        NavigationSplitView {
            PromptSideBar(
                isEditingPromptSheetPresented: $isEditingPromptSheetPresented,
                promptSelection: $promptSelection, isPresentingNewPromptDialog: $isPresentingNewPromptDialog
            ).frame(minWidth: 200)
        } detail: {
            switch promptSelection {
            case .allPrompts:
                UnifiedPromptBrowserView()
                    .navigationTitle("All Prompts")
            case .prompt(let selectedPrompt):
                PromptDetail(prompt: selectedPrompt)
                    .navigationTitle(selectedPrompt.name)
            }
        }
        .onKeyPress(.escape) {
            if case .prompt(_) = promptSelection {
                promptSelection = .allPrompts
                return .handled
            }
            return .ignored
        }
        .sheet(isPresented: $isPresentingNewPromptDialog) {
            NewPromptDialog(isPresented: $isPresentingNewPromptDialog)
        }
        .sheet(isPresented: $isEditingPromptSheetPresented) {
            if case .prompt(let currentPrompt) = promptSelection {
                EditPromptSheet(prompt: currentPrompt, isPresented: self.$isEditingPromptSheetPresented)
                    .frame(minWidth: 400, idealWidth: 500, minHeight: 350, idealHeight: 450)
            }
        }
        .onAppear {
            let lastShownVersion = appSettings.lastShownWhatsNewVersion
            
            if lastShownVersion != currentAppVersion {
                self.whatsNew = WhatsNew(
                    version: WhatsNew.Version(stringLiteral: currentAppVersion),
                    title: WhatsNew.Title(stringLiteral: "What's New in PromptBox \(currentAppVersion)!"),
                    features: [

                        .init(
                            image: .init(
                                systemName: "command",
                                foregroundColor: .blue
                            ),
                            title: WhatsNew.Text("Keyboard Shortcuts"),
                            subtitle: WhatsNew.Text("Access PromptHub quickly from anywhere with the new keyboard shortcuts. Configure your own shortcuts in Settings to trigger the quick search feature.")
                        ),

                        .init(
                            image: .init(
                                systemName: "magnifyingglass",
                                foregroundColor: .purple
                            ),
                            title: WhatsNew.Text("Enhanced Search"),
                            subtitle: WhatsNew.Text("Find your prompts faster with the new global search feature. Search across all your prompts from anywhere in the app with a convenient search window.")
                        ),

                        .init(
                            image: .init(
                                systemName: "gearshape",
                                foregroundColor: .green
                            ),
                            title: WhatsNew.Text("Improved Settings Layout"),
                            subtitle: WhatsNew.Text("Settings have been reorganized and improved for better usability. Keyboard shortcuts settings now have better visual distinction and consistent layout.")
                        ),

                        .init(
                            image: .init(
                                systemName: "slider.horizontal.3",
                                foregroundColor: .orange
                            ),
                            title: WhatsNew.Text("Better Model Management"),
                            subtitle: WhatsNew.Text("Enhanced model configuration with intuitive service management. Configure multiple AI services and switch between them seamlessly.")
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
        .sheet(whatsNew: self.$whatsNew, onDismiss: {
            appSettings.lastShownWhatsNewVersion = self.currentAppVersion
        })
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Prompt.self, PromptHistory.self], inMemory: true)
}
