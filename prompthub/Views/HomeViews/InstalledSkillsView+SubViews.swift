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
                    .buttonStyle(PHChromeButtonStyle(emphasis: .accent))
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
        } else {
            skillBrowser
        }
    }

    @ToolbarContentBuilder
    var installedToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: fetchInstalledSkills) {
                toolbarIcon(systemImage: "arrow.clockwise")
            }
            .disabled(installedWorkspaceStore.isLoading)
            .help("Refresh installed skills")

            Button(action: {
                if skillsWithUpdates.isEmpty {
                    checkAllUpdates()
                } else {
                    applyUpdates(for: updateEligibleSkills)
                }
            }) {
                ZStack(alignment: .topTrailing) {
                    if isCheckingUpdates || isApplyingBulkUpdates {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 18, height: 18)
                    } else {
                        toolbarIcon(systemImage: "arrow.triangle.2.circlepath")
                    }
                    if !isCheckingUpdates && !skillsWithUpdates.isEmpty {
                        Text("\(skillsWithUpdates.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(PH.Color.accent, in: Capsule())
                            .offset(x: 6, y: -5)
                    }
                }
            }
            .disabled(isCheckingUpdates || isApplyingBulkUpdates || (!skillsWithUpdates.isEmpty && updateEligibleSkills.isEmpty))
            .help(skillsWithUpdates.isEmpty ? "Check all skills for available updates" : "Update all visible")

            Button(action: { showingAuditReport = true }) {
                toolbarIcon(systemImage: "checklist")
            }
            .help("Audit all installed skills")

            Menu {
                ForEach(ListFilter.allCases, id: \.rawValue) { filter in
                    Button(action: { listFilter = filter }) {
                        HStack {
                            Text(filter.rawValue)
                            if listFilter == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                toolbarIcon(systemImage: "line.3.horizontal.decrease.circle")
            }
            .help("Filter: \(listFilter.rawValue)")

            Menu {
                ForEach(SkillsSortOrder.allCases, id: \.rawValue) { order in
                    Button(action: { skillsSortOrder = order }) {
                        HStack {
                            Text(order.rawValue)
                            if skillsSortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                toolbarIcon(systemImage: "arrow.up.arrow.down.circle")
            }
            .help("Sort: \(skillsSortOrder.rawValue)")
        }
    }

    private func toolbarIcon(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .medium))
            .frame(width: 18, height: 18)
    }

    var skillBrowser: some View {
        WorkspaceSplitShell(
            sidebarMinWidth: 240,
            sidebarIdealWidth: 300,
            sidebarMaxWidth: 380,
            detailMinWidth: 280
        ) {
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
                .background(PH.Color.sidebarBg)
            }
            if filteredSkills.isEmpty {
                SkillLibraryEmptyState(
                    title: "No Matches",
                    systemImage: "magnifyingglass",
                    description: "Try a different search term or filter."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredSkills) { skill in
                        InstalledSkillListRow(
                            skill: skill,
                            isRemoving: removingSkillIDs.contains(skill.id),
                            isUpdating: updatingSkillIDs.contains(skill.id),
                            isSelected: selectedSkillID == skill.id,
                            projectNames: skill.projectDisplayNames,
                            hasUpdate: skillsWithUpdates.contains(skill.id),
                            onSelect: { selectedSkillID = skill.id },
                            onUpdate: skillsWithUpdates.contains(skill.id) ? {
                                selectedSkillID = skill.id
                                updatingSkill = skill
                            } : nil
                        )
                        .contextMenu {
                            Button("Edit Draft") {
                                selectedSkillID = skill.id
                                openDraft(for: skill)
                            }

                            if skillsWithUpdates.contains(skill.id) {
                                Button("Update") {
                                    selectedSkillID = skill.id
                                    updatingSkill = skill
                                }
                            }

                            Divider()

                            Button("Remove", role: .destructive) {
                                selectedSkillID = skill.id
                                pendingRemoval = PendingRemoval(skill: skill, targetAgents: nil)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: false))
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, PH.Spacing.detailB, for: .scrollContent)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    var skillDetailPane: some View {
        if let selectedSkill {
            InstalledSkillDetailPane(
                skill: selectedSkill,
                installedMarkdown: installedMarkdown,
                isLoadingMarkdown: isLoadingMarkdown,
                linkedDraft: linkedDraft(for: selectedSkill),
                agentVisibility: agentVisibility,
                isLoadingVisibility: isLoadingVisibility,
                sourceIntegrity: sourceIntegrity,
                isLoadingIntegrity: isLoadingIntegrity,
                structuralQuality: structuralQuality,
                isLoadingStructuralQuality: isLoadingStructuralQuality,
                isAdding: addingSkillIDs.contains(selectedSkill.id),
                isRemoving: removingSkillIDs.contains(selectedSkill.id),
                hasUpdate: skillsWithUpdates.contains(selectedSkill.id),
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
            .background(PH.Color.detailBg)
            .id("installed-snapshot-\(selectedSkill.id)")
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
