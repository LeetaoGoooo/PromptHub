import AppKit
import PromptHubSkillKit
import SwiftUI

struct InstalledSkillDetailPane: View {
    let skill: InstalledSkillSnapshot
    let installedMarkdown: String
    let isLoadingMarkdown: Bool
    let linkedDraft: Skill?
    let agentVisibility: [SkillAgentVisibility]
    let isLoadingVisibility: Bool
    let sourceIntegrity: SkillSourceIntegrity?
    let isLoadingIntegrity: Bool
    let structuralQuality: SkillStructuralQualityReport?
    let isLoadingStructuralQuality: Bool
    let isAdding: Bool
    let isRemoving: Bool
    let hasUpdate: Bool
    let onEditDraft: () -> Void
    let onAddAgents: ([AgentWorkflow]) -> Void
    let onRemoveAll: () -> Void
    let onRemoveAgent: (AgentWorkflow) -> Void
    let onOpenSourcePage: () -> Void

    @ObservedObject private var privateSourceStore = PrivateSkillSourceStore.shared
    @State private var showingUpdateDiff = false
    @State private var isShowingInspectorDrawer = false
    @State private var isPropertiesExpanded = true
    @State private var isHealthExpanded = true
    @State private var isAgentVisibilityExpanded = false
    @State private var isSourcesExpanded = false
    @State private var isFilesExpanded = true

    private var addableAgents: [AgentWorkflow] {
        AgentWorkflow.defaultTargets.filter { !skill.agents.contains($0) }
    }

    private var supportsAddTargets: Bool { !addableAgents.isEmpty }

    private var summaryText: String {
        skill.summary.isEmpty ? "No summary was recorded for this installed skill." : skill.summary
    }

    private var integritySummary: String {
        guard let sourceIntegrity else {
            return isLoadingIntegrity ? "Checking source…" : "Not available"
        }

        switch sourceIntegrity.status {
        case .verified:
            return "Verified"
        case .modified:
            return "Modified locally"
        case .remoteUnavailable:
            return "Remote unavailable"
        case .noRemoteSource:
            return "Local only"
        case .notInstalled:
            return "File missing"
        }
    }

    private var qualitySummary: String {
        guard let structuralQuality else {
            return isLoadingStructuralQuality ? "Analyzing…" : "Not available"
        }

        guard structuralQuality.fileFound else {
            return "SKILL.md missing"
        }

        return "\(Int(structuralQuality.score * 100)) · \(structuralQuality.tier.label)"
    }

    private var coverageSummary: String {
        if skill.agents.isEmpty {
            return "No connected CLIs"
        }

        return skill.agents.map(\.displayName).joined(separator: ", ")
    }

    private var projectSummary: String {
        if skill.isGlobal {
            return "Global only"
        }

        if skill.projectDisplayNames.count == 1, let project = skill.projectDisplayNames.first {
            return project
        }

        if skill.projectDisplayNames.count > 1 {
            return skill.projectDisplayNames.joined(separator: ", ")
        }

        return "Current project"
    }

    private var linkedDraftSummary: String {
        linkedDraft?.displayName ?? "No draft linked"
    }

    private var visibilitySummary: String {
        if skill.agents.isEmpty {
            return "No CLIs configured"
        }

        if isLoadingVisibility {
            return "Checking CLI visibility…"
        }

        if visibleAgentCount == 0 && missingAgentCount == 0 {
            return "Visibility not scanned yet"
        }

        if missingAgentCount == 0 {
            return "\(visibleAgentCount) visible"
        }

        if visibleAgentCount == 0 {
            return "\(missingAgentCount) missing"
        }

        return "\(visibleAgentCount) visible · \(missingAgentCount) missing"
    }

    private var visibleAgentCount: Int {
        agentVisibility.filter { $0.status == .visible }.count
    }

    private var missingAgentCount: Int {
        agentVisibility.filter { $0.status == .missing }.count
    }

    private var sourceRows: [(String, String)] {
        var rows: [(String, String)] = [
            ("Scope", skill.isGlobal ? "Global" : "Project"),
            ("Status", integritySummary),
            ("Identifier", skill.package.rawValue)
        ]

        if let healthSummary {
            rows.insert(("Health", healthSummary), at: 0)
        }

        if let localHash = sourceIntegrity?.localHash {
            rows.append(("SHA-256", String(localHash.prefix(16)) + "…"))
        }

        return rows
    }

