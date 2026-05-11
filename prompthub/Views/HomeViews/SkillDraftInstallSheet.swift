import AlertToast
import AppKit
import PromptHubSkillKit
import SwiftData
import SwiftUI

/// A focused, modal install sheet for a skill draft. Shown directly from the My Skills
/// summary pane so users can install without opening the full draft editor.
struct SkillDraftInstallSheet: View {
    let skill: Skill

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let draftService = SkillDraftService.shared
    private let workspaceService = SkillWorkspaceService.shared

    @State private var selectedScope: SkillInstallScope = .project
    @State private var selectedAgents: Set<AgentWorkflow> = Set(AgentWorkflow.defaultTargets)
    @State private var isInstalling = false
    @State private var showToast = false
    @State private var toastTitle = ""
    @State private var toastType: AlertToast.AlertType = .regular

    private var iconSymbols: [String] { ["wand.and.stars", "text.badge.star", "command.square", "slider.horizontal.below.square.and.square.filled", "sparkles.rectangle.stack"] }
    private var iconColors: [Color] { [.pink, .blue, .orange, .mint, .indigo] }
    private var iconSeed: Int { skill.displayName.unicodeScalars.reduce(0) { $0 + Int($1.value) } }
    private var iconSymbol: String { iconSymbols[iconSeed % iconSymbols.count] }
    private var iconColor: Color { iconColors[iconSeed % iconColors.count] }

    private var installationName: String { skill.installationName }

    private var globalPathPreview: String {
        "~/.claude/agents/\(installationName).md"
    }

    private var projectPathPreview: String {
        let projectName = workspaceService.selectedProjectDisplayName
        return "\(projectName)/.claude/agents/\(installationName).md"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: iconSymbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)
                    .background(iconColor.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Install \"\(skill.displayName)\"")
                        .font(.title3.weight(.semibold))
                    Text("Choose where and for which agents this skill will be installed.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel")
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Scope section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Scope").font(.headline)
                        HStack(spacing: 10) {
                            ScopeInstallCard(
                                icon: "globe",
                                title: "Global",
                                subtitle: "Available across all projects",
                                pathPreview: globalPathPreview,
                                isSelected: selectedScope == .global
                            ) {
                                selectedScope = .global
                            }
                            ScopeInstallCard(
                                icon: "folder",
                                title: "Project",
                                subtitle: "Scoped to the selected project",
                                pathPreview: projectPathPreview,
                                isSelected: selectedScope == .project
                            ) {
                                selectedScope = .project
                            }
                        }
                    }

                    // Agent section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Target Agents").font(.headline)
                        Text("Select which AI agents should receive this skill.")
                            .font(.callout).foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(AgentWorkflow.allCases, id: \.rawValue) { agent in
                                AgentToggleRow(
                                    agent: agent,
                                    isOn: selectedAgents.contains(agent)
                                ) { enabled in
                                    if enabled {
                                        selectedAgents.insert(agent)
                                    } else {
                                        selectedAgents.remove(agent)
                                    }
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            Button("Select All") {
                                selectedAgents = Set(AgentWorkflow.allCases)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            Button("Default") {
                                selectedAgents = Set(AgentWorkflow.defaultTargets)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Install Path Preview").font(.headline)
                        Text(selectedScope == .global ? globalPathPreview : projectPathPreview)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1))
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                if let lastInstalledAt = skill.lastInstalledAt {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                        Text("Last installed \(lastInstalledAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "circle").foregroundStyle(.secondary).font(.caption)
                        Text("Not yet installed").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape)

                Button(action: performInstall) {
                    if isInstalling {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Installing…")
                        }
                    } else {
                        Label("Install", systemImage: "arrow.down.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isInstalling || selectedAgents.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: 560)
        .toast(isPresenting: $showToast) {
            AlertToast(type: toastType, title: toastTitle)
        }
    }

    private func performInstall() {
        isInstalling = true
        let agents = Array(selectedAgents).sorted { $0.rawValue < $1.rawValue }
        let scope = selectedScope
        Task {
            do {
                try await draftService.installDraft(skill, scope: scope, targetAgents: agents, in: modelContext)
                await MainActor.run {
                    isInstalling = false
                    showToast(message: "Installed \(skill.displayName)", type: .complete(.green))
                }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    isInstalling = false
                    showToast(message: "Install failed: \(error.localizedDescription)", type: .error(.red))
                }
            }
        }
    }

    private func showToast(message: String, type: AlertToast.AlertType = .error(.red)) {
        toastTitle = message
        toastType = type
        showToast = true
    }
}

// MARK: - Sub-views

private struct ScopeInstallCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let pathPreview: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon).foregroundStyle(isSelected ? .white : .accentColor).font(.system(size: 13, weight: .semibold))
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(isSelected ? .white : .primary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.white).font(.caption)
                    }
                }
                Text(subtitle).font(.caption).foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary).lineLimit(1)
                Text(pathPreview)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .padding(12)
            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.clear : Color(NSColor.separatorColor).opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct AgentToggleRow: View {
    let agent: AgentWorkflow
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Button {
            onChange(!isOn)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
                    .font(.system(size: 14))
                Text(agent.displayName)
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isOn ? Color.accentColor.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
