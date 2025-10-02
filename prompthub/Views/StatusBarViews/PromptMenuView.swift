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
    @Query private var sharedCreations: [SharedCreation]
    
    @State private var searchPrompt: String = ""
    @State private var galleryPrompts: [GalleryPrompt] = []
    @State private var isLoading = true

    @FocusState private var isSearchFieldFocused: Bool
    
    private var filteredUserPrompts: [Prompt] {
        if searchPrompt.isEmpty {
            return allPrompts
        } else {
            return allPrompts.filter { prompt in
                prompt.name.localizedCaseInsensitiveContains(searchPrompt) ||
                (prompt.desc?.localizedCaseInsensitiveContains(searchPrompt) ?? false)
            }
        }
    }
    
    private var filteredSharedCreations: [SharedCreation] {
        if searchPrompt.isEmpty {
            return sharedCreations
        }
        return sharedCreations.filter { creation in
            creation.name.localizedCaseInsensitiveContains(searchPrompt) ||
            (creation.desc?.localizedCaseInsensitiveContains(searchPrompt) ?? false)
        }
    }
    
    private var filteredGalleryPrompts: [GalleryPrompt] {
        if searchPrompt.isEmpty {
            return galleryPrompts
        }
        return galleryPrompts.filter { prompt in
            prompt.name.localizedCaseInsensitiveContains(searchPrompt) ||
            (prompt.description?.localizedCaseInsensitiveContains(searchPrompt) ?? false)
        }
    }
    
    private var hasAnyPrompts: Bool {
        !allPrompts.isEmpty || !sharedCreations.isEmpty || !galleryPrompts.isEmpty
    }
    
    private var hasFilteredResults: Bool {
        !filteredUserPrompts.isEmpty || !filteredSharedCreations.isEmpty || !filteredGalleryPrompts.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            
            SearchBarView(searchText: $searchPrompt, isFocused: $isSearchFieldFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        
            Divider()

            if isLoading {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !hasAnyPrompts {
                emptyStateView(text: "No prompts available.")
            } else if !hasFilteredResults && !searchPrompt.isEmpty {
                emptyStateView(text: "No results for \"\(searchPrompt)\"")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        // Always show user prompts
                        ForEach(filteredUserPrompts) { prompt in
                            PromptRowView(
                                prompt: prompt,
                                promptType: .user,
                                action: { copyToClipboard(prompt.getLatestPromptContent()) }
                            )
                        }
                        
                        // Only show shared creations and gallery prompts when searching
                        if !searchPrompt.isEmpty {
                            // Shared creations section
                            ForEach(filteredSharedCreations, id: \.id) { creation in
                                SharedCreationRowView(
                                    sharedCreation: creation,
                                    action: { copyToClipboard(creation.prompt) }
                                )
                            }
                            
                            // Gallery prompts section
                            ForEach(filteredGalleryPrompts) { galleryPrompt in
                                GalleryPromptRowView(
                                    galleryPrompt: galleryPrompt,
                                    action: { copyToClipboard(galleryPrompt.prompt) }
                                )
                            }
                        }
                    }
                    .padding(6)
                }
            }
        }
        .frame(width: 320, height: 400)
        .onAppear {
            loadGalleryPrompts()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                           isSearchFieldFocused = true
            }
        }
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
    
    private func loadGalleryPrompts() {
        isLoading = true
        
        DispatchQueue.main.async {
            self.galleryPrompts = BuiltInAgents.agents.map { $0.toGalleryPrompt() }
            self.isLoading = false
        }
    }

    private func copyToClipboard(_ promptText: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(promptText, forType: .string)
        print("Copied prompt to clipboard")
    }
}

// MARK: - Prompt Type Enum
enum PromptType {
    case user
    case shared
    case gallery
    
    var icon: String {
        switch self {
        case .user:
            return "person.crop.circle.fill"
        case .shared:
            return "square.and.arrow.up.fill"
        case .gallery:
            return "globe"
        }
    }
    
    var color: Color {
        switch self {
        case .user:
            return .blue
        case .shared:
            return .orange
        case .gallery:
            return .gray
        }
    }
}

// MARK: - Prompt Row View
struct PromptRowView: View {
    let prompt: Prompt
    let promptType: PromptType
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
                            .foregroundColor(.green)
                        Text("Copied!")
                            .fontWeight(.semibold)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: promptType.icon)
                            .font(.caption)
                            .foregroundColor(promptType.color)
                        Text(prompt.name)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering && !didCopy ? promptType.color.opacity(0.1) : Color.clear)
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

// MARK: - Shared Creation Row View
struct SharedCreationRowView: View {
    let sharedCreation: SharedCreation
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
                            .foregroundColor(.green)
                        Text("Copied!")
                            .fontWeight(.semibold)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: PromptType.shared.icon)
                            .font(.caption)
                            .foregroundColor(PromptType.shared.color)
                        Text(sharedCreation.name)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering && !didCopy ? PromptType.shared.color.opacity(0.1) : Color.clear)
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

// MARK: - Gallery Prompt Row View
struct GalleryPromptRowView: View {
    let galleryPrompt: GalleryPrompt
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
                            .foregroundColor(.green)
                        Text("Copied!")
                            .fontWeight(.semibold)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: PromptType.gallery.icon)
                            .font(.caption)
                            .foregroundColor(PromptType.gallery.color)
                        Text(galleryPrompt.name)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering && !didCopy ? PromptType.gallery.color.opacity(0.1) : Color.clear)
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
