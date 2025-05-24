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

    @State private var isPresentingNewPromptDialog = false
    @State private var promptSelection: Prompt?
    
    @State private var isEditingPromptSheetPresented = false

    var body: some View {
        NavigationSplitView {
            PromptSideBar(
                          isEditingPromptSheetPresented: $isEditingPromptSheetPresented,
                          promptSelection: $promptSelection, isPresentingNewPromptDialog: $isPresentingNewPromptDialog
            )
                .navigationSplitViewColumnWidth(min: 150, ideal: 200, max: 300)
                .id("PromptSideBar ثابت")
        } detail: {
            if let selectedPrompt = promptSelection {
                PromptDetail(prompt:selectedPrompt)
            } else {
                Text("Select A Prompt")
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Prompt.self, PromptHistory.self], inMemory: true)
}
