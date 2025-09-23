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
    @State private var showIconLegend = false
    
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            HStack(spacing: 0) {
                ForEach(PromptTab.allCases, id: \.self) { tab in
                    HStack(spacing: 4) {
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
                        
                        // Add info icon only for All tab
                        if tab == .all {
                            Button {
                                showIconLegend.toggle()
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .opacity(0.7)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .popover(isPresented: $showIconLegend, arrowEdge: .bottom) {
                                IconLegendView()
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Search Bar
            HStack {
                SearchBarView(searchText: $searchText,isFocused: $isSearchFieldFocused)
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
                    AllPromptsView(
                        searchText: searchText,
                        galleryPrompts: galleryPrompts,
                        isLoading: isLoading,
                        showToastMsg: showToastMessage,
                        copyPromptToClipboard: copyToClipboard
                    )
                case .mine:
                    MyPromptsView(
                        searchText: searchText,
                        showToastMsg: showToastMessage,
                        copyPromptToClipboard: copyToClipboard
                    )
                case .shared:
                    SharedCreationsView(
                        searchText: searchText,
                        showToastMsg: showToastMessage,
                        copyPromptToClipboard: copyToClipboard
                    )
                case .explore:
                    ExploreView(
                        searchText: searchText,
                        galleryPrompts: galleryPrompts,
                        isLoading: isLoading,
                        showToastMsg: showToastMessage,
                        copyPromptToClipboard: copyToClipboard
                    )
                }
            }
        }
        .toast(isPresenting: $showToast) {
            AlertToast(type: toastType, title: toastMessage)
        }
        .onAppear {
            loadGalleryPrompts()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                           isSearchFieldFocused = true
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

struct IconLegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon Meanings")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundColor(.blue)
                Text("Unshared prompt")
                    .font(.system(size: 13))
                Spacer()
            }
            
            HStack(spacing: 8) {
                Image(systemName: "shared.with.you.slash")
                    .foregroundColor(.orange)
                Text("Shared prompt (private)")
                    .font(.system(size: 13))
                Spacer()
            }
            
            HStack(spacing: 8) {
                Image(systemName: "shared.with.you")
                    .foregroundColor(.green)
                Text("Public prompt")
                    .font(.system(size: 13))
                Spacer()
            }
        }
        .padding(12)
        .frame(width: 200)
    }
}

#Preview {
    UnifiedPromptBrowserView()
        .environment(\.locale, .init(identifier: "zh-Hans"))
        .modelContainer(for: [Prompt.self, PromptHistory.self, SharedCreation.self])
}
