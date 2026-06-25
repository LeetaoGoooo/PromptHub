import PromptHubSkillKit
import SwiftUI

struct SkillDraftSummaryPane: View {
    let skill: Skill
    let installations: [InstalledSkillSnapshot]
    let exportedMarkdown: String
    let onOpenDraft: () -> Void
    let onCopyMarkdown: () -> Void
    let onCopyName: () -> Void
    let onDeleteDraft: () -> Void

    @State private var showingInstallSheet = false

    private var latestInstructionsPreview: String {
        let text = skill.latestVersion?.instructions.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "No instructions yet." : text
    }

    private var formattedTags: String { skill.tags.isEmpty ? "No tags yet" : skill.tags.joined(separator: ", ") }

    private var lastInstalledText: String {
        skill.lastInstalledAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Never"
    }

    private var installedAgentsText: String {
        let agents = installations.flatMap(\.agents)
        guard !agents.isEmpty else { return "Not installed to any agent" }
        return AgentWorkflow.defaultTargets
            .filter { agents.contains($0) }
            .map(\.displayName)
            .joined(separator: ", ")
    }

    private var installedScopeText: String {
        guard !installations.isEmpty else { return "Draft only" }
        let scopes = Array(Set(installations.map(\.scope.displayName))).sorted()
        return scopes.joined(separator: ", ")
    }

    var body: some View {
        SkillLibraryInspectorCard {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(PH.Color.primary)
                            .frame(width: 34, height: 34)
                            .background(PH.Color.chipBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(skill.displayName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(PH.Color.primary)
                            Text(skill.desc?.isEmpty == false ? skill.desc! : "No description yet.")
                                .font(PH.Font.body)
                                .foregroundStyle(PH.Color.secondary)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(skill.category)
                            .font(PH.Font.badge)
                            .foregroundStyle(PH.Color.statusOK)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(PH.Color.statusOK.opacity(0.12), in: Capsule())
                        if !installations.isEmpty {
                            Text("Installed")
                                .font(PH.Font.badge)
                                .foregroundStyle(PH.Color.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(PH.Color.accentTint, in: Capsule())
                        }
                    }
                }

                SkillLibraryMetadataBlock(title: "Identity", rows: [
                    ("Slug", skill.slug.isEmpty ? "Not set" : skill.slug),
                    ("Identifier", skill.identifier.isEmpty ? "Not set" : skill.identifier),
                    ("Tags", formattedTags),
                    ("Agents", installedAgentsText),
                    ("Scope", installedScopeText)
                ])

                SkillLibraryMetadataBlock(title: "Lifecycle", rows: [
                    ("Version", skill.latestVersion?.version ?? "1.0.0"),
                    ("Updated", skill.updatedAt.formatted(date: .abbreviated, time: .shortened)),
                    ("Installed", lastInstalledText)
                ])

                VStack(alignment: .leading, spacing: 12) {
                    PHSectionHead(systemImage: "bolt", label: "Actions")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10, alignment: .leading)], alignment: .leading, spacing: 10) {
                        Button(action: { showingInstallSheet = true }) {
                            Label("Install…", systemImage: "arrow.down.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PHChromeButtonStyle(emphasis: .accent))

                        Button(action: onOpenDraft) {
                            Label("Open Draft", systemImage: "arrow.right.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PHChromeButtonStyle(emphasis: .standard))

                        Button(action: onCopyMarkdown) {
                            Label("Copy SKILL.md", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PHChromeButtonStyle(emphasis: .standard))

                        Button(action: onCopyName) {
                            Label("Copy Name", systemImage: "doc.on.clipboard")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PHChromeButtonStyle(emphasis: .standard))

                        Button(role: .destructive, action: onDeleteDraft) {
                            Label("Delete Draft", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PHChromeButtonStyle(emphasis: .standard))
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    PHSectionHead(systemImage: "text.alignleft", label: "Latest Instructions")
                    ScrollView {
                        Text(latestInstructionsPreview)
                            .font(PH.Font.body)
                            .foregroundStyle(PH.Color.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(14)
                    }
                    .frame(minHeight: 110, idealHeight: 140, maxHeight: 180)
                    .background(PH.Color.sidebarBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 12) {
                    PHSectionHead(systemImage: "doc.plaintext", label: "SKILL.md")
                    ScrollView([.horizontal, .vertical]) {
                        Text(exportedMarkdown)
                            .font(PH.Font.monoBody)
                            .foregroundStyle(PH.Color.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 260, idealHeight: 340, maxHeight: 420)
                    .padding(12)
                    .background(PH.Color.sidebarBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .sheet(isPresented: $showingInstallSheet) {
                    SkillDraftInstallSheet(skill: skill)
                }
            }
        }
    }
}
