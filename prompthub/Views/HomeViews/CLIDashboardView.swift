import AppKit
import PromptHubSkillKit
import SwiftUI

struct CLIDashboardView: View {
    @ObservedObject private var cliAccess = CLIDirectoryAccessManager.shared
    private let workspaceService = SkillWorkspaceService.shared

    @State private var installedSkills: [InstalledSkillSnapshot] = []
    @State private var loadingSkills = false
    @State private var loadError: String?
    @State private var selectedDirectory: CLIDirectory?
    @State private var showingAccessManager = false
    @State private var showingInstallHint = false
    @State private var showingCLISettingsHint = false
    @State private var copiedCommand: String?

    private var grantedDirectories: [CLIDirectory] {
        CLIDirectory.allCases.filter { cliAccess.hasAccess(to: $0) }
    }

    private var sortedDirectories: [CLIDirectory] {
        CLIDirectory.allCases.sorted { lhs, rhs in
            let lhsGranted = cliAccess.hasAccess(to: lhs)
            let rhsGranted = cliAccess.hasAccess(to: rhs)
            if lhsGranted != rhsGranted {
                return lhsGranted && !rhsGranted
            }
            return lhs.displayName < rhs.displayName
        }
    }

    private var totalInstalledCount: Int { installedSkills.count }

    private var selectedProjectLabel: String {
        if let url = workspaceService.selectedProjectRootURL {
            return url.lastPathComponent + "/"
        }
        return "No project selected"
    }

    private var projectSkills: [InstalledSkillSnapshot] {
        installedSkills.filter { !$0.isGlobal }
    }

    private var globalSkills: [InstalledSkillSnapshot] {
        installedSkills.filter { $0.isGlobal }
    }

    private var cliExecutablePath: String? {
        let candidates = [
            "/opt/homebrew/bin/ph",
            "/usr/local/bin/ph",
            NSHomeDirectory() + "/.local/bin/ph"
        ]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0) })
    }

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    CLIHowItWorksCard(onCopyCommand: copyCommand(_:), copiedCommand: copiedCommand)
                    connectedAgentsSection
                    installedSkillsSection(
                        title: "Skills — Project Scope",
                        subtitle: selectedProjectLabel + "  ·  ~/.agents/skills/",
                        skills: projectSkills
                    )
                    installedSkillsSection(
                        title: "Skills — Global Scope",
                        subtitle: "~/Library/Application Support/PromptHub",
                        skills: globalSkills
                    )
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(NSColor.windowBackgroundColor))

            CLIDashboardInspector(
                cliExecutablePath: cliExecutablePath,
                grantedDirectories: grantedDirectories,
                selectedProjectLabel: selectedProjectLabel,
                hasGeminiAccess: cliAccess.hasAccess(to: .gemini),
                onInstallSkill: { showingInstallHint = true },
                onGrantAccess: { showingAccessManager = true },
                onChangeProject: chooseProjectRoot,
                onCLISettings: { showingCLISettingsHint = true }
            )
            .frame(minWidth: 290, idealWidth: 310, maxWidth: 340, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .task { await loadSkills() }
        .onReceive(NotificationCenter.default.publisher(for: .skillInstallationsDidChange)) { _ in
            Task { await loadSkills() }
        }
        .sheet(isPresented: $showingAccessManager) {
            CLIAccessManagerView()
        }
        .alert("Install Skill", isPresented: $showingInstallHint) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Use Discover or My Skills to install a skill, then return here to verify which agents received it.")
        }
        .alert("CLI Settings", isPresented: $showingCLISettingsHint) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Manage CLI directories from Grant Agent Access, and select the active project folder here in the dashboard.")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "terminal")
                            .foregroundStyle(.accent)
                        Text("CLI Integration")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        if cliAccess.anyAccessGranted {
                            StatusCapsule(title: "Active", tint: .green)
                        }
                    }
                    Text("Install your Skills into any AI coding agent so they become part of every conversation automatically.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        HeaderMetric(title: "agents connected", value: "\(grantedDirectories.count)", systemImage: "cube")
                        HeaderMetric(title: "skills installed", value: "\(totalInstalledCount)", systemImage: "wand.and.stars")
                        HeaderMetric(title: "project", value: selectedProjectLabel, systemImage: "link")
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        showingInstallHint = true
                    } label: {
                        Label("Install Skill", systemImage: "square.stack.3d.up")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showingAccessManager = true
                    } label: {
                        Label("Manage Access", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let loadError {
                Text(loadError)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var connectedAgentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connected AI Agents")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                ForEach(sortedDirectories) { directory in
                    CLIAgentWorkspaceCard(
                        directory: directory,
                        isGranted: cliAccess.hasAccess(to: directory),
                        skills: skills(for: directory),
                        isSelected: selectedDirectory == directory,
                        onTap: { selectedDirectory = directory }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func installedSkillsSection(title: String, subtitle: String, skills: [InstalledSkillSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }

            if skills.isEmpty {
                Text("No installed skills in this scope yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 10) {
                    ForEach(skills) { skill in
                        CLISkillActivityRow(skill: skill, selectedDirectory: selectedDirectory)
                    }
                }
            }
        }
    }

    private func skills(for directory: CLIDirectory) -> [InstalledSkillSnapshot] {
        installedSkills.filter { snapshot in
            snapshot.agents.contains { $0.cliDirectory == directory }
        }
    }

    @MainActor
    private func loadSkills() async {
        loadingSkills = true
        loadError = nil
        do {
            let snapshot = try await workspaceService.loadInstalledWorkspace()
            installedSkills = snapshot.installedSkills
            if selectedDirectory == nil {
                selectedDirectory = grantedDirectories.first ?? sortedDirectories.first
            }
        } catch {
            loadError = error.localizedDescription
        }
        loadingSkills = false
    }

    private func chooseProjectRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose the project folder whose CLI skill roots should be managed."
        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        workspaceService.setSelectedProjectRootURL(selectedURL)
    }

    private func copyCommand(_ command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        copiedCommand = command
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if copiedCommand == command {
                copiedCommand = nil
            }
        }
    }
}

