import SwiftData
import SwiftUI

struct PromptMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Prompt.name, order: .forward) private var allPrompts: [Prompt]
    @Query private var sharedCreations: [SharedCreation]

    @State private var searchPrompt: String = ""
    @State private var galleryPrompts: [GalleryPrompt] = []
    @State private var isLoading = true
    @FocusState private var isSearchFieldFocused: Bool

    private var filteredUserPrompts: [Prompt] {
        searchPrompt.isEmpty ? allPrompts : allPrompts.filter {
            $0.name.localizedCaseInsensitiveContains(searchPrompt) ||
            ($0.desc?.localizedCaseInsensitiveContains(searchPrompt) ?? false)
        }
    }

    private var filteredSharedCreations: [SharedCreation] {
        searchPrompt.isEmpty ? sharedCreations : sharedCreations.filter {
            $0.name.localizedCaseInsensitiveContains(searchPrompt) ||
            ($0.desc?.localizedCaseInsensitiveContains(searchPrompt) ?? false)
        }
    }

    private var filteredGalleryPrompts: [GalleryPrompt] {
        searchPrompt.isEmpty ? galleryPrompts : galleryPrompts.filter {
            $0.name.localizedCaseInsensitiveContains(searchPrompt) ||
            ($0.description?.localizedCaseInsensitiveContains(searchPrompt) ?? false)
        }
    }

    private var hasAnyPrompts: Bool { !allPrompts.isEmpty || !sharedCreations.isEmpty || !galleryPrompts.isEmpty }
    private var hasFilteredResults: Bool { !filteredUserPrompts.isEmpty || !filteredSharedCreations.isEmpty || !filteredGalleryPrompts.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            SearchBarView(searchText: $searchPrompt, isFocused: $isSearchFieldFocused)
                .padding(.horizontal, 12).padding(.vertical, 10)
            Divider()

            if isLoading {
                ProgressView("Loading...").progressViewStyle(.circular).scaleEffect(0.8).padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !hasAnyPrompts {
                menuEmptyState(text: "No prompts available.")
            } else if !hasFilteredResults && !searchPrompt.isEmpty {
                menuEmptyState(text: "No results for \"\(searchPrompt)\"")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredUserPrompts) { prompt in
                            PromptRowView(prompt: prompt, promptType: .user, action: { copyToClipboard(prompt.getLatestPromptContent()) })
                        }
                        if !searchPrompt.isEmpty {
                            ForEach(filteredSharedCreations, id: \.id) { creation in
                                SharedCreationRowView(sharedCreation: creation, action: { copyToClipboard(creation.prompt) })
                            }
                            ForEach(filteredGalleryPrompts) { gp in
                                GalleryPromptRowView(galleryPrompt: gp, action: { copyToClipboard(gp.prompt) })
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isSearchFieldFocused = true }
        }
    }

    @ViewBuilder
    private func menuEmptyState(text: String) -> some View {
        VStack { Spacer(); Text(text).foregroundColor(.secondary).font(.callout); Spacer() }.frame(maxWidth: .infinity)
    }

    private func loadGalleryPrompts() {
        isLoading = true
        DispatchQueue.main.async {
            self.galleryPrompts = BuiltInAgents.agents.map { $0.toGalleryPrompt() }
            self.isLoading = false
        }
    }

    private func copyToClipboard(_ promptText: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(promptText, forType: .string)
    }
}

#Preview {
    PromptMenuView().modelContainer(PreviewData.previewContainer)
}
