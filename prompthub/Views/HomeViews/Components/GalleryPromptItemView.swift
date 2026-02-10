//
//  GalleryPromptItemView.swift
//  prompthub
//
//  Created by leetao on 2025/6/1.
//

import AlertToast
import SwiftUI

struct GalleryPromptItemView: View {
    let galleryPromptItem: GalleryPrompt
    let showToastMsg: (_ msg: String, _ alertType: AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (_ prompt: String) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var isHovering = false
    @State private var showingPreviewSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .foregroundColor(.accentColor)
                    .font(.headline)
                    .frame(width: 24, height: 24)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(galleryPromptItem.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let desc = galleryPromptItem.description, !desc.isEmpty {
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
                copyPromptToClipboard(galleryPromptItem.prompt)
            } label: {
                Label("Copy Content", systemImage: "doc.on.doc")
            }
            
            Button {
                Task { @MainActor in
                    savePrompt()
                }
            } label: {
                Label("Save to My Prompts", systemImage: "square.and.arrow.down")
            }
        }
        .sheet(isPresented: $showingPreviewSheet) {
            PromptPreviewView(
                promptName: galleryPromptItem.name,
                promptContent: galleryPromptItem.prompt,
                copyPromptToClipboard: copyPromptToClipboard
            )
        }
        .onTapGesture {
            showingPreviewSheet.toggle()
        }
    }

    @MainActor
    func savePrompt() {
        do {
            let newPrompt = Prompt(name: galleryPromptItem.name, desc: galleryPromptItem.description, link: galleryPromptItem.link)
            modelContext.insert(newPrompt)

            let newPromptHistory = newPrompt.createHistory(prompt: galleryPromptItem.prompt, version: 0)
            modelContext.insert(newPromptHistory)

            try modelContext.save()

        } catch {
            print("Failed to save prompt and PromptHistory transactionally: \(error)")
            showToastMsg("Failed to save prompt: \(error)", .error(Color.red))
        }
    }
}

#Preview {
    GalleryPromptItemView(galleryPromptItem: GalleryPrompt(id:"1", name: "Test", description: "It makes your UI look great and it doesn't require a lot of effort. \n It's easy to implement and looks much better than a flat design.", prompt: "I like to use this type of card view in my designs."), showToastMsg: { message, alertType in
        // This is a dummy implementation for the SwiftUI Preview.
        // In a real app, this closure would be provided by a parent view
        // and would trigger an actual toast message.
        print("Show Toast (Preview): '\(message)' with type: \(alertType)")
    }, copyPromptToClipboard: { prompt in
        print("promt:\(prompt)")
    })
}
