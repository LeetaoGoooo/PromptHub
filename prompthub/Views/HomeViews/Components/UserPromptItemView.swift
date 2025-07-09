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
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(prompt.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    if let desc = prompt.desc, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        copyPromptToClipboard(latestPromptContent)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            .help("Copy")
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                            .help("Delete Prompt")
                    }
                    .buttonStyle(PlainButtonStyle())
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
                promptName: prompt.name,
                promptContent: latestPromptContent,
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
        .onTapGesture{
            showingPreviewSheet.toggle()
        }
    }
}