    private var passedChecksCount: Int {
        structuralQuality?.checks.filter(\.passed).count ?? 0
    }

    private var totalChecksCount: Int {
        structuralQuality?.checks.count ?? 0
    }

    private var topStatusText: String {
        let scopeSummary: String
        if skill.isGlobal {
            scopeSummary = "installed globally"
        } else if skill.projectDisplayNames.count > 1 {
            scopeSummary = "installed across \(skill.projectDisplayNames.count) saved projects"
        } else {
            scopeSummary = "installed for this project"
        }

        return "\(scopeSummary.capitalized) · \(skill.isManagedByPromptHub ? "PromptHub managed" : "external install")"
    }

    private var headerMetrics: [SkillLibraryMetric] {
        var metrics: [SkillLibraryMetric] = [
            SkillLibraryMetric(value: skill.isGlobal ? "Global" : "Project", title: "Scope", systemImage: "shippingbox"),
            SkillLibraryMetric(value: coverageSummary, title: "Targets", systemImage: "person.2")
        ]
        if let healthSummary {
            metrics.append(SkillLibraryMetric(value: healthSummary, title: "Health", systemImage: "exclamationmark.triangle"))
        }
        return metrics
    }

    private var qualityBadgeText: String {
        guard let structuralQuality, structuralQuality.fileFound else {
            return isLoadingStructuralQuality ? "Analyzing quality…" : "Quality unavailable"
        }

        return "\(Int(structuralQuality.score * 100)) \(structuralQuality.tier.label) · \(passedChecksCount)/\(totalChecksCount) checks"
    }

    private var healthSummary: String? {
        guard !isLoadingStructuralQuality else { return "Analyzing" }
        guard let structuralQuality else { return nil }
        guard structuralQuality.fileFound else { return "SKILL.md missing" }
        if failedChecksCount == 0 {
            return nil
        }
        return "\(failedChecksCount) issue\(failedChecksCount == 1 ? "" : "s")"
    }

    private var footerStatusText: String {
        let scopeText = skill.isGlobal ? "Global scope" : "Project scope"
        if linkedDraft != nil {
            return "\(scopeText) · Draft linked"
        }
        return "\(scopeText) · No linked draft"
    }

    private var qualityChecks: [SkillStructuralQualityCheck] {
        structuralQuality?.checks ?? []
    }

    private var installedPackagePaths: [String] {
        let paths = skill.installedPaths.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !paths.isEmpty {
            return Array(Set(paths)).sorted()
        }

        if let localSkillFilePath {
            return [URL(fileURLWithPath: localSkillFilePath).deletingLastPathComponent().path]
        }

        return []
    }

    private var localSkillFilePath: String? {
        sourceIntegrity?.localPath
    }

    private var editDraftButtonTitle: String {
        linkedDraft == nil ? "Create Editable Draft" : "Edit Draft"
    }

    private var failedChecksCount: Int {
        max(totalChecksCount - passedChecksCount, 0)
    }

    private var groupedInstallLocations: [InstallLocationGroup] {
        var groups: [InstallLocationGroup] = []
        let uniquePaths = Array(Set(installedPackagePaths)).sorted()
        if !uniquePaths.isEmpty {
            groups.append(
                InstallLocationGroup(
                    title: skill.isGlobal ? "Global Directories" : "Project Directories",
                    rows: uniquePaths.map { path in
                        InstallLocationRow(
                            label: labelForInstallPath(path),
                            path: path,
                            exists: FileManager.default.fileExists(atPath: path)
                        )
                    }
                )
            )
        }

        if let localSkillFilePath {
            groups.append(
                InstallLocationGroup(
                    title: "Installed Files",
                    rows: [
                        InstallLocationRow(
                            label: "Active SKILL.md",
                            path: localSkillFilePath,
                            exists: FileManager.default.fileExists(atPath: localSkillFilePath)
                        )
                    ]
                )
            )
        }

        if let source = resolvedPrivateSource {
            groups.append(
                InstallLocationGroup(
                    title: "Resolved Source",
                    rows: [
                        InstallLocationRow(
                            label: source.label,
                            path: source.location,
                            exists: FileManager.default.fileExists(atPath: source.location) || source.type == .githubPrivate
                        )
                    ]
                )
            )
        } else if let displaySource = skill.displaySource {
            groups.append(
                InstallLocationGroup(
                    title: "Resolved Source",
                    rows: [
                        InstallLocationRow(label: "Remote Source", path: displaySource, exists: true)
                    ]
                )
            )
        }

        return groups
    }

