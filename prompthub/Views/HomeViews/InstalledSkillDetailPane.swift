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
    let hasUpdate: Bool
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
        SkillLibraryInspectorCard {
            VStack(alignment: .leading, spacing: 22) {
                heroSection
                installScopeSection
                healthSection
                sourceIntegritySection
                updateStatusSection
                auditFindingsSection
                footerSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showingUpdateDiff) {
            SkillUpdateDiffSheet(skill: skill) { showingUpdateDiff = false }
        }
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

    private var heroSection: some View {
        detailSectionCard {
            HStack(alignment: .top, spacing: 18) {
                Image(systemName: iconSymbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 56, height: 56)
                    .background(iconColor.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    headerSection

                    Text(summaryText)
                        .font(PH.Font.body)
                        .foregroundStyle(PH.Color.secondary)
                        .lineSpacing(PH.Font.bodyLineSpacing)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    SkillLibraryMetadataBlock(title: "Source", rows: [
                        ("Source", skill.displaySource ?? "Local only"),
                        ("Identifier", skill.package.rawValue),
                        ("Draft", linkedDraftSummary)
                    ])
                }
            }

            primaryActionButtons
        }
    }

    private var installScopeSection: some View {
        detailSectionCard {
            PHSectionHead(systemImage: "square.stack.3d.up", label: "Install Scope")

            SkillLibraryMetadataBlock(title: "Coverage", rows: [
                ("Scope", skill.isGlobal ? "Global" : "Project"),
                ("Projects", projectSummary),
                ("Connected CLIs", coverageSummary)
            ])

            InstalledSkillScopeMatrixView(skill: skill)

            footerActionButtons
        }
    }

    private var healthSection: some View {
        detailSectionCard {
            PHSectionHead(systemImage: "heart.text.square", label: "Health")

            SkillLibraryMetadataBlock(title: "Health Summary", rows: [
                ("Structure", qualitySummary),
                ("Visibility", visibilitySummary),
                ("Integrity", integritySummary)
            ])

            InstalledSkillStructuralQualityView(
                structuralQuality: structuralQuality,
                isLoading: isLoadingStructuralQuality
            )

            InstalledSkillAgentVisibilityView(
                visibility: agentVisibility,
                isLoading: isLoadingVisibility
            )
        }
    }

    private var sourceIntegritySection: some View {
        detailSectionCard {
            PHSectionHead(systemImage: "checkmark.shield", label: "Source Integrity")

            SkillLibraryMetadataBlock(title: "Package", rows: sourceRows)

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

            InstalledSkillIntegrityView(
                integrity: sourceIntegrity,
                isLoading: isLoadingIntegrity
            )
        }
    }

    private var updateStatusSection: some View {
        detailSectionCard {
            PHSectionHead(systemImage: "arrow.triangle.2.circlepath", label: "Update Status")

            SkillLibraryMetadataBlock(title: "Remote Status", rows: [
                ("Source Type", skill.package.remoteInstallDescriptor == nil ? "Local only" : "Remote backed"),
                ("Update State", updateSummaryText),
                ("Action", skill.package.remoteInstallDescriptor == nil ? "No remote update path" : "Review update diff")
            ])

            HStack(spacing: 10) {
                if skill.package.remoteInstallDescriptor != nil {
                    Button("Review Update") { showingUpdateDiff = true }
                        .buttonStyle(PHChromeButtonStyle(emphasis: .accent))
                }

                if skill.url != nil {
                    Button("Open Source Page", action: onOpenSourcePage)
                        .buttonStyle(PHChromeButtonStyle(emphasis: .standard))
                }
            }
        }
    }

    private var auditFindingsSection: some View {
        detailSectionCard {
            PHSectionHead(systemImage: "checklist", label: "Audit Findings")
            auditDiagnosticsBlock
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

    private var updateSummaryText: String {
        guard skill.package.remoteInstallDescriptor != nil else {
            return "Not available for local-only skills"
        }

        return hasUpdate ? "Update available" : "No pending update detected"
    }

    private var primaryActionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Button(editDraftButtonTitle, action: onEditDraft)
                    .buttonStyle(PHChromeButtonStyle(emphasis: .accent))

                if skill.package.remoteInstallDescriptor != nil {
                    Button("Review Update") { showingUpdateDiff = true }
                        .buttonStyle(PHChromeButtonStyle(emphasis: .standard))
                }

                if !installedPackagePaths.isEmpty || localSkillFilePath != nil {
                    Button("Reveal Installed Files", action: revealInstalledFiles)
                        .buttonStyle(PHChromeButtonStyle(emphasis: .standard))
                }

                if skill.url != nil {
                    Button("Open Source Page", action: onOpenSourcePage)
                        .buttonStyle(PHChromeButtonStyle(emphasis: .standard))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Button(editDraftButtonTitle, action: onEditDraft)
                    .buttonStyle(PHChromeButtonStyle(emphasis: .accent))

                if skill.package.remoteInstallDescriptor != nil {
                    Button("Review Update") { showingUpdateDiff = true }
                        .buttonStyle(PHChromeButtonStyle(emphasis: .standard))
                }

                if !installedPackagePaths.isEmpty || localSkillFilePath != nil {
                    Button("Reveal Installed Files", action: revealInstalledFiles)
                        .buttonStyle(PHChromeButtonStyle(emphasis: .standard))
                }

                if skill.url != nil {
                    Button("Open Source Page", action: onOpenSourcePage)
                        .buttonStyle(PHChromeButtonStyle(emphasis: .standard))
                }
            }
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
                    .buttonStyle(PHChromeButtonStyle(emphasis: .standard))

                    Button("Remove", role: .destructive, action: onRemoveAll)
                        .buttonStyle(PHChromeButtonStyle(emphasis: .standard))

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
                    .buttonStyle(PHChromeButtonStyle(emphasis: .standard))

                    Button("Remove", role: .destructive, action: onRemoveAll)
                        .buttonStyle(PHChromeButtonStyle(emphasis: .standard))

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
