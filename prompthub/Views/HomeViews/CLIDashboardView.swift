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
    @State private var showingCLISettingsHint = false
    @State private var copiedCommand: String?
    @State private var agentFilter: CLIAgentFilter = .all

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
            agentListPane
            agentDetailPane
            inspectorColumn
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
        .alert("CLI Settings", isPresented: $showingCLISettingsHint) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Manage CLI directories from Grant Agent Access, and select the active project folder here in the dashboard.")
        }
    }

    // MARK: - List pane (left)

    private var agentListPane: some View {
        VStack(spacing: 0) {
            // Compact header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .foregroundStyle(PH.Color.accent)
                        .font(.system(size: 14, weight: .medium))
                    Text("CLI Agents")
                        .font(PH.Font.paneTitle)
                        .foregroundStyle(PH.Color.primary)
                    if cliAccess.anyAccessGranted {
                        StatusCapsule(title: "Active", tint: .green)
                    }
                }
                HStack(spacing: PH.Spacing.rowItemGap) {
                    HeaderMetric(title: "agents", value: "\(grantedDirectories.count)", systemImage: "cube")
                    HeaderMetric(title: "skills", value: "\(totalInstalledCount)", systemImage: "wand.and.stars")
                }
                .font(.caption)
            }
            .padding(.horizontal, PH.Spacing.rowH)
            .padding(.top, PH.Spacing.toolbarV + 4)
            .padding(.bottom, PH.Spacing.toolbarV)

            Divider().opacity(0.5)

            connectedAgentsSection
        }
        .frame(minWidth: 260, idealWidth: 280, maxWidth: 340, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Detail pane (middle)

    private var agentDetailPane: some View {
        ScrollView {
            if let selectedDirectory {
                CLIAgentDetailContent(
                    directory: selectedDirectory,
                    isGranted: cliAccess.hasAccess(to: selectedDirectory),
                    projectSkills: skills(for: selectedDirectory).filter { !$0.isGlobal },
                    globalSkills: skills(for: selectedDirectory).filter { $0.isGlobal },
                    selectedProjectLabel: selectedProjectLabel
                )
                .padding(PH.Spacing.detailH)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "terminal")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(PH.Color.secondary)
                    Text("Select an agent to inspect")
                        .font(PH.Font.rowName)
                        .foregroundStyle(PH.Color.secondary)
                    CLIHowItWorksCard(onCopyCommand: copyCommand(_:), copiedCommand: copiedCommand, availableWidth: 560)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(PH.Spacing.detailH)
            }
        }
        .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        .background(PH.Color.detailBg)
    }

    @ViewBuilder
    private var inspectorColumn: some View {
        CLIDashboardInspector(
            cliExecutablePath: cliExecutablePath,
            grantedDirectories: grantedDirectories,
            selectedProjectLabel: selectedProjectLabel,
            hasGeminiAccess: cliAccess.hasAccess(to: .gemini),
            onGrantAccess: { showingAccessManager = true },
            onChangeProject: chooseProjectRoot,
            onCLISettings: { showingCLISettingsHint = true }
        )
        .frame(minWidth: 240, idealWidth: 260, maxWidth: 300, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var filteredDirectories: [CLIDirectory] {
        switch agentFilter {
        case .all:       return sortedDirectories
        case .connected: return sortedDirectories.filter { cliAccess.hasAccess(to: $0) }
        case .attention: return sortedDirectories.filter { !cliAccess.hasAccess(to: $0) || skills(for: $0).isEmpty }
        }
    }

    private var connectedAgentsSection: some View {
        VStack(alignment: .leading, spacing: PH.Spacing.sectionHeadGap) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PH.Spacing.toolbarGap) {
                    ForEach(CLIAgentFilter.allCases, id: \.rawValue) { filter in
                        PHFilterChip(label: filter.rawValue, isActive: agentFilter == filter) {
                            agentFilter = filter
                        }
                    }
                }
                .padding(.vertical, PH.Spacing.toolbarV)
            }

            // 2-line agent rows
            if filteredDirectories.isEmpty {
                Text("No agents match the current filter.")
                    .font(PH.Font.rowSub)
                    .foregroundStyle(PH.Color.secondary)
                    .padding(PH.Spacing.detailH)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PH.Color.sidebarBg, in: RoundedRectangle(cornerRadius: PH.Spacing.rowCorner))
            } else {
                VStack(spacing: 2) {
                    ForEach(filteredDirectories) { directory in
                        CLIAgentListRow(
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

private enum CLIAgentFilter: String, CaseIterable {
    case all       = "All"
    case connected = "Connected"
    case attention = "Attention"
}

private struct CLIAgentListRow: View {
    let directory: CLIDirectory
    let isGranted: Bool
    let skills: [InstalledSkillSnapshot]
    let isSelected: Bool
    let onTap: () -> Void

    private var statusDot: Color { isGranted && !skills.isEmpty ? PH.Color.statusOK : (isGranted ? PH.Color.statusWarn : PH.Color.secondary) }
    private var subText: String {
        if !isGranted { return "Not connected · Grant folder access" }
        if skills.isEmpty { return "Connected · No skills installed" }
        let names = skills.prefix(3).map(\.displayName).joined(separator: ", ")
        let extra = skills.count > 3 ? " +\(skills.count - 3)" : ""
        return "\(skills.count) skill\(skills.count == 1 ? "" : "s") · \(names)\(extra)"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: PH.Spacing.rowGap) {
                // Line 1: name + status chip
                HStack(spacing: 0) {
                    Text(directory.displayName)
                        .font(PH.Font.rowName)
                        .foregroundStyle(PH.Color.primary)
                    Spacer(minLength: 0)
                    Text(isGranted ? (skills.isEmpty ? "Idle" : "Active") : "Disconnected")
                        .font(PH.Font.statusLabel)
                        .foregroundStyle(isGranted ? (skills.isEmpty ? PH.Color.statusWarn : PH.Color.statusOK) : PH.Color.secondary)
                }
                // Line 2: dot + sub-text
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusDot)
                        .frame(width: PH.Layout.statusDotSize, height: PH.Layout.statusDotSize)
                    Text(subText)
                        .font(PH.Font.rowSub)
                        .foregroundStyle(PH.Color.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, PH.Spacing.rowH)
            .padding(.vertical, PH.Spacing.rowV)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? PH.Color.accentTint : .clear)
            .clipShape(RoundedRectangle(cornerRadius: PH.Spacing.rowCorner))
            .contentShape(RoundedRectangle(cornerRadius: PH.Spacing.rowCorner))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(directory.displayName)
        .accessibilityValue(subText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Agent detail content (middle pane)

private struct CLIAgentDetailContent: View {
    let directory: CLIDirectory
    let isGranted: Bool
    let projectSkills: [InstalledSkillSnapshot]
    let globalSkills: [InstalledSkillSnapshot]
    let selectedProjectLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title + status
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(directory.displayName)
                        .font(PH.Font.paneTitle)
                        .foregroundStyle(PH.Color.primary)
                    Spacer(minLength: 0)
                    StatusCapsule(
                        title: isGranted ? (projectSkills.isEmpty && globalSkills.isEmpty ? "Idle" : "Active") : "Disconnected",
                        tint: isGranted ? (projectSkills.isEmpty && globalSkills.isEmpty ? .orange : .green) : .secondary
                    )
                }
                Text("~/\(directory.rawValue)/")
                    .font(PH.Font.mono)
                    .foregroundStyle(PH.Color.secondary)
            }

            Divider().opacity(0.6)

            if !isGranted {
                // Not connected state
                VStack(alignment: .leading, spacing: 12) {
                    PHSectionHead(systemImage: "powerplug.fill", label: "Not Connected")
                    Label("Grant folder access to install skills into this agent.", systemImage: "lock.open")
                        .font(PH.Font.rowSub)
                        .foregroundStyle(PH.Color.secondary)
                }
            } else {
                // Global skills section
                VStack(alignment: .leading, spacing: PH.Spacing.sectionHeadMB) {
                    PHSectionHead(systemImage: "globe", label: "Global Skills")
                    if globalSkills.isEmpty {
                        Text("No global skills installed.")
                            .font(PH.Font.rowSub)
                            .foregroundStyle(PH.Color.secondary)
                            .padding(PH.Spacing.rowH)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PH.Color.sidebarBg, in: RoundedRectangle(cornerRadius: PH.Spacing.rowCorner))
                    } else {
                        VStack(spacing: 2) {
                            ForEach(globalSkills) { skill in
                                CLISkillActivityRow(skill: skill, selectedDirectory: directory)
                            }
                        }
                    }
                }

                Divider().opacity(0.6)

                // Project skills section
                VStack(alignment: .leading, spacing: PH.Spacing.sectionHeadMB) {
                    HStack {
                        PHSectionHead(systemImage: "folder", label: "Project Skills")
                        Spacer(minLength: 0)
                        Text(selectedProjectLabel)
                            .font(PH.Font.mono)
                            .foregroundStyle(PH.Color.secondary)
                    }
                    if projectSkills.isEmpty {
                        Text("No project-scoped skills installed.")
                            .font(PH.Font.rowSub)
                            .foregroundStyle(PH.Color.secondary)
                            .padding(PH.Spacing.rowH)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PH.Color.sidebarBg, in: RoundedRectangle(cornerRadius: PH.Spacing.rowCorner))
                    } else {
                        VStack(spacing: 2) {
                            ForEach(projectSkills) { skill in
                                CLISkillActivityRow(skill: skill, selectedDirectory: directory)
                            }
                        }
                    }
                }

            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
    let onGrantAccess: () -> Void
    let onChangeProject: () -> Void
    let onCLISettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Connection section
                VStack(alignment: .leading, spacing: PH.Spacing.sectionHeadMB) {
                    PHSectionHead(systemImage: "powerplug", label: "Connection")
                    SetupStatusRow(
                        title: cliExecutablePath == nil ? "CLI not detected" : "CLI installed",
                        subtitle: cliExecutablePath ?? "Install with brew install prompthub",
                        isDone: cliExecutablePath != nil,
                        chipTitle: cliExecutablePath == nil ? nil : "Detected"
                    )
                    SetupStatusRow(
                        title: "Gemini CLI",
                        subtitle: hasGeminiAccess ? "Connected" : "Grant ~/.gemini/ access to connect",
                        isDone: hasGeminiAccess,
                        chipTitle: hasGeminiAccess ? nil : "Optional"
                    )
                }

                Divider().opacity(0.6)

                // Paths section
                VStack(alignment: .leading, spacing: PH.Spacing.sectionHeadMB) {
                    PHSectionHead(systemImage: "folder.badge.gear", label: "Paths")
                    SetupStatusRow(
                        title: "Agent directories",
                        subtitle: grantedDirectories.isEmpty ? "Grant access to .claude, .cursor, .codex and more" : grantedDirectories.map(\.displayName).joined(separator: " · "),
                        isDone: !grantedDirectories.isEmpty,
                        chipTitle: nil
                    )
                    SetupStatusRow(
                        title: "Project folder",
                        subtitle: selectedProjectLabel,
                        isDone: selectedProjectLabel != "No project selected",
                        chipTitle: nil
                    )
                }

                Divider().opacity(0.6)

                // Status section
                VStack(alignment: .leading, spacing: PH.Spacing.sectionHeadMB) {
                    PHSectionHead(systemImage: "checkmark.shield", label: "Status")
                    HStack(spacing: PH.Spacing.rowItemGap) {
                        Circle()
                            .fill(cliExecutablePath != nil ? PH.Color.statusOK : PH.Color.statusWarn)
                            .frame(width: PH.Layout.statusDotSize, height: PH.Layout.statusDotSize)
                        Text(cliExecutablePath != nil ? (grantedDirectories.isEmpty ? "CLI ready — no agents connected" : "Fully operational") : "Setup required")
                            .font(PH.Font.rowSub)
                            .foregroundStyle(PH.Color.secondary)
                    }
                }

                Divider().opacity(0.6)

                // Actions section
                VStack(alignment: .leading, spacing: PH.Spacing.sectionHeadMB) {
                    PHSectionHead(systemImage: "bolt", label: "Actions")
                    VStack(spacing: 6) {
                        Button(action: onGrantAccess) {
                            Label("Grant Agent Access", systemImage: "powerplug")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderedProminent)

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
            .padding(PH.Spacing.detailH)
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
    let availableWidth: CGFloat

    private var usesVerticalLayout: Bool {
        availableWidth < 860
    }

    var body: some View {
        Group {
            if usesVerticalLayout {
                VStack(alignment: .leading, spacing: 16) {
                    introBlock
                    commandBlock
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    introBlock
                    Spacer(minLength: 0)
                    commandBlock
                }
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var introBlock: some View {
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
        }
    }

    private var commandBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            CLICommandRow(label: "Install", command: "brew install prompthub", copiedCommand: copiedCommand, onCopy: onCopyCommand)
            CLICommandRow(label: "Add skill", command: "ph skill install owner/repo@commit-writer", copiedCommand: copiedCommand, onCopy: onCopyCommand)
            CLICommandRow(label: "List", command: "ph skill list", copiedCommand: copiedCommand, onCopy: onCopyCommand)
        }
        .frame(maxWidth: usesVerticalLayout ? .infinity : 320, alignment: .leading)
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
