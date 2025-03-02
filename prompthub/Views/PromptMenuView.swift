//
//  PromptMenuView.swift
//  prompthub
//
//  Created by leetao on 2025/3/2.
//

import SwiftData
import SwiftUI

struct PromptMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var prompts: [Prompt]
    @State private var searchPrompt: String = ""

    var body: some View {
    
            VStack {
                if prompts.isEmpty {
                    Text("No prompts available")
                        .disabled(true) // Make it gray and not selectable
                } else {
                    ForEach(prompts) { prompt in
                        Button {
                            copyToClipboard(prompt)
                        } label: {
                            Text(prompt.name)
                        }
                    }
                }
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        
    }

    func copyToClipboard(_ prompt: Prompt) {
        let promptId = prompt.id
        let relatedPromptHistoriesDescriptor = FetchDescriptor<PromptHistory>(predicate: #Predicate { history in
            history.promptId == promptId
        }, sortBy: [SortDescriptor(\.version, order: .reverse)])
        let promptHistories = try? modelContext.fetch(relatedPromptHistoriesDescriptor)
        let latestPromptHistory = promptHistories?.first
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(latestPromptHistory?.prompt ?? "", forType: .string)
    }

    private func filterPrompts(_ prompts: [Prompt]) -> [Prompt] {
        if searchPrompt.isEmpty {
            return prompts
        } else {
            return prompts.filter { prompt in
                prompt.name.localizedCaseInsensitiveContains(searchPrompt)
            }
        }
    }
}

#Preview {
    PromptMenuView()
}
