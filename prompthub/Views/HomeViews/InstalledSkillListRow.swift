import AppKit
import PromptHubSkillKit
import SwiftUI

struct InstalledSkillListRow: View {
    let skill: InstalledSkillSnapshot
    let isRemoving: Bool
    let isSelected: Bool
    var projectNames: [String] = []
    var hasUpdate: Bool = false
    var onSelect: () -> Void = {}
    var onUpdate: (() -> Void)?

    @State private var isHovering = false

    // Quick quality hint derived from agent coverage — no async audit needed in list.
    private var qualityHint: (label: String, color: Color)? {
        let n = skill.agents.count
        if n >= 3 { return ("Excellent", PH.Color.statusOK) }
        if n >= 1 { return ("Strong",    PH.Color.statusOK) }
        if skill.isManagedByPromptHub { return ("Needs Check", PH.Color.statusWarn) }
        return nil
    }

    private var subText: String {
        let scope: String = {
            if skill.isGlobal {
                return "Global"
            }
            if projectNames.count == 1, let projectName = projectNames.first {
                return projectName
            }
            if projectNames.count > 1 {
                return "\(projectNames.count) projects"
            }
            return "Project"
        }()
        let origin = skill.isManagedByPromptHub ? "Managed" : "External"
        return "\(scope) · \(origin)"
    }

    private var backgroundFill: Color {
        if isSelected {
            return PH.Color.accentTint
        }

        if isHovering {
            return PH.Color.hoverFill
        }

        return .clear
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: PH.Spacing.rowGap) {
                // Line 1: name + optional update badge + quality label (right-aligned)
                HStack(spacing: 4) {
                    Text(skill.displayName)
                        .font(PH.Font.rowName)
                        .foregroundStyle(PH.Color.primary)
                        .lineLimit(1)

                    if isRemoving {
                        ProgressView().controlSize(.mini)
                    }

                    if hasUpdate {
                        if let onUpdate {
                            Button(action: onUpdate) {
                                Text("Update")
                                    .font(PH.Font.badge)
                                    .foregroundStyle(PH.Color.statusWarn)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(PH.Color.statusWarn.opacity(0.12))
                                    .clipShape(Capsule(style: .continuous))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("Update")
                                .font(PH.Font.badge)
                                .foregroundStyle(PH.Color.statusWarn)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(PH.Color.statusWarn.opacity(0.12))
                                .clipShape(Capsule(style: .continuous))
                        }
                    }

                    Spacer(minLength: 0)

                    if let q = qualityHint {
                        Text(q.label)
                            .font(PH.Font.statusLabel)
                            .foregroundStyle(q.color)
                    }
                }

                // Line 2: status dot + scope/origin
                HStack(spacing: PH.Spacing.sectionHeadGap) {
                    Circle()
                        .fill(skill.isGlobal ? PH.Color.statusOK : PH.Color.accent)
                        .frame(width: PH.Layout.statusDotSize, height: PH.Layout.statusDotSize)
                    Text(subText)
                        .font(PH.Font.rowSub)
                        .foregroundStyle(PH.Color.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, PH.Spacing.rowH)
            .padding(.horizontal, PH.Spacing.rowV)
            .contentShape(RoundedRectangle(cornerRadius: PH.Spacing.rowCorner))
        }
        .buttonStyle(.plain)
        .background(backgroundFill)
        .overlay {
            RoundedRectangle(cornerRadius: PH.Spacing.rowCorner)
                .stroke(isSelected ? PH.Color.accent.opacity(0.18) : PH.Color.stroke.opacity(isHovering ? 1 : 0), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: PH.Spacing.rowCorner))
        .opacity(isRemoving ? 0.55 : 1)
        .animation(PH.Motion.hover, value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .accessibilityLabel(skill.displayName)
        .accessibilityValue(subText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
