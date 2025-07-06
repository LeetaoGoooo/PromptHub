//
//  AllPromptsView.swift
//  prompthub
//
//  Created by leetao on 2025/6/24.
//

import AlertToast
import SwiftData
import SwiftUI

struct AllPromptsView: View {
    @Query private var userPrompts: [Prompt]
    
    let searchText: String
    let galleryPrompts: [GalleryPrompt]
    let isLoading: Bool
    let showToastMsg: (String, AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (String) -> Void
    
    private func columns(for width: CGFloat) -> [GridItem] {
        return PromptViewHelpers.columns(for: width)
    }
    
    private var filteredGalleryPrompts: [GalleryPrompt] {
        if searchText.isEmpty {
            return galleryPrompts
        }
        return galleryPrompts.filter { prompt in
            prompt.name.localizedCaseInsensitiveContains(searchText) ||
            (prompt.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
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
        if isLoading {
            ProgressView("Loading Prompts...")
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: columns(for: geometry.size.width), spacing: 16) {
                        // User prompts with sharing status indication
                        ForEach(filteredUserPrompts) { prompt in
                            PromptItemView(
                                prompt: prompt,
                                showToastMsg: showToastMsg,
                                copyPromptToClipboard: copyPromptToClipboard
                            )
                            .background(
                                PromptViewHelpers.promptItemBackground(borderColor: Color.blue.opacity(0.25))
                            )
                        }
                        
                        // Gallery prompts
                        ForEach(filteredGalleryPrompts) { prompt in
                            GalleryPromptItemView(
                                galleryPromptItem: prompt,
                                showToastMsg: showToastMsg,
                                copyPromptToClipboard: copyPromptToClipboard
                            )
                            .background(
                                PromptViewHelpers.promptItemBackground(borderColor: Color.gray.opacity(0.25))
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

#Preview {
    AllPromptsView(
        searchText: "",
        galleryPrompts: [],
        isLoading: false,
        showToastMsg: { _, _ in },
        copyPromptToClipboard: { _ in }
    )
    .modelContainer(for: [Prompt.self, PromptHistory.self, SharedCreation.self])
}
