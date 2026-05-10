import AppKit
import PromptHubSkillKit
import SwiftUI

// MARK: - View Building

extension InstalledSkillsView {

    @ViewBuilder
    var mainContentView: some View {
        if !cliAccessManager.anyAccessGranted {
            SkillLibraryEmptyState(
                title: "CLI Access Required",
                systemImage: "lock.shield",
                description: "PromptHub needs access to CLI agent folders (like ~/.claude, ~/.cursor) to manage their skills."
            ) {
                Button("Configure Access\u{2026}") { showingCLIAccessManager = true }
                    .buttonStyle(.borderedProminent)
            }
        } else if isLoading && installedSkills.isEmpty {
            ProgressView("Loading installed skills...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = errorMessage, installedSkills.isEmpty {
            SkillLibraryEmptyState(
                title: "Error Loading Skills",
                systemImage: "exclamationmark.triangle",
                description: error
            ) {
                Button("Retry") { fetchInstalledSkills() }
            }
        } else if filteredSkills.isEmpty {
            SkillLibraryEmptyState(
                title: searchText.isEmpty ? "No Skills Installed" : "No Matches",
                systemImage: searchText.isEmpty ? "square.stack.3d.up.slash" : "magnifyingglass",
                description: searchText.isEmpty
                    ? "Install skills from the Skill Store to extend your agents' capabilities."
                    : "Try a different search term."
            )
        } else {
            skillBrowser
        }
    }

    var skillBrowser: some View {
        SkillLibraryBrowser {
            skillListPane
        } detail: {
            skillDetailPane
        }
    }

    var skillListPane: some View {
        VStack(spacing: 0) {
            if isLoading && !installedSkills.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Refreshing installations…")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
            }
            List {
                installedSection(title: "Project", skills: projectSkills)
                installedSection(title: "Global",  skills: globalSkills)
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    func installedSection(title: String, skills: [InstalledSkillSnapshot]) -> some View {
        if !skills.isEmpty {
            Section(title) {
                ForEach(skills) { skill in
                    Button {
                        selectedSkillID = skill.id
                    } label: {
                        InstalledSkillListRow(
                            skill: skill,
                            isRemoving: removingSkillIDs.contains(skill.id),
                            isSelected: selectedSkillID == skill.id
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
    }

    @ViewBuilder
    var skillDetailPane: some View {
        if let selectedSkill {
            ScrollView {
                InstalledSkillDetailPane(
                    skill: selectedSkill,
                    linkedDraft: linkedDraft(for: selectedSkill),
                    agentVisibility: agentVisibility,
                    isLoadingVisibility: isLoadingVisibility,
                    sourceIntegrity: sourceIntegrity,
                    isLoadingIntegrity: isLoadingIntegrity,
                    effectiveness: effectiveness,
                    isLoadingEffectiveness: isLoadingEffectiveness,
                    isAdding: addingSkillIDs.contains(selectedSkill.id),
                    isRemoving: removingSkillIDs.contains(selectedSkill.id),
                    onEditDraft: { openDraft(for: selectedSkill) },
                    onAddAgents: { agents in addSkillTargets(selectedSkill, agents: agents) },
                    onRemoveAll: { pendingRemoval = PendingRemoval(skill: selectedSkill, targetAgents: nil) },
                    onRemoveAgent: { agent in pendingRemoval = PendingRemoval(skill: selectedSkill, targetAgents: [agent]) },
                    onOpenSourcePage: {
                        guard let urlString = selectedSkill.url, let url = URL(string: urlString) else { return }
                        NSWorkspace.shared.open(url)
                    }
                )
                .padding(24)
            }
        } else {
            SkillLibraryEmptyState(
                title: "No Skill Selected",
                systemImage: "square.stack.3d.up.slash",
                description: "Choose an installed skill to inspect where it is active and remove it safely."
            )
        }
    }

    @ViewBuilder
    var nonFatalErrorBanner: some View {
        if let error = errorMessage, !installedSkills.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(error).font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("Dismiss") { withAnimation { errorMessage = nil } }
                    .font(.caption.bold()).buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.orange.opacity(0.08))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
