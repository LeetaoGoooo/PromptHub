//
//  ContentView.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import SwiftData
import SwiftUI
import WhatsNewKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isPresentingNewPromptDialog = false
    @State private var promptSelection: Prompt?

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
            if let selectedPrompt = promptSelection {
                PromptDetail(prompt: selectedPrompt)
            } else {
                GalleryPromptView()
            }
        }.sheet(isPresented: $isPresentingNewPromptDialog) {
            NewPromptDialog(isPresented: $isPresentingNewPromptDialog)
        }
        .sheet(isPresented: $isEditingPromptSheetPresented) {
            if let currentPromptForSheet = self.promptSelection {
                EditPromptSheet(prompt: currentPromptForSheet, isPresented: self.$isEditingPromptSheetPresented)
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
                                systemName: "magnifyingglass.circle.fill", // 代表“搜索”和“优化”
                                foregroundColor: .blue
                            ),
                            title: WhatsNew.Text("Status Bar Enhancements"),
                            subtitle: WhatsNew.Text("A new search bar has been added to the status bar, with its display optimized for when you have many prompts.")
                        ),
                        .init(
                            image: .init(
                                systemName: "sidebar.squares.leading", // 代表“侧边栏”和“布局”
                                foregroundColor: .green
                            ),
                            title: WhatsNew.Text("Intuitive Layout Adjustment"),
                            subtitle: WhatsNew.Text("The sidebar's search bar has been repositioned to a more intuitive location for a smoother experience.")
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
