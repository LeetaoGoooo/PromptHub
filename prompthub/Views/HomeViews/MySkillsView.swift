import AppKit
import PromptHubSkillKit
import SwiftData
import SwiftUI

struct MySkillsView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Skill.updatedAt, order: .reverse) var skillDrafts: [Skill]
    @ObservedObject var installedWorkspaceStore: InstalledSkillsWorkspaceStore
    @Binding var navigationState: WorkspaceNavigationState
    @Binding var agentFilter: AgentWorkflow?

    let draftService = SkillDraftService.shared

    @Binding var searchText: String

    @State var errorMessage: String?
    @State var selectedSkillID: UUID?
    @State var skillPendingDeletion: Skill?
    @State var editingSkillID: UUID?

    var body: some View {
        SkillLibraryScreen {
            mainContentView
        }
        .onAppear { syncSelection() }
        .onChange(of: navigationState.selectedSkillDraftID) { _, _ in syncSelection() }
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
