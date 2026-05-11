import AppKit
import PromptHubSkillKit
import SwiftUI

struct InstalledSkillListRow: View {
    let skill: InstalledSkillSnapshot
    let isRemoving: Bool
    let isSelected: Bool
    var hasUpdate: Bool = false
    var onSelect: () -> Void = {}
    var onUpdate: (() -> Void)?
    @State private var isHovered = false

    private var scopeColor: Color {
        skill.isGlobal ? .blue : .mint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(skill.displayName)
                    .font(.headline)
                    .lineLimit(1)

                if isRemoving {
                    ProgressView()
                        .controlSize(.small)
                }

                if hasUpdate {
                    if let onUpdate {
                        Button(action: onUpdate) {
                            Label("Update", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Update")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }

                Spacer()
            }

            if let source = skill.displaySource {
                Text(source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(skill.summary.isEmpty ? "No summary available" : skill.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                InstalledSkillBadge(
                    title: skill.isGlobal ? "Global" : "Project",
                    icon: skill.isGlobal ? "globe" : "folder",
                    foreground: scopeColor,
                    background: scopeColor.opacity(0.14)
                )

                if !skill.agents.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(AgentWorkflow.allCases.prefix(6), id: \.rawValue) { agent in
                            let covered = skill.agents.contains(agent)
                            Circle()
                                .fill(covered ? scopeColor : Color(NSColor.separatorColor).opacity(0.5))
                                .frame(width: 6, height: 6)
                                .help(agent.displayName + (covered ? " ✓" : " —"))
                        }
                        if AgentWorkflow.allCases.count > 6 {
                            Text("+\(AgentWorkflow.allCases.count - 6)")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(Capsule())
                }

                if !skill.isManagedByPromptHub {
                    InstalledSkillBadge(
                        title: "External",
                        icon: "arrow.triangle.branch",
                        foreground: .orange,
                        background: Color.orange.opacity(0.14)
                    )
                }
            }
        }
        .padding(12)
        .modifier(SkillLibraryRowCardStyle(isSelected: isSelected, isHovered: isHovered))
        .opacity(isRemoving ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.14), value: isHovered)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture(perform: onSelect)
        .accessibilityAddTraits(.isButton)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
