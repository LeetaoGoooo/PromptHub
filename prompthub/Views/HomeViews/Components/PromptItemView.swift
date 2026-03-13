//
//  PromptItemView.swift
//  prompthub
//
//  Created by leetao on 2025/7/6.
//

import SwiftUI
import SwiftData
import AlertToast

struct PromptItemView: View {
    let prompt: Prompt
    let showToastMsg: (_ msg: String, _ alertType: AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (_ prompt: String) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var isHovering = false
    @State private var showingPreviewSheet = false
    @State private var showingDeleteAlert = false
    
    // Computed properties for sharing status
    private var sharedCreation: SharedCreation? {
        findExistingSharedCreation(for: prompt)
    }
    
    private var isShared: Bool {
        sharedCreation != nil
    }
    
    private var isPublic: Bool {
        sharedCreation?.isPublic ?? false
    }
    
    private var promptContent: String {
        prompt.getLatestPromptContent()
    }
    
    private var iconName: String {
        if isPublic {
          return  "shared.with.you"
        }
        if isShared {
            return "shared.with.you.slash"
        } else {
            return "person.crop.circle.fill"
        }
    }
    
    private var iconColor: Color {
        if isPublic {
            return .green
        } else if isShared {
            return .orange
        } else {
            return .blue
        }
    }
    
    private var borderColor: Color {
        iconColor.opacity(0.3)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Icon based on sharing status
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .font(.headline)
                    .frame(width: 24, height: 24)
                    .background(iconColor.opacity(0.1))
                    .cornerRadius(6)
                    .help(isPublic ? "Public Shared Prompt" : isShared ? "Shared Prompt" : "Personal Prompt")
                
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
        .padding(12)
        .background(isHovering ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovering ? Color.accentColor.opacity(0.3) : Color(NSColor.separatorColor), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isHovering = hovering
            }
        }
        .onTapGesture {
            // In a Master-Detail view, we might want to select it.
            // But PromptItemView is currently a card in a grid.
            showingPreviewSheet.toggle()
        }
        // Context menu remains the primary way to interact for quick actions
        .contextMenu {
            Button {
                copyPromptToClipboard(promptContent)
            } label: {
                Label("Copy Content", systemImage: "doc.on.doc")
            }
            
            if isShared {
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
        guard let creation = sharedCreation else { return }
        
        let shareLink = "sharedprompt://creation/\(creation.id.uuidString)"
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
    
    private func findExistingSharedCreation(for prompt: Prompt) -> SharedCreation? {
        // Get the latest prompt content
        let latestContent = prompt.getLatestPromptContent()
        
        // Capture the values as constants for the predicate
        let promptName = prompt.name
        let promptText = latestContent
        let promptDesc = prompt.desc

        let descriptor = FetchDescriptor<SharedCreation>(
            predicate: #Predicate<SharedCreation> { sharedCreation in
                sharedCreation.name == promptName &&
                    sharedCreation.prompt == promptText &&
                    sharedCreation.desc == promptDesc
            }
        )

        do {
            let results = try modelContext.fetch(descriptor)
            // Return the most recently modified shared creation if multiple exist
            return results.max(by: { ($0.lastModified ?? Date.distantPast) < ($1.lastModified ?? Date.distantPast) })
        } catch {
            print("Error fetching existing shared creations: \(error)")
            return nil
        }
    }
}
