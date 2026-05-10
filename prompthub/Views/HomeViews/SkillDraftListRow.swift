import SwiftUI

struct SkillDraftListRow: View {
    let skill: Skill
    let isSelected: Bool
    @State private var isHovered = false

    private var summary: String {
        if let desc = skill.desc?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty { return desc }
        return "No description yet"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(skill.displayName).font(.headline).lineLimit(1)
                if skill.lastInstalledAt != nil {
                    Image(systemName: "arrow.down.circle.fill").font(.caption).foregroundStyle(.green)
                }
                Spacer()
                if let latestVersion = skill.latestVersion {
                    Text(latestVersion.version).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
            }
            Text(summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            HStack(spacing: 6) {
                DraftBadge(title: skill.category, icon: "tag", foreground: .accentColor, background: Color.accentColor.opacity(0.14))
                if !skill.tags.isEmpty {
                    DraftBadge(
                        title: "\(min(skill.tags.count, 3)) tag\(skill.tags.count == 1 ? "" : "s")",
                        icon: "number", foreground: .secondary, background: Color.secondary.opacity(0.12)
                    )
                }
            }
            Text("Updated \(skill.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(12)
        .modifier(SkillLibraryRowCardStyle(isSelected: isSelected, isHovered: isHovered))
        .animation(.easeInOut(duration: 0.14), value: isHovered)
        .onHover { hovering in isHovered = hovering }
    }
}
