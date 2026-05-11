import AppKit
import SwiftData
import SwiftUI

struct MySkillsView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Skill.updatedAt, order: .reverse) var skillDrafts: [Skill]
    @Binding var promptSelection: PromptSelection

    let draftService = SkillDraftService.shared

    let searchText: String
    let onSelectSkill: (Skill) -> Void
    let onCreateSkill: (Skill) -> Void

    @State var errorMessage: String?
    @State var selectedSkillID: UUID?
    @State var skillPendingDeletion: Skill?

    var body: some View {
        SkillLibraryScreen(
            title: "My Skills",
            subtitle: "Write, version, and install first-class skill drafts. Prompts can graduate into reusable skills without leaving the authoring flow.",
            metrics: headerMetrics,
            accessory: {
                HStack(spacing: 6) {
                    SkillsWorkspacePicker(promptSelection: $promptSelection)

                    Divider().frame(height: 14)

                    if !skillDrafts.isEmpty {
                        Button(action: createSkillDraft) {
                            Label("New Draft", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    Button {
                        if let selectedSkill {
                            copySkillMarkdown(for: selectedSkill)
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(selectedSkill == nil)
                    .accessibilityLabel("Copy SKILL.md")
                    .help("Copy SKILL.md")
                }
            }
        ) {
            mainContentView
        }
        .onAppear { syncSelection() }
        .onChange(of: searchText) { _, _ in syncSelection() }
        .onChange(of: skillDrafts.map(\.id)) { _, _ in syncSelection() }
        .alert("Skill Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(
            "Delete Skill Draft",
            isPresented: Binding(
                get: { skillPendingDeletion != nil },
                set: { if !$0 { skillPendingDeletion = nil } }
            ),
            presenting: skillPendingDeletion
        ) { draft in
            Button("Delete", role: .destructive) { deleteDraft(draft) }
            Button("Cancel", role: .cancel) {}
        } message: { draft in
            Text("Delete \(draft.displayName)? This will also remove its saved versions.")
        }
    }
}
