import PromptHubSkillKit
import SwiftUI

struct SkillDraftListRow: View {
    let skill: Skill
    let installations: [InstalledSkillSnapshot]
    let isSelected: Bool
    @State private var isHovered = false

    private var summary: String {
        if let desc = skill.desc?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty { return desc }
        return "No description yet"
    }

    private var agentLine: String {
        let agents = installations.flatMap(\.agents)
        guard !agents.isEmpty else { return "Draft · Not installed" }
        let names = AgentWorkflow.defaultTargets
            .filter { agents.contains($0) }
            .map(\.displayName)
            .joined(separator: ", ")
        return "Draft · \(names)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(skill.displayName)
                    .font(PH.Font.rowName)
                    .foregroundStyle(isSelected ? .white : PH.Color.primary)
                    .lineLimit(1)
                if !installations.isEmpty {
                    Circle()
                        .fill(PH.Color.statusOK)
                        .frame(width: 6, height: 6)
                }
                Spacer()
                if let latestVersion = skill.latestVersion {
                    Text(latestVersion.version)
                        .font(PH.Font.mono)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.82) : PH.Color.tertiary)
                }
            }
            Text(summary)
                .font(PH.Font.rowSub)
                .foregroundStyle(isSelected ? Color.white.opacity(0.86) : PH.Color.secondary)
                .lineLimit(2)
            HStack(spacing: 6) {
                Text(skill.category)
                    .font(PH.Font.badge)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.86) : PH.Color.statusOK)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((isSelected ? Color.white.opacity(0.14) : PH.Color.statusOK.opacity(0.12)), in: Capsule())
                Text(agentLine)
                    .font(PH.Font.rowSub)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.75) : PH.Color.tertiary)
                    .lineLimit(1)
            }
            Text("Updated \(skill.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(PH.Font.rowSub)
                .foregroundStyle(isSelected ? Color.white.opacity(0.7) : PH.Color.tertiary)
        }
        .padding(12)
        .background(backgroundFill, in: RoundedRectangle(cornerRadius: PH.Spacing.rowCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PH.Spacing.rowCorner, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.14), value: isHovered)
        .onHover { hovering in isHovered = hovering }
    }

    private var backgroundFill: Color {
        if isSelected { return PH.Color.selectedFill }
        if isHovered { return PH.Color.hoverFill }
        return .clear
    }

    private var borderColor: Color {
        if isSelected { return PH.Color.selectedFill.opacity(0.22) }
        if isHovered { return PH.Color.stroke }
        return .clear
    }
}
