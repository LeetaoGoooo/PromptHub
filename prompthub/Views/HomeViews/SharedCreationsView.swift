//
//  SharedCreationsView.swift
//  prompthub
//
//  Created by leetao on 2025/6/24.
//

import AlertToast
import CloudKit
import SwiftData
import SwiftUI

struct SharedCreationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var localSharedCreations: [SharedCreation]
    
    let searchText: String
    let showToastMsg: (String, AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (String) -> Void
    
    @State private var publicSharedCreations: [SharedCreation] = []
    @State private var isLoading = false
    @State private var loadError: String?

    private let gridColumns = [GridItem(.adaptive(minimum: 250, maximum: 320), spacing: 16, alignment: .top)]

    private var localSharedCreationIDs: Set<UUID> {
        Set(localSharedCreations.map(\.id))
    }
    
    // Combine and categorize shared creations based on whether they exist locally
    // Items with publicRecordName that exist locally are user's creations
    private var categorizedSharedCreations: (userCreations: [SharedCreation], otherCreations: [SharedCreation]) {
        // Filter by search text first
        let filteredCreations: [SharedCreation]
        if searchText.isEmpty {
            filteredCreations = publicSharedCreations
        } else {
            filteredCreations = publicSharedCreations.filter { creation in
                creation.name.localizedCaseInsensitiveContains(searchText) ||
                    (creation.desc?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Categorize into user's and others' based on local existence
        let userCreations = filteredCreations.filter { localSharedCreationIDs.contains($0.id) }

        let otherCreations = filteredCreations.filter { !localSharedCreationIDs.contains($0.id) }
        
        return (
            userCreations: userCreations.sorted { $0.lastModified ?? Date.distantPast > $1.lastModified ?? Date.distantPast },
            otherCreations: otherCreations.sorted { $0.lastModified ?? Date.distantPast > $1.lastModified ?? Date.distantPast }
        )
    }
    
    private var summary: String {
        searchText.isEmpty
            ? "Browse prompts shared from your library alongside creations published by the broader community."
            : "Showing shared creations that match your current search."
    }
    
    @MainActor
    private func loadPublicSharedCreations() async {
        isLoading = true
        loadError = nil
        
        do {
            let syncManager = try PublicCloudKitSyncManager(
                containerIdentifier: CloudKitAccess.publicContainerIdentifier,
                modelContext: modelContext
            )
            let publicCreations = try await syncManager.fetchAllPublicSharedCreations(limit: 100)
            publicSharedCreations = publicCreations
            isLoading = false
        } catch {
            loadError = "Failed to load public shared creations: \(error.localizedDescription)"
            isLoading = false
            showToastMsg("Failed to load public creations", .error(.red))
        }
    }
    
    var body: some View {
        let categorized = categorizedSharedCreations
        let visibleCount = categorized.userCreations.count + categorized.otherCreations.count
        let communityMetrics = [
            PromptCollectionMetric(title: "mine", value: "\(categorized.userCreations.count)", systemImage: "person"),
            PromptCollectionMetric(title: "community", value: "\(categorized.otherCreations.count)", systemImage: "person.3"),
            PromptCollectionMetric(title: "visible", value: "\(visibleCount)", systemImage: "square.grid.2x2")
        ]

        PromptCollectionWorkspace(
            title: "Shared with Me",
            subtitle: summary,
            systemImage: "person.3",
            metrics: communityMetrics,
            actions: {
                Button {
                    Task {
                        await loadPublicSharedCreations()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            },
            content: {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoading && visibleCount == 0 {
                        VStack(spacing: 12) {
                            ProgressView("Loading public shared creations...")
                            if let loadError {
                                Text(loadError)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 260)
                    } else if !isLoading && visibleCount == 0 && !searchText.isEmpty {
                        PromptViewHelpers.emptyStateView(
                            iconName: "magnifyingglass",
                            title: "No matching shared creations found",
                            subtitle: "Try broader keywords or clear the current filter."
                        )
                        .frame(minHeight: 260)
                    } else if visibleCount == 0 {
                        PromptViewHelpers.emptyStateView(
                            iconName: "square.and.arrow.up",
                            title: "No shared creations yet",
                            subtitle: "Share your prompts or explore public creations from the community."
                        )
                        .frame(minHeight: 260)
                    } else {
                        if !categorized.userCreations.isEmpty {
                            PromptCollectionSectionLabel(title: "My Shared Prompts", count: categorized.userCreations.count, systemImage: "person")
                            LazyVGrid(columns: gridColumns, spacing: 16) {
                                ForEach(categorized.userCreations, id: \.id) { creation in
                                    SharedCreationItemView(
                                        sharedCreation: creation,
                                        isOwnedByCurrentUser: true,
                                        showToastMsg: showToastMsg,
                                        copyPromptToClipboard: copyPromptToClipboard,
                                        onDeleted: {
                                            Task {
                                                await loadPublicSharedCreations()
                                            }
                                        }
                                    )
                                }
                            }
                        }

                        if !categorized.otherCreations.isEmpty {
                            PromptCollectionSectionLabel(title: "Community Gallery", count: categorized.otherCreations.count, systemImage: "person.3")
                            LazyVGrid(columns: gridColumns, spacing: 16) {
                                ForEach(categorized.otherCreations, id: \.id) { creation in
                                    SharedCreationItemView(
                                        sharedCreation: creation,
                                        isOwnedByCurrentUser: false,
                                        showToastMsg: showToastMsg,
                                        copyPromptToClipboard: copyPromptToClipboard,
                                        onDeleted: nil
                                    )
                                }
                            }
                        }

                        if isLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Updating gallery...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            },
            inspector: {
                VStack(alignment: .leading, spacing: 12) {
                    PromptCollectionInspectorPanel(title: "Community Totals") {
                        PromptCollectionKVList(items: [
                            ("My Shared Prompts", "\(categorized.userCreations.count)"),
                            ("Community Gallery", "\(categorized.otherCreations.count)"),
                            ("Showing", "\(visibleCount)"),
                            ("Filter", searchText.isEmpty ? "All creations" : searchText)
                        ])
                    }

                    PromptCollectionInspectorPanel(title: "Sync Status") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(isLoading ? "Refreshing public gallery…" : "Public gallery is up to date.")
                                .font(.callout)
                            if let loadError {
                                Text(loadError)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    PromptCollectionInspectorPanel(title: "Actions") {
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                Task {
                                    await loadPublicSharedCreations()
                                }
                            } label: {
                                Label("Refresh Community", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        )
        .task {
            await loadPublicSharedCreations()
        }
    }
}

#Preview {
    SharedCreationsView(
        searchText: "",
        showToastMsg: { _, _ in },
        copyPromptToClipboard: { _ in }
    )
    .modelContainer(for: [Prompt.self, PromptHistory.self, SharedCreation.self, DataSource.self])
}
