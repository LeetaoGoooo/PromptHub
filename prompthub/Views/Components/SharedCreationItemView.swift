//
//  SharedCreationItemView.swift
//  prompthub
//
//  Created by leetao on 2025/6/24.
//

import SwiftUI
import AlertToast

struct SharedCreationItemView: View {
    let sharedCreation: SharedCreation
    let showToastMsg: (_ msg: String, _ alertType: AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (_ prompt: String) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var isHovering = false
    @State private var showingPreviewSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false

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
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
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
                Task {
                    await deleteSharedCreation()
                }
            }
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
        isDeleting = true
        
        do {
            let syncManager = PublicCloudKitSyncManager(
                containerIdentifier: "iCloud.com.duck.leetao.promptbox",
                modelContext: modelContext
            )
            
            try await syncManager.deleteSharedCreation(sharedCreation)
            
            showToastMsg(
                "Shared creation deleted successfully",
                .complete(.green)
            )
        } catch {
            showToastMsg(
                "Failed to delete shared creation: \(error.localizedDescription)",
                .error(.red)
            )
        }
        
        isDeleting = false
    }
}
