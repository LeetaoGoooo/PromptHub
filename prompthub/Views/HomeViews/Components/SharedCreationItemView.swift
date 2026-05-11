//
//  SharedCreationItemView.swift
//  prompthub
//
//  Created by leetao on 2025/6/24.
//

import SwiftUI
import AlertToast
import OSLog

struct SharedCreationItemView: View {
    let sharedCreation: SharedCreation
    let isOwnedByCurrentUser: Bool
    let showToastMsg: (_ msg: String, _ alertType: AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (_ prompt: String) -> Void
    let onDeleted: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @State private var showingPreviewSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.duck.leetao.prompthub",
        category: "SharedCreationItemView"
    )

    private var footerBadges: [PromptCollectionFooterBadge] {
        [
            PromptCollectionFooterBadge(
                title: sharedCreation.isPublic ? "Public" : "Shared",
                tint: sharedCreation.isPublic ? .green : .orange
            ),
            PromptCollectionFooterBadge(
                title: isOwnedByCurrentUser ? "Mine" : "Community",
                tint: isOwnedByCurrentUser ? .accentColor : .secondary
            )
        ]
    }

    var body: some View {
        PromptCollectionCard(
            title: sharedCreation.name,
            description: sharedCreation.desc,
            systemImage: sharedCreation.isPublic ? "shared.with.you" : "shared.with.you.slash",
            iconTint: sharedCreation.isPublic ? .green : .orange,
            onTap: { showingPreviewSheet = true }
        ) {
            PromptCollectionCardFooter(
                leadingBadges: footerBadges,
                trailingText: PromptViewHelpers.relativeDateString(from: sharedCreation.lastModified)
            )
        }
        .contextMenu {
            Button {
                copyShareLink()
            } label: {
                Label("Copy Share Link", systemImage: "link")
            }
            
            if isOwnedByCurrentUser {
                Divider()
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingPreviewSheet) {
            PromptPreviewView(
                promptName: sharedCreation.name,
                promptContent: sharedCreation.prompt,
                copyPromptToClipboard: copyPromptToClipboard
            )
        }
        .confirmationDialog(
            "Delete Shared Creation",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                isDeleting = true
                Task {
                    await deleteSharedCreation()
                }
            }
            .disabled(isDeleting)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(sharedCreation.name)'? This action cannot be undone and will remove it from the public gallery.")
        }
    }
    
    private func copyShareLink() {
        // Generate share link using the shared creation ID - use the same scheme as in LatestVersionView
        let shareLink = "sharedprompt://creation/\(sharedCreation.id.uuidString)"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(shareLink, forType: .string)
        showToastMsg("Share link copied to clipboard", .complete(.green))
    }
    
    private func deleteSharedCreation() async {
        do {
            let syncManager = try PublicCloudKitSyncManager(
                containerIdentifier: CloudKitAccess.publicContainerIdentifier,
                modelContext: modelContext
            )
            
            showToastMsg(
                "Deleting shared creation...",
                .regular
            )
            
            logger.info("Starting deletion for SharedCreation: \(self.sharedCreation.id)")
            // Delete from CloudKit
            try await syncManager.deleteSharedCreation(sharedCreation)
            logger.info("CloudKit deletion completed successfully for SharedCreation: \(self.sharedCreation.id)")
            showToastMsg(
                "Shared creation deleted successfully",
                .complete(.green)
            )
            
            // Trigger refresh callback
            onDeleted?()
        } catch {
            logger.error("Deletion failed for SharedCreation: \(self.sharedCreation.id), error: \(error.localizedDescription)")
            
            // Check if this is a CloudKit sync error
            if (error as NSError).domain == "CloudKitSync" && (error as NSError).code == 1001 {
                showToastMsg(
                    "CloudKit deletion failed. Please try again when online.",
                    .error(.orange)
                )
            } else {
                showToastMsg(
                    "Failed to delete shared creation: \(error.localizedDescription)",
                    .error(.red)
                )
            }
        }
        
        isDeleting = false
    }
}