private struct HeaderMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            Text("\(value) \(title)")
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct StatusCapsule: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct CLIAgentWorkspaceCard: View {
    let directory: CLIDirectory
    let isGranted: Bool
    let skills: [InstalledSkillSnapshot]
    let isSelected: Bool
    let onTap: () -> Void

    private var displayedSkillNames: [String] {
        Array(skills.map(\.displayName).sorted().prefix(3))
    }

    private var extraCount: Int {
        max(skills.count - displayedSkillNames.count, 0)
    }

    private var badgeText: String {
        let hasGlobal = skills.contains(where: \.isGlobal)
        let hasProject = skills.contains(where: { !$0.isGlobal })
        switch (hasGlobal, hasProject, isGranted) {
        case (_, _, false): return "Disconnected"
        case (true, true, true): return "Global + Project"
        case (true, false, true): return "Global only"
        case (false, true, true): return "Project only"
        case (false, false, true): return "Authorized"
        }
    }

    private var badgeTint: Color {
        if !isGranted { return .secondary }
        if skills.contains(where: \.isGlobal) && skills.contains(where: { !$0.isGlobal }) { return .green }
        if skills.isEmpty { return .secondary }
        return skills.contains(where: \.isGlobal) ? .accentColor : .orange
    }

    private var pathText: String {
        "~/\(directory.rawValue)/  ·  \(isGranted ? "granted" : "not connected")"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(directory.displayName)
                            .font(.headline)
                        Text(pathText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontDesign(.monospaced)
                    }
                    Spacer()
                    StatusCapsule(title: badgeText, tint: badgeTint)
                }

                HStack(spacing: 12) {
                    Label("\(skills.count) skills", systemImage: "cube")
                    Label(skills.contains(where: \.isGlobal) ? "global scope" : "project scope", systemImage: "wand.and.stars")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if isGranted && !displayedSkillNames.isEmpty {
                    FlexibleChipWrap(items: displayedSkillNames, extraCount: extraCount)
                } else if !isGranted {
                    Label("Grant folder access to connect", systemImage: "powerplug")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color(NSColor.separatorColor).opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(isGranted ? 1 : 0.7)
        }
        .buttonStyle(.plain)
    }
}

private struct FlexibleChipWrap: View {
    let items: [String]
    let extraCount: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.windowBackgroundColor))
                    .clipShape(Capsule())
            }
            if extraCount > 0 {
                Text("+\(extraCount) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.windowBackgroundColor))
                    .clipShape(Capsule())
            }
            Spacer(minLength: 0)
        }
    }
}

private struct CLISkillActivityRow: View {
    let skill: InstalledSkillSnapshot
    let selectedDirectory: CLIDirectory?

