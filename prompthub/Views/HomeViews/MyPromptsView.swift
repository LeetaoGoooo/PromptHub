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
    @Environment(\.modelContext) private var modelContext
    @Query private var userPrompts: [Prompt]
    @Query private var sharedCreations: [SharedCreation]

    let searchText: String
    let showToastMsg: (String, AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (String) -> Void
    let onCreatePrompt: () -> Void
    @State private var selectedItemID: String?
    @State private var testingPrompt: Prompt?
    @State private var optimizingPrompt: Prompt?

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
        return prioritizeDraftPrompts(in: base)
    }

    private var editedThisWeekCount: Int {
        filteredUserPrompts.filter { prompt in
            guard let lastEditedAt = prompt.lastEditedAt else { return false }
            return Calendar.current.isDate(lastEditedAt, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
    }

    private var sharedPromptCount: Int {
        filteredUserPrompts.filter { matchingSharedCreation(for: $0) != nil }.count
    }

    private var sourceLinkedCount: Int {
        filteredUserPrompts.filter { !($0.externalSources?.isEmpty ?? true) }.count
    }

    private var headerSummary: String {
        searchText.isEmpty
            ? "Private prompts and drafts. Inspect, render, test, or optimize directly from the selected detail pane."
            : "Private prompts and drafts filtered by your current search."
    }

    private var metrics: [PromptCollectionMetric] {
        [
            PromptCollectionMetric(title: "prompts", value: "\(filteredUserPrompts.count)", systemImage: "doc.text"),
            PromptCollectionMetric(title: "edited this week", value: "\(editedThisWeekCount)", systemImage: "clock"),
            PromptCollectionMetric(title: "shared", value: "\(sharedPromptCount)", systemImage: "shared.with.you")
        ]
    }

    private var browserSections: [PromptBrowserSection] {
        guard !filteredUserPrompts.isEmpty else { return [] }

        return [
            PromptBrowserSection(
                id: "my-prompts",
                title: "My Prompts",
                systemImage: "person",
                items: filteredUserPrompts.map { prompt in
                    PromptBrowserItem(
                        id: "prompt-\(prompt.id.uuidString)",
                        title: prompt.name,
                        summary: prompt.desc ?? "No description",
                        promptText: prompt.getLatestPromptContent(),
                        systemImage: "doc.text",
                        iconTint: .accentColor,
                        badges: badges(for: prompt) + [PromptCollectionFooterBadge(title: "v\(max(prompt.latestVersionNumber, 1))", tint: .secondary)],
                        trailingDetail: PromptViewHelpers.relativeDateString(from: prompt.lastEditedAt),
                        metadata: metadataRows(for: prompt),
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
                        isShared: matchingSharedCreation(for: prompt) != nil
                    )
                }
            )
        ]
    }
    
    var body: some View {
        PromptBrowserScreen(
            sections: browserSections,
            selectedItemID: $selectedItemID,
            emptyState: {
                if filteredUserPrompts.isEmpty && !searchText.isEmpty {
                    PromptViewHelpers.emptyStateView(
                        iconName: "magnifyingglass",
                        title: "No matching prompts found",
                        subtitle: "Try broader keywords or clear the current search filter."
                    )
                } else {
                    PromptViewHelpers.emptyStateView(
                        iconName: "doc.text",
                        title: "No custom prompts yet",
                        subtitle: "Create your first prompt to start building a private library."
                    )
                }
            },
            toolbarContent: {
                ToolbarItemGroup(placement: .primaryAction) {}
            }
        )
        .sheet(item: $testingPrompt) { prompt in
            SinglePromptTestView(prompt: prompt.getLatestPromptContent())
        }
        .sheet(item: $optimizingPrompt) { prompt in
            PromptOptimizeSheet(prompt: prompt)
        }
    }

    private func badges(for prompt: Prompt) -> [PromptCollectionFooterBadge] {
        var badges: [PromptCollectionFooterBadge] = []

        if let sharedCreation = matchingSharedCreation(for: prompt) {
            badges.append(
                PromptCollectionFooterBadge(
                    title: sharedCreation.isPublic ? "Public" : "Shared",
                    tint: sharedCreation.isPublic ? .green : .orange
                )
            )
        }

        if !((prompt.externalSources?.isEmpty) ?? true) {
            badges.append(PromptCollectionFooterBadge(title: "Sources", tint: .secondary))
        }

        if prompt.link?.isEmpty == false {
            badges.append(PromptCollectionFooterBadge(title: "Imported", tint: .accentColor))
        }

        return badges
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

    private func metadataRows(for prompt: Prompt) -> [PromptBrowserMetadataRow] {
        var rows: [PromptBrowserMetadataRow] = [
            PromptBrowserMetadataRow(label: "Source", value: "Private Library"),
            PromptBrowserMetadataRow(label: "Version", value: "v\(max(prompt.latestVersionNumber, 1))")
        ]

        if let lastEditedAt = prompt.lastEditedAt {
            rows.append(PromptBrowserMetadataRow(label: "Updated", value: PromptViewHelpers.relativeDateString(from: lastEditedAt)))
        }

        if let sharedCreation = matchingSharedCreation(for: prompt) {
            rows.append(PromptBrowserMetadataRow(label: "Sharing", value: sharedCreation.isPublic ? "Public" : "Shared"))
        }

        if !((prompt.externalSources?.isEmpty) ?? true) {
            rows.append(PromptBrowserMetadataRow(label: "Sources", value: "Attached"))
        }

        return rows
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
}

#Preview {
    MyPromptsView(
        searchText: "",
        showToastMsg: { _, _ in },
        copyPromptToClipboard: { _ in },
        onCreatePrompt: { }
    )
    .modelContainer(for: [Prompt.self, PromptHistory.self, SharedCreation.self])
}
