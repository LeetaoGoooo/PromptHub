import AppKit
import PromptHubSkillKit
import SwiftUI

// MARK: - List Row

struct SkillStoreListRow: View {
    let skill: CatalogSkill
    let installationState: CatalogSkillInstallationState
    let isInstalling: Bool
    let justInstalled: Bool
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(skill.displayName)
                    .font(PH.Font.rowName)
                    .foregroundStyle(PH.Color.primary)
                    .lineLimit(1)
                if isInstalling {
                    ProgressView().controlSize(.small)
                }
                Spacer()
            }
            if let source = skill.displaySource {
                Text(source).font(PH.Font.rowSub).foregroundStyle(PH.Color.tertiary).lineLimit(1)
            }
            Text(skill.summary).font(PH.Font.rowSub).foregroundStyle(PH.Color.secondary).lineLimit(2)
            SkillInstallationBadges(
                installationState: installationState,
                isInstalling: isInstalling,
                justInstalled: justInstalled
            )
        }
        .padding(12)
        .modifier(SkillLibraryRowCardStyle(isSelected: isSelected, isHovered: isHovered))
        .animation(.easeInOut(duration: 0.14), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Shared Badges

struct SkillInstallationBadges: View {
    let installationState: CatalogSkillInstallationState
    let isInstalling: Bool
    let justInstalled: Bool

    var body: some View {
        if isInstalling {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Installing…").font(.caption).foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 6) {
                if justInstalled || installationState.isInstalled {
                    skillBadge(title: "Installed", foreground: .green, background: .green.opacity(0.14))
                } else {
                    skillBadge(title: "Available", foreground: .secondary, background: Color.secondary.opacity(0.12))
                }
                ForEach(sortedScopes, id: \.rawValue) { scope in
                    skillBadge(
                        title: scope.displayName,
                        foreground: scope == .global ? .blue : .mint,
                        background: (scope == .global ? Color.blue : Color.mint).opacity(0.14)
                    )
                }
            }
        }
    }

    private var sortedScopes: [SkillInstallScope] {
        installationState.scopes.sorted { lhs, rhs in
            switch (lhs, rhs) {
            case (.project, .global): return true
            case (.global, .project): return false
            default: return lhs.rawValue < rhs.rawValue
            }
        }
    }

    private func skillBadge(title: String, foreground: Color, background: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
    }
}
