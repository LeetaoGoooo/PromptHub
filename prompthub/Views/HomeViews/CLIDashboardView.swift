import AppKit
import PromptHubSkillKit
import SwiftUI

struct CLIDashboardView: View {
    @ObservedObject private var cliAccess = CLIDirectoryAccessManager.shared
    private let workspaceService = SkillWorkspaceService.shared

    @State private var selectedDirectory: CLIDirectory?
    @State private var selectedProjectRootURL: URL?
    @State private var showingAccessManager = false
    @State private var showingCLISettingsHint = false
    @State private var agentFilter: CLIAgentFilter = .all
    @State private var sortOrder: CLIAgentSortOrder = .statusThenName

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

    private var selectedProjectLabel: String {
        if let url = selectedProjectRootURL {
            return url.lastPathComponent + "/"
        }
        return "No project selected"
    }

    private var connectedAgentCount: Int {
        grantedDirectories.count
    }

    private var disconnectedAgentCount: Int {
        CLIDirectory.allCases.count - grantedDirectories.count
    }

    private var selectedProjectMenuLabel: String {
        if let url = selectedProjectRootURL {
            return url.lastPathComponent
        }
        return "Active Project"
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
        VStack(spacing: 0) {
            pageHeader
            Divider().opacity(0.6)
            HSplitView {
                agentListPane
                agentDetailPane
                inspectorColumn
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            selectedProjectRootURL = workspaceService.selectedProjectRootURL
            if selectedDirectory == nil {
                selectedDirectory = grantedDirectories.first ?? sortedDirectories.first
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillProjectSelectionDidChange)) { _ in
            selectedProjectRootURL = workspaceService.selectedProjectRootURL
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

    private var pageHeader: some View {
        HStack(spacing: PH.Spacing.toolbarGap) {
            Text("CLI Integrations")
                .font(PH.Font.paneTitle)
                .foregroundStyle(PH.Color.primary)

            Spacer(minLength: 24)

            Menu {
                ForEach(CLIAgentFilter.allCases, id: \.rawValue) { filter in
                    Button(action: { agentFilter = filter }) {
                        if agentFilter == filter {
                            Label(filter.rawValue, systemImage: "checkmark")
                        } else {
                            Text(filter.rawValue)
                        }
                    }
                }
            } label: {
                headerMenuLabel(title: "Filter", value: agentFilter.rawValue)
            }
            .menuStyle(.borderlessButton)

            Menu {
                ForEach(CLIAgentSortOrder.allCases, id: \.rawValue) { option in
                    Button(action: { sortOrder = option }) {
                        if sortOrder == option {
                            Label(option.rawValue, systemImage: "checkmark")
                        } else {
                            Text(option.rawValue)
                        }
                    }
                }
            } label: {
                headerMenuLabel(title: "Sort", value: sortOrder.rawValue)
            }
            .menuStyle(.borderlessButton)

            Menu {
                Button("Choose Project Folder…", action: chooseProjectRoot)
                if selectedProjectRootURL != nil {
                    Divider()
                    Button("Clear Project Folder") {
                        workspaceService.setSelectedProjectRootURL(nil)
                        selectedProjectRootURL = nil
                    }
                }
            } label: {
                headerMenuLabel(title: selectedProjectMenuLabel, value: "")
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, PH.Spacing.toolbarH)
        .padding(.vertical, PH.Spacing.toolbarV)
        .background(PH.Color.sidebarBg)
    }

    private var agentListPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: PH.Spacing.rowItemGap) {
                HeaderMetric(title: "connected", value: "\(connectedAgentCount)", systemImage: "checkmark.circle")
                HeaderMetric(title: "attention", value: "\(disconnectedAgentCount)", systemImage: "exclamationmark.circle")
                Spacer(minLength: 0)
                if cliAccess.anyAccessGranted {
                    StatusCapsule(title: "Active", tint: .green)
                }
            }
            .padding(.horizontal, PH.Spacing.rowH)
            .padding(.vertical, PH.Spacing.toolbarV)
            .background(PH.Color.sidebarBg)
            .overlay(alignment: .bottom) { Divider().opacity(0.6) }

            // Agent rows — scrollable
            ScrollView {
                if filteredDirectories.isEmpty {
                    Text("No agents match the current filter.")
                        .font(PH.Font.rowSub)
                        .foregroundStyle(PH.Color.secondary)
                        .padding(PH.Spacing.detailH)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PH.Color.sidebarBg, in: RoundedRectangle(cornerRadius: PH.Spacing.rowCorner))
                        .padding(.horizontal, PH.Spacing.rowH)
                        .padding(.top, PH.Spacing.rowV)
                } else {
                    VStack(spacing: 2) {
                        ForEach(filteredDirectories) { directory in
                            CLIAgentListRow(
                                directory: directory,
                                isGranted: cliAccess.hasAccess(to: directory),
                                isSelected: selectedDirectory == directory,
                                onTap: { selectedDirectory = directory }
                            )
                        }
                    }
                    .padding(.vertical, PH.Spacing.rowV)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(minWidth: 220, idealWidth: 260, maxWidth: 320, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Detail pane (middle)

    private var agentDetailPane: some View {
        ScrollView {
            if let selectedDirectory {
                CLIAgentDetailContent(
                    directory: selectedDirectory,
                    isGranted: cliAccess.hasAccess(to: selectedDirectory),
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
                    CLIHowItWorksCard(availableWidth: 560)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(PH.Spacing.detailH)
            }
        }
        .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        .background(PH.Color.detailBg)
    }

    @ViewBuilder
    private var inspectorColumn: some View {
        CLIDashboardInspector(
            cliExecutablePath: cliExecutablePath,
            selectedDirectory: selectedDirectory,
            selectedDirectoryHasAccess: selectedDirectory.map { cliAccess.hasAccess(to: $0) } ?? false,
            grantedDirectories: grantedDirectories,
            selectedProjectLabel: selectedProjectLabel,
            onGrantAccess: { showingAccessManager = true },
            onChangeProject: chooseProjectRoot,
            onCLISettings: { showingCLISettingsHint = true }
        )
        .frame(minWidth: 220, idealWidth: 240, maxWidth: 280, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var filteredDirectories: [CLIDirectory] {
        let base: [CLIDirectory] = switch agentFilter {
        case .all:       sortedDirectories
        case .connected: sortedDirectories.filter { cliAccess.hasAccess(to: $0) }
        case .attention: sortedDirectories.filter { !cliAccess.hasAccess(to: $0) }
        }

        switch sortOrder {
        case .statusThenName:
            return base.sorted { lhs, rhs in
                let lhsGranted = cliAccess.hasAccess(to: lhs)
                let rhsGranted = cliAccess.hasAccess(to: rhs)
                if lhsGranted != rhsGranted {
                    return lhsGranted && !rhsGranted
                }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        case .nameAsc:
            return base.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        case .nameDesc:
            return base.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedDescending
            }
        }
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
        selectedProjectRootURL = selectedURL
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

private enum CLIAgentSortOrder: String, CaseIterable {
    case statusThenName = "Status First"
    case nameAsc        = "Name A–Z"
    case nameDesc       = "Name Z–A"
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
    let isSelected: Bool
    let onTap: () -> Void

    private var statusDot: Color { isGranted ? PH.Color.statusOK : PH.Color.secondary }
    private var subText: String {
        isGranted ? "Connected · ~/\(directory.rawValue)/" : "Not connected · Grant folder access"
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
                    Text(isGranted ? "Connected" : "Disconnected")
                        .font(PH.Font.statusLabel)
                        .foregroundStyle(isGranted ? PH.Color.statusOK : PH.Color.secondary)
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
    let selectedProjectLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(directory.displayName)
                        .font(PH.Font.paneTitle)
                        .foregroundStyle(PH.Color.primary)
                    Spacer(minLength: 0)
                    StatusCapsule(
                        title: isGranted ? "Connected" : "Disconnected",
                        tint: isGranted ? .green : .secondary
                    )
                }
                Text("~/\(directory.rawValue)/")
                    .font(PH.Font.mono)
                    .foregroundStyle(PH.Color.secondary)
            }

            Divider().opacity(0.6)

            if !isGranted {
                VStack(alignment: .leading, spacing: 12) {
                    PHSectionHead(systemImage: "powerplug.fill", label: "Not Connected")
                    Label("Grant folder access to install skills into this agent.", systemImage: "lock.open")
                        .font(PH.Font.rowSub)
                        .foregroundStyle(PH.Color.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: PH.Spacing.sectionHeadMB) {
                    PHSectionHead(systemImage: "folder.badge.gearshape", label: "Project Folder")
                    Text(selectedProjectLabel == "No project selected" ? "No project selected" : selectedProjectLabel)
                        .font(PH.Font.rowName)
                        .foregroundStyle(PH.Color.primary)
                    Text("Project-scoped skill install management lives in Skills > Installed.")
                        .font(PH.Font.rowSub)
                        .foregroundStyle(PH.Color.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private extension CLIDashboardView {
    @ViewBuilder
    func headerMenuLabel(title: String, value: String) -> some View {
        if value.isEmpty {
            Text(title + " ⌄")
                .font(.system(.body, design: .default))
                .foregroundStyle(PH.Color.primary)
        } else {
            Text("\(title): \(value) ⌄")
                .font(.system(.body, design: .default))
                .foregroundStyle(PH.Color.primary)
        }
    }
}

private struct CLIDashboardInspector: View {
    let cliExecutablePath: String?
    let selectedDirectory: CLIDirectory?
    let selectedDirectoryHasAccess: Bool
    let grantedDirectories: [CLIDirectory]
    let selectedProjectLabel: String
    let onGrantAccess: () -> Void
    let onChangeProject: () -> Void
    let onCLISettings: () -> Void

    private var selectedConnectionTitle: String {
        selectedDirectory?.displayName ?? "No agent selected"
    }

    private var selectedConnectionSubtitle: String {
        guard let selectedDirectory else {
            return "Choose an agent from the list to inspect its connection state"
        }

        if selectedDirectoryHasAccess {
            return "Connected"
        }

        return "Grant ~\(selectedDirectory.rawValue)/ access to connect"
    }

    private var cliInstallHint: String {
        cliExecutablePath ?? "Install: brew install leetaogoooo/prompthub/ph (or --HEAD on Intel)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Connection section
                VStack(alignment: .leading, spacing: PH.Spacing.sectionHeadMB) {
                    PHSectionHead(systemImage: "powerplug", label: "Connection")
                    SetupStatusRow(
                        title: cliExecutablePath == nil ? "PromptHub CLI not detected" : "PromptHub CLI detected",
                        subtitle: cliInstallHint,
                        isDone: cliExecutablePath != nil,
                        chipTitle: cliExecutablePath == nil ? nil : "Detected"
                    )
                    SetupStatusRow(
                        title: selectedConnectionTitle,
                        subtitle: selectedConnectionSubtitle,
                        isDone: selectedDirectoryHasAccess,
                        chipTitle: nil
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
            Text("PromptHub CLI")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Install `ph` via Homebrew: `brew tap leetaogoooo/prompthub https://github.com/LeetaoGoooo/PromptHub.git && brew install leetaogoooo/prompthub/ph` (Apple Silicon). Intel users can run `brew install --HEAD leetaogoooo/prompthub/ph` to build from source. The `ph` binary reads the same `~/.prompthub/` exports this dashboard writes, so prompt and skill state stays in sync. Use the app to author and edit; use `ph` to script, automate, and install agent skills from CI. Run `ph doctor` if anything looks wrong on the CLI side.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
