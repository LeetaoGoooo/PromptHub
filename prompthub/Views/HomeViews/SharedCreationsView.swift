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
    @State private var selectedItemID: String?

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

    private var browserSections: [PromptBrowserSection] {
        let categorized = categorizedSharedCreations
        var sections: [PromptBrowserSection] = []

        if !categorized.userCreations.isEmpty {
            sections.append(
                PromptBrowserSection(
                    id: "my-shared",
                    title: "My Shared Prompts",
                    systemImage: "person",
                    items: categorized.userCreations.map { creation in
                        browserItem(for: creation, isOwnedByCurrentUser: true)
                    }
                )
            )
        }

        if !categorized.otherCreations.isEmpty {
            sections.append(
                PromptBrowserSection(
                    id: "community-shared",
                    title: "Community Gallery",
                    systemImage: "person.3",
                    items: categorized.otherCreations.map { creation in
                        browserItem(for: creation, isOwnedByCurrentUser: false)
                    }
                )
            )
        }

        return sections
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

        return PromptBrowserScreen(
            sections: browserSections,
            selectedItemID: $selectedItemID,
            emptyState: {
                if isLoading && visibleCount == 0 {
                    VStack(spacing: 12) {
                        ProgressView("Loading public shared creations...")
                        if let loadError {
                            Text(loadError)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if !isLoading && visibleCount == 0 && !searchText.isEmpty {
                    PromptViewHelpers.emptyStateView(
                        iconName: "magnifyingglass",
                        title: "No matching shared creations found",
                        subtitle: "Try broader keywords or clear the current filter."
                    )
                } else {
                    PromptViewHelpers.emptyStateView(
                        iconName: "square.and.arrow.up",
                        title: "No shared creations yet",
                        subtitle: "Share your prompts or explore public creations from the community."
                    )
                }
            },
            toolbarContent: {
                ToolbarItemGroup(placement: .primaryAction) {}
            }
        )
        .task {
            if publicSharedCreations.isEmpty {
                await loadPublicSharedCreations()
            }
        }
    }

    private func browserItem(for creation: SharedCreation, isOwnedByCurrentUser: Bool) -> PromptBrowserItem {
        PromptBrowserItem(
            id: "shared-\(creation.id.uuidString)",
            title: creation.name,
            summary: creation.desc ?? "No description",
            promptText: creation.prompt,
            systemImage: creation.isPublic ? "shared.with.you" : "shared.with.you.slash",
            iconTint: creation.isPublic ? .green : .orange,
            badges: [
                PromptCollectionFooterBadge(title: creation.isPublic ? "Public" : "Shared", tint: creation.isPublic ? .green : .orange),
                PromptCollectionFooterBadge(title: isOwnedByCurrentUser ? "Mine" : "Community", tint: isOwnedByCurrentUser ? .accentColor : .secondary)
            ],
            trailingDetail: PromptViewHelpers.relativeDateString(from: creation.lastModified),
            metadata: [
                PromptBrowserMetadataRow(label: "Source", value: isOwnedByCurrentUser ? "My Shared Prompt" : "Community Gallery"),
                PromptBrowserMetadataRow(label: "Visibility", value: creation.isPublic ? "Public" : "Shared"),
                PromptBrowserMetadataRow(label: "Updated", value: PromptViewHelpers.relativeDateString(from: creation.lastModified))
            ],
            primaryActionTitle: "Copy Share Link",
            primaryActionSystemImage: "link",
            isPrimaryActionDisabled: false,
            onPrimaryAction: { copyShareLink(for: creation) },
            secondaryActionTitle: "Copy Content",
            secondaryActionSystemImage: "doc.on.doc",
            onSecondaryAction: { copyPromptToClipboard(creation.prompt) }
        )
    }

    private func copyShareLink(for creation: SharedCreation) {
        let shareLink = "sharedprompt://creation/\(creation.id.uuidString)"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(shareLink, forType: .string)
        showToastMsg("Share link copied to clipboard", .complete(.green))
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
