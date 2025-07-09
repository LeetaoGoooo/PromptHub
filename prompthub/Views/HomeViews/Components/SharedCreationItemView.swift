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
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: sharedCreation.isPublic ? "shared.with.you": "shared.with.you.slash" )
                            .foregroundColor(sharedCreation.isPublic ? .green : .orange)
                            .font(.caption)
                        Text(sharedCreation.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    if let desc = sharedCreation.desc, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    if let lastModified = sharedCreation.lastModified {
                        Text("Modified: \(lastModified.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        copyShareLink()
                    } label: {
                        Image(systemName: "link")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                            .help("Copy Share Link")
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Show delete button only if the current user created this shared creation
                    if canDeleteThisCreation() {
                        Button {
                            showingDeleteConfirmation = true
                        } label: {
                            if isDeleting {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            } else {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                                    .help("Delete Shared Creation")
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isDeleting)
                    }
                }
            }
        }
        .padding()
        .cornerRadius(20)
        .shadow(
            color: Color.primary.opacity(isHovering ? 0.3 : 0.15),
            radius: isHovering ? 12 : 5,
            x: 0,
            y: isHovering ? 6 : 3
        )
        .offset(y: isHovering ? -4 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isHovering)
        .onHover { hovering in
            self.isHovering = hovering
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
