import AppKit
import PromptHubSkillKit
import SwiftUI

struct InstalledSkillDetailPane: View {
    let skill: InstalledSkillSnapshot
    let linkedDraft: Skill?
    let agentVisibility: [SkillAgentVisibility]
    let isLoadingVisibility: Bool
    let sourceIntegrity: SkillSourceIntegrity?
    let isLoadingIntegrity: Bool
    let structuralQuality: SkillStructuralQualityReport?
    let isLoadingStructuralQuality: Bool
    let isAdding: Bool
    let isRemoving: Bool
    let onEditDraft: () -> Void
    let onAddAgents: ([AgentWorkflow]) -> Void
    let onRemoveAll: () -> Void
    let onRemoveAgent: (AgentWorkflow) -> Void
    let onOpenSourcePage: () -> Void

    @State private var showingUpdateDiff = false

    private let iconSymbols = [
        "hammer.fill", "paintpalette.fill", "terminal.fill",
        "wand.and.stars", "cpu.fill", "shippingbox.fill", "doc.text.magnifyingglass"
    ]
    private let iconColors: [Color] = [.blue, .orange, .green, .pink, .mint, .indigo, .teal]

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
            ("Identifier", skill.package.rawValue),
            ("Managed", skill.isManagedByPromptHub ? "PromptHub managed" : "External install"),
            ("Integrity", integritySummary)
        ]

        if let localHash = sourceIntegrity?.localHash {
            rows.append(("SHA-256", String(localHash.prefix(16)) + "…"))
        }

        return rows
    }

    private var coverageEntries: [(agent: AgentWorkflow, visibility: SkillAgentVisibility?)] {
        AgentWorkflow.allCases.map { agent in
            (agent, agentVisibility.first(where: { $0.agent == agent }))
        }
    }

    private var coverageRows: [[(agent: AgentWorkflow, visibility: SkillAgentVisibility?)]] {
        stride(from: 0, to: coverageEntries.count, by: 2).map { startIndex in
            Array(coverageEntries[startIndex..<min(startIndex + 2, coverageEntries.count)])
        }
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

    private var qualityBadgeText: String {
        guard let structuralQuality, structuralQuality.fileFound else {
            return isLoadingStructuralQuality ? "Analyzing quality…" : "Quality unavailable"
        }

        return "\(Int(structuralQuality.score * 100)) \(structuralQuality.tier.label) · \(passedChecksCount)/\(totalChecksCount) checks"
    }

    private var footerStatusText: String {
        let scopeText = skill.isGlobal ? "Global scope" : "Project scope"
        if linkedDraft != nil {
            return "\(scopeText) · Draft linked"
        }
        return "\(scopeText) · No linked draft"
    }

    private var sourceBadgeTitle: String {
        switch sourceIntegrity?.status {
        case .verified:
            return "Verified"
        case .modified:
            return "Modified"
        case .remoteUnavailable:
            return "Remote unavailable"
        case .noRemoteSource:
            return "Local only"
        case .notInstalled:
            return "Missing file"
        case .none:
            return isLoadingIntegrity ? "Checking source" : "Source status"
        }
    }

    private var sourceBadgeColor: Color {
        switch sourceIntegrity?.status {
        case .verified:
            return .green
        case .modified:
            return .orange
        case .remoteUnavailable, .noRemoteSource, .none:
            return .secondary
        case .notInstalled:
            return .red
        }
    }

    private var sourceBadgeIcon: String {
        switch sourceIntegrity?.status {
        case .verified:
            return "checkmark.shield"
        case .modified:
            return "exclamationmark.shield"
        case .remoteUnavailable:
            return "wifi.slash"
        case .noRemoteSource:
            return "internaldrive"
        case .notInstalled:
            return "xmark.circle"
        case .none:
            return "questionmark.circle"
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            headerSection
            quickActionsSection
            overviewSection
            diagnosticsSection
            coverageSection
            footerSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SkillStoreInspectorChrome())
        .sheet(isPresented: $showingUpdateDiff) {
            SkillUpdateDiffSheet(skill: skill) { showingUpdateDiff = false }
        }
    }

    private func coverageRow(agent: AgentWorkflow, visibility: SkillAgentVisibility?) -> some View {
        let isInstalled = skill.agents.contains(agent)
        let visibilityStatus = visibility?.status
        let visibilityLabel: String = {
            switch visibilityStatus {
            case .visible:
                return "Visible"
            case .missing:
                return "Missing"
            case .unknownPath:
                return "Unknown path"
            case .none:
                return isLoadingVisibility ? "Checking…" : "Not scanned"
            }
        }()
        let visibilityColor: Color = {
            switch visibilityStatus {
            case .visible:
                return .green
            case .missing:
                return .red
            case .unknownPath:
                return .secondary
            case .none:
                return .secondary
            }
        }()

        return HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(isInstalled ? Color.green : Color(NSColor.separatorColor))
                .frame(width: 8, height: 8)

            Text(agent.displayName)
                .font(.callout.weight(.medium))
                .foregroundStyle(isInstalled ? .primary : .secondary)

            if isInstalled {
                InstalledSkillBadge(
                    title: skill.isGlobal ? "Global" : "Project",
                    icon: skill.isGlobal ? "globe" : "folder",
                    foreground: skill.isGlobal ? .blue : .mint,
                    background: (skill.isGlobal ? Color.blue : Color.mint).opacity(0.14)
                )
            }

            Spacer(minLength: 0)

            Text(visibilityLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(visibilityColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(skill.displayName)
                    .font(.title2.weight(.semibold))
                Text(topStatusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            qualityPill
        }
    }

    private var qualityPill: some View {
        HStack(spacing: 8) {
            Text(qualityBadgeText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(qualityPillColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(qualityPillColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(qualityPillColor.opacity(0.25), lineWidth: 0.8)
        )
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

    private var quickActionsSection: some View {
        detailSectionCard {
            PHSectionHead(systemImage: "sparkles", label: "Quick Actions")

            VStack(alignment: .leading, spacing: 10) {
                primaryActionButtons
                footerActionButtons
            }
        }
    }

    private var primaryActionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Button(editDraftButtonTitle, action: onEditDraft)
                    .buttonStyle(.borderedProminent)

                if skill.package.remoteInstallDescriptor != nil {
                    Button("Review Update") { showingUpdateDiff = true }
                        .buttonStyle(.bordered)
                }

                if !installedPackagePaths.isEmpty || localSkillFilePath != nil {
                    Button("Reveal Installed Files", action: revealInstalledFiles)
                        .buttonStyle(.bordered)
                }

                if skill.url != nil {
                    Button("Open Source Page", action: onOpenSourcePage)
                        .buttonStyle(.bordered)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Button(editDraftButtonTitle, action: onEditDraft)
                    .buttonStyle(.borderedProminent)

                if skill.package.remoteInstallDescriptor != nil {
                    Button("Review Update") { showingUpdateDiff = true }
                        .buttonStyle(.bordered)
                }

                if !installedPackagePaths.isEmpty || localSkillFilePath != nil {
                    Button("Reveal Installed Files", action: revealInstalledFiles)
                        .buttonStyle(.bordered)
                }

                if skill.url != nil {
                    Button("Open Source Page", action: onOpenSourcePage)
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private var overviewSection: some View {
        detailSectionCard {
            PHSectionHead(systemImage: "doc.text", label: "Overview")

            Text(summaryText)
                .font(PH.Font.body)
                .foregroundStyle(PH.Color.secondary)
                .lineSpacing(PH.Font.bodyLineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)

            metadataStrip

            SkillLibraryMetadataBlock(title: "Connections", rows: [
                ("Projects", projectSummary),
                ("Linked Draft", linkedDraftSummary),
                ("Connected CLIs", coverageSummary),
                ("Visibility", visibilitySummary)
            ])

            if !installedPackagePaths.isEmpty {
                SkillLibraryMetadataBlock(
                    title: installedPackagePaths.count > 1 ? "Installed Packages" : "Installed Package",
                    rows: installedPackagePaths.enumerated().map { index, path in
                        (installedPackagePaths.count > 1 ? "Path \(index + 1)" : "Path", path)
                    }
                )
            } else if let localSkillFilePath {
                SkillLibraryMetadataBlock(title: "Installed Files", rows: [
                    ("Primary File", localSkillFilePath)
                ])
            }
        }
    }

    private var metadataStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 8) {
                    InstalledSkillBadge(
                        title: skill.isGlobal ? "Global" : "Project",
                        icon: skill.isGlobal ? "globe" : "folder",
                        foreground: skill.isGlobal ? .blue : .mint,
                        background: (skill.isGlobal ? Color.blue : Color.mint).opacity(0.14)
                    )

                    InstalledSkillBadge(
                        title: skill.isManagedByPromptHub ? "PromptHub managed" : "External install",
                        icon: skill.isManagedByPromptHub ? "checkmark.circle" : "arrow.triangle.branch",
                        foreground: skill.isManagedByPromptHub ? .green : .orange,
                        background: (skill.isManagedByPromptHub ? Color.green : Color.orange).opacity(0.14)
                    )

                    InstalledSkillBadge(
                        title: sourceBadgeTitle,
                        icon: sourceBadgeIcon,
                        foreground: sourceBadgeColor,
                        background: sourceBadgeColor.opacity(0.12)
                    )

                    if let localHash = sourceIntegrity?.localHash {
                        Text("SHA-256  \(String(localHash.prefix(12)))…")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(PH.Color.buttonBg, in: Capsule())
                    }
                }
                .padding(.vertical, 1)
            }

            HStack(spacing: 6) {
                Text("Identifier:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(skill.package.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PH.Color.buttonBg, in: Capsule())
            }
        }
    }

    private var coverageSection: some View {
        detailSectionCard {
            PHSectionHead(systemImage: "checklist", label: "CLI Visibility")

            VStack(spacing: 0) {
                ForEach(Array(coverageRows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .top, spacing: 18) {
                        coverageCell(for: row[0])
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if row.count > 1 {
                            coverageCell(for: row[1])
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)

                    if index < coverageRows.count - 1 {
                        Divider()
                    }
                }
            }

            HStack(spacing: 16) {
                legendDot(color: .green, text: "Installed & visible")
                legendDot(color: .secondary.opacity(0.6), text: "Not installed / unreachable")
            }
            .padding(.top, 2)
        }
    }

    private func coverageCell(for entry: (agent: AgentWorkflow, visibility: SkillAgentVisibility?)) -> some View {
        let isInstalled = skill.agents.contains(entry.agent)
        let visibilityStatus = entry.visibility?.status
        let visibilityText: String = {
            switch visibilityStatus {
            case .visible:
                return "Visible"
            case .missing:
                return "Missing"
            case .unknownPath:
                return "Unknown path"
            case .none:
                return isLoadingVisibility ? "Checking…" : "Unknown path"
            }
        }()
        let visibilityColor: Color = {
            switch visibilityStatus {
            case .visible:
                return .green
            case .missing:
                return .red
            case .unknownPath, .none:
                return .secondary
            }
        }()

        return HStack(spacing: 8) {
            Circle()
                .fill(isInstalled ? Color.green : Color(NSColor.separatorColor).opacity(0.7))
                .frame(width: 7, height: 7)

            Text(entry.agent.displayName)
                .font(.callout)
                .foregroundStyle(isInstalled ? .primary : .secondary)

            if isInstalled {
                Text(skill.isGlobal ? "global" : "project")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(skill.isGlobal ? .blue : .mint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((skill.isGlobal ? Color.blue : Color.mint).opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            Spacer(minLength: 6)

            HStack(spacing: 5) {
                Image(systemName: visibilityStatus == .visible ? "checkmark" : (visibilityStatus == .missing ? "xmark" : "minus"))
                    .font(.caption2.weight(.semibold))
                Text(visibilityText)
                    .font(.caption)
            }
            .foregroundStyle(visibilityColor)
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var diagnosticsSection: some View {
        detailSectionCard {
            PHSectionHead(systemImage: "waveform.path.ecg", label: "Diagnostics")

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 32) {
                    auditDiagnosticsBlock
                    integrityDiagnosticsBlock
                }

                VStack(alignment: .leading, spacing: 18) {
                    auditDiagnosticsBlock
                    integrityDiagnosticsBlock
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var auditDiagnosticsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audit")
                .font(.headline)

            if isLoadingStructuralQuality && structuralQuality == nil {
                Text("Analyzing SKILL.md…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if qualityChecks.isEmpty {
                Text("Quality analysis not available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(qualityChecks.enumerated()), id: \.offset) { index, check in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: check.passed ? "checkmark.circle" : "xmark.circle")
                                .foregroundStyle(check.passed ? Color.green : Color.red)
                                .font(.caption)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(check.title)
                                    .font(.callout)
                                if !check.passed, let hint = check.hint, !hint.isEmpty {
                                    Text(hint)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 7)

                        if index < qualityChecks.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var integrityDiagnosticsBlock: some View {
        VStack(alignment: .leading, spacing: 18) {
            SkillLibraryMetadataBlock(title: "Package", rows: [
                ("Identifier", skill.package.rawValue),
                ("Managed", skill.isManagedByPromptHub ? "PromptHub managed" : "External install"),
                ("Source", skill.displaySource ?? "Local only")
            ])

            SkillLibraryMetadataBlock(title: "Integrity", rows: [
                ("Status", integritySummary),
                ("Quality", qualitySummary),
                ("SHA-256", sourceIntegrity?.localHash.map { String($0.prefix(16)) + "…" } ?? "Unavailable")
            ])
        }
    }

    private var footerSection: some View {
        Text(footerStatusText)
            .font(.caption)
            .foregroundStyle(.secondary)
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

    private func copyName() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(skill.displayName, forType: .string)
    }

    @ViewBuilder
    private var footerActionButtons: some View {
        if isRemoving {
            Label("Removing…", systemImage: "hourglass")
                .foregroundStyle(.secondary)
        } else if isAdding {
            Label("Updating CLIs…", systemImage: "hourglass")
                .foregroundStyle(.secondary)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Button(action: copyName) {
                        Label("Copy Name", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)

                    Button("Remove", role: .destructive, action: onRemoveAll)
                        .buttonStyle(.bordered)

                    if !skill.agents.isEmpty {
                        Menu {
                            ForEach(skill.agents, id: \.rawValue) { agent in
                                Button(role: .destructive) { onRemoveAgent(agent) } label: {
                                    Label("Remove from \(agent.displayName)", systemImage: "trash")
                                }
                            }
                        } label: {
                            Label("Manage CLIs", systemImage: "slider.horizontal.3")
                        }
                        .menuStyle(.borderedButton)
                    }

                    if supportsAddTargets {
                        Menu {
                            if addableAgents.count > 1 {
                                Button { onAddAgents(addableAgents) } label: {
                                    Label("Add All Missing CLIs", systemImage: "plus.circle")
                                }
                            }
                            ForEach(addableAgents, id: \.rawValue) { agent in
                                Button { onAddAgents([agent]) } label: {
                                    Label("Add \(agent.displayName)", systemImage: "plus")
                                }
                            }
                        } label: {
                            Label("Add CLI", systemImage: "plus")
                        }
                        .menuStyle(.borderedButton)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button(action: copyName) {
                        Label("Copy Name", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)

                    Button("Remove", role: .destructive, action: onRemoveAll)
                        .buttonStyle(.bordered)

                    if !skill.agents.isEmpty {
                        Menu {
                            ForEach(skill.agents, id: \.rawValue) { agent in
                                Button(role: .destructive) { onRemoveAgent(agent) } label: {
                                    Label("Remove from \(agent.displayName)", systemImage: "trash")
                                }
                            }
                        } label: {
                            Label("Manage CLIs", systemImage: "slider.horizontal.3")
                        }
                        .menuStyle(.borderedButton)
                    }

                    if supportsAddTargets {
                        Menu {
                            if addableAgents.count > 1 {
                                Button { onAddAgents(addableAgents) } label: {
                                    Label("Add All Missing CLIs", systemImage: "plus.circle")
                                }
                            }
                            ForEach(addableAgents, id: \.rawValue) { agent in
                                Button { onAddAgents([agent]) } label: {
                                    Label("Add \(agent.displayName)", systemImage: "plus")
                                }
                            }
                        } label: {
                            Label("Add CLI", systemImage: "plus")
                        }
                        .menuStyle(.borderedButton)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.4)
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(PH.Color.stroke)
    }

    private func detailSectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(PH.Color.detailBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PH.Color.strokeSoft, lineWidth: 0.8)
        )
    }

    // MARK: - Icon generation

    private var iconSeed: Int {
        skill.displayName.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    }

    private var iconSymbol: String { iconSymbols[iconSeed % iconSymbols.count] }
    private var iconColor: Color   { iconColors[iconSeed % iconColors.count] }
}
