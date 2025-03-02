//
//  ContentView.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var prompts: [Prompt]
    @State private var isPresentingNewPromptDialog = false
    @State private var promptSelection: UUID?;

    var body: some View {
        NavigationSplitView {
            PromptSideBar(promptSelection: $promptSelection, isPresentingNewPromptDialog: $isPresentingNewPromptDialog)
                .navigationSplitViewColumnWidth(min: 150, ideal: 200, max: 300)
          } detail: {
              if promptSelection != nil {
                  PromptDetail(promptId: promptSelection!)
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
