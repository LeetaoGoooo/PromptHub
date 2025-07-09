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
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // Icon based on sharing status
                        Image(systemName: iconName)
                            .foregroundColor(iconColor)
                            .font(.caption)
                            .help(isPublic ? "Public Shared Prompt" : isShared ? "Shared Prompt" : "Personal Prompt")
                        
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
                    // Copy button
                    Button {
                        copyPromptToClipboard(promptContent)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            .help("Copy")
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Share link button (only for shared prompts)
                    if isShared {
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
                    }
                    
                    // Delete button
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .help("Delete")
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
                promptContent: promptContent,
                copyPromptToClipboard: copyPromptToClipboard
            )
        }
        .onTapGesture {
            showingPreviewSheet.toggle()
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
