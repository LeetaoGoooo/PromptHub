//
//  AllPromptsView.swift
//  prompthub
//
//  Created by leetao on 2025/6/24.
//

import AlertToast
import AppKit
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
    let onCreatePrompt: () -> Void
    @State private var selectedItemID: String?
    @State private var testingPrompt: Prompt?
    @State private var optimizingPrompt: Prompt?
    @AppStorage("promptsSortOrder") private var sortOrderRaw: String = "nameAsc"

    enum PromptSortOrder: String, CaseIterable {
        case nameAsc  = "nameAsc"
        case nameDesc = "nameDesc"
        
        var displayName: String {
            switch self {
            case .nameAsc: return "Name A–Z"
            case .nameDesc: return "Name Z–A"
            }
        }
    }
    
    private var sortOrder: PromptSortOrder {
        PromptSortOrder(rawValue: sortOrderRaw) ?? .nameAsc
    }
    
    private func sortedPrompts<T: Identifiable>(_ prompts: [T], name: KeyPath<T, String>) -> [T] {
        switch sortOrder {
        case .nameAsc:  return prompts.sorted { $0[keyPath: name].localizedCaseInsensitiveCompare($1[keyPath: name]) == .orderedAscending }
        case .nameDesc: return prompts.sorted { $0[keyPath: name].localizedCaseInsensitiveCompare($1[keyPath: name]) == .orderedDescending }
        }
    }
    
    private func setSortOrder(_ order: PromptSortOrder) {
        sortOrderRaw = order.rawValue
    }

    private var filteredGalleryPrompts: [GalleryPrompt] {
        let base: [GalleryPrompt]
        if searchText.isEmpty {
            base = galleryPrompts
        } else {
            base = galleryPrompts.filter { prompt in
                prompt.name.localizedCaseInsensitiveContains(searchText) ||
                (prompt.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        return sortedPrompts(base, name: \.name)
    }
    
    private var filteredUserPrompts: [Prompt] {
        let base: [Prompt]
        if searchText.isEmpty {
            base = userPrompts
        } else {
            base = userPrompts.filter { prompt in
                prompt.name.localizedCaseInsensitiveContains(searchText) ||
                (prompt.desc?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        return prioritizeDraftPrompts(in: sortedPrompts(base, name: \.name))
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
                            historyEntries: historyEntries(for: prompt),
                            primaryActionTitle: nil,
                            primaryActionSystemImage: nil,
                            isPrimaryActionDisabled: false,
                            onPrimaryAction: nil,
                            secondaryActionTitle: "Copy Content",
                            secondaryActionSystemImage: "doc.on.doc",
                            onSecondaryAction: { copyPromptToClipboard(prompt.getLatestPromptContent()) },
                            quickActions: [
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
                            isEditable: true,
                            onSaveEdits: { title, summary, content in
                                saveEdits(for: prompt, title: title, summary: summary, content: content)
                            },
                            onDelete: { deletePrompt(prompt) },
                            deletionTitle: isEphemeralDraft(prompt) ? "Discard" : "Delete",
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
                            quickActions: [],
                            isEditable: false
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
                sections: browserSections,
                selectedItemID: $selectedItemID,
                emptyState: {
                    PromptViewHelpers.emptyStateView(
                        iconName: searchText.isEmpty ? "tray" : "magnifyingglass",
                        title: searchText.isEmpty ? "No prompts available" : "No prompts match \"\(searchText)\"",
                        subtitle: searchText.isEmpty ? "Create a prompt or save one from the gallery to start building your library." : "Try broader keywords or clear the current filter."
                    )
                },
                toolbarContent: {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            ForEach(PromptSortOrder.allCases, id: \.rawValue) { order in
                                Button {
                                    setSortOrder(order)
                                } label: {
                                    HStack {
                                        Text(order.displayName)
                                        if sortOrder == order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .font(.system(size: 15, weight: .medium))
                                .frame(width: 18, height: 18)
                        }
                        .help("Sort: \(sortOrder.displayName)")
                    }
                }
            )
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

    private func historyEntries(for prompt: Prompt) -> [PromptBrowserHistoryEntry] {
        let entries = (prompt.history ?? []).sorted { $0.version > $1.version }
        let currentID = entries.first?.id

        return entries.map { entry in
            PromptBrowserHistoryEntry(
                id: entry.id.uuidString,
                versionLabel: "v\(max(entry.version, 1))",
                timestamp: PromptViewHelpers.relativeDateString(from: entry.updatedAt),
                summary: historySummary(for: entry.promptText),
                isCurrent: entry.id == currentID,
                onRestore: entry.id == currentID ? nil : { restore(entry, for: prompt) }
            )
        }
    }

    private func historySummary(for text: String) -> String {
        let trimmed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No content" : String(trimmed.prefix(140))
    }

    private func restore(_ entry: PromptHistory, for prompt: Prompt) {
        let nextVersion = max(prompt.latestVersionNumber, 0) + 1
        let restored = prompt.createHistory(prompt: entry.promptText, version: nextVersion)
        restored.createdAt = Date()
        restored.updatedAt = Date()
        modelContext.insert(restored)

        do {
            try modelContext.save()
            showToastMsg("Restored \(max(entry.version, 1)) to v\(nextVersion)", .complete(.green))
        } catch {
            modelContext.delete(restored)
            showToastMsg("Failed to restore history: \(error.localizedDescription)", .error(.red))
        }
    }

    private func prioritizeDraftPrompts(in prompts: [Prompt]) -> [Prompt] {
        prompts.sorted { lhs, rhs in
            let lhsIsDraft = isEphemeralDraft(lhs)
            let rhsIsDraft = isEphemeralDraft(rhs)

            if lhsIsDraft != rhsIsDraft {
                return lhsIsDraft
            }

            return (lhs.lastEditedAt ?? .distantPast) > (rhs.lastEditedAt ?? .distantPast)
        }
    }

    private func isEphemeralDraft(_ prompt: Prompt) -> Bool {
        let trimmedName = prompt.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = (prompt.desc ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = prompt.getLatestPromptContent().trimmingCharacters(in: .whitespacesAndNewlines)
        let hasExternalSources = !(prompt.externalSources?.isEmpty ?? true)

        return !hasExternalSources
            && prompt.link == nil
            && (prompt.history?.count ?? 0) <= 1
            && trimmedDescription.isEmpty
            && trimmedContent.isEmpty
            && (trimmedName.isEmpty || trimmedName == "Untitled Prompt")
    }

    private func saveEdits(for prompt: Prompt, title: String, summary: String?, content: String) {
        prompt.name = title.isEmpty ? "Untitled Prompt" : title
        prompt.desc = summary
        prompt.latestHistoryEntry?.promptText = content
        prompt.latestHistoryEntry?.updatedAt = Date()
        try? modelContext.save()
        PromptHubBridge.shared.exportPrompt(prompt)
    }

    private func deletePrompt(_ prompt: Prompt) {
        modelContext.delete(prompt)
        do {
            try modelContext.save()
            showToastMsg("Prompt deleted", .complete(.green))
        } catch {
            showToastMsg("Failed to delete prompt: \(error.localizedDescription)", .error(.red))
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
    AllPromptsView(
        searchText: "",
        galleryPrompts: [],
        isLoading: false,
        showToastMsg: { _, _ in },
        copyPromptToClipboard: { _ in },
        onCreatePrompt: { }
    )
    .modelContainer(for: [Prompt.self, PromptHistory.self, SharedCreation.self])
}
