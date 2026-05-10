import PromptHubSkillKit
import SwiftUI

/// A sheet that runs a full audit over all installed skills and presents a summary table.
///
/// "Audit" encompasses three checks per skill:
///   - Agent visibility  (filesystem — fast)
///   - Source integrity  (network — may be slow)
///   - Effectiveness     (filesystem + structural parse — fast)
struct SkillAuditReportView: View {
    let skills: [InstalledSkillSnapshot]
    let onDismiss: () -> Void

    // Individual reports keyed by skill.id
    @State private var visibilityMap: [String: [SkillAgentVisibility]] = [:]
    @State private var integrityMap: [String: SkillSourceIntegrity] = [:]
    @State private var effectivenessMap: [String: SkillEffectivenessReport] = [:]
    @State private var progress: Double = 0
    @State private var isRunning = false
    @State private var isDone = false
    @State private var currentSkillName = ""
    @State private var auditTask: Task<Void, Never>?
    @State private var sortOrder: [KeyPathComparator<AuditRow>] = [
        .init(\.displayName, order: .forward)
    ]
    @State private var tableSelection: String?

    private let workspaceService = SkillWorkspaceService.shared

    // MARK: - Data model for Table rows

    private struct AuditRow: Identifiable {
        let id: String
        let skill: InstalledSkillSnapshot
        let visibility: [SkillAgentVisibility]
        let integrity: SkillSourceIntegrity?
        let effectiveness: SkillEffectivenessReport?

        var displayName: String { skill.displayName }
        var scope: String { skill.isGlobal ? "Global" : "Project" }
        var visibleCount: Int { visibility.filter { $0.status == .visible }.count }
        var totalAgents: Int { AgentWorkflow.allCases.count }
        var integrityRank: Int {
            guard let i = integrity else { return -1 }
            switch i.status {
            case .verified: return 0
            case .noRemoteSource: return 1
            case .remoteUnavailable: return 2
            case .modified: return 3
            case .notInstalled: return 4
            }
        }
        var effectivenessScore: Double { effectiveness?.score ?? -1 }
    }

    private var auditRows: [AuditRow] {
        skills.map { skill in
            AuditRow(
                id: skill.id,
                skill: skill,
                visibility: visibilityMap[skill.id] ?? [],
                integrity: integrityMap[skill.id],
                effectiveness: effectivenessMap[skill.id]
            )
        }
    }

    private var sortedRows: [AuditRow] {
        auditRows.sorted(using: sortOrder)
    }


    // MARK: - Computed summary stats

    private var totalSkills: Int { skills.count }

    private var missingAgentCount: Int {
        visibilityMap.values.flatMap { $0 }.filter { $0.status == .missing }.count
    }

    private var integrityIssueCount: Int {
        integrityMap.values.filter { $0.status == .modified }.count
    }

