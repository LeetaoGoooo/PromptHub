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
            case .prompt(let selectedPrompt):
                PromptDetail(prompt: selectedPrompt)
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

            print("lastShownVersion:\(lastShownVersion) currentAppVersion:\(currentAppVersion)")
            
            if lastShownVersion != currentAppVersion {
                self.whatsNew = WhatsNew(
                    version: WhatsNew.Version(stringLiteral: currentAppVersion),
                    title: WhatsNew.Title(stringLiteral: "What's New in PromptBox \(currentAppVersion)!"),
                    features: [

                        .init(
                            image: .init(
                                systemName: "arrow.left.arrow.right.square",
                                foregroundColor: .purple
                            ),
                            title: WhatsNew.Text("Prompt Playground & A/B Testing"),
                            subtitle: WhatsNew.Text("Directly test and compare different versions of your prompt side-by-side. Instantly see the AI's response to each, helping you choose the most effective one.")
                        ),

                        .init(
                            image: .init(
                                systemName: "plus.forwardslash.minus",
                                foregroundColor: .green
                            ),
                            title: WhatsNew.Text("Version Comparison & Diff"),
                            subtitle: WhatsNew.Text("Easily compare text changes between prompt versions. The diff view highlights additions and deletions, helping you track your edits.")
                        ),

                        .init(
                            image: .init(
                                systemName: "square.stack.3d.up.fill",
                                foregroundColor: .cyan
                            ),
                            title: WhatsNew.Text("Expanded AI Model Support"),
                            subtitle: WhatsNew.Text("Now supports a wider range of AI services, including Anthropic, Llama, Mistral, and Ollama, in addition to OpenAI.")
                        ),
                        .init(
                            image: .init(
                                systemName: "wand.and.stars",
                                foregroundColor: .orange
                            ),
                            title: WhatsNew.Text("UI Polish & Performance Boosts"),
                            subtitle: WhatsNew.Text("Enjoy a faster, smoother experience with various UI tweaks and under-the-hood optimizations for a more reliable workflow.")
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
