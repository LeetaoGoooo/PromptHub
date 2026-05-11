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
    @Query private var userPrompts: [Prompt]
    @Query private var sharedCreations: [SharedCreation]

    let searchText: String
    let showToastMsg: (String, AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (String) -> Void
    let onSelectPrompt: (Prompt) -> Void
    let onCreatePrompt: () -> Void
    let onRenderPrompt: () -> Void

    private let gridColumns = [GridItem(.adaptive(minimum: 250, maximum: 320), spacing: 16, alignment: .top)]

    private func navigateToPrompt(_ prompt: Prompt) {
        onSelectPrompt(prompt)
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
            ? "Private prompts and drafts. Click any card to open the editor."
            : "Private prompts and drafts filtered by your current search."
    }

    private var metrics: [PromptCollectionMetric] {
        [
            PromptCollectionMetric(title: "prompts", value: "\(filteredUserPrompts.count)", systemImage: "doc.text"),
            PromptCollectionMetric(title: "edited this week", value: "\(editedThisWeekCount)", systemImage: "clock"),
            PromptCollectionMetric(title: "shared", value: "\(sharedPromptCount)", systemImage: "shared.with.you")
        ]
    }
    
    var body: some View {
        PromptCollectionWorkspace(
            title: "My Prompts",
            subtitle: headerSummary,
            systemImage: "person",
            metrics: metrics,
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
                if filteredUserPrompts.isEmpty && !searchText.isEmpty {
                    PromptViewHelpers.emptyStateView(
                        iconName: "magnifyingglass",
                        title: "No matching prompts found",
                        subtitle: "Try broader keywords or clear the current search filter."
                    )
                    .frame(minHeight: 260)
                } else if filteredUserPrompts.isEmpty {
                    PromptViewHelpers.emptyStateView(
                        iconName: "doc.text",
                        title: "No custom prompts yet",
                        subtitle: "Create your first prompt to start building a private library."
                    )
                    .frame(minHeight: 260)
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(filteredUserPrompts) { prompt in
                            UserPromptItemView(
                                prompt: prompt,
                                footerBadges: badges(for: prompt),
                                showToastMsg: showToastMsg,
                                copyPromptToClipboard: copyPromptToClipboard,
                                onOpen: { navigateToPrompt(prompt) }
                            )
                        }
                    }
                }
            },
            inspector: {
                VStack(alignment: .leading, spacing: 12) {
                    PromptCollectionInspectorPanel(title: "Private Scope") {
                        PromptCollectionKVList(items: [
                            ("Prompts", "\(userPrompts.count) owned"),
                            ("Edited this week", "\(editedThisWeekCount)"),
                            ("Shared", "\(sharedPromptCount)"),
                            ("Linked to sources", "\(sourceLinkedCount)")
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
}

#Preview {
    MyPromptsView(
        searchText: "",
        showToastMsg: { _, _ in },
        copyPromptToClipboard: { _ in },
        onSelectPrompt: { _ in },
        onCreatePrompt: { },
        onRenderPrompt: { }
    )
    .modelContainer(for: [Prompt.self, PromptHistory.self, SharedCreation.self])
}
