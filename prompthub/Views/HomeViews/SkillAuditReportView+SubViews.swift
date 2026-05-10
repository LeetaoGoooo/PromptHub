import PromptHubSkillKit
import SwiftUI

// MARK: - AuditRow model

extension SkillAuditReportView {
    struct AuditRow: Identifiable {
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
}

// MARK: - Sub Views

extension SkillAuditReportView {

    var summaryBar: some View {
        HStack(spacing: 16) {
            summaryPill("\(totalSkills)", label: "Skills", icon: "shippingbox.fill", color: .blue)
            summaryPill("\(missingAgentCount)", label: "Missing Agents", icon: "exclamationmark.triangle.fill",
                        color: missingAgentCount > 0 ? .orange : Color(NSColor.tertiaryLabelColor))
            summaryPill("\(integrityIssueCount)", label: "Modified", icon: "exclamationmark.shield.fill",
                        color: integrityIssueCount > 0 ? .orange : Color(NSColor.tertiaryLabelColor))
            summaryPill("\(poorEffectivenessCount)", label: "Low Quality", icon: "xmark.circle.fill",
                        color: poorEffectivenessCount > 0 ? .red : Color(NSColor.tertiaryLabelColor))
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    @ViewBuilder
    func summaryPill(_ value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(color).font(.caption)
            Text(value).font(.callout.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    var auditTable: some View {
        Table(sortedRows, selection: $tableSelection, sortOrder: $sortOrder) {
            TableColumn("Skill", value: \.displayName) { row in
                let isSelected = tableSelection == row.id
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.accentColor)
                        .frame(width: 3)
                        .opacity(isSelected ? 1 : 0)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.displayName).font(.callout.weight(.medium)).lineLimit(1)
                        if let source = row.skill.displaySource {
                            Text(source).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .padding(.leading, isSelected ? 8 : 11)
                }
            }
            TableColumn("Scope", value: \.scope) { row in
                let isGlobal = row.skill.isGlobal
                let color: Color = isGlobal ? .blue : .mint
                Label(isGlobal ? "Global" : "Project", systemImage: isGlobal ? "globe" : "folder")
                    .font(.caption2).foregroundStyle(color)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(color.opacity(0.12)).clipShape(Capsule())
            }.width(90)

            TableColumn("Agents", value: \.visibleCount) { row in agentCell(row) }.width(80)
            TableColumn("Integrity", value: \.integrityRank) { row in integrityCell(row.integrity) }.width(110)
            TableColumn("Quality", value: \.effectivenessScore) { row in effectivenessCell(row.effectiveness) }.width(100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
    }

    @ViewBuilder
    func agentCell(_ row: AuditRow) -> some View {
        if row.visibility.isEmpty {
            ProgressView().controlSize(.mini)
        } else {
            let visible = row.visibleCount
            let total = row.totalAgents
            HStack(spacing: 3) {
                Text("\(visible)/\(total)").font(.caption.weight(.semibold))
                    .foregroundStyle(visible == total ? Color.green : Color.orange).monospacedDigit()
                if visible < total { Image(systemName: "exclamationmark.triangle.fill").font(.caption2).foregroundStyle(.orange) }
            }
        }
    }

    @ViewBuilder
    func integrityCell(_ integrity: SkillSourceIntegrity?) -> some View {
        if let integrity {
            let (icon, color, label): (String, Color, String) = {
                switch integrity.status {
                case .verified:         return ("checkmark.shield.fill", .green, "Verified")
                case .modified:         return ("exclamationmark.shield.fill", .orange, "Modified")
                case .remoteUnavailable: return ("wifi.slash", Color(NSColor.secondaryLabelColor), "Unavailable")
                case .noRemoteSource:   return ("internaldrive", Color(NSColor.secondaryLabelColor), "Local")
                case .notInstalled:     return ("xmark.circle.fill", .red, "Missing")
                }
            }()
            HStack(spacing: 4) {
                Image(systemName: icon).foregroundStyle(color).font(.caption)
                Text(label).font(.caption).foregroundStyle(color)
            }
        } else {
            ProgressView().controlSize(.mini)
        }
    }

    @ViewBuilder
    func effectivenessCell(_ effectiveness: SkillEffectivenessReport?) -> some View {
        if let effectiveness {
            let color = tierColor(effectiveness.tier)
            HStack(spacing: 4) {
                Image(systemName: effectiveness.tier.systemImage).foregroundStyle(color).font(.caption)
                Text(effectiveness.tier.label).font(.caption).foregroundStyle(color)
            }
        } else {
            ProgressView().controlSize(.mini)
        }
    }

    func tierColor(_ tier: EffectivenessTier) -> Color {
        switch tier {
        case .excellent: return .green
        case .good:      return .blue
        case .fair:      return .orange
        case .poor:      return .red
        }
    }
}
