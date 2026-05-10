import AppKit
import PromptHubSkillKit
import SwiftUI

/// Compact grid showing which agents have this skill installed and in which scope.
struct InstalledSkillScopeMatrixView: View {
    let skill: InstalledSkillSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scope Coverage")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 0) {
                Text("Agent")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Global")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .center)
                Text("Project")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .center)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 2)

            VStack(spacing: 0) {
                ForEach(AgentWorkflow.allCases, id: \.rawValue) { agent in
                    let hasGlobal = skill.isGlobal && skill.agents.contains(agent)
                    let hasProject = !skill.isGlobal && skill.agents.contains(agent)
                    let isInstalled = hasGlobal || hasProject

                    HStack(spacing: 0) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isInstalled ? Color.green : Color(NSColor.separatorColor))
                                .frame(width: 7, height: 7)
                            Text(agent.displayName)
                                .font(.callout)
                                .foregroundStyle(isInstalled ? Color.primary : Color.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        scopeCell(active: hasGlobal, color: .blue)
                            .frame(width: 60)
                        scopeCell(active: hasProject, color: .mint)
                            .frame(width: 60)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(isInstalled
                        ? Color(NSColor.controlBackgroundColor).opacity(0.5)
                        : Color.clear)

                    if agent != AgentWorkflow.allCases.last {
                        Divider()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )

            HStack(spacing: 14) {
                legendItem(color: .blue, label: "Global")
                legendItem(color: .mint, label: "Project")
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(NSColor.separatorColor))
                        .frame(width: 8, height: 8)
                    Text("Not installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func scopeCell(active: Bool, color: Color) -> some View {
        if active {
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(Color(NSColor.separatorColor))
                .frame(maxWidth: .infinity)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.8))
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
