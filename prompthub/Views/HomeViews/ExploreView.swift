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
    @Query private var userPrompts: [Prompt]

    let searchText: String
    let galleryPrompts: [GalleryPrompt]
    let isLoading: Bool
    let showToastMsg: (String, AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (String) -> Void
    let onRefreshGallery: () -> Void

    private let gridColumns = [GridItem(.adaptive(minimum: 250, maximum: 320), spacing: 16, alignment: .top)]
    
    private var filteredGalleryPrompts: [GalleryPrompt] {
        if searchText.isEmpty {
            return galleryPrompts
        }
        return galleryPrompts.filter { prompt in
            prompt.name.localizedCaseInsensitiveContains(searchText) ||
            (prompt.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var savedGalleryPromptCount: Int {
        filteredGalleryPrompts.filter(isGalleryPromptSaved).count
    }

    private var metrics: [PromptCollectionMetric] {
        [
            PromptCollectionMetric(title: "available", value: "\(galleryPrompts.count)", systemImage: "sparkles"),
            PromptCollectionMetric(title: "saved locally", value: "\(savedGalleryPromptCount)", systemImage: "square.and.arrow.down"),
            PromptCollectionMetric(title: "showing", value: "\(filteredGalleryPrompts.count)", systemImage: "square.grid.2x2")
        ]
    }

    private var summary: String {
        searchText.isEmpty
            ? "Browse public gallery prompts. Open any card to preview it, then save it to your library."
            : "Showing gallery prompts that match your current search."
    }
    
    var body: some View {
        if isLoading && galleryPrompts.isEmpty {
            VStack {
                ProgressView()
                    .controlSize(.large)
                Text("Loading Gallery...")
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        } else {
            PromptCollectionWorkspace(
                title: "Explore Gallery",
                subtitle: summary,
                systemImage: "sparkles",
                metrics: metrics,
                actions: {
                    Button(action: onRefreshGallery) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                },
                content: {
                    VStack(alignment: .leading, spacing: 20) {
                        if filteredGalleryPrompts.isEmpty && !searchText.isEmpty {
                            PromptViewHelpers.emptyStateView(
                                iconName: "magnifyingglass",
                                title: "No matching content found",
                                subtitle: "Try using different keywords or clear the search filter."
                            )
                            .frame(minHeight: 260)
                        } else if filteredGalleryPrompts.isEmpty {
                            PromptViewHelpers.emptyStateView(
                                iconName: "sparkles",
                                title: "No content available",
                                subtitle: "Gallery prompts will appear here after a refresh."
                            )
                            .frame(minHeight: 260)
                        } else {
                            PromptCollectionSectionLabel(title: "Gallery", count: filteredGalleryPrompts.count, systemImage: "sparkles")
                            LazyVGrid(columns: gridColumns, spacing: 16) {
                                ForEach(filteredGalleryPrompts) { prompt in
                                    GalleryPromptItemView(
                                        galleryPromptItem: prompt,
                                        isAlreadySaved: isGalleryPromptSaved(prompt),
                                        showToastMsg: showToastMsg,
                                        copyPromptToClipboard: copyPromptToClipboard
                                    )
                                }
                            }
                        }
                    }
                },
                inspector: {
                    VStack(alignment: .leading, spacing: 12) {
                        PromptCollectionInspectorPanel(title: "Gallery Totals") {
                            PromptCollectionKVList(items: [
                                ("Available", "\(galleryPrompts.count)"),
                                ("Visible", "\(filteredGalleryPrompts.count)"),
                                ("Saved locally", "\(savedGalleryPromptCount)"),
                                ("Filter", searchText.isEmpty ? "All prompts" : searchText)
                            ])
                        }

                        PromptCollectionInspectorPanel(title: "Actions") {
                            VStack(alignment: .leading, spacing: 8) {
                                Button(action: onRefreshGallery) {
                                    Label("Refresh Gallery", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
            )
        }
    }

    private func isGalleryPromptSaved(_ galleryPrompt: GalleryPrompt) -> Bool {
        userPrompts.contains {
            $0.name == galleryPrompt.name &&
            $0.getLatestPromptContent() == galleryPrompt.prompt
        }
    }
}

#Preview {
    ExploreView(
        searchText: "",
        galleryPrompts: [],
        isLoading: false,
        showToastMsg: { _, _ in },
        copyPromptToClipboard: { _ in },
        onRefreshGallery: { }
    )
    .modelContainer(for: [Prompt.self, PromptHistory.self, SharedCreation.self])
}
