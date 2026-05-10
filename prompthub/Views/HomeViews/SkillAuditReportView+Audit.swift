import PromptHubSkillKit
import SwiftUI

// MARK: - Audit Runner

extension SkillAuditReportView {

    func startAudit() {
        auditTask?.cancel()
        isRunning = true; isDone = false; progress = 0
        visibilityMap = [:]; integrityMap = [:]; effectivenessMap = [:]

        auditTask = Task {
            let total = Double(max(skills.count, 1))
            for (index, skill) in skills.enumerated() {
                guard !Task.isCancelled else { return }
                await MainActor.run { currentSkillName = skill.displayName }

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
            await MainActor.run { isRunning = false; isDone = true; currentSkillName = "" }
        }
    }
}
