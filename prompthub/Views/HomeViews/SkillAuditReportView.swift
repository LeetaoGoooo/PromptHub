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

    private let workspaceService = SkillWorkspaceService.shared

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
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Skill Audit")
                        .font(.headline)
                    Text("\(totalSkills) installed skill\(totalSkills == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close", action: {
                    auditTask?.cancel()
                    onDismiss()
                })
                .keyboardShortcut(.escape)
            }
            .padding(16)

            Divider()

            if !isDone {
                progressView
            } else {
                reportView
            }
        }
        .frame(minWidth: 720, minHeight: 520)
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
            // Summary bar
            summaryBar

            Divider()

            // Table
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Column headers
                    auditTableHeader

                    Divider()

                    ForEach(skills) { skill in
                        auditTableRow(skill)
                        Divider()
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Button {
                    isDone = false
                    startAudit()
                } label: {
                    Label("Re-run Audit", systemImage: "arrow.clockwise")
                }
                Spacer()
                Button("Close", action: onDismiss)
            }
            .padding(16)
        }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack(spacing: 20) {
            auditSummaryPill(
                value: "\(totalSkills)",
                label: "Skills",
                icon: "shippingbox.fill",
                color: .blue
            )
            auditSummaryPill(
                value: "\(missingAgentCount)",
                label: "Missing Agents",
                icon: "exclamationmark.triangle.fill",
                color: missingAgentCount > 0 ? .orange : .secondary
            )
            auditSummaryPill(
                value: "\(integrityIssueCount)",
                label: "Modified",
                icon: "exclamationmark.shield.fill",
                color: integrityIssueCount > 0 ? .orange : .secondary
            )
            auditSummaryPill(
                value: "\(poorEffectivenessCount)",
                label: "Low Quality",
                icon: "xmark.circle.fill",
                color: poorEffectivenessCount > 0 ? .red : .secondary
            )
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func auditSummaryPill(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Table Header

    private var auditTableHeader: some View {
        HStack(spacing: 0) {
            Text("Skill")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Scope")
                .frame(width: 70, alignment: .center)
            Text("Agents")
                .frame(width: 90, alignment: .center)
            Text("Integrity")
                .frame(width: 100, alignment: .center)
            Text("Quality")
                .frame(width: 80, alignment: .center)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Table Row

    @ViewBuilder
    private func auditTableRow(_ skill: InstalledSkillSnapshot) -> some View {
        let visibility = visibilityMap[skill.id] ?? []
        let integrity = integrityMap[skill.id]
        let effectiveness = effectivenessMap[skill.id]

        HStack(spacing: 0) {
            // Skill name
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                if let source = skill.displaySource {
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Scope
            scopeBadgeSmall(skill)
                .frame(width: 70)

            // Agent visibility
            agentVisibilityCells(visibility)
                .frame(width: 90)

            // Integrity
            integrityCellSmall(integrity)
                .frame(width: 100)

            // Effectiveness
            effectivenessCellSmall(effectiveness)
                .frame(width: 80)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private func scopeBadgeSmall(_ skill: InstalledSkillSnapshot) -> some View {
        let color: Color = skill.isGlobal ? .blue : .mint
        Label(skill.isGlobal ? "Global" : "Project",
              systemImage: skill.isGlobal ? "globe" : "folder")
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func agentVisibilityCells(_ visibility: [SkillAgentVisibility]) -> some View {
        if visibility.isEmpty {
            ProgressView().controlSize(.mini)
        } else {
            let visible = visibility.filter { $0.status == .visible }.count
            let total = AgentWorkflow.allCases.count
            HStack(spacing: 3) {
                Text("\(visible)/\(total)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(visible == total ? Color.green : Color.orange)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func integrityCellSmall(_ integrity: SkillSourceIntegrity?) -> some View {
        if let integrity {
            let (icon, color): (String, Color) = {
                switch integrity.status {
                case .verified: return ("checkmark.shield.fill", .green)
                case .modified: return ("exclamationmark.shield.fill", .orange)
                case .remoteUnavailable: return ("wifi.slash", .secondary)
                case .noRemoteSource: return ("internaldrive", .secondary)
                case .notInstalled: return ("xmark.circle.fill", .red)
                }
            }()
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)
        } else {
            ProgressView().controlSize(.mini)
        }
    }

    @ViewBuilder
    private func effectivenessCellSmall(_ effectiveness: SkillEffectivenessReport?) -> some View {
        if let effectiveness {
            let color = tierColor(effectiveness.tier)
            HStack(spacing: 3) {
                Image(systemName: effectiveness.tier.systemImage)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(effectiveness.tier.label)
                    .font(.caption2)
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
