import PromptHubSkillKit
import SwiftUI

// MARK: - CLI Dashboard

struct CLIDashboardView: View {
    @ObservedObject private var cliAccess = CLIDirectoryAccessManager.shared
    @State private var selectedDirectory: CLIDirectory?
    @State private var installedSkills: [InstalledSkillSnapshot] = []
    @State private var loadingSkills = false
    @State private var loadError: String?

    var body: some View {
        HSplitView {
            // Left pane — Agent list
            leftPane
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)

            // Right pane — Detail / Inspector
            rightPane
                .frame(minWidth: 320, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await loadSkills() }
        .onReceive(
            NotificationCenter.default.publisher(for: .skillInstallationsDidChange)
        ) { _ in
            Task { await loadSkills() }
        }
    }

    // MARK: Left pane

    private var leftPane: some View {
        VStack(spacing: 0) {
            // Summary header
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connected AI Agents")
                            .font(.headline)
                        Text("\(cliAccess.grantedDirectories.count) of \(CLIDirectory.allCases.count) authorized")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if cliAccess.anyAccessGranted {
                        Label("Active", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

                Divider()
            }

            // Agent rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(CLIDirectory.allCases) { dir in
                        CLIAgentRow(
                            directory: dir,
                            isGranted: cliAccess.hasAccess(to: dir),
                            skillCount: skillCount(for: dir),
                            isSelected: selectedDirectory == dir
                        ) {
                            selectedDirectory = dir
                        }
                        Divider().padding(.leading, 52)
                    }
                }
            }

            Divider()

            // Quick actions footer
            HStack(spacing: 12) {
                Button {
                    grantAll()
                } label: {
                    Label("Authorize All", systemImage: "lock.open")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(cliAccess.grantedDirectories.count == CLIDirectory.allCases.count)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: Right pane

    @ViewBuilder
    private var rightPane: some View {
        if let dir = selectedDirectory {
            CLIAgentDetailPane(
                directory: dir,
                isGranted: cliAccess.hasAccess(to: dir),
                skills: installedSkills.filter { snapshot in
                    snapshot.agents.contains { $0.cliDirectory == dir }
                }
            )
        } else {
            CLIHowItWorksCard()
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: Helpers

    private func skillCount(for dir: CLIDirectory) -> Int {
        installedSkills.filter { $0.agents.contains { $0.cliDirectory == dir } }.count
    }

    @MainActor
    private func loadSkills() async {
        loadingSkills = true
        loadError = nil
        do {
            let snapshot = try await SkillWorkspaceService.shared.loadInstalledWorkspace()
            installedSkills = snapshot.installedSkills
        } catch {
            loadError = error.localizedDescription
        }
        loadingSkills = false
    }

    private func grantAll() {
        for dir in CLIDirectory.allCases where !cliAccess.hasAccess(to: dir) {
            cliAccess.requestAccess(for: dir)
        }
    }
}

// MARK: - Agent Row

private struct CLIAgentRow: View {
    let directory: CLIDirectory
    let isGranted: Bool
    let skillCount: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(isGranted ? Color.green.opacity(0.15) : Color(NSColor.separatorColor).opacity(0.3))
                        .frame(width: 36, height: 36)
                    Image(systemName: isGranted ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(isGranted ? .green : .secondary)
                        .font(.system(size: 16))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(directory.displayName)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("~/\(directory.rawValue)/")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                }

                Spacer()

                if isGranted && skillCount > 0 {
                    Text("\(skillCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Agent Detail Pane

private struct CLIAgentDetailPane: View {
    let directory: CLIDirectory
    let isGranted: Bool
    let skills: [InstalledSkillSnapshot]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(isGranted ? Color.green.opacity(0.12) : Color(NSColor.separatorColor).opacity(0.2))
                            .frame(width: 48, height: 48)
                        Image(systemName: isGranted ? "checkmark.shield.fill" : "shield.slash")
                            .font(.system(size: 20))
                            .foregroundStyle(isGranted ? .green : .secondary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(directory.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("~/\(directory.rawValue)/")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fontDesign(.monospaced)
                    }
                    Spacer()
                    if !isGranted {
                        Button("Grant Access") {
                            CLIDirectoryAccessManager.shared.requestAccess(for: directory)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    } else {
                        Label("Authorized", systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.bottom, 4)

                Divider()

                // Installed Skills
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Installed Skills")
                            .font(.headline)
                        Spacer()
                        Text("\(skills.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if skills.isEmpty {
                        ContentUnavailableView {
                            Label("No Skills", systemImage: "square.stack.3d.up")
                        } description: {
                            Text("Install skills with:\nph skill install owner/repo@skill-name")
                                .fontDesign(.monospaced)
                                .font(.caption)
                        }
                        .frame(height: 120)
                    } else {
                        ForEach(skills) { skill in
                            CLISkillRow(skill: skill)
                        }
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(20)
        }
    }
}

private struct CLISkillRow: View {
    let skill: InstalledSkillSnapshot

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.badge.gearshape")
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(skill.displayName)
                    .font(.callout)
                    .fontWeight(.medium)
                if let source = skill.displaySource {
                    Text(source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Scope badge
            Text(skill.scope.rawValue.capitalized)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(skill.isGlobal ? .purple : .blue)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background((skill.isGlobal ? Color.purple : Color.blue).opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - How It Works card

struct CLIHowItWorksCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("How Skills Get Into Your AI Agents", systemImage: "terminal")
                .font(.headline)
                .padding(.bottom, 12)

            Text("PromptHub writes **SKILL.md** files into each agent's config directory. Next time you open Cursor, Claude Code, or Codex, those skills are already loaded — no copy-paste needed.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)

            Divider()
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 8) {
                CLICommandRow(label: "Install CLI",  command: "brew install prompthub")
                CLICommandRow(label: "Add skill",    command: "ph skill install owner/repo@commit-writer")
                CLICommandRow(label: "List skills",  command: "ph skill list")
                CLICommandRow(label: "Remove skill", command: "ph skill remove commit-writer")
            }

            Spacer(minLength: 24)

            Text("Select an agent on the left to view its authorized directory and installed skills.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .italic()
        }
    }
}

private struct CLICommandRow: View {
    let label: String
    let command: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text(command)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(NSColor.tertiaryLabelColor).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

// MARK: - AgentWorkflow → CLIDirectory mapping

extension AgentWorkflow {
    var cliDirectory: CLIDirectory? {
        switch self {
        case .codex:      return .codex
        case .claudeCode: return .claude
        case .cursor:     return .cursor
        case .geminiCLI:  return .gemini
        case .iflow:      return .iflow
        case .opencode:   return .opencode
        case .qwenCode:   return .qwen
        case .qoder:      return .qoder
        }
    }
}

#Preview {
    CLIDashboardView()
        .frame(width: 800, height: 550)
}
