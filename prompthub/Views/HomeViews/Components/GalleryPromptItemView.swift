//
//  GalleryPromptItemView.swift
//  prompthub
//
//  Created by leetao on 2025/6/1.
//

import AlertToast
import SwiftData
import SwiftUI

struct GalleryPromptItemView: View {
    let galleryPromptItem: GalleryPrompt
    let showToastMsg: (_ msg: String, _ alertType: AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (_ prompt: String) -> Void
    @Environment(\.modelContext) private var modelContext
    @Query private var savedPrompts: [Prompt]
    @State private var showingPreviewSheet = false

    private var isAlreadySaved: Bool {
        savedPrompts.contains {
            $0.name == galleryPromptItem.name &&
            $0.getLatestPromptContent() == galleryPromptItem.prompt
        }
    }

    private var footerBadges: [PromptCollectionFooterBadge] {
        [PromptCollectionFooterBadge(title: isAlreadySaved ? "Saved" : "Save to library", tint: isAlreadySaved ? .secondary : .green)]
    }

    var body: some View {
        PromptCollectionCard(
            title: galleryPromptItem.name,
            description: galleryPromptItem.description,
            systemImage: "sparkles",
            iconTint: .primary,
            onTap: { showingPreviewSheet = true }
        ) {
            PromptCollectionCardFooter(
                leadingBadges: footerBadges,
                trailingText: galleryPromptItem.link?.isEmpty == false ? "Link available" : "Built-in"
            )
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
    }

    @MainActor
    func savePrompt() {
        guard !isAlreadySaved else {
            showToastMsg("Prompt already saved", .complete(.green))
            return
        }

        do {
            let newPrompt = Prompt(name: galleryPromptItem.name, desc: galleryPromptItem.description, link: galleryPromptItem.link)
            modelContext.insert(newPrompt)

            let newPromptHistory = newPrompt.createHistory(prompt: galleryPromptItem.prompt, version: 0)
            modelContext.insert(newPromptHistory)

            try modelContext.save()
            PromptHubBridge.shared.exportPrompt(newPrompt)
            showToastMsg("Saved to My Prompts", .complete(.green))

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
