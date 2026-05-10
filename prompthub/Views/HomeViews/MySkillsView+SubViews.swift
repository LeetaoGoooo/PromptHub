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
            SkillLibraryEmptyState(title: "No Skill Drafts Yet", systemImage: "wand.and.stars.inverse", description: "Create your first skill draft here, or promote an existing prompt into a skill.") {
                Button("Create Skill Draft", action: createSkillDraft)
            }
        } else {
            skillBrowser
        }
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
