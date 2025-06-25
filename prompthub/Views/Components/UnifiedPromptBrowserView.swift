//
//  UnifiedPromptBrowserView.swift
//  prompthub
//
//  Created by leetao on 2025/6/24.
//

import AlertToast
import SwiftData
import SwiftUI

enum PromptTab: String, CaseIterable {
    case all
    case mine
    case shared
    case explore
    
    var localizedTitle: String {
        switch self {
        case .all:
            return "All"
        case .mine:
            return "Mine"
        case .shared:
            return "Shared"
        case .explore:
            return "Explore"
        }
    }
    
    var icon: String {
        switch self {
        case .all:
            return "square.grid.2x2"
        case .mine:
            return "person.crop.circle"
        case .shared:
            return "square.and.arrow.up"
        case .explore:
            return "globe"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .all:
            return .accentColor
        case .mine:
            return .blue
        case .shared:
            return .orange
        case .explore:
            return .gray
        }
    }
}

struct UnifiedPromptBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userPrompts: [Prompt]
    @Query private var sharedCreations: [SharedCreation]
    
    @State private var selectedTab: PromptTab = .all
    @State private var searchText = ""
    @State private var galleryPrompts: [GalleryPrompt] = []
    @State private var isLoading = true
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: AlertToast.AlertType = .regular
    
    private func columns(for width: CGFloat) -> [GridItem] {
        let columnCount = max(1, Int(width / 300))
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }
    
    private var filteredGalleryPrompts: [GalleryPrompt] {
        if searchText.isEmpty {
            return galleryPrompts
        }
        return galleryPrompts.filter { prompt in
            prompt.name.localizedCaseInsensitiveContains(searchText) ||
            (prompt.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    private var filteredUserPrompts: [Prompt] {
        if searchText.isEmpty {
            return userPrompts
        }
        return userPrompts.filter { prompt in
            prompt.name.localizedCaseInsensitiveContains(searchText) ||
            (prompt.desc?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    private var filteredSharedCreations: [SharedCreation] {
        if searchText.isEmpty {
            return sharedCreations
        }
        return sharedCreations.filter { creation in
            creation.name.localizedCaseInsensitiveContains(searchText) ||
            (creation.desc?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            HStack(spacing: 0) {
                ForEach(PromptTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14, weight: .medium))
                            Text(tab.localizedTitle)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(selectedTab == tab ? tab.accentColor : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? tab.accentColor.opacity(0.1) : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Search Bar
            HStack {
                SearchBarView(searchText: $searchText)
                    .frame(maxWidth: 300)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Content Area
            Group {
                switch selectedTab {
                case .all:
                    allPromptsView
                case .mine:
                    myPromptsView
                case .shared:
                    sharedCreationsView
                case .explore:
                    exploreView
                }
            }
        }
        .toast(isPresenting: $showToast) {
            AlertToast(type: toastType, title: toastMessage)
        }
        .onAppear {
            loadGalleryPrompts()
        }
    }
    
    @ViewBuilder
    private var allPromptsView: some View {
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
                        // User's prompts first
                        ForEach(filteredUserPrompts) { prompt in
                            UserPromptItemView(
                                prompt: prompt,
                                showToastMsg: showToastMessage,
                                copyPromptToClipboard: copyToClipboard
                            )
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(NSColor.windowBackgroundColor))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            }
                            .shadow(
                                color: Color.black.opacity(0.12),
                                radius: 5,
                                x: 0,
                                y: 2
                            )
                        }
                        
                        // Local shared creations
                        ForEach(filteredSharedCreations, id: \.id) { creation in
                            SharedCreationItemView(
                                sharedCreation: creation,
                                showToastMsg: showToastMessage,
                                copyPromptToClipboard: copyToClipboard
                            )
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(NSColor.windowBackgroundColor))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            }
                            .shadow(
                                color: Color.black.opacity(0.12),
                                radius: 5,
                                x: 0,
                                y: 2
                            )
                        }
                        
                        // Gallery prompts
                        ForEach(filteredGalleryPrompts) { prompt in
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
    
    @ViewBuilder
    private var myPromptsView: some View {
        if filteredUserPrompts.isEmpty && !searchText.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No matching prompts found")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Try using different keywords")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredUserPrompts.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No custom prompts yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Click the \"+\" button in the sidebar to create your first prompt")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: columns(for: geometry.size.width), spacing: 16) {
                        ForEach(filteredUserPrompts) { prompt in
                            UserPromptItemView(
                                prompt: prompt,
                                showToastMsg: showToastMessage,
                                copyPromptToClipboard: copyToClipboard
                            )
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(NSColor.windowBackgroundColor))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
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
    
    @ViewBuilder
    private var sharedCreationsView: some View {
        if filteredSharedCreations.isEmpty && !searchText.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No matching shared creations found")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Try using different keywords")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredSharedCreations.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No shared creations yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Share your prompts to see them here")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: columns(for: geometry.size.width), spacing: 16) {
                        // Local shared creations
                        ForEach(filteredSharedCreations, id: \.id) { creation in
                            SharedCreationItemView(
                                sharedCreation: creation,
                                showToastMsg: showToastMessage,
                                copyPromptToClipboard: copyToClipboard
                            )
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(NSColor.windowBackgroundColor))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
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
    
    @ViewBuilder
    private var exploreView: some View {
        if isLoading {
            ProgressView("Loading Prompts...")
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredGalleryPrompts.isEmpty && !searchText.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No matching content found")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Try using different keywords")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredGalleryPrompts.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "globe")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No content available")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Gallery prompts will appear here")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: columns(for: geometry.size.width), spacing: 16) {
                        // Gallery prompts
                        ForEach(filteredGalleryPrompts) { prompt in
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
    
    private func loadGalleryPrompts() {
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
    UnifiedPromptBrowserView()
        .environment(\.locale, .init(identifier: "zh-Hans"))
        .modelContainer(for: [Prompt.self, PromptHistory.self, SharedCreation.self])
}
