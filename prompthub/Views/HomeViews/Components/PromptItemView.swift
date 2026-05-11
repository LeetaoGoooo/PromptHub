//
//  PromptItemView.swift
//  prompthub
//
//  Created by leetao on 2025/7/6.
//

import SwiftUI
import SwiftData
import AlertToast

struct PromptItemSharingPresentation {
    let iconName: String
    let iconColor: Color
    let footerBadges: [PromptCollectionFooterBadge]
    let helpText: String
    let sharedCreationID: UUID?

    static let personal = PromptItemSharingPresentation(
        iconName: "person.crop.circle.fill",
        iconColor: .blue,
        footerBadges: [],
        helpText: "Personal Prompt",
        sharedCreationID: nil
    )
}

struct PromptItemView: View {
    let prompt: Prompt
    let sharingPresentation: PromptItemSharingPresentation
    let showToastMsg: (_ msg: String, _ alertType: AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (_ prompt: String) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var showingPreviewSheet = false
    @State private var showingDeleteAlert = false
    
    private var promptContent: String {
        prompt.getLatestPromptContent()
    }
    
    var body: some View {
        PromptCollectionCard(
            title: prompt.name,
            description: prompt.desc,
            systemImage: sharingPresentation.iconName,
            iconTint: sharingPresentation.iconColor,
            onTap: { showingPreviewSheet = true }
        ) {
            PromptCollectionCardFooter(
                leadingBadges: sharingPresentation.footerBadges,
                trailingText: PromptViewHelpers.relativeDateString(from: prompt.lastEditedAt)
            )
        }
        .help(sharingPresentation.helpText)
        .contextMenu {
            Button {
                copyPromptToClipboard(promptContent)
            } label: {
                Label("Copy Content", systemImage: "doc.on.doc")
            }
            
            if sharingPresentation.sharedCreationID != nil {
                Button {
                    copyShareLink()
                } label: {
                    Label("Copy Share Link", systemImage: "link")
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingPreviewSheet) {
            PromptPreviewView(
                promptName: prompt.name,
                promptContent: promptContent,
                copyPromptToClipboard: copyPromptToClipboard
            )
        }
        .alert("Delete Prompt", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePrompt()
            }
        } message: {
            Text("Are you sure you want to delete '\(prompt.name)'? This action cannot be undone.")
        }
    }
    
    private func copyShareLink() {
        guard let sharedCreationID = sharingPresentation.sharedCreationID else { return }

        let shareLink = "sharedprompt://creation/\(sharedCreationID.uuidString)"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(shareLink, forType: .string)
        showToastMsg("Share link copied to clipboard", .complete(.green))
    }
    
    private func deletePrompt() {
        modelContext.delete(prompt)
        do {
            try modelContext.save()
            showToastMsg("Prompt deleted successfully", .complete(.green))
        } catch {
            showToastMsg("Failed to delete prompt", .error(.red))
        }
    }
}
