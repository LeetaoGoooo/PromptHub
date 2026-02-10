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
            VStack {
                ProgressView()
                    .controlSize(.large)
                Text("Loading Prompts...")
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        } else {
            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: columns(for: geometry.size.width), spacing: 20) {
                        // User prompts
                        ForEach(filteredUserPrompts) { prompt in
                            PromptItemView(
                                prompt: prompt,
                                showToastMsg: showToastMsg,
                                copyPromptToClipboard: copyPromptToClipboard
                            )
                        }
                        
                        // Gallery prompts
                        ForEach(filteredGalleryPrompts) { prompt in
                            GalleryPromptItemView(
                                galleryPromptItem: prompt,
                                showToastMsg: showToastMsg,
                                copyPromptToClipboard: copyPromptToClipboard
                            )
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
    AllPromptsView(
        searchText: "",
        galleryPrompts: [],
        isLoading: false,
        showToastMsg: { _, _ in },
        copyPromptToClipboard: { _ in }
    )
    .modelContainer(for: [Prompt.self, PromptHistory.self, SharedCreation.self])
}
