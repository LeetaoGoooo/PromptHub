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
        } else if installedWorkspaceStore.isLoading && installedSkills.isEmpty {
            ProgressView("Loading installed skills...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = installedWorkspaceStore.errorMessage, installedSkills.isEmpty {
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
            if installedWorkspaceStore.isLoading && !installedSkills.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Refreshing installations…")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
            }

            installedListHeaderBar

            List {
                ForEach(filteredSkills) { skill in
                    InstalledSkillListRow(
                        skill: skill,
                        isRemoving: removingSkillIDs.contains(skill.id),
                        isSelected: selectedSkillID == skill.id,
                        hasUpdate: skillsWithUpdates.contains(skill.id),
                        onSelect: { selectedSkillID = skill.id },
                        onUpdate: skillsWithUpdates.contains(skill.id) ? {
                            selectedSkillID = skill.id
                            updatingSkill = skill
                        } : nil
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var installedListHeaderBar: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Results")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text("\(filteredSkills.count) installed skills")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                installedScopeControl
                installedSourceControl
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.82))
    }

    private var installedScopeControl: some View {
        HStack(spacing: 6) {
            installedFilterButton(title: "All", systemImage: "square.stack.3d.up", isActive: scopeFilter == .allInstalled) {
                scopeFilter = .allInstalled
            }
            installedFilterButton(title: "Global", systemImage: "globe", isActive: scopeFilter == .global) {
                scopeFilter = .global
            }
            installedFilterButton(title: "Project", systemImage: "folder", isActive: scopeFilter == .project) {
                scopeFilter = .project
            }
        }
    }

    private var installedSourceControl: some View {
        HStack(spacing: 6) {
            installedFilterButton(title: "Any Source", systemImage: "line.3.horizontal.decrease.circle", isActive: sourceFilter == .all) {
                sourceFilter = .all
            }
            installedFilterButton(title: "External", systemImage: "wrench.and.screwdriver", isActive: sourceFilter == .external) {
                sourceFilter = .external
            }
            installedFilterButton(title: "Local", systemImage: "laptopcomputer", isActive: sourceFilter == .localOnly) {
                sourceFilter = .localOnly
            }
        }
    }

    private func installedFilterButton(title: String, systemImage: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(isActive ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.06))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isActive ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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
        if let error = installedWorkspaceStore.errorMessage, !installedSkills.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(error).font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("Dismiss") { withAnimation { installedWorkspaceStore.setError(nil) } }
                    .font(.caption.bold()).buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.orange.opacity(0.08))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
