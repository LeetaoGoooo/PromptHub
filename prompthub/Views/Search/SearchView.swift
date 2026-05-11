//
//  SearchView.swift
//  prompthub
//
//  Created by leetao on 2025/4/5.
//

import SwiftData
import SwiftUI

struct SearchView: View {
    private let workspaceService = SkillWorkspaceService.shared

    @Query(sort: \Prompt.name, order: .forward) private var allPrompts: [Prompt]
    @Query private var sharedCreations: [SharedCreation]
    @Query(sort: \Skill.updatedAt, order: .reverse) private var skillDrafts: [Skill]

    @State private var searchText: String = ""
    @State private var galleryPrompts: [GalleryPrompt] = []
    @State private var installedSkills: [InstalledSkillSnapshot] = []
    @State private var catalogSkills: [CatalogSkill] = []
    @State private var isLoading = true
    @State private var selectedIndex: Int = 0
    @State private var copiedIndex: Int? = nil

    @FocusState private var isSearchFieldFocused: Bool

    let onClose: () -> Void

    private struct SearchSectionModel: Identifiable {
        let id: String
        let title: String
        let type: SearchResultType
        let items: [any SearchableItem]
    }

    private var allShortcuts: [SearchableShortcut] {
        [
            SearchableShortcut(
                id: "action-new-prompt",
                name: "New Prompt",
                description: "Create a blank prompt draft",
                content: "new prompt create",
                searchableContent: "new prompt create draft library",
                navigationTarget: .newPrompt
            ),
            SearchableShortcut(
                id: "action-new-skill",
                name: "New Skill Draft",
                description: "Create a new skill draft",
                content: "new skill create",
                searchableContent: "new skill draft create my skills",
                navigationTarget: .newSkillDraft
            ),
            SearchableShortcut(
                id: "nav-all-prompts",
                name: "All Prompts",
                description: "Browse your full prompt library",
                content: "all prompts library",
                searchableContent: "all prompts prompt library",
                navigationTarget: .selection(.allPrompts, query: nil)
            ),
            SearchableShortcut(
                id: "nav-my-prompts",
                name: "My Prompts",
                description: "Open your private prompts",
                content: "my prompts private",
                searchableContent: "my prompts private library",
                navigationTarget: .selection(.mine, query: nil)
            ),
            SearchableShortcut(
                id: "nav-explore",
                name: "Explore Gallery",
                description: "Browse built-in prompt gallery",
                content: "explore gallery",
                searchableContent: "explore gallery prompts",
                navigationTarget: .selection(.explore, query: nil)
            ),
            SearchableShortcut(
                id: "nav-shared",
                name: "Shared Library",
                description: "Open shared and community prompts",
                content: "shared library",
                searchableContent: "shared community library prompts",
                navigationTarget: .selection(.shared, query: nil)
            ),
            SearchableShortcut(
                id: "nav-my-skills",
                name: "My Skills",
                description: "Open authored skill drafts",
                content: "my skills",
                searchableContent: "my skills drafts",
                navigationTarget: .selection(.mySkills, query: nil)
            ),
            SearchableShortcut(
                id: "nav-skill-store",
                name: "Skill Store",
                description: "Browse catalog skills",
                content: "skill store",
                searchableContent: "skill store catalog discover",
                navigationTarget: .selection(.skillStore, query: nil)
            ),
            SearchableShortcut(
                id: "nav-installed-skills",
                name: "Installed Skills",
                description: "Audit installed CLI skills",
                content: "installed skills",
                searchableContent: "installed skills audit",
                navigationTarget: .selection(.installedSkills, query: nil)
            ),
            SearchableShortcut(
                id: "nav-cli",
                name: "CLI Integration",
                description: "Open agent and workspace integration",
                content: "cli integration",
                searchableContent: "cli integration agents workspaces",
                navigationTarget: .selection(.cliDashboard, query: nil)
            ),
            SearchableShortcut(
                id: "nav-settings",
                name: "Settings",
                description: "Open PromptHub settings",
                content: "settings preferences",
                searchableContent: "settings preferences",
                navigationTarget: .selection(.settings, query: nil)
            ),
            SearchableShortcut(
                id: "nav-onboarding",
                name: "Get Started Guide",
                description: "Open onboarding and setup guidance",
                content: "get started onboarding",
                searchableContent: "get started onboarding guide",
                navigationTarget: .selection(.onboarding, query: nil)
            )
        ]
    }

