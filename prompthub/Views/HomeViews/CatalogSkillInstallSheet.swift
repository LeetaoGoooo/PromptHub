import AppKit
import PromptHubSkillKit
import SwiftUI

struct CatalogSkillInstallSheet: View {
    let skill: CatalogSkill
    let installationState: CatalogSkillInstallationState
    let initialScope: SkillInstallScope
    let initialProjectRootURL: URL?
    let onConfirm: (SkillInstallScope, [AgentWorkflow], URL?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedScope: SkillInstallScope
    @State private var selectedAgents: Set<AgentWorkflow>
    @State private var selectedProjectRootURL: URL?

    init(
        skill: CatalogSkill,
        installationState: CatalogSkillInstallationState,
        initialScope: SkillInstallScope,
        initialProjectRootURL: URL?,
        onConfirm: @escaping (SkillInstallScope, [AgentWorkflow], URL?) -> Void
    ) {
        self.skill = skill
        self.installationState = installationState
        self.initialScope = initialScope
        self.initialProjectRootURL = initialProjectRootURL
        self.onConfirm = onConfirm
        let initialAgents = Self.missingAgents(for: initialScope, installationState: installationState)
        _selectedScope = State(initialValue: initialScope)
        _selectedAgents = State(initialValue: Set(initialAgents))
        _selectedProjectRootURL = State(initialValue: initialProjectRootURL)
    }

    private var availableAgents: [AgentWorkflow] {
        Self.missingAgents(for: selectedScope, installationState: installationState)
    }
    private var installedAgents: [AgentWorkflow] {
        installationState.agentsByScope[selectedScope] ?? []
    }
    private var confirmTitle: String {
        installationState.scopes.contains(selectedScope) ? "Add CLIs" : "Install Skill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    scopeSection
                    if selectedScope == .project { projectSection }
                    agentSection
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            footerBar
        }
        .padding(24)
        .frame(width: 480, height: 520)
        .onChange(of: selectedScope) { _, newScope in
            selectedAgents = Set(Self.missingAgents(for: newScope, installationState: installationState))
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(confirmTitle).font(.title3.weight(.semibold))
            Text(skill.displayName).font(.headline)
            Text("Choose where this skill should live first, then select the CLI environments that should receive it.")
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Installation Scope").font(.headline)
            HStack(spacing: 10) {
                ScopeCard(
                    title: "Global",
                    subtitle: "All projects",
                    icon: "globe",
                    pathExample: globalPathExample,
                    isSelected: selectedScope == .global
                ) { selectedScope = .global }

                ScopeCard(
                    title: "Project",
                    subtitle: "This folder only",
                    icon: "folder",
                    pathExample: projectPathExample,
                    isSelected: selectedScope == .project
                ) { selectedScope = .project }
            }
        }
    }

    private var globalPathExample: String {
        "~/.claude/agents/\(skill.package.skillName).md"
    }

    private var projectPathExample: String {
        if let root = selectedProjectRootURL {
            return "\(root.lastPathComponent)/.claude/agents/\(skill.package.skillName).md"
        }
        return "<project>/.claude/agents/\(skill.package.skillName).md"
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Project Folder", systemImage: "folder.badge.gearshape")
                    .font(.headline)
                Spacer()
                Button("Choose\u{2026}") { chooseProjectRoot() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            if let url = selectedProjectRootURL {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 13))
                    Text(url.path)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fontDesign(.monospaced)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 13))
                    Text("No project selected. Skills will be installed relative to the project root.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    @ViewBuilder
    private var agentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CLI Targets").font(.headline)
            if !installedAgents.isEmpty {
                Text("Already installed in \(selectedScope.displayName.lowercased()): \(installedAgents.map(\.displayName).joined(separator: ", ")).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if availableAgents.isEmpty {
                ContentUnavailableView(
                    "Nothing to Add",
                    systemImage: "checkmark.circle",
                    description: Text("All supported CLIs already have this skill in \(selectedScope.displayName.lowercased()) scope.")
                )
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if availableAgents.count > 1 {
                        HStack {
                            Button("Select All") { selectedAgents = Set(availableAgents) }.buttonStyle(.link)
                            Button("Clear") { selectedAgents = [] }.buttonStyle(.link)
                            Spacer()
                        }
                    }
                    ForEach(availableAgents, id: \.rawValue) { agent in
                        Toggle(isOn: binding(for: agent)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(agent.displayName)
                                Text(agent.rawValue).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(14)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var footerBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
            Spacer()
            Button(confirmTitle) {
                onConfirm(selectedScope,
                          availableAgents.filter { selectedAgents.contains($0) },
                          selectedProjectRootURL)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedAgents.isEmpty || (selectedScope == .project && selectedProjectRootURL == nil))
        }
    }

    private func binding(for agent: AgentWorkflow) -> Binding<Bool> {
        Binding(
            get: { selectedAgents.contains(agent) },
            set: { if $0 { selectedAgents.insert(agent) } else { selectedAgents.remove(agent) } }
        )
    }

    private func chooseProjectRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose the project folder for this project-scope skill install."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        selectedProjectRootURL = url
    }

    private static func missingAgents(for scope: SkillInstallScope, installationState: CatalogSkillInstallationState) -> [AgentWorkflow] {
        let installed = Set(installationState.agentsByScope[scope] ?? [])
        return AgentWorkflow.defaultTargets.filter { !installed.contains($0) }
    }
}

// MARK: - Scope selection card

private struct ScopeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let pathExample: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .frame(width: 22, height: 22)
                        .background(isSelected ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 5))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(pathExample)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.4), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
