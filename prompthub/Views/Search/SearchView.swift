//
//  SearchView.swift
//  prompthub
//
//  Created by leetao on 2025/4/5.
//

import SwiftData
import SwiftUI

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Prompt.name, order: .forward) private var allPrompts: [Prompt]
    @Query private var sharedCreations: [SharedCreation]
    @Query(sort: \Skill.updatedAt, order: .reverse) private var skillDrafts: [Skill]
    
    @State private var searchText: String = ""
    @State private var galleryPrompts: [GalleryPrompt] = []
    @State private var isLoading = true
    @State private var selectedIndex: Int = 0
    @State private var copiedIndex: Int? = nil
    
    @FocusState private var isSearchFieldFocused: Bool
    
    let onClose: () -> Void
    
    private var filteredUserPrompts: [SearchablePrompt] {
        if searchText.isEmpty {
            return allPrompts.map { SearchablePrompt(prompt: $0) }
        } else {
            return allPrompts.filter { prompt in
                prompt.name.localizedCaseInsensitiveContains(searchText) ||
                (prompt.desc?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                prompt.getLatestPromptContent().localizedCaseInsensitiveContains(searchText)
            }.map { SearchablePrompt(prompt: $0) }
        }
    }
    
    private var filteredSharedCreations: [SearchableSharedCreation] {
        if searchText.isEmpty {
            return sharedCreations.map { SearchableSharedCreation(creation: $0) }
        }
        return sharedCreations.filter { creation in
            creation.name.localizedCaseInsensitiveContains(searchText) ||
            (creation.desc?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            creation.prompt.localizedCaseInsensitiveContains(searchText)
        }.map { SearchableSharedCreation(creation: $0) }
    }
    
    private var filteredGalleryPrompts: [SearchableGalleryPrompt] {
        if searchText.isEmpty {
            return galleryPrompts.map { SearchableGalleryPrompt(galleryPrompt: $0) }
        }
        return galleryPrompts.filter { prompt in
            prompt.name.localizedCaseInsensitiveContains(searchText) ||
            (prompt.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            prompt.prompt.localizedCaseInsensitiveContains(searchText)
        }.map { SearchableGalleryPrompt(galleryPrompt: $0) }
    }

    private var filteredSkillDrafts: [SearchableSkillDraft] {
        let drafts = skillDrafts.map { SearchableSkillDraft(skill: $0) }
        guard !searchText.isEmpty else {
            return drafts
        }

        return drafts.filter { draft in
            draft.name.localizedCaseInsensitiveContains(searchText) ||
            (draft.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            draft.searchableContent.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var allFilteredResults: [any SearchableItem] {
        var results: [any SearchableItem] = []
        results.append(contentsOf: filteredUserPrompts)
        results.append(contentsOf: filteredSharedCreations)
        results.append(contentsOf: filteredGalleryPrompts)
        results.append(contentsOf: filteredSkillDrafts)
        return results
    }
    
    private var hasAnyPrompts: Bool {
        !allPrompts.isEmpty || !sharedCreations.isEmpty || !galleryPrompts.isEmpty || !skillDrafts.isEmpty
    }
    
    private var hasFilteredResults: Bool {
        !filteredUserPrompts.isEmpty || !filteredSharedCreations.isEmpty || !filteredGalleryPrompts.isEmpty || !filteredSkillDrafts.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SearchBarView(searchText: $searchText, isFocused: $isSearchFieldFocused)
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
            } else if !hasFilteredResults && !searchText.isEmpty {
                emptyStateView(text: "No results for \"\(searchText)\"")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            if !filteredUserPrompts.isEmpty {
                                searchSectionHeader("My Prompts")
                                ForEach(filteredUserPrompts.indices, id: \.self) { index in
                                    SearchResultRowView(
                                    item: filteredUserPrompts[index],
                                    type: .user,
                                    isSelected: index == selectedIndex,
                                    onOpen: {
                                        openItem(filteredUserPrompts[index])
                                    },
                                    onCopy: {
                                        copyItem(filteredUserPrompts[index])
                                    },
                                    index: index,
                                    copiedIndex: copiedIndex
                                    )
                                    .id("user_\(index)")
                                }
                            }

                            if !filteredSharedCreations.isEmpty {
                                searchSectionHeader("Shared With Me")
                                ForEach(filteredSharedCreations.indices, id: \.self) { index in
                                    let actualIndex = index + filteredUserPrompts.count
                                    SearchResultRowView(
                                    item: filteredSharedCreations[index],
                                    type: .shared,
                                    isSelected: actualIndex == selectedIndex,
                                    onOpen: {
                                        openItem(filteredSharedCreations[index])
                                    },
                                    onCopy: {
                                        copyItem(filteredSharedCreations[index])
                                    },
                                    index: actualIndex,
                                    copiedIndex: copiedIndex
                                    )
                                    .id("shared_\(index)")
                                }
                            }

                            if !filteredGalleryPrompts.isEmpty {
                                searchSectionHeader("Gallery")
                                ForEach(filteredGalleryPrompts.indices, id: \.self) { index in
                                    let actualIndex = index + filteredUserPrompts.count + filteredSharedCreations.count
                                    SearchResultRowView(
                                    item: filteredGalleryPrompts[index],
                                    type: .gallery,
                                    isSelected: actualIndex == selectedIndex,
                                    onOpen: {
                                        openItem(filteredGalleryPrompts[index])
                                    },
                                    onCopy: {
                                        copyItem(filteredGalleryPrompts[index])
                                    },
                                    index: actualIndex,
                                    copiedIndex: copiedIndex
                                    )
                                    .id("gallery_\(index)")
                                }
                            }

                            if !filteredSkillDrafts.isEmpty {
                                searchSectionHeader("Skill Drafts")
                                ForEach(filteredSkillDrafts.indices, id: \.self) { index in
                                    let actualIndex = index + filteredUserPrompts.count + filteredSharedCreations.count + filteredGalleryPrompts.count
                                    SearchResultRowView(
                                    item: filteredSkillDrafts[index],
                                    type: .skill,
                                    isSelected: actualIndex == selectedIndex,
                                    onOpen: {
                                        openItem(filteredSkillDrafts[index])
                                    },
                                    onCopy: {
                                        copyItem(filteredSkillDrafts[index])
                                    },
                                    index: actualIndex,
                                    copiedIndex: copiedIndex
                                    )
                                    .id("skill_\(index)")
                                }
                            }
                        }
                        .padding(6)
                    }
                }
            }
        }
        .frame(width: 600, height: 400)
        .onAppear {
            // Load initial data
            loadGalleryPrompts()
            // Make the search field focused as soon as the view appears.
            // Use async to ensure the window/panel is already key before requesting focus.
            DispatchQueue.main.async {
                isSearchFieldFocused = true
            }
        }
        .onExitCommand(perform: onClose)
        .onKeyPress(.upArrow) {
            if allFilteredResults.count > 0 {
                selectedIndex = max(0, selectedIndex - 1)
                scrollToSelected()
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if allFilteredResults.count > 0 {
                selectedIndex = min(allFilteredResults.count - 1, selectedIndex + 1)
                scrollToSelected()
            }
            return .handled
        }
        .onKeyPress(.return) {
            if selectedIndex < allFilteredResults.count {
                let selectedItem = allFilteredResults[selectedIndex]
                openItem(selectedItem)
            }
            return .handled
        }
    }
    
    func scrollToSelected() { /* TODO: scroll to selectedIndex */ }

    @ViewBuilder
    func searchSectionHeader(_ title: String) -> some View {
        Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 4)
    }

    @ViewBuilder
    func emptyStateView(text: String) -> some View {
        VStack { Spacer(); Text(text).foregroundColor(.secondary).font(.callout); Spacer() }.frame(maxWidth: .infinity)
    }

    func loadGalleryPrompts() {
        isLoading = true
        DispatchQueue.main.async { self.galleryPrompts = BuiltInAgents.agents.map { $0.toGalleryPrompt() }; self.isLoading = false }
    }

    func copyToClipboard(_ promptText: String) {
        let pasteboard = NSPasteboard.general; pasteboard.clearContents(); pasteboard.setString(promptText, forType: .string)
    }

    func copyItem(_ item: any SearchableItem) {
        copyToClipboard(item.content)
        copiedIndex = allFilteredResults.firstIndex(where: { $0.stableID == item.stableID })
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { copiedIndex = nil }
    }

    func openItem(_ item: any SearchableItem) {
        if let target = item.navigationTarget { SearchNavigationRequest.post(target); onClose(); return }
        copyItem(item)
    }
}

#Preview {
    SearchView(onClose: {})
        .modelContainer(PreviewData.previewContainer)
}
