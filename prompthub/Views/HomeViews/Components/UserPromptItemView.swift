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
    let showToastMsg: (_ msg: String, _ alertType: AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (_ prompt: String) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var isHovering = false
    @State private var showingPreviewSheet = false
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundColor(.blue)
                    .font(.headline)
                    .frame(width: 24, height: 24)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let desc = prompt.desc, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
        }
        .promptCardStyle(isHovering: $isHovering) {
            copyPromptToClipboard(latestPromptContent)
            showToastMsg("Copied to clipboard", .complete(.green))
        }
        // Context menu remains the primary way to interact without opening
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
