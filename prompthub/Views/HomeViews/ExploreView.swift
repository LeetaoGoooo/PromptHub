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
    @Environment(\.modelContext) private var modelContext
    @Query private var userPrompts: [Prompt]

    let searchText: String
    let galleryPrompts: [GalleryPrompt]
    let isLoading: Bool
    let showToastMsg: (String, AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (String) -> Void
    let onRefreshGallery: () -> Void
    @State private var selectedItemID: String?
    
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

    private var browserSections: [PromptBrowserSection] {
        guard !filteredGalleryPrompts.isEmpty else { return [] }

        return [
            PromptBrowserSection(
                id: "gallery",
                title: "Gallery",
                systemImage: "sparkles",
                items: filteredGalleryPrompts.map { prompt in
                    let isSaved = isGalleryPromptSaved(prompt)

                    return PromptBrowserItem(
                        id: "gallery-\(prompt.id)",
                        title: prompt.name,
                        summary: prompt.description ?? "No description",
                        promptText: prompt.prompt,
                        systemImage: "sparkles",
                        iconTint: .primary,
                        badges: [PromptCollectionFooterBadge(title: isSaved ? "Saved" : "Save to library", tint: isSaved ? .secondary : .green)],
                        trailingDetail: prompt.link?.isEmpty == false ? "Link available" : "Built-in",
                        metadata: [
                            PromptBrowserMetadataRow(label: "Source", value: "Gallery"),
                            PromptBrowserMetadataRow(label: "Saved", value: isSaved ? "Already in library" : "Not saved yet"),
                            PromptBrowserMetadataRow(label: "Link", value: prompt.link?.isEmpty == false ? "Available" : "Built-in")
                        ],
                        primaryActionTitle: isSaved ? "Saved" : "Save to Library",
                        primaryActionSystemImage: "square.and.arrow.down",
                        isPrimaryActionDisabled: isSaved,
                        onPrimaryAction: {
                            Task { @MainActor in
                                saveGalleryPrompt(prompt)
                            }
                        },
                        secondaryActionTitle: "Copy Content",
                        secondaryActionSystemImage: "doc.on.doc",
                        onSecondaryAction: { copyPromptToClipboard(prompt.prompt) }
                    )
                }
            )
        ]
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
            PromptBrowserScreen(
                title: "Explore Gallery",
                subtitle: summary,
                systemImage: "sparkles",
                metrics: metrics,
                sections: browserSections,
                selectedItemID: $selectedItemID,
                actions: {
                    Button(action: onRefreshGallery) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                },
                emptyState: {
                    if filteredGalleryPrompts.isEmpty && !searchText.isEmpty {
                        PromptViewHelpers.emptyStateView(
                            iconName: "magnifyingglass",
                            title: "No matching content found",
                            subtitle: "Try using different keywords or clear the search filter."
                        )
                    } else {
                        PromptViewHelpers.emptyStateView(
                            iconName: "sparkles",
                            title: "No content available",
                            subtitle: "Gallery prompts will appear here after a refresh."
                        )
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

    @MainActor
    private func saveGalleryPrompt(_ galleryPrompt: GalleryPrompt) {
        guard !isGalleryPromptSaved(galleryPrompt) else {
            showToastMsg("Prompt already saved", .complete(.green))
            return
        }

        do {
            let newPrompt = Prompt(name: galleryPrompt.name, desc: galleryPrompt.description, link: galleryPrompt.link)
            modelContext.insert(newPrompt)

            let newPromptHistory = newPrompt.createHistory(prompt: galleryPrompt.prompt, version: 0)
            modelContext.insert(newPromptHistory)

            try modelContext.save()
            PromptHubBridge.shared.exportPrompt(newPrompt)
            showToastMsg("Saved to My Prompts", .complete(.green))
        } catch {
            showToastMsg("Failed to save prompt: \(error.localizedDescription)", .error(.red))
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
