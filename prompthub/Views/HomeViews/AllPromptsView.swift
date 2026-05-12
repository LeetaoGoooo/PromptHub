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
    @Environment(\.modelContext) private var modelContext
    @Query private var userPrompts: [Prompt]
    @Query private var sharedCreations: [SharedCreation]

    let searchText: String
    let galleryPrompts: [GalleryPrompt]
    let isLoading: Bool
    let showToastMsg: (String, AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (String) -> Void
    let onSelectPrompt: (Prompt) -> Void
    let onCreatePrompt: () -> Void
    let onRenderPrompt: () -> Void
    @State private var selectedItemID: String?
    @State private var renderingPrompt: Prompt?
    @State private var testingPrompt: Prompt?
    @State private var optimizingPrompt: Prompt?
    
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
            ? "Browse your private library alongside gallery prompts, then render, test, or optimize directly from the detail pane."
            : "Showing matches across your private library and gallery prompts."
    }

    private var libraryMetrics: [PromptCollectionMetric] {
        [
            PromptCollectionMetric(title: "personal", value: "\(filteredUserPrompts.count)", systemImage: "person"),
            PromptCollectionMetric(title: "gallery", value: "\(filteredGalleryPrompts.count)", systemImage: "sparkles"),
            PromptCollectionMetric(title: "visible", value: "\(visiblePromptCount)", systemImage: "square.grid.2x2")
        ]
    }

    private var browserSections: [PromptBrowserSection] {
        var sections: [PromptBrowserSection] = []

        if !filteredUserPrompts.isEmpty {
            sections.append(
                PromptBrowserSection(
                    id: "user-prompts",
                    title: "My Prompts",
                    systemImage: "person",
                    items: filteredUserPrompts.map { prompt in
                        let sharing = sharingPresentation(for: prompt)

                        return PromptBrowserItem(
                            id: "prompt-\(prompt.id.uuidString)",
                            title: prompt.name,
                            summary: prompt.desc ?? "No description",
                            promptText: prompt.getLatestPromptContent(),
                            systemImage: sharing.iconName ?? "doc.text",
                            iconTint: sharing.iconColor ?? .accentColor,
                            badges: sharing.footerBadges + [PromptCollectionFooterBadge(title: "v\(max(prompt.latestVersionNumber, 1))", tint: .secondary)],
                            trailingDetail: PromptViewHelpers.relativeDateString(from: prompt.lastEditedAt),
                            metadata: promptMetadata(for: prompt, sharing: sharing),
                            primaryActionTitle: "Open Prompt",
                            primaryActionSystemImage: "arrow.right.circle",
                            isPrimaryActionDisabled: false,
                            onPrimaryAction: { onSelectPrompt(prompt) },
                            secondaryActionTitle: "Copy Content",
                            secondaryActionSystemImage: "doc.on.doc",
                            onSecondaryAction: { copyPromptToClipboard(prompt.getLatestPromptContent()) },
                            quickActions: [
                                PromptBrowserQuickAction(
                                    id: "render-\(prompt.id.uuidString)",
                                    title: "Render",
                                    systemImage: "play.rectangle",
                                    emphasis: .standard,
                                    isDisabled: false,
                                    onSelect: { renderingPrompt = prompt }
                                ),
                                PromptBrowserQuickAction(
                                    id: "test-\(prompt.id.uuidString)",
                                    title: "Test",
                                    systemImage: "bolt.badge.checkmark",
                                    emphasis: .standard,
                                    isDisabled: false,
                                    onSelect: { testingPrompt = prompt }
                                ),
                                PromptBrowserQuickAction(
                                    id: "optimize-\(prompt.id.uuidString)",
                                    title: "AI Optimize",
                                    systemImage: "wand.and.stars",
                                    emphasis: .standard,
                                    isDisabled: false,
                                    onSelect: { optimizingPrompt = prompt }
                                )
                            ],
                            hasExternalSources: !((prompt.externalSources?.isEmpty) ?? true),
                            isShared: !sharing.footerBadges.isEmpty
                        )
                    }
                )
            )
        }

        if !filteredGalleryPrompts.isEmpty {
            sections.append(
                PromptBrowserSection(
                    id: "gallery-prompts",
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
                            iconTint: .indigo,
                            badges: [PromptCollectionFooterBadge(title: isSaved ? "Saved" : "Save to library", tint: isSaved ? .secondary : .green)],
                            trailingDetail: prompt.link?.isEmpty == false ? "Link available" : "Built-in",
                            metadata: galleryMetadata(for: prompt, isSaved: isSaved),
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
                            onSecondaryAction: { copyPromptToClipboard(prompt.prompt) },
                            quickActions: []
                        )
                    }
                )
            )
        }

        return sections
    }
    
    var body: some View {
        if isLoading && filteredUserPrompts.isEmpty && filteredGalleryPrompts.isEmpty {
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
            PromptBrowserScreen(
                title: "All Prompts",
                subtitle: headerSummary,
                systemImage: "archivebox",
                metrics: libraryMetrics,
                sections: browserSections,
                selectedItemID: $selectedItemID,
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
                emptyState: {
                    PromptViewHelpers.emptyStateView(
                        iconName: searchText.isEmpty ? "tray" : "magnifyingglass",
                        title: searchText.isEmpty ? "No prompts available" : "No prompts match \"\(searchText)\"",
                        subtitle: searchText.isEmpty ? "Create a prompt or save one from the gallery to start building your library." : "Try broader keywords or clear the current filter."
                    )
                }
            )
            .sheet(item: $renderingPrompt) { prompt in
                PromptRenderSheet(initialPromptID: prompt.id) {
                    renderingPrompt = nil
                }
            }
            .sheet(item: $testingPrompt) { prompt in
                SinglePromptTestView(prompt: prompt.getLatestPromptContent())
            }
            .sheet(item: $optimizingPrompt) { prompt in
                PromptOptimizeSheet(prompt: prompt)
            }
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

    private func isGalleryPromptSaved(_ galleryPrompt: GalleryPrompt) -> Bool {
        userPrompts.contains {
            $0.name == galleryPrompt.name &&
            $0.getLatestPromptContent() == galleryPrompt.prompt
        }
    }

    private func promptMetadata(for prompt: Prompt, sharing: PromptItemSharingPresentation) -> [PromptBrowserMetadataRow] {
        var rows: [PromptBrowserMetadataRow] = [
            PromptBrowserMetadataRow(label: "Source", value: "My Library"),
            PromptBrowserMetadataRow(label: "Version", value: "v\(max(prompt.latestVersionNumber, 1))")
        ]

        if let lastEdited = prompt.lastEditedAt {
            rows.append(PromptBrowserMetadataRow(label: "Updated", value: PromptViewHelpers.relativeDateString(from: lastEdited)))
        }

        if !sharing.footerBadges.isEmpty {
            rows.append(PromptBrowserMetadataRow(label: "Sharing", value: sharing.footerBadges.map(\.title).joined(separator: ", ")))
        }

        if !((prompt.externalSources?.isEmpty) ?? true) {
            rows.append(PromptBrowserMetadataRow(label: "Sources", value: "Attached"))
        }

        return rows
    }

    private func galleryMetadata(for prompt: GalleryPrompt, isSaved: Bool) -> [PromptBrowserMetadataRow] {
        [
            PromptBrowserMetadataRow(label: "Source", value: "Gallery"),
            PromptBrowserMetadataRow(label: "Saved", value: isSaved ? "Already in library" : "Not saved yet"),
            PromptBrowserMetadataRow(label: "Link", value: prompt.link?.isEmpty == false ? "Available" : "Built-in")
        ]
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
    AllPromptsView(
        searchText: "",
        galleryPrompts: [],
        isLoading: false,
        showToastMsg: { _, _ in },
        copyPromptToClipboard: { _ in },
        onSelectPrompt: { _ in },
        onCreatePrompt: { },
        onRenderPrompt: { }
    )
    .modelContainer(for: [Prompt.self, PromptHistory.self, SharedCreation.self])
}
