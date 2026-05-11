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
    @Query private var sharedCreations: [SharedCreation]

    let searchText: String
    let galleryPrompts: [GalleryPrompt]
    let isLoading: Bool
    let showToastMsg: (String, AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (String) -> Void
    let onCreatePrompt: () -> Void
    let onRenderPrompt: () -> Void

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
    
    private var filteredUserPrompts: [Prompt] {
        if searchText.isEmpty {
            return userPrompts
        }
        return userPrompts.filter { prompt in
            prompt.name.localizedCaseInsensitiveContains(searchText) ||
            (prompt.desc?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var visiblePromptCount: Int {
        filteredUserPrompts.count + filteredGalleryPrompts.count
    }

    private var headerSummary: String {
        searchText.isEmpty
            ? "Browse your private library alongside gallery prompts."
            : "Showing matches across your private library and gallery prompts."
    }

    private var libraryMetrics: [PromptCollectionMetric] {
        [
            PromptCollectionMetric(title: "personal", value: "\(filteredUserPrompts.count)", systemImage: "person"),
            PromptCollectionMetric(title: "gallery", value: "\(filteredGalleryPrompts.count)", systemImage: "sparkles"),
            PromptCollectionMetric(title: "visible", value: "\(visiblePromptCount)", systemImage: "square.grid.2x2")
        ]
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
            PromptCollectionWorkspace(
                title: "All Prompts",
                subtitle: headerSummary,
                systemImage: "archivebox",
                metrics: libraryMetrics,
                actions: {
                    Button(action: onCreatePrompt) {
                        Label("New Prompt", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: onRenderPrompt) {
                        Label("Render Prompt…", systemImage: "play.rectangle")
                    }
                    .buttonStyle(.bordered)
                },
                content: {
                    VStack(alignment: .leading, spacing: 20) {
                        if filteredUserPrompts.isEmpty && filteredGalleryPrompts.isEmpty {
                            PromptViewHelpers.emptyStateView(
                                iconName: searchText.isEmpty ? "tray" : "magnifyingglass",
                                title: searchText.isEmpty ? "No prompts available" : "No prompts match \"\(searchText)\"",
                                subtitle: searchText.isEmpty ? "Create a prompt or save one from the gallery to start building your library." : "Try broader keywords or clear the current filter."
                            )
                            .frame(minHeight: 260)
                        }

                        if !filteredUserPrompts.isEmpty {
                            PromptCollectionSectionLabel(title: "My Prompts", count: filteredUserPrompts.count, systemImage: "person")
                            LazyVGrid(columns: gridColumns, spacing: 16) {
                                ForEach(filteredUserPrompts) { prompt in
                                    PromptItemView(
                                        prompt: prompt,
                                        sharingPresentation: sharingPresentation(for: prompt),
                                        showToastMsg: showToastMsg,
                                        copyPromptToClipboard: copyPromptToClipboard
                                    )
                                }
                            }
                        }

                        if !filteredGalleryPrompts.isEmpty {
                            PromptCollectionSectionLabel(title: "Gallery", count: filteredGalleryPrompts.count, systemImage: "sparkles")
                            LazyVGrid(columns: gridColumns, spacing: 16) {
                                ForEach(filteredGalleryPrompts) { prompt in
                                    GalleryPromptItemView(
                                        galleryPromptItem: prompt,
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
                        PromptCollectionInspectorPanel(title: "Library Totals") {
                            PromptCollectionKVList(items: [
                                ("My Prompts", "\(userPrompts.count)"),
                                ("Gallery", "\(galleryPrompts.count)"),
                                ("Showing", "\(visiblePromptCount)"),
                                ("Filter", searchText.isEmpty ? "All items" : searchText)
                            ])
                        }

                        PromptCollectionInspectorPanel(title: "Actions") {
                            VStack(alignment: .leading, spacing: 8) {
                                Button(action: onCreatePrompt) {
                                    Label("New Prompt", systemImage: "plus")
                                }
                                .buttonStyle(.borderedProminent)

                                Button(action: onRenderPrompt) {
                                    Label("Render Prompt…", systemImage: "play.rectangle")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            )
        }
    }

    private func sharingPresentation(for prompt: Prompt) -> PromptItemSharingPresentation {
        guard let sharedCreation = matchingSharedCreation(for: prompt) else {
            return .personal
        }

        if sharedCreation.isPublic {
            return PromptItemSharingPresentation(
                iconName: "shared.with.you",
                iconColor: .green,
                footerBadges: [PromptCollectionFooterBadge(title: "Public", tint: .green)],
                helpText: "Public Shared Prompt",
                sharedCreationID: sharedCreation.id
            )
        }

        return PromptItemSharingPresentation(
            iconName: "shared.with.you.slash",
            iconColor: .orange,
            footerBadges: [PromptCollectionFooterBadge(title: "Shared", tint: .orange)],
            helpText: "Shared Prompt",
            sharedCreationID: sharedCreation.id
        )
    }

    private func matchingSharedCreation(for prompt: Prompt) -> SharedCreation? {
        let latestContent = prompt.getLatestPromptContent()

        return sharedCreations
            .filter {
                $0.name == prompt.name &&
                $0.prompt == latestContent &&
                $0.desc == prompt.desc
            }
            .max(by: { ($0.lastModified ?? Date.distantPast) < ($1.lastModified ?? Date.distantPast) })
    }
}

#Preview {
    AllPromptsView(
        searchText: "",
        galleryPrompts: [],
        isLoading: false,
        showToastMsg: { _, _ in },
        copyPromptToClipboard: { _ in },
        onCreatePrompt: { },
        onRenderPrompt: { }
    )
    .modelContainer(for: [Prompt.self, PromptHistory.self, SharedCreation.self])
}
