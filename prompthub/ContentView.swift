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
                    title: WhatsNew.Title(stringLiteral: "Welcome to PromptBox Version \(currentAppVersion)!"),
                    features: [
                        .init(
                            image: .init(
                                systemName: "doc.plaintext.fill",
                                foregroundColor: .teal
                            ),
                            title: WhatsNew.Text("Enhanced Prompt Details"),
                            subtitle: WhatsNew.Text("Add context, notes, and personal insights directly to your prompts for better organization.")
                        ),
                        .init(
                            image: .init(
                                systemName: "link.circle.fill",
                                foregroundColor: .indigo
                            ),
                            title: WhatsNew.Text("Track Prompt Origins"),
                            subtitle: WhatsNew.Text("Easily remember and reference where your valuable prompts came from.")
                        ),
                        .init(
                            image: .init(
                                systemName: "play.rectangle.fill",
                                foregroundColor: .green
                            ),
                            title: WhatsNew.Text("Visual Prompt Previews"),
                            subtitle: WhatsNew.Text("Attach example outputs to your prompts to instantly visualize their results.")
                        ),
                        .init(
                            image: .init(
                                systemName: "square.and.arrow.up.fill",
                                foregroundColor: .blue
                            ),
                            title: WhatsNew.Text("Effortless Prompt Sharing"),
                            subtitle: WhatsNew.Text("Share your favorite prompts with colleagues or friends in just one tap.")
                        ),
                        .init(
                            image: .init(
                                systemName: "square.grid.2x2.fill",
                                foregroundColor: .purple
                            ),
                            title: WhatsNew.Text("Curated Prompt Gallery"),
                            subtitle: WhatsNew.Text("Explore a growing collection of pre-built prompts to kickstart your creativity and ideas (thanks cherry studio).")
                        )
                    ],
                    primaryAction: .init(
                        title: WhatsNew.Text("Got It!"),
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
