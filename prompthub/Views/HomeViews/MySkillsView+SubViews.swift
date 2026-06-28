import AppKit
import PromptHubSkillKit
import SwiftUI

// MARK: - Sub Views + Actions

extension MySkillsView {

    private func normalizedSkillKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func linkedInstallations(for skill: Skill) -> [InstalledSkillSnapshot] {
        let installationName = normalizedSkillKey(skill.installationName)
        let slug = normalizedSkillKey(skill.slug)
        let identifier = normalizedSkillKey(skill.identifier)

        return installedWorkspaceStore.installedSkills.filter { snapshot in
            let packageName = normalizedSkillKey(snapshot.packageName)
            let shortName = normalizedSkillKey(snapshot.package.skillName)

            return [installationName, slug, identifier]
                .filter { !$0.isEmpty }
                .contains { key in
                    key == packageName || key == shortName
                }
        }
    }

    var availableSkillAgents: [AgentWorkflow] {
        let installedAgents = installedWorkspaceStore.installedSkills.flatMap(\.agents)
        return AgentWorkflow.defaultTargets.filter { agent in
            installedAgents.contains(agent)
        }
    }

    var filteredSkills: [Skill] {
        skillDrafts.filter { skill in
            let matchesSearch = searchText.isEmpty || skill.displayName.localizedCaseInsensitiveContains(searchText) ||
                (skill.desc?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                skill.category.localizedCaseInsensitiveContains(searchText) ||
                skill.identifier.localizedCaseInsensitiveContains(searchText) ||
                skill.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)

            let matchesAgent = agentFilter.map { agent in
                linkedInstallations(for: skill).contains { $0.agents.contains(agent) }
            } ?? true

            return matchesSearch && matchesAgent
        }
    }

    var selectedSkill: Skill? {
        if let selectedSkillID, let matched = skillDrafts.first(where: { $0.id == selectedSkillID }) { return matched }
        return filteredSkills.first ?? skillDrafts.first
    }

    @ViewBuilder
    var mainContentView: some View {
        if skillDrafts.isEmpty {
            mySkillsOnboarding
        } else {
            skillBrowser
        }
    }

    var mySkillsOnboarding: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor.opacity(0.8))
                    Text("No Skill Drafts Yet").font(.title3.weight(.semibold))
                    Text("Skills are reusable, versioned instruction sets that extend AI agents. Create one from scratch or promote an existing prompt.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).frame(maxWidth: 400)
                    Button("Create Skill Draft", action: createSkillDraft)
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)

                // How it works
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill").foregroundStyle(.yellow).font(.caption)
                        Text("How Skills Work").font(.subheadline.weight(.semibold))
                    }
                    .padding(.bottom, 10)

                    ForEach(Array(skillWorkflowSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 24, height: 24)
                                Text("\(index + 1)").font(.caption.weight(.bold)).foregroundStyle(Color.accentColor)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title).font(.callout.weight(.medium))
                                Text(step.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        if index < skillWorkflowSteps.count - 1 {
                            Divider().padding(.leading, 36)
                        }
                    }
                }
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: 460)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
    }

    private var skillWorkflowSteps: [(title: String, detail: String)] {
        [
            ("Write", "Compose a SKILL.md with a clear description, input/output schema, and instructions for the agent."),
            ("Version", "Snapshot versions as you refine — roll back anytime if a change breaks your workflow."),
            ("Install", "Push the skill into a specific agent (Claude Code, Cursor, Codex…) at project or global scope."),
            ("Audit", "Use Installed Skills → Audit to verify the skill is visible to the right agents and hasn't been modified.")
        ]
    }

    var skillBrowser: some View {
        WorkspaceSplitShell(
            sidebarMinWidth: 240,
            sidebarIdealWidth: 300,
            sidebarMaxWidth: 380,
            detailMinWidth: 280
        ) { skillListPane } detail: { skillDetailPane }
    }

    var skillListPane: some View {
        VStack(spacing: 0) {
            if filteredSkills.isEmpty {
                SkillLibraryEmptyState(
                    title: "No Matching Skills",
                    systemImage: "magnifyingglass",
                    description: "Try a different name, tag, or identifier."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredSkills) { skill in
                        SkillDraftListRow(
                            skill: skill,
                            installations: linkedInstallations(for: skill),
                            isSelected: selectedSkillID == skill.id,
                            onSelect: {
                                selectedSkillID = skill.id
                            }
                        )
                        .contextMenu {
                            Button("Edit Draft") { navigationState.selectSkillDraft(skill.id) }
                            Button("Copy SKILL.md") { copySkillMarkdown(for: skill) }
                            Button("Delete Draft", role: .destructive) { skillPendingDeletion = skill }
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
                .onChange(of: selectedSkillID) { _, newValue in
                    guard let newValue, navigationState.selectedSkillDraftID != newValue else { return }
                    navigationState.selectSkillDraft(newValue)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    var skillDetailPane: some View {
        if let selectedSkill {
            if editingSkillID == selectedSkill.id {
                SkillDraftDetailView(skill: selectedSkill, onCloseWorkspace: {
                    editingSkillID = nil
                })
                .id("workspace-\(selectedSkill.id.uuidString)")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(NSColor.windowBackgroundColor))
            } else {
                SkillDraftPreviewPane(
                    skill: selectedSkill,
                    installations: linkedInstallations(for: selectedSkill),
                    onEditWorkspace: {
                        editingSkillID = selectedSkill.id
                    },
                    onCopyMarkdown: {
                        copySkillMarkdown(for: selectedSkill)
                    },
                    onCreateVersion: {
                        do {
                            let instructions = selectedSkill.latestVersion?.instructions ?? ""
                            _ = try draftService.snapshotVersion(for: selectedSkill, using: instructions, in: modelContext)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    },
                    onRevealInFinder: {
                        do {
                            try draftService.revealPackageItem(relativePath: "SKILL.md", for: selectedSkill)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                )
                .id("preview-\(selectedSkill.id.uuidString)")
            }
        } else {
            SkillLibraryEmptyState(title: "No Draft Selected", systemImage: "wand.and.rays", description: "Choose a skill draft to inspect its metadata, version history, and exported SKILL.md.")
        }
    }

    // MARK: - Actions

    func createSkillDraft() {
        do {
            let draft = try draftService.createDraft(in: modelContext)
            navigationState.selectSkillDraft(draft.id)
        } catch { errorMessage = error.localizedDescription }
    }

    func copySkillMarkdown(for skill: Skill) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(draftService.exportMarkdown(for: skill), forType: .string)
    }

    func deleteDraft(_ skill: Skill) {
        do {
            if selectedSkillID == skill.id { selectedSkillID = nil }
            try draftService.deleteDraft(skill, in: modelContext)
            skillPendingDeletion = nil
            syncSelection()
        } catch { errorMessage = error.localizedDescription }
    }

    func syncSelection() {
        if let skillID = navigationState.selectedSkillDraftID {
            selectedSkillID = skillID
            if skillDrafts.contains(where: { $0.id == skillID }) {
                return
            }
            return
        }

        if let selectedSkillID,
           skillDrafts.contains(where: { $0.id == selectedSkillID }) {
            return
        }

        if let nextSkillID = filteredSkills.first?.id ?? skillDrafts.first?.id {
            selectedSkillID = nextSkillID
            editingSkillID = nil
            navigationState.selectSkillDraft(nextSkillID)
        } else {
            selectedSkillID = nil
            editingSkillID = nil
            navigationState.clearSkillDraftSelection()
        }
    }
}
