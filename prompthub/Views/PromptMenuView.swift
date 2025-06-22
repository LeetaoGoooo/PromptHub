//
//  PromptMenuView.swift
//  prompthub
//
//  Created by leetao on 2025/3/2.
//

import SwiftData
import SwiftUI

// MARK: - Main Menu View

struct PromptMenuView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Prompt.name, order: .forward) private var allPrompts: [Prompt]
    
    @State private var searchPrompt: String = ""

    private var filteredPrompts: [Prompt] {
        if searchPrompt.isEmpty {
            return allPrompts
        } else {
            return allPrompts.filter { prompt in
                prompt.name.localizedCaseInsensitiveContains(searchPrompt)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            
            SearchBarView(searchText: $searchPrompt)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            
            Divider()

            if allPrompts.isEmpty {
                emptyStateView(text: "No prompts available.")
            } else if filteredPrompts.isEmpty {
                emptyStateView(text: "No results for \"\(searchPrompt)\"")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredPrompts) { prompt in
                            PromptRowView(prompt: prompt) {
                                copyToClipboard(prompt)
                            }
                        }
                    }
                    .padding(6)
                }
            }
        }
        .frame(width: 320, height: 400)
    }
    
    @ViewBuilder
    private func emptyStateView(text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .foregroundColor(.secondary)
                .font(.callout)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func copyToClipboard(_ prompt: Prompt) {
        // Get the latest history from the prompt's relationship
        let sortedHistory = prompt.history.sorted { $0.version > $1.version }
        
        if let latestPromptText = sortedHistory.first?.content {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(latestPromptText, forType: .string)
            
            print("Copied: \(prompt.name)")
        } else {
            print("No history found for prompt: \(prompt.name)")
        }
    }
}

// MARK: - Prompt Row View
struct PromptRowView: View {
    let prompt: Prompt
    let action: () -> Void
    
    @State private var isHovering = false
    @State private var didCopy = false
    
    var body: some View {
        Button(action: {
            guard !didCopy else { return }
            
            action()
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                didCopy = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    didCopy = false
                    if isHovering {
                        isHovering = !isHovering;
                    }
                }
            }
        }) {
            Group {
                if didCopy {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                        Text("Copied!")
                            .fontWeight(.semibold)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                } else {
                    Text(prompt.name)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering && !didCopy ? Color.primary.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            if !didCopy {
                withAnimation(.easeOut(duration: 0.1)) {
                    isHovering = hovering
                }
            }
        }
    }
}

#Preview {
    PromptMenuView()
        .modelContainer(PreviewData.previewContainer)
}
