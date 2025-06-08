//
//  GalleryPromptView.swift
//  prompthub (macOS)
//  Created by leetao on 2025/5/31. (Adjusted date for example)
//

import AlertToast
import SwiftUI

struct GalleryPromptView: View {
    @State private var galleryPrompts: [GalleryPrompt] = []
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: AlertToast.AlertType = .regular
    @State private var isLoading = true

    private func columns(for width: CGFloat) -> [GridItem] {
        let columnCount = max(1, Int(width / 300))
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading Prompts...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.2)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        LazyVGrid(columns: columns(for: geometry.size.width), spacing: 16) {
                            ForEach(galleryPrompts) { prompt in
                                GalleryPromptItemView(
                                    galleryPromptItem: prompt,
                                    showToastMsg: showToastMessage,
                                    copyPromptToClipboard: copyToClipboard
                                )
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(NSColor.windowBackgroundColor))
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                }
                                .shadow(
                                    color: Color.black.opacity(0.12),
                                    radius: 5,
                                    x: 0,
                                    y: 2
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .toast(isPresenting: $showToast) {
            AlertToast(type: toastType, title: toastMessage)
        }
        .onAppear {
            loadPrompts()
        }
        .frame(minWidth: 400, idealWidth: 800, maxWidth: .infinity,
               minHeight: 300, idealHeight: 600, maxHeight: .infinity)
    }

    private func loadPrompts() {
        isLoading = true
        
        DispatchQueue.main.async {
            self.galleryPrompts = BuiltInAgents.agents.map { $0.toGalleryPrompt() }
            self.isLoading = false
        }
    }

    private func showToastMessage(_ message: String, _ type: AlertToast.AlertType) {
        toastMessage = message
        toastType = type
        showToast = true
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showToastMessage("Copied to clipboard", .complete(.green))
    }
}

#Preview {
    GalleryPromptView()
        .environment(\.locale, .init(identifier: "en")) // For consistent preview
}
