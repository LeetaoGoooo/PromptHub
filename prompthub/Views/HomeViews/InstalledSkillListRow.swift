import AppKit
import PromptHubSkillKit
import SwiftUI

struct InstalledSkillListRow: View {
    let skill: InstalledSkillSnapshot
    let isRemoving: Bool
    let isUpdating: Bool
    let isSelected: Bool
    var projectNames: [String] = []
    var hasUpdate: Bool = false
    var showsSelectionControl: Bool = false
    var isMarkedForUpdate: Bool = false
    var onToggleMarkedForUpdate: (() -> Void)?
    var onSelect: () -> Void = {}
    var onUpdate: (() -> Void)?

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

    var body: some View {
        SkillLibraryCompactRow(
            title: skill.displayName,
            metaText: subText,
            dotColor: skill.isGlobal ? PH.Color.statusOK : PH.Color.accent,
            isSelected: isSelected,
            onSelect: onSelect
        ) {
            if showsSelectionControl {
                Button(action: { onToggleMarkedForUpdate?() }) {
                    Image(systemName: isMarkedForUpdate ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isMarkedForUpdate ? PH.Color.accent : PH.Color.tertiary)
                }
                .buttonStyle(.plain)
            }

            if isRemoving || isUpdating {
                ProgressView().controlSize(.mini)
            }

            if hasUpdate && !showsSelectionControl {
                if let onUpdate {
                    Button(action: onUpdate) {
                        updateBadge
                    }
                    .buttonStyle(.plain)
                } else {
                    updateBadge
                }
            }
        }
        .opacity((isRemoving || isUpdating) ? 0.55 : 1)
        .accessibilityLabel(skill.displayName)
        .accessibilityValue(subText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var updateBadge: some View {
        Text("Update")
            .font(PH.Font.badge)
            .foregroundStyle(PH.Color.statusWarn)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(PH.Color.statusWarn.opacity(0.12))
            .clipShape(Capsule(style: .continuous))
    }
}
