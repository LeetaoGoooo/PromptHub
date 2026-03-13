//
//  MyPromptsView.swift
//  prompthub
//
//  Created by leetao on 2025/6/24.
//

import AlertToast
import SwiftData
import SwiftUI

struct MyPromptsView: View {
    @Query private var userPrompts: [Prompt]
    
    let searchText: String
    let showToastMsg: (String, AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (String) -> Void
    let onSelectPrompt: (Prompt) -> Void
    
    private func navigateToPrompt(_ prompt: Prompt) {
        onSelectPrompt(prompt)
    }
    
    private func columns(for width: CGFloat) -> [GridItem] {
        return PromptViewHelpers.columns(for: width)
    }
    
    private var filteredUserPrompts: [Prompt] {
        if searchText.isEmpty {
            return userPrompts
        }
        return userPrompts.filter { prompt in
            prompt.name.localizedCaseInsensitiveContains(searchText) ||
            (prompt.desc?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        if filteredUserPrompts.isEmpty && !searchText.isEmpty {
            PromptViewHelpers.emptyStateView(
                iconName: "magnifyingglass",
                title: "No matching prompts found",
                subtitle: "Try using different keywords"
            )
        } else if filteredUserPrompts.isEmpty {
            PromptViewHelpers.emptyStateView(
                iconName: "doc.text",
                title: "No custom prompts yet",
                subtitle: "Click the \"+\" button in the sidebar to create your first prompt"
            )
        } else {
            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: columns(for: geometry.size.width), spacing: 20) {
                        ForEach(filteredUserPrompts) { prompt in
                            Button {
                                navigateToPrompt(prompt)
                            } label: {
                                UserPromptItemView(
                                    prompt: prompt,
                                    showToastMsg: showToastMsg,
                                    copyPromptToClipboard: copyPromptToClipboard
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
    }
}

#Preview {
    MyPromptsView(
        searchText: "",
        showToastMsg: { _, _ in },
        copyPromptToClipboard: { _ in },
        onSelectPrompt: { _ in }
    )
    .modelContainer(for: [Prompt.self, PromptHistory.self, SharedCreation.self])
}
