import PromptHubSkillKit
import SwiftUI

/// A sheet that runs a full audit over all installed skills and presents a summary table.
struct SkillAuditReportView: View {
    let skills: [InstalledSkillSnapshot]
    let onDismiss: () -> Void

    @State var visibilityMap: [String: [SkillAgentVisibility]] = [:]
    @State var integrityMap: [String: SkillSourceIntegrity] = [:]
    @State var effectivenessMap: [String: SkillEffectivenessReport] = [:]
    @State var progress: Double = 0
    @State var isRunning = false
    @State var isDone = false
    @State var currentSkillName = ""
    @State var auditTask: Task<Void, Never>?
    @State var sortOrder: [KeyPathComparator<AuditRow>] = [.init(\.displayName, order: .forward)]
    @State var tableSelection: String?

    let workspaceService = SkillWorkspaceService.shared

    var auditRows: [AuditRow] {
        skills.map { skill in
            AuditRow(id: skill.id, skill: skill,
                     visibility: visibilityMap[skill.id] ?? [],
                     integrity: integrityMap[skill.id],
                     effectiveness: effectivenessMap[skill.id])
        }
    }

    var sortedRows: [AuditRow] { auditRows.sorted(using: sortOrder) }

    var totalSkills: Int { skills.count }
    var missingAgentCount: Int { visibilityMap.values.flatMap { $0 }.filter { $0.status == .missing }.count }
    var integrityIssueCount: Int { integrityMap.values.filter { $0.status == .modified }.count }
    var poorEffectivenessCount: Int { effectivenessMap.values.filter { $0.tier == .poor || $0.tier == .fair }.count }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if !isDone { progressView } else { reportView }
        }
        .frame(minWidth: 700, minHeight: 480)
        .onAppear { startAudit() }
    }

    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Skill Audit").font(.headline)
                Text("\(totalSkills) skill\(totalSkills == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isDone {
                Button { isDone = false; startAudit() } label: { Label("Re-run", systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered)
            }
            Button("Close") { auditTask?.cancel(); onDismiss() }.keyboardShortcut(.escape)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    var progressView: some View {
        VStack(spacing: 16) {
            if isRunning {
                ProgressView(value: progress) {
                    Text("Auditing \(currentSkillName.isEmpty ? "skills" : currentSkillName)…").font(.callout)
                }
                .progressViewStyle(.linear).padding(.horizontal, 32)
                Text("\(Int(progress * 100))% complete").font(.caption).foregroundStyle(.secondary)
            } else {
                Button("Run Audit") { startAudit() }.buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }

    var reportView: some View {
        VStack(spacing: 0) {
            summaryBar
            Divider()
            auditTable
        }
    }
}
