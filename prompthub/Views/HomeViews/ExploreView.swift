//
//  ExploreView.swift
//  prompthub
//
//  Created by leetao on 2025/6/24.
//

import AlertToast
import SwiftData
import SwiftUI

struct ExploreView: View {
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
    
    var body: some View {
        if isLoading {
            VStack {
                ProgressView()
                    .controlSize(.large)
                Text("Loading Gallery...")
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        } else if filteredGalleryPrompts.isEmpty && !searchText.isEmpty {
            PromptViewHelpers.emptyStateView(
                iconName: "magnifyingglass",
                title: "No matching content found",
                subtitle: "Try using different keywords"
            )
            .background(Color(NSColor.windowBackgroundColor))
        } else if filteredGalleryPrompts.isEmpty {
            PromptViewHelpers.emptyStateView(
                iconName: "globe",
                title: "No content available",
                subtitle: "Gallery prompts will appear here"
            )
            .background(Color(NSColor.windowBackgroundColor))
        } else {
            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: columns(for: geometry.size.width), spacing: 20) {
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
    ExploreView(
        searchText: "",
        galleryPrompts: [],
        isLoading: false,
        showToastMsg: { _, _ in },
        copyPromptToClipboard: { _ in }
    )
    .modelContainer(for: [Prompt.self, PromptHistory.self, SharedCreation.self])
}