    private var filteredUserPrompts: [SearchablePrompt] {
        let prompts = allPrompts.map { SearchablePrompt(prompt: $0) }
        guard !searchText.isEmpty else {
            return prompts
        }

        return prompts.filter { prompt in
            prompt.name.localizedCaseInsensitiveContains(searchText) ||
            (prompt.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            prompt.searchableContent.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredSharedCreations: [SearchableSharedCreation] {
        let items = sharedCreations.map { SearchableSharedCreation(creation: $0) }
        guard !searchText.isEmpty else {
            return items
        }

        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText) ||
            (item.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            item.searchableContent.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredGalleryPrompts: [SearchableGalleryPrompt] {
        let items = galleryPrompts.map { SearchableGalleryPrompt(galleryPrompt: $0) }
        guard !searchText.isEmpty else {
            return items
        }

        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText) ||
            (item.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            item.searchableContent.localizedCaseInsensitiveContains(searchText)
        }
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

    private var filteredInstalledSkills: [SearchableInstalledSkill] {
        let items = installedSkills.map { SearchableInstalledSkill(skill: $0) }
        guard !searchText.isEmpty else {
            return items
        }

        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText) ||
            (item.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            item.searchableContent.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredCatalogSkills: [SearchableCatalogSkill] {
        let items = catalogSkills.map { SearchableCatalogSkill(skill: $0) }
        guard !searchText.isEmpty else {
            return items
        }

        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText) ||
            (item.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            item.searchableContent.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredShortcuts: [SearchableShortcut] {
        guard !searchText.isEmpty else {
            return allShortcuts
        }

        return allShortcuts.filter { shortcut in
            shortcut.name.localizedCaseInsensitiveContains(searchText) ||
            (shortcut.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            shortcut.searchableContent.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var searchSections: [SearchSectionModel] {
        var sections: [SearchSectionModel] = []

        if !filteredShortcuts.isEmpty {
            sections.append(SearchSectionModel(id: "actions", title: "Actions", type: .action, items: filteredShortcuts))
        }
        if !filteredUserPrompts.isEmpty {
            sections.append(SearchSectionModel(id: "user-prompts", title: "My Prompts", type: .user, items: filteredUserPrompts))
        }
        if !filteredSharedCreations.isEmpty {
            sections.append(SearchSectionModel(id: "shared-library", title: "Shared Library", type: .shared, items: filteredSharedCreations))
        }
        if !filteredGalleryPrompts.isEmpty {
            sections.append(SearchSectionModel(id: "gallery", title: "Gallery", type: .gallery, items: filteredGalleryPrompts))
        }
        if !filteredSkillDrafts.isEmpty {
            sections.append(SearchSectionModel(id: "skill-drafts", title: "Skill Drafts", type: .skill, items: filteredSkillDrafts))
        }
        if !filteredInstalledSkills.isEmpty {
            sections.append(SearchSectionModel(id: "installed-skills", title: "Installed Skills", type: .installedSkill, items: filteredInstalledSkills))
        }
        if !filteredCatalogSkills.isEmpty {
            sections.append(SearchSectionModel(id: "catalog-skills", title: "Skill Catalog", type: .catalogSkill, items: filteredCatalogSkills))
        }

        return sections
    }

    private var allFilteredResults: [any SearchableItem] {
        searchSections.flatMap(\.items)
    }

    private var hasFilteredResults: Bool {
        !allFilteredResults.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchBarView(searchText: $searchText, isFocused: $isSearchFieldFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            if isLoading && allFilteredResults.isEmpty {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !hasFilteredResults && !searchText.isEmpty {
                emptyStateView(text: "No results for \"\(searchText)\"")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(searchSections) { section in
                                searchSectionHeader(section.title)

                                ForEach(Array(section.items.enumerated()), id: \.element.stableID) { _, item in
                                    if let actualIndex = absoluteIndex(for: item) {
                                        SearchResultRowView(
                                            item: item,
                                            type: section.type,
                                            isSelected: actualIndex == selectedIndex,
                                            onOpen: {
                                                openItem(item)
                                            },
                                            onCopy: {
                                                copyItem(item)
                                            },
                                            index: actualIndex,
                                            copiedIndex: copiedIndex
                                        )
                                        .id(item.stableID)
                                    }
                                }
                            }
                        }
                        .padding(6)
                    }
                    .onAppear {
                        scrollToSelected(using: proxy)
                    }
                    .onChange(of: selectedIndex) { _, _ in
                        scrollToSelected(using: proxy)
                    }
                    .onChange(of: searchText) { _, _ in
                        selectedIndex = 0
                        copiedIndex = nil
                        scrollToSelected(using: proxy)
                    }
                }
            }
        }
        .frame(width: 600, height: 400)
        .onAppear {
            Task {
                await loadSearchSources()
            }

            DispatchQueue.main.async {
                isSearchFieldFocused = true
            }
        }
        .onExitCommand(perform: onClose)
        .onKeyPress(.upArrow) {
            if !allFilteredResults.isEmpty {
                selectedIndex = max(0, selectedIndex - 1)
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if !allFilteredResults.isEmpty {
                selectedIndex = min(allFilteredResults.count - 1, selectedIndex + 1)
            }
            return .handled
        }
        .onKeyPress(.return) {
            if selectedIndex < allFilteredResults.count {
                openItem(allFilteredResults[selectedIndex])
            }
            return .handled
        }
    }

    func scrollToSelected(using proxy: ScrollViewProxy) {
        guard let rowID = rowID(for: selectedIndex) else { return }
        withAnimation(.easeInOut(duration: 0.12)) {
            proxy.scrollTo(rowID, anchor: .center)
        }
    }

    func rowID(for index: Int) -> String? {
        guard index >= 0, index < allFilteredResults.count else { return nil }
        return allFilteredResults[index].stableID
    }

    func absoluteIndex(for item: any SearchableItem) -> Int? {
        allFilteredResults.firstIndex(where: { $0.stableID == item.stableID })
    }

    @ViewBuilder
    func searchSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    func emptyStateView(text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .foregroundColor(.secondary)
                .font(.callout)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @MainActor
    func loadSearchSources() async {
        isLoading = true
        galleryPrompts = BuiltInAgents.agents.map { $0.toGalleryPrompt() }

        async let installedTask = workspaceService.listInstalledSkills()
        async let catalogTask = workspaceService.loadSkillStore(authoredDraftCount: skillDrafts.count)

        do {
            let installed = try await installedTask
            let catalog = try await catalogTask
            installedSkills = installed
            catalogSkills = catalog.catalogSkills
        } catch {
            installedSkills = []
            catalogSkills = []
        }

        isLoading = false
    }

    func copyToClipboard(_ promptText: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(promptText, forType: .string)
    }

    func copyItem(_ item: any SearchableItem) {
        copyToClipboard(item.content)
        let itemIndex = allFilteredResults.firstIndex(where: { $0.stableID == item.stableID })
        copiedIndex = itemIndex
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if copiedIndex == itemIndex {
                copiedIndex = nil
            }
        }
    }

    func openItem(_ item: any SearchableItem) {
        if let target = item.navigationTarget {
            SearchNavigationRequest.post(target)
            onClose()
            return
        }

        copyItem(item)
    }
}

#Preview {
    SearchView(onClose: {})
        .modelContainer(PreviewData.previewContainer)
}
