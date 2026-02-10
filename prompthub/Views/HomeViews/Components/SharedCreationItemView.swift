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
    let showToastMsg: (_ msg: String, _ alertType: AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (_ prompt: String) -> Void
    let onDeleted: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @State private var isHovering = false
    @State private var showingPreviewSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SharedCreationItemView")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: sharedCreation.isPublic ? "shared.with.you": "shared.with.you.slash" )
                    .foregroundColor(sharedCreation.isPublic ? .green : .orange)
                    .font(.headline)
                    .frame(width: 24, height: 24)
                    .background((sharedCreation.isPublic ? Color.green : Color.orange).opacity(0.1))
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(sharedCreation.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let desc = sharedCreation.desc, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
        }
        .padding(12)
        .background(isHovering ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovering ? Color.accentColor.opacity(0.3) : Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isHovering = hovering
            }
        }
        .contextMenu {
            Button {
                copyShareLink()
            } label: {
                Label("Copy Share Link", systemImage: "link")
            }
            
            if canDeleteThisCreation() {
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
        .onTapGesture {
            showingPreviewSheet.toggle()
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
    
    private func canDeleteThisCreation() -> Bool {
        return SharedCreation.isCreatedByCurrentUser(id: sharedCreation.id, modelContext: modelContext)
    }
    
    private func deleteSharedCreation() async {
        do {
            let syncManager = PublicCloudKitSyncManager(
                containerIdentifier: "iCloud.com.duck.leetao.promptbox",
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
