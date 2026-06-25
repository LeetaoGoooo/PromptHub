import PromptHubSkillKit
import SwiftUI

struct SkillsRootView: View {
    @ObservedObject var installedWorkspaceStore: InstalledSkillsWorkspaceStore
    @Binding var navigationState: WorkspaceNavigationState
    let searchText: String
    @Binding var skillsScopeFilter: SkillsSidebarScopeFilter
    @Binding var skillsSourceFilter: SkillsSidebarSourceFilter
    @Binding var skillsAgentFilter: AgentWorkflow?

    var body: some View {
        switch navigationState.skillLens {
        case .store:
            SkillStoreView(navigationState: $navigationState, searchText: searchText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(NSColor.windowBackgroundColor))
        case .installed:
            InstalledSkillsView(
                installedWorkspaceStore: installedWorkspaceStore,
                navigationState: $navigationState,
                searchText: searchText,
                scopeFilter: $skillsScopeFilter,
                sourceFilter: $skillsSourceFilter,
                agentFilter: $skillsAgentFilter,
                onSelectSkillDraft: { skill in
                    navigationState.selectSkillDetail(skill.id)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(NSColor.windowBackgroundColor))
        case .drafts:
            MySkillsView(
                installedWorkspaceStore: installedWorkspaceStore,
                navigationState: $navigationState,
                agentFilter: $skillsAgentFilter,
                searchText: searchText,
                onSelectSkill: { skill in
                    navigationState.selectSkillDetail(skill.id)
                },
                onCreateSkill: { skill in
                    navigationState.selectSkillDetail(skill.id)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}
