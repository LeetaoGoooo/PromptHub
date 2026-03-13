import AppKit
import SwiftData
import SwiftUI

struct MySkillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Skill.updatedAt, order: .reverse) private var skillDrafts: [Skill]

    private let draftService = SkillDraftService.shared

    let searchText: String
    let onSelectSkill: (Skill) -> Void
    let onCreateSkill: (Skill) -> Void

    @State private var errorMessage: String?
    @State private var selectedSkillID: UUID?
    @State private var skillPendingDeletion: Skill?

    private var headerMetrics: [SkillLibraryMetric] {
        [
            SkillLibraryMetric(
                value: "\(skillDrafts.count)",
                title: "Drafts",
                systemImage: "wand.and.stars"
            ),
            SkillLibraryMetric(
                value: "\(skillDrafts.filter { $0.lastInstalledAt != nil }.count)",
                title: "Installed",
                systemImage: "arrow.down.circle"
            ),
            SkillLibraryMetric(
                value: "\(skillDrafts.reduce(0) { $0 + $1.sortedVersions.count })",
                title: "Versions",
                systemImage: "square.stack"
            )
        ]
    }

    private var filteredSkills: [Skill] {
        if searchText.isEmpty {
            return skillDrafts
        }

        return skillDrafts.filter { skill in
            skill.displayName.localizedCaseInsensitiveContains(searchText) ||
            (skill.desc?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            skill.category.localizedCaseInsensitiveContains(searchText) ||
            skill.identifier.localizedCaseInsensitiveContains(searchText) ||
            skill.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedSkill: Skill? {
        if let selectedSkillID,
           let matched = filteredSkills.first(where: { $0.id == selectedSkillID }) {
            return matched
        }
        return filteredSkills.first
    }

    var body: some View {
        SkillLibraryScreen(
            title: "My Skills",
            subtitle: "Write, version, and install first-class skill drafts. Prompts can graduate into reusable skills without leaving the authoring flow.",
            metrics: headerMetrics
        ) {
            mainContentView
        }
        .onAppear {
            syncSelection()
        }
        .onChange(of: searchText) { _, _ in
            syncSelection()
        }
        .onChange(of: skillDrafts.map(\.id)) { _, _ in
            syncSelection()
        }
        .alert("Skill Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(
            "Delete Skill Draft",
            isPresented: Binding(
                get: { skillPendingDeletion != nil },
                set: { if !$0 { skillPendingDeletion = nil } }
            ),
            presenting: skillPendingDeletion
        ) { draft in
            Button("Delete", role: .destructive) {
                deleteDraft(draft)
            }
            Button("Cancel", role: .cancel) {}
        } message: { draft in
            Text("Delete \(draft.displayName)? This will also remove its saved versions.")
        }
    }

    @ViewBuilder
    private var mainContentView: some View {
        if filteredSkills.isEmpty && !searchText.isEmpty {
            SkillLibraryEmptyState(
                title: "No Matching Skills",
                systemImage: "magnifyingglass",
                description: "Try a different name, tag, or identifier."
            )
        } else if filteredSkills.isEmpty {
            SkillLibraryEmptyState(
                title: "No Skill Drafts Yet",
                systemImage: "wand.and.stars.inverse",
                description: "Create your first skill draft here, or promote an existing prompt into a skill."
            ) {
                Button("Create Skill Draft", action: createSkillDraft)
            }
        } else {
            skillBrowser
        }
    }

    private var skillBrowser: some View {
        SkillLibraryBrowser {
            skillListPane
        } detail: {
            skillDetailPane
        }
    }

    private var skillListPane: some View {
        List {
            ForEach(filteredSkills) { skill in
                Button {
                    selectedSkillID = skill.id
                } label: {
                    SkillDraftListRow(
                        skill: skill,
                        isSelected: selectedSkillID == skill.id
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Open Draft") {
                        onSelectSkill(skill)
                    }

                    Button("Delete Draft", role: .destructive) {
                        skillPendingDeletion = skill
                    }
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
    private var skillDetailPane: some View {
        if let selectedSkill {
            ScrollView {
                SkillDraftSummaryPane(
                    skill: selectedSkill,
                    exportedMarkdown: draftService.exportMarkdown(for: selectedSkill),
                    onOpenDraft: {
                        onSelectSkill(selectedSkill)
                    },
                    onCopyMarkdown: {
                        copySkillMarkdown(for: selectedSkill)
                    },
                    onDeleteDraft: {
                        skillPendingDeletion = selectedSkill
                    }
                )
                .padding(24)
            }
        } else {
            SkillLibraryEmptyState(
                title: "No Draft Selected",
                systemImage: "wand.and.rays",
                description: "Choose a skill draft to inspect its metadata, version history, and exported SKILL.md."
            )
        }
    }

    private func createSkillDraft() {
        do {
            let draft = try draftService.createDraft(in: modelContext)
            onCreateSkill(draft)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copySkillMarkdown(for skill: Skill) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(draftService.exportMarkdown(for: skill), forType: .string)
    }

    private func deleteDraft(_ skill: Skill) {
        do {
            if selectedSkillID == skill.id {
                selectedSkillID = nil
            }
            try draftService.deleteDraft(skill, in: modelContext)
            skillPendingDeletion = nil
            syncSelection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncSelection() {
        if !filteredSkills.contains(where: { $0.id == selectedSkillID }) {
            selectedSkillID = filteredSkills.first?.id
        }
    }
}

private struct SkillDraftListRow: View {
    let skill: Skill
    let isSelected: Bool
    @State private var isHovered = false

    private var summary: String {
        if let desc = skill.desc?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty {
            return desc
        }
        return "No description yet"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(skill.displayName)
                    .font(.headline)
                    .lineLimit(1)

                if skill.lastInstalledAt != nil {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()

                if let latestVersion = skill.latestVersion {
                    Text(latestVersion.version)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                DraftBadge(
                    title: skill.category,
                    icon: "tag",
                    foreground: .accentColor,
                    background: Color.accentColor.opacity(0.14)
                )

                if !skill.tags.isEmpty {
                    DraftBadge(
                        title: "\(min(skill.tags.count, 3)) tag\(skill.tags.count == 1 ? "" : "s")",
                        icon: "number",
                        foreground: .secondary,
                        background: Color.secondary.opacity(0.12)
                    )
                }
            }

            Text("Updated \(skill.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .modifier(SkillLibraryRowCardStyle(isSelected: isSelected, isHovered: isHovered))
        .animation(.easeInOut(duration: 0.14), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct SkillDraftSummaryPane: View {
    let skill: Skill
    let exportedMarkdown: String
    let onOpenDraft: () -> Void
    let onCopyMarkdown: () -> Void
    let onDeleteDraft: () -> Void

    private let iconSymbols = [
        "wand.and.stars",
        "text.badge.star",
        "command.square",
        "slider.horizontal.below.square.and.square.filled",
        "sparkles.rectangle.stack"
    ]

    private let iconColors: [Color] = [
        .pink,
        .blue,
        .orange,
        .mint,
        .indigo
    ]

    private var latestInstructionsPreview: String {
        let text = skill.latestVersion?.instructions.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty {
            return "No instructions yet."
        }
        return text
    }

    private var formattedTags: String {
        if skill.tags.isEmpty {
            return "No tags yet"
        }
        return skill.tags.joined(separator: ", ")
    }

    private var lastInstalledText: String {
        if let lastInstalledAt = skill.lastInstalledAt {
            return lastInstalledAt.formatted(date: .abbreviated, time: .shortened)
        }
        return "Never"
    }

    var body: some View {
        SkillLibraryInspectorCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 18) {
                    Image(systemName: iconSymbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 56, height: 56)
                        .background(iconColor.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(skill.displayName)
                            .font(.title2.weight(.semibold))

                        Text(skill.desc?.isEmpty == false ? skill.desc! : "No description yet.")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            DraftBadge(
                                title: skill.category,
                                icon: "tag",
                                foreground: .accentColor,
                                background: Color.accentColor.opacity(0.14)
                            )

                            if skill.lastInstalledAt != nil {
                                DraftBadge(
                                    title: "Installed",
                                    icon: "arrow.down.circle.fill",
                                    foreground: .green,
                                    background: Color.green.opacity(0.14)
                                )
                            }
                        }
                    }

                    Spacer()
                }

                SkillLibraryMetadataBlock(
                    title: "Identity",
                    rows: [
                        ("Slug", skill.slug.isEmpty ? "Not set" : skill.slug),
                        ("Identifier", skill.identifier.isEmpty ? "Not set" : skill.identifier),
                        ("Tags", formattedTags)
                    ]
                )

                SkillLibraryMetadataBlock(
                    title: "Lifecycle",
                    rows: [
                        ("Version", skill.latestVersion?.version ?? "1.0.0"),
                        ("Updated", skill.updatedAt.formatted(date: .abbreviated, time: .shortened)),
                        ("Installed", lastInstalledText)
                    ]
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Latest Instructions")
                        .font(.headline)

                    Text(latestInstructionsPreview)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("SKILL.md Preview")
                        .font(.headline)

                    ScrollView(.horizontal) {
                        Text(exportedMarkdown)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                HStack(spacing: 10) {
                    Button(action: onOpenDraft) {
                        Label("Open Draft", systemImage: "arrow.right.circle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: onCopyMarkdown) {
                        Label("Copy SKILL.md", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive, action: onDeleteDraft) {
                        Label("Delete Draft", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var iconSeed: Int {
        skill.displayName.unicodeScalars.reduce(0) { partial, scalar in
            partial + Int(scalar.value)
        }
    }

    private var iconSymbol: String {
        iconSymbols[iconSeed % iconSymbols.count]
    }

    private var iconColor: Color {
        iconColors[iconSeed % iconColors.count]
    }
}

private struct DraftBadge: View {
    let title: String
    let icon: String
    let foreground: Color
    let background: Color

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
    }
}
