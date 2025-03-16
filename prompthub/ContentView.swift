//
//  ContentView.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var prompts: [Prompt]
    @State private var isPresentingNewPromptDialog = false
    @State private var promptSelection: UUID?

    var body: some View {
        NavigationSplitView {
            PromptSideBar(promptSelection: $promptSelection, isPresentingNewPromptDialog: $isPresentingNewPromptDialog)
                .navigationSplitViewColumnWidth(min: 150, ideal: 200, max: 300)
        } detail: {
            if let promptId = promptSelection {
                PromptDetail(promptId: Binding(get: { promptId }, set: { newValue in
                    promptSelection = newValue
                }))
            } else {
                Text("Select A Prompt")
            }
        }.sheet(isPresented: $isPresentingNewPromptDialog) {
            NewPromptDialog(isPresented: $isPresentingNewPromptDialog)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Prompt.self, PromptHistory.self], inMemory: true)
}