    private var fileTreeRoot: SkillFileNode? {
        let visibilityPaths = agentVisibility.compactMap { item in
            item.checkedPath.map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }
        }
        let localPaths = localSkillFilePath.map {
            [URL(fileURLWithPath: $0).deletingLastPathComponent().path]
        } ?? []
        let sourcePaths = resolvedPrivateSource
            .flatMap { source -> [String]? in
                guard source.type != .githubPrivate else { return nil }
                return [source.location]
            } ?? []
        let rootPaths = Array(
            Set(installedPackagePaths + visibilityPaths + localPaths + sourcePaths)
        ).sorted()
        let existingRoots = rootPaths.filter { FileManager.default.fileExists(atPath: $0) }
        let chosenRoot = localPaths.first
            ?? existingRoots.min(by: { $0.count < $1.count })
            ?? rootPaths.first
        guard let chosenRoot else { return nil }
        return buildFileNode(for: URL(fileURLWithPath: chosenRoot, isDirectory: true))
    }

    private var resolvedPrivateSource: PrivateSkillSource? {
        if let displaySource = skill.displaySource {
            return privateSourceStore.sources.first(where: { $0.location.caseInsensitiveCompare(displaySource) == .orderedSame })
        }
        if let localSkillFilePath {
            return privateSourceStore.sources.first { localSkillFilePath.hasPrefix($0.location) }
        }
        return nil
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                mainPreviewPane
                if isShowingInspectorDrawer {
                    inspectorDrawer(maxHeight: proxy.size.height - 40)
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(1)
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isShowingInspectorDrawer)
        .sheet(isPresented: $showingUpdateDiff) {
            SkillUpdateDiffSheet(skill: skill) { showingUpdateDiff = false }
        }
    }

    private var mainPreviewPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SkillDetailHeader(
                    timestamp: sourceIntegrity?.checkedAt.formatted(date: .omitted, time: .shortened) ?? "Last updated locally",
                    title: skill.displayName,
                    summary: summaryText,
                    metrics: headerMetrics
                ) {
                    headerActions
                }

                if isLoadingMarkdown {
                    ProgressView("Loading SKILL.md…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    SkillPreviewMarkdownView(
                        markdown: installedMarkdown,
                        fallbackText: summaryText
                    )
                }

                footerSection
            }
            .padding(PH.Spacing.promptInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PH.Color.detailBg)
    }

    private func inspectorDrawer(maxHeight: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Text("Inspector")
                        .font(PH.Font.sectionHead)
                        .foregroundStyle(PH.Color.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                    Spacer(minLength: 0)
                    Button {
                        isShowingInspectorDrawer = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PH.Color.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Hide inspector")
                }

                drawerSection("Skill Info", isExpanded: $isPropertiesExpanded) {
                    SkillLibraryMetadataBlock(title: "", rows: sourceRows)
                }

                drawerSection("Active Agents", isExpanded: $isAgentVisibilityExpanded) {
                    agentVisibilityIcons
                }

                drawerSection("Health", isExpanded: $isHealthExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(qualityChecks.sorted { $0.passed == $1.passed ? $0.title < $1.title : !$0.passed && $1.passed }.enumerated()), id: \.offset) { index, check in
                            qualityCheckRow(check)
                            if index < qualityChecks.count - 1 {
                                Divider()
                            }
                        }
                    }
                }

                drawerSection("Sources & Paths", isExpanded: $isSourcesExpanded) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(groupedInstallLocations) { group in
                            installLocationGroup(group)
                        }
                    }
                }

                drawerSection("File Manager", isExpanded: $isFilesExpanded) {
                    if let fileTreeRoot {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .foregroundStyle(PH.Color.accent)
                                Text(fileTreeRoot.name)
                                    .font(PH.Font.rowSub)
                                    .foregroundStyle(PH.Color.secondary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: fileTreeRoot.path)])
                                } label: {
                                    Image(systemName: "arrow.up.forward.square")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(PH.Color.tertiary)
                                }
                                .buttonStyle(.plain)
                                .help("Reveal root in Finder")
                            }

                            if let localSkillFilePath {
                                SkillFileTreeNodeView(
                                    node: SkillFileNode(
                                        name: URL(fileURLWithPath: localSkillFilePath).lastPathComponent,
                                        path: localSkillFilePath,
                                        isDirectory: false,
                                        children: nil
                                    ),
                                    depth: 0
                                )
                            }

                            if let children = fileTreeRoot.children, !children.isEmpty {
                                ForEach(children.filter { $0.path != localSkillFilePath }) { child in
                                    SkillFileTreeNodeView(node: child, depth: 0)
                                }
                            }
                        }
                    } else {
                        Text("No files resolved.")
                            .font(PH.Font.rowSub)
                            .foregroundStyle(PH.Color.secondary)
                    }
                }
            }
            .padding(20)
        }
        .frame(width: 320, alignment: .topLeading)
        .frame(maxHeight: maxHeight, alignment: .top)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PH.Color.strokeSoft, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
    }

    private var qualityPillColor: Color {
        guard let structuralQuality, structuralQuality.fileFound else {
            return .secondary
        }

        switch structuralQuality.tier {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .fair:
            return .orange
        case .poor:
            return .red
        }
    }

    private var updateSummaryText: String {
        guard skill.package.remoteInstallDescriptor != nil else {
            return "Not available for local-only skills"
        }

        return hasUpdate ? "Update available" : "No pending update detected"
    }

    private var footerSection: some View {
        Text(footerStatusText)
            .font(PH.Font.rowSub)
            .foregroundStyle(PH.Color.tertiary)
    }

    private func revealInstalledFiles() {
        let packageURLs = installedPackagePaths.map { URL(fileURLWithPath: $0, isDirectory: true) }
        if !packageURLs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(packageURLs)
            return
        }

        guard let localSkillFilePath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: localSkillFilePath)])
    }

    private func drawerSection<Content: View>(_ title: String, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
            VStack(alignment: .leading, spacing: 10) {
                DisclosureGroup(isExpanded: isExpanded) {
                    content()
                        .padding(.top, 8)
                } label: {
                Text(title)
                    .font(PH.Font.sectionHead)
                    .foregroundStyle(PH.Color.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
        }
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            if let firstFail = qualityChecks.first(where: { !$0.passed }) {
                Button {
                    isShowingInspectorDrawer = true
                    isHealthExpanded = true
                } label: {
                    iconChromeButton("exclamationmark.triangle")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help(firstFail.hint ?? firstFail.rationale)
            }

            Button(action: onEditDraft) {
                iconChromeButton("square.and.pencil")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help(editDraftButtonTitle)

            if !installedPackagePaths.isEmpty || localSkillFilePath != nil {
                Button(action: revealInstalledFiles) {
                    iconChromeButton("folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Reveal in Finder")
            }

            Menu {
                if skill.package.remoteInstallDescriptor != nil {
                    Button {
                        showingUpdateDiff = true
                    } label: {
                        Label("Review Update", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                if skill.url != nil {
                    Button(action: onOpenSourcePage) {
                        Label("Open Source Page", systemImage: "globe")
                    }
                }
                if supportsAddTargets {
                    if addableAgents.count > 1 {
                        Button {
                            onAddAgents(addableAgents)
                        } label: {
                            Label("Add All Missing CLIs", systemImage: "plus.circle")
                        }
                    }
                    ForEach(addableAgents, id: \.rawValue) { agent in
                        Button {
                            onAddAgents([agent])
                        } label: {
                            Label("Add to \(agent.displayName)", systemImage: "plus.circle")
                        }
                    }
                }
                if !skill.agents.isEmpty {
                    Divider()
                    ForEach(skill.agents, id: \.rawValue) { agent in
                        Button(role: .destructive) {
                            onRemoveAgent(agent)
                        } label: {
                            Label("Remove from \(agent.displayName)", systemImage: "minus.circle")
                        }
                    }
                }
                Divider()
                Button(role: .destructive, action: onRemoveAll) {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                iconChromeButton("ellipsis")
            }
            .menuStyle(.button)
            .help("More actions")

            Button {
                isShowingInspectorDrawer.toggle()
            } label: {
                iconChromeButton("sidebar.right")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help(isShowingInspectorDrawer ? "Hide inspector" : "Show inspector")
        }
    }

    private func iconChromeButton(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .medium))
            .frame(width: 16, height: 16)
    }
}

private extension InstalledSkillDetailPane {
    struct InstallLocationGroup: Identifiable {
        let id = UUID()
        let title: String
        let rows: [InstallLocationRow]
    }

    struct InstallLocationRow: Identifiable {
        let id = UUID()
        let label: String
        let path: String
        let exists: Bool
    }

    struct SkillFileNode: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let isDirectory: Bool
        let children: [SkillFileNode]?
    }

    var agentSummaryIcons: some View {
        Group {
            if !skill.agents.isEmpty {
                HStack(spacing: 8) {
                    ForEach(skill.agents, id: \.rawValue) { agent in
                        agent.iconImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundStyle(PH.Color.primary)
                            .padding(4)
                            .help(agent.displayName)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    var agentVisibilityIcons: some View {
        HStack(spacing: 10) {
            ForEach(agentVisibility, id: \.agent.rawValue) { item in
                item.agent.iconImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(PH.Color.primary)
                    .opacity(item.status == .visible ? 1 : 0.35)
                    .padding(4)
                    .help("\(item.agent.displayName): \(agentVisibilityLabel(item.status))")
            }
        }
    }

    @ViewBuilder
    func qualityCheckRow(_ check: SkillStructuralQualityCheck) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(check.passed ? PH.Color.statusOK : PH.Color.statusFail)
                .font(.caption)

            VStack(alignment: .leading, spacing: 3) {
                Text(check.title)
                    .font(PH.Font.kvValue.weight(.medium))
                    .foregroundStyle(PH.Color.primary)
                Text(check.passed ? check.rationale : (check.hint ?? check.rationale))
                    .font(PH.Font.rowSub)
                    .foregroundStyle(PH.Color.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    func installLocationGroup(_ group: InstallLocationGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.title)
                .font(PH.Font.sectionHead)
                .foregroundStyle(PH.Color.secondary)
                .textCase(.uppercase)
                .tracking(0.6)

            VStack(spacing: 0) {
                ForEach(Array(group.rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.label)
                                .font(PH.Font.kvValue.weight(.medium))
                                .foregroundStyle(PH.Color.primary)
                            Text(row.path)
                                .font(PH.Font.mono)
                                .foregroundStyle(PH.Color.secondary)
                                .textSelection(.enabled)
                        }
                        Spacer(minLength: 0)
                        Text(row.exists ? "Available" : "Missing")
                            .font(PH.Font.badge)
                            .foregroundStyle(row.exists ? PH.Color.statusOK : PH.Color.statusFail)
                    }
                    .padding(.vertical, 8)

                    if index < group.rows.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    func labelForInstallPath(_ path: String) -> String {
        if let source = resolvedPrivateSource, path.hasPrefix(source.location) {
            return source.label
        }
        if skill.isGlobal {
            return "Global Install Root"
        }
        return "Project Install Root"
    }

    func agentVisibilityLabel(_ status: AgentVisibilityStatus) -> String {
        switch status {
        case .visible:
            return "Visible"
        case .missing:
            return "Missing"
        case .unknownPath:
            return "Unknown path"
        }
    }

    func buildFileNode(for url: URL) -> SkillFileNode {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else {
            return SkillFileNode(name: url.lastPathComponent, path: url.path, isDirectory: false, children: nil)
        }

        if isDirectory.boolValue {
            let children = (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ))?
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .map(buildFileNode(for:))
            return SkillFileNode(
                name: url.lastPathComponent,
                path: url.path,
                isDirectory: true,
                children: children
            )
        }

        return SkillFileNode(name: url.lastPathComponent, path: url.path, isDirectory: false, children: nil)
    }
}

private struct SkillFileTreeNodeView: View {
    let node: InstalledSkillDetailPane.SkillFileNode
    let depth: Int
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if node.isDirectory, let children = node.children, !children.isEmpty {
                DisclosureGroup(isExpanded: $isExpanded) {
                    ForEach(children) { child in
                        SkillFileTreeNodeView(node: child, depth: depth + 1)
                    }
                } label: {
                    row
                }
                .padding(.leading, CGFloat(depth) * 12)
            } else {
                row
                    .padding(.leading, CGFloat(depth) * 12 + (node.isDirectory ? 0 : 20))
            }
        }
        .onAppear { isExpanded = depth == 0 }
    }

    private var row: some View {
        HStack(spacing: 8) {
            Image(systemName: node.isDirectory ? "folder" : "doc.text")
                .foregroundStyle(node.isDirectory ? PH.Color.accent : PH.Color.secondary)
                .frame(width: 14)
            Text(node.name)
                .font(node.isDirectory ? PH.Font.kvValue.weight(.medium) : PH.Font.rowSub)
                .foregroundStyle(PH.Color.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.path)])
            } label: {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PH.Color.tertiary)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .help(node.path)
    }
}