    private var filteredAgents: [AgentWorkflow] {
        guard let selectedDirectory else { return skill.agents }
        return skill.agents.filter { $0.cliDirectory == selectedDirectory }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(skill.isGlobal ? Color.green.opacity(0.14) : Color.accentColor.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(skill.isGlobal ? .green : .accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(skill.displayName)
                        .font(.callout)
                        .fontWeight(.semibold)
                    if let source = skill.displaySource {
                        Text(source)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text((filteredAgents.isEmpty ? skill.agents : filteredAgents).map(\.displayName).joined(separator: " · ") + " · installed " + (skill.isGlobal ? "globally" : "in project only"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusCapsule(title: skill.isGlobal ? "global" : "project", tint: skill.isGlobal ? .green : .accentColor)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct CLIDashboardInspector: View {
    let cliExecutablePath: String?
    let grantedDirectories: [CLIDirectory]
    let selectedProjectLabel: String
    let hasGeminiAccess: Bool
    let onInstallSkill: () -> Void
    let onGrantAccess: () -> Void
    let onChangeProject: () -> Void
    let onCLISettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                InspectorPanel(title: "Setup Status") {
                    VStack(alignment: .leading, spacing: 10) {
                        SetupStatusRow(
                            title: cliExecutablePath == nil ? "CLI not detected" : "CLI installed",
                            subtitle: cliExecutablePath ?? "Install with brew install prompthub",
                            isDone: cliExecutablePath != nil,
                            chipTitle: cliExecutablePath == nil ? nil : "Detected"
                        )
                        SetupStatusRow(
                            title: "Agent dirs granted",
                            subtitle: grantedDirectories.isEmpty ? "Grant access to .claude, .cursor, .codex and more" : grantedDirectories.map(\.displayName).joined(separator: " · "),
                            isDone: !grantedDirectories.isEmpty,
                            chipTitle: nil
                        )
                        SetupStatusRow(
                            title: "Project selected",
                            subtitle: selectedProjectLabel,
                            isDone: selectedProjectLabel != "No project selected",
                            chipTitle: nil
                        )
                        SetupStatusRow(
                            title: "Gemini CLI",
                            subtitle: hasGeminiAccess ? "Connected" : "Grant ~/.gemini/ access to connect",
                            isDone: hasGeminiAccess,
                            chipTitle: hasGeminiAccess ? nil : "Optional"
                        )
                    }
                }

                InspectorPanel(title: "Quick Actions") {
                    VStack(spacing: 8) {
                        Button(action: onInstallSkill) {
                            Label("Install Skill…", systemImage: "square.stack.3d.up")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: onGrantAccess) {
                            Label("Grant Agent Access", systemImage: "powerplug")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)

                        Button(action: onChangeProject) {
                            Label("Change Project Folder", systemImage: "link")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)

                        Button(action: onCLISettings) {
                            Label("CLI Settings", systemImage: "slider.horizontal.3")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(18)
        }
    }
}

private struct InspectorPanel<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct SetupStatusRow: View {
    let title: String
    let subtitle: String
    let isDone: Bool
    let chipTitle: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isDone ? .green : .secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.callout)
                        .fontWeight(.medium)
                    if let chipTitle {
                        StatusCapsule(title: chipTitle, tint: .secondary)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct CLIHowItWorksCard: View {
    let onCopyCommand: (String) -> Void
    let copiedCommand: String?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "terminal")
                    .foregroundStyle(.accent)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("How Skills Get Into Your AI Agents")
                    .font(.headline)
                Text("PromptHub writes SKILL.md files into each agent's config directory. Next time you open Cursor, Claude Code, or Codex, those skills are already loaded and ready to use.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                CLICommandRow(label: "Install", command: "brew install prompthub", copiedCommand: copiedCommand, onCopy: onCopyCommand)
                CLICommandRow(label: "Add skill", command: "ph skill install owner/repo@commit-writer", copiedCommand: copiedCommand, onCopy: onCopyCommand)
                CLICommandRow(label: "List", command: "ph skill list", copiedCommand: copiedCommand, onCopy: onCopyCommand)
            }
            .frame(minWidth: 290)
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct CLICommandRow: View {
    let label: String
    let command: String
    let copiedCommand: String?
    let onCopy: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)

            Button {
                onCopy(command)
            } label: {
                HStack(spacing: 8) {
                    Text(command)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: copiedCommand == command ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(copiedCommand == command ? .green : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}

extension AgentWorkflow {
    var cliDirectory: CLIDirectory? {
        switch self {
        case .codex:
            return .codex
        case .claudeCode:
            return .claude
        case .cursor:
            return .cursor
        case .geminiCLI:
            return .gemini
        case .iflow:
            return .iflow
        case .opencode:
            return .opencode
        case .qwenCode:
            return .qwen
        case .qoder:
            return .qoder
        }
    }
}

#Preview {
    CLIDashboardView()
        .frame(width: 1180, height: 760)
}
