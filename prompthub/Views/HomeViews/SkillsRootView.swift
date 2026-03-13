import SwiftUI

struct SkillsRootView: View {
    @Binding var promptSelection: PromptSelection
    let searchText: String

    var body: some View {
        Group {
            switch promptSelection {
            case .skillStore:
                SkillStoreView(searchText: searchText)
            case .installedSkills:
                InstalledSkillsView(
                    searchText: searchText,
                    onSelectSkillDraft: { skill in
                        promptSelection = .skill(skill)
                    }
                )
            case .mySkills:
                MySkillsView(
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
