import SwiftUI

/// CLI Dashboard — shows connected AI agents and installed skills.
/// Full implementation: UI-2 task.
struct CLIDashboardView: View {
    @ObservedObject private var cliAccess = CLIDirectoryAccessManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // ── Header callout ──────────────────────────────────────
                CLIHowItWorksCard()

                // ── Connected Agents ────────────────────────────────────
                CLIAgentListSection()

                Spacer(minLength: 32)
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - How It Works card

private struct CLIHowItWorksCard: View {
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("How Skills Get Into Your AI Agents", systemImage: "terminal")
                    .font(.headline)

                Text("PromptHub writes **SKILL.md** files into each agent's config directory. Next time you open Cursor, Claude Code, or Codex, those skills are already in context — no copy-paste needed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    CLICommandRow(label: "Install CLI", command: "brew install prompthub")
                    CLICommandRow(label: "Add skill",   command: "ph skill install owner/repo@commit-writer")
                    CLICommandRow(label: "List skills", command: "ph skill list")
                }
            }
            .padding(4)
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
                .frame(width: 72, alignment: .trailing)
            Text(command)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(NSColor.tertiaryLabelColor).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

// MARK: - Agent List (placeholder — full list added in UI-2 / CLI-8)

private struct CLIAgentListSection: View {
    @ObservedObject private var cliAccess = CLIDirectoryAccessManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected AI Agents")
                .font(.headline)
                .padding(.bottom, 2)

            ForEach(CLIDirectory.allCases) { dir in
                CLIAgentRow(directory: dir, isGranted: cliAccess.hasAccess(to: dir))
            }
        }
    }
}

private struct CLIAgentRow: View {
    let directory: CLIDirectory
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(isGranted ? .green : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(directory.displayName)
                    .font(.callout)
                    .fontWeight(.medium)
                Text("~/\(directory.rawValue)/")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }

            Spacer()

            if !isGranted {
                Button("Grant Access") {
                    Task { @MainActor in
                        CLIDirectoryAccessManager.shared.requestAccess(for: directory)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("Connected")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    CLIDashboardView()
        .frame(width: 600, height: 500)
}
