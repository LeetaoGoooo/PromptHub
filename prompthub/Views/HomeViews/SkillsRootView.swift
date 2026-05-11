import SwiftUI

struct SkillsRootView: View {
    @ObservedObject var installedWorkspaceStore: InstalledSkillsWorkspaceStore
    @Binding var promptSelection: PromptSelection
    let searchText: String
    @Binding var skillsScopeFilter: SkillsSidebarScopeFilter
    @Binding var skillsSourceFilter: SkillsSidebarSourceFilter

    var body: some View {
        Group {
            switch promptSelection {
            case .skillStore:
                SkillStoreView(promptSelection: $promptSelection, searchText: searchText)
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
            case .skill(let selectedSkill):
                SkillDraftDetailView(skill: selectedSkill)
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
