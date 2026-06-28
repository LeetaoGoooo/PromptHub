import PromptHubSkillKit
import SwiftUI

struct SkillDraftPreviewPane: View {
    let skill: Skill
    let installations: [InstalledSkillSnapshot]
    let onEditWorkspace: () -> Void
    let onCopyMarkdown: () -> Void
    let onCreateVersion: () -> Void
    let onRevealInFinder: () -> Void

    private let draftService = SkillDraftService.shared

    private var displayName: String {
        let raw = skill.displayName
        let cleaned = raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return raw }
        return cleaned
            .split(separator: " ")
            .map {
                guard let first = $0.first else { return String($0) }
                return first.uppercased() + $0.dropFirst()
            }
            .joined(separator: " ")
    }

    private var markdown: String { draftService.exportMarkdown(for: skill) }

    private var statusValue: String {
        skill.lastInstalledAt == nil ? "Not Installed" : "Installed"
    }

    private var targetsValue: String {
        let agents = Array(Set(installations.flatMap(\.agents)))
        guard !agents.isEmpty else { return "Draft only" }
        return AgentWorkflow.defaultTargets
            .filter { agents.contains($0) }
            .map(\.displayName)
            .joined(separator: ", ")
    }

    private var metrics: [SkillLibraryMetric] {
        [
            SkillLibraryMetric(value: "1", title: "Files", systemImage: "folder"),
            SkillLibraryMetric(value: "\(skill.sortedVersions.count)", title: "Versions", systemImage: "square.stack"),
            SkillLibraryMetric(value: statusValue, title: "Status", systemImage: "shippingbox")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SkillDetailHeader(
                    timestamp: skill.updatedAt.formatted(date: .omitted, time: .shortened),
                    title: displayName,
                    summary: skill.desc?.isEmpty == false ? skill.desc! : "No description yet.",
                    metrics: metrics,
                    controlSize: .small
                ) {
                    HStack(spacing: 6) {
                        Button(action: onEditWorkspace) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Edit workspace")

                        Button(action: onCreateVersion) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Save version snapshot")

                        Button(action: onCopyMarkdown) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Copy SKILL.md")

                        Button(action: onRevealInFinder) {
                            Image(systemName: "folder")
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Reveal in Finder")
                    }
                }

                SkillPreviewMarkdownView(
                    markdown: markdown,
                    fallbackText: skill.desc?.isEmpty == false ? skill.desc! : "No description yet."
                )

                Text(targetsValue)
                    .font(PH.Font.rowSub)
                    .foregroundStyle(PH.Color.tertiary)
            }
            .padding(PH.Spacing.promptInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PH.Color.detailBg)
    }
}
