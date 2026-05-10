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
                    VStack(alignment: .leading, spacing: 0) {
                        // My Prompts section
                        if !filteredUserPrompts.isEmpty {
                            sectionHeader(
                                title: "My Prompts",
                                count: filteredUserPrompts.count,
                                systemImage: "person.circle"
                            )
                            LazyVGrid(columns: columns(for: geometry.size.width), spacing: 16) {
                                ForEach(filteredUserPrompts) { prompt in
                                    PromptItemView(
                                        prompt: prompt,
                                        showToastMsg: showToastMsg,
                                        copyPromptToClipboard: copyPromptToClipboard
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        }

                        // Gallery section
                        if !filteredGalleryPrompts.isEmpty {
                            sectionHeader(
                                title: "Gallery",
                                count: filteredGalleryPrompts.count,
                                systemImage: "safari"
                            )
                            LazyVGrid(columns: columns(for: geometry.size.width), spacing: 16) {
                                ForEach(filteredGalleryPrompts) { prompt in
                                    GalleryPromptItemView(
                                        galleryPromptItem: prompt,
                                        showToastMsg: showToastMsg,
                                        copyPromptToClipboard: copyPromptToClipboard
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        }

                        if filteredUserPrompts.isEmpty && filteredGalleryPrompts.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)
                                Text("No prompts match \"\(searchText)\"")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 80)
                        }
                    }
                    .padding(.top, 20)
                }
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(title: String, count: Int, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("(\(count))")
                .font(.subheadline)
                .foregroundStyle(Color(NSColor.tertiaryLabelColor))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
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
