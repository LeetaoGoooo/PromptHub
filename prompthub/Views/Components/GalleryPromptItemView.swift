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
        VStack(alignment: .leading) {
            HStack {
                Text(galleryPromptItem.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()

                HStack(spacing: 8) {
                    Button {
                        copyPromptToClipboard(galleryPromptItem.prompt)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                            .help("Copy")
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button {
                        Task { @MainActor in
                            savePrompt()
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                            .help("Save")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            if galleryPromptItem.description != nil {
                Text(galleryPromptItem.description!)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .help(galleryPromptItem.description!)
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
                promptName: galleryPromptItem.name,
                promptContent: galleryPromptItem.prompt,
                copyPromptToClipboard: copyPromptToClipboard
            )
        }
        .onTapGesture{
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
