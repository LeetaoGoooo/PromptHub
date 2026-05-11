import SwiftUI

struct SkillsRootView: View {
    @ObservedObject var installedWorkspaceStore: InstalledSkillsWorkspaceStore
    @Binding var promptSelection: PromptSelection
    let searchText: String
    @Binding var skillsScopeFilter: SkillsSidebarScopeFilter
    @Binding var skillsSourceFilter: SkillsSidebarSourceFilter

    var body: some View {
        switch promptSelection {
        case .skillStore:
            SkillStoreView(promptSelection: $promptSelection, searchText: searchText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(NSColor.windowBackgroundColor))
        case .installedSkills:
            InstalledSkillsView(
                installedWorkspaceStore: installedWorkspaceStore,
                promptSelection: $promptSelection,
                searchText: searchText,
                scopeFilter: $skillsScopeFilter,
                sourceFilter: $skillsSourceFilter,
                onSelectSkillDraft: { skill in
                    promptSelection = .skill(skill)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(NSColor.windowBackgroundColor))
        case .mySkills:
            MySkillsView(
                promptSelection: $promptSelection,
                searchText: searchText,
                onSelectSkill: { skill in
                    promptSelection = .skill(skill)
                },
                onCreateSkill: { skill in
                    promptSelection = .skill(skill)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(NSColor.windowBackgroundColor))
        case .skill(let selectedSkill):
            SkillDraftDetailView(skill: selectedSkill)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(NSColor.windowBackgroundColor))
        default:
            EmptyView()
        }
    }
}
