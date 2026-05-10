import AppKit
import SwiftUI

// MARK: - Sub Views + Actions

extension MySkillsView {

    var headerMetrics: [SkillLibraryMetric] {
        [
            SkillLibraryMetric(value: "\(skillDrafts.count)", title: "Drafts", systemImage: "wand.and.stars"),
            SkillLibraryMetric(value: "\(skillDrafts.filter { $0.lastInstalledAt != nil }.count)", title: "Installed", systemImage: "arrow.down.circle"),
            SkillLibraryMetric(value: "\(skillDrafts.reduce(0) { $0 + $1.sortedVersions.count })", title: "Versions", systemImage: "square.stack")
        ]
    }

    var filteredSkills: [Skill] {
        guard !searchText.isEmpty else { return skillDrafts }
        return skillDrafts.filter { skill in
            skill.displayName.localizedCaseInsensitiveContains(searchText) ||
            (skill.desc?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            skill.category.localizedCaseInsensitiveContains(searchText) ||
            skill.identifier.localizedCaseInsensitiveContains(searchText) ||
            skill.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
        }
    }

    var selectedSkill: Skill? {
        if let selectedSkillID, let matched = filteredSkills.first(where: { $0.id == selectedSkillID }) { return matched }
        return filteredSkills.first
    }

    @ViewBuilder
    var mainContentView: some View {
        if filteredSkills.isEmpty && !searchText.isEmpty {
            SkillLibraryEmptyState(title: "No Matching Skills", systemImage: "magnifyingglass", description: "Try a different name, tag, or identifier.")
        } else if filteredSkills.isEmpty {
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
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5))
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
        SkillLibraryBrowser { skillListPane } detail: { skillDetailPane }
    }

    var skillListPane: some View {
        List {
            ForEach(filteredSkills) { skill in
                Button { selectedSkillID = skill.id } label: {
                    SkillDraftListRow(skill: skill, isSelected: selectedSkillID == skill.id)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Open Draft") { onSelectSkill(skill) }
                    Button("Delete Draft", role: .destructive) { skillPendingDeletion = skill }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: false))
        .scrollContentBackground(.hidden)
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    var skillDetailPane: some View {
        if let selectedSkill {
            ScrollView {
                SkillDraftSummaryPane(
                    skill: selectedSkill,
                    exportedMarkdown: draftService.exportMarkdown(for: selectedSkill),
                    onOpenDraft: { onSelectSkill(selectedSkill) },
                    onCopyMarkdown: { copySkillMarkdown(for: selectedSkill) },
                    onDeleteDraft: { skillPendingDeletion = selectedSkill }
                )
                .padding(24)
            }
        } else {
            SkillLibraryEmptyState(title: "No Draft Selected", systemImage: "wand.and.rays", description: "Choose a skill draft to inspect its metadata, version history, and exported SKILL.md.")
        }
    }

    // MARK: - Actions

    func createSkillDraft() {
        do {
            let draft = try draftService.createDraft(in: modelContext)
            onCreateSkill(draft)
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
        if !filteredSkills.contains(where: { $0.id == selectedSkillID }) {
            selectedSkillID = filteredSkills.first?.id
        }
    }
}