    private var poorEffectivenessCount: Int {
        effectivenessMap.values.filter { $0.tier == .poor || $0.tier == .fair }.count
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Skill Audit")
                        .font(.headline)
                    Text("\(totalSkills) skill\(totalSkills == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isDone {
                    Button {
                        isDone = false
                        startAudit()
                    } label: {
                        Label("Re-run", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
                Button("Close") {
                    auditTask?.cancel()
                    onDismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if !isDone {
                progressView
            } else {
                reportView
            }
        }
        .frame(minWidth: 700, minHeight: 480)
        .onAppear { startAudit() }
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: 16) {
            if isRunning {
                ProgressView(value: progress) {
                    Text("Auditing \(currentSkillName.isEmpty ? "skills" : currentSkillName)…")
                        .font(.callout)
                }
                .progressViewStyle(.linear)
                .padding(.horizontal, 32)

                Text("\(Int(progress * 100))% complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Run Audit") { startAudit() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Report View

    private var reportView: some View {
        VStack(spacing: 0) {
            summaryBar
            Divider()
            auditTable
        }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack(spacing: 16) {
            summaryPill(
                value: "\(totalSkills)",
                label: "Skills",
                icon: "shippingbox.fill",
                color: .blue
            )
            summaryPill(
                value: "\(missingAgentCount)",
                label: "Missing Agents",
                icon: "exclamationmark.triangle.fill",
                color: missingAgentCount > 0 ? .orange : Color(NSColor.tertiaryLabelColor)
            )
            summaryPill(
                value: "\(integrityIssueCount)",
                label: "Modified",
                icon: "exclamationmark.shield.fill",
                color: integrityIssueCount > 0 ? .orange : Color(NSColor.tertiaryLabelColor)
            )
            summaryPill(
                value: "\(poorEffectivenessCount)",
                label: "Low Quality",
                icon: "xmark.circle.fill",
                color: poorEffectivenessCount > 0 ? .red : Color(NSColor.tertiaryLabelColor)
            )
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func summaryPill(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Native Table

    private var auditTable: some View {
        Table(sortedRows, selection: $tableSelection, sortOrder: $sortOrder) {
            TableColumn("Skill", value: \.displayName) { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.displayName)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    if let source = row.skill.displaySource {
                        Text(source)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            TableColumn("Scope", value: \.scope) { row in
                let isGlobal = row.skill.isGlobal
                let color: Color = isGlobal ? .blue : .mint
                Label(isGlobal ? "Global" : "Project",
                      systemImage: isGlobal ? "globe" : "folder")
                    .font(.caption2)
                    .foregroundStyle(color)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
            .width(90)

            TableColumn("Agents", value: \.visibleCount) { row in
                agentCell(row)
            }
            .width(80)

            TableColumn("Integrity", value: \.integrityRank) { row in
                integrityCell(row.integrity)
            }
            .width(110)

            TableColumn("Quality", value: \.effectivenessScore) { row in
                effectivenessCell(row.effectiveness)
            }
            .width(100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    @ViewBuilder
    private func agentCell(_ row: AuditRow) -> some View {
        if row.visibility.isEmpty {
            ProgressView().controlSize(.mini)
        } else {
            let visible = row.visibleCount
            let total = row.totalAgents
            HStack(spacing: 3) {
                Text("\(visible)/\(total)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(visible == total ? Color.green : Color.orange)
                    .monospacedDigit()
                if visible < total {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private func integrityCell(_ integrity: SkillSourceIntegrity?) -> some View {
        if let integrity {
            let (icon, color, label): (String, Color, String) = {
                switch integrity.status {
                case .verified: return ("checkmark.shield.fill", .green, "Verified")
                case .modified: return ("exclamationmark.shield.fill", .orange, "Modified")
                case .remoteUnavailable: return ("wifi.slash", Color(NSColor.secondaryLabelColor), "Unavailable")
                case .noRemoteSource: return ("internaldrive", Color(NSColor.secondaryLabelColor), "Local")
                case .notInstalled: return ("xmark.circle.fill", .red, "Missing")
                }
            }()
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(color)
            }
        } else {
            ProgressView().controlSize(.mini)
        }
    }

    @ViewBuilder
    private func effectivenessCell(_ effectiveness: SkillEffectivenessReport?) -> some View {
        if let effectiveness {
            let color = tierColor(effectiveness.tier)
            HStack(spacing: 4) {
                Image(systemName: effectiveness.tier.systemImage)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(effectiveness.tier.label)
                    .font(.caption)
                    .foregroundStyle(color)
            }
        } else {
            ProgressView().controlSize(.mini)
        }
    }

    private func tierColor(_ tier: EffectivenessTier) -> Color {
        switch tier {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }

    // MARK: - Audit Runner

    private func startAudit() {
        auditTask?.cancel()
        isRunning = true
        isDone = false
        progress = 0
        visibilityMap = [:]
        integrityMap = [:]
        effectivenessMap = [:]

        auditTask = Task {
            let total = Double(max(skills.count, 1))
            for (index, skill) in skills.enumerated() {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    currentSkillName = skill.displayName
                }

                // Run three checks concurrently per skill.
                async let visTask = workspaceService.auditAgentVisibility(for: skill)
                async let intTask = workspaceService.auditSourceIntegrity(for: skill)
                async let effTask = workspaceService.auditEffectiveness(for: skill)

                let (vis, int, eff) = await (visTask, intTask, effTask)

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    visibilityMap[skill.id] = vis
                    integrityMap[skill.id] = int
                    effectivenessMap[skill.id] = eff
                    progress = Double(index + 1) / total
                }
            }

            await MainActor.run {
                isRunning = false
                isDone = true
                currentSkillName = ""
            }
        }
    }
}
