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
                                systemName: "testtube.2",
                                foregroundColor: .blue
                            ),
                            title: WhatsNew.Text("Multi-Model Prompt Testing"),
                            subtitle: WhatsNew.Text("Test your prompts across multiple AI models simultaneously. Select from all configured services and compare results side-by-side to find the best performing model for your use case.")
                        ),

                        .init(
                            image: .init(
                                systemName: "rectangle.split.3x1",
                                foregroundColor: .purple
                            ),
                            title: WhatsNew.Text("Global Comparison View"),
                            subtitle: WhatsNew.Text("View all model results in a comprehensive comparison interface. Expand, collapse, and analyze outputs from different AI models in an organized, easy-to-navigate layout.")
                        ),

                        .init(
                            image: .init(
                                systemName: "wave.3.right",
                                foregroundColor: .green
                            ),
                            title: WhatsNew.Text("Real-time Streaming Results"),
                            subtitle: WhatsNew.Text("Watch AI responses generate in real-time as they stream. See live updates across all selected models with progress indicators and smooth animations.")
                        ),

                        .init(
                            image: .init(
                                systemName: "slider.horizontal.3",
                                foregroundColor: .orange
                            ),
                            title: WhatsNew.Text("Enhanced Model Management"),
                            subtitle: WhatsNew.Text("Intuitive model selection sidebar with easy configuration management. Select all, clear all, or pick specific models with visual feedback for configured and unconfigured services.")
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
