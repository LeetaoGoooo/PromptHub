//
//  UserPromptItemView.swift
//  prompthub
//
//  Created by leetao on 2025/6/24.
//

import SwiftUI
import AlertToast


struct UserPromptItemView: View {
    let prompt: Prompt
    let footerBadges: [PromptCollectionFooterBadge]
    let showToastMsg: (_ msg: String, _ alertType: AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (_ prompt: String) -> Void
    let onOpen: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteAlert = false
    
    private var latestPromptContent: String {
        prompt.history?.sorted { $0.version > $1.version }.first?.promptText ?? ""
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
    
    var body: some View {
        PromptCollectionCard(
            title: prompt.name,
            description: prompt.desc,
            systemImage: "person",
            iconTint: .blue,
            onTap: onOpen
        ) {
            PromptCollectionCardFooter(
                leadingBadges: footerBadges + [PromptCollectionFooterBadge(title: "v\(max(prompt.latestVersionNumber, 1))", tint: .secondary)],
                trailingText: PromptViewHelpers.relativeDateString(from: prompt.lastEditedAt)
            )
        }
        .contextMenu {
            Button {
                copyPromptToClipboard(latestPromptContent)
            } label: {
                Label("Copy Content", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
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
}
