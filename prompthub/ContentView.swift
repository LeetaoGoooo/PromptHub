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
            // Clear selection when ESC is pressed, following macOS conventions
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
                                systemName: "square.grid.2x2.fill",
                                foregroundColor: .purple
                            ),
                            title: WhatsNew.Text("Unified Prompt Browser"),
                            subtitle: WhatsNew.Text("Brand new tabbed interface with organized categories: All, Mine, Shared, and Explore for better prompt management.")
                        ),
                        .init(
                            image: .init(
                                systemName: "gear.circle.fill",
                                foregroundColor: .orange
                            ),
                            title: WhatsNew.Text("Architecture Refactor"),
                            subtitle: WhatsNew.Text("Complete data model restructuring with enhanced SwiftData integration and improved performance.")
                        ),
                        .init(
                            image: .init(
                                systemName: "magnifyingglass.circle.fill",
                                foregroundColor: .blue
                            ),
                            title: WhatsNew.Text("Enhanced Search & Navigation"),
                            subtitle: WhatsNew.Text("Optimized search functionality with better keyboard navigation and intuitive sidebar layout adjustments.")
                        ),
                        .init(
                            image: .init(
                                systemName: "icloud.and.arrow.up.fill",
                                foregroundColor: .green
                            ),
                            title: WhatsNew.Text("CloudKit Sync Improvements"),
                            subtitle: WhatsNew.Text("Enhanced public cloud synchronization and sharing capabilities for better collaboration.")
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
