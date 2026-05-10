import AlertToast
import AppKit
import PromptHubSkillKit
import SwiftUI

// MARK: - Actions

extension SkillDraftDetailView {

    func syncEditorState(from latestVersion: SkillVersion) {
        instructionsText = latestVersion.instructions
        tagText = skill.tags.joined(separator: ", ")
        if selectedAgents.isEmpty { selectedAgents = Set(AgentWorkflow.defaultTargets) }
    }

    func saveDraftMetadata() {
        skill.touch()
        try? modelContext.save()
    }

    func saveInstructions() {
        if let latest = skill.latestVersion {
            latest.instructions = instructionsText
            latest.parentSkillID = skill.id
        }
        skill.touch()
        try? modelContext.save()
    }

    func createVersionSnapshot() {
        do {
            _ = try draftService.snapshotVersion(for: skill, using: instructionsText, in: modelContext)
            showToastMsg("Saved \(skill.latestVersion?.version ?? "new")")
        } catch {
            showToastMsg("Failed to save snapshot: \(error.localizedDescription)")
        }
    }

    func duplicateVersion(_ version: SkillVersion) {
        do {
            _ = try draftService.snapshotVersion(for: skill, using: version.instructions, in: modelContext)
            instructionsText = version.instructions
            showToastMsg("Duplicated \(version.version) into a new latest draft")
        } catch {
            showToastMsg("Failed to duplicate version: \(error.localizedDescription)")
        }
    }

    func copySkillMarkdown() {
        NSPasteboard.general.clearContents()
        let markdown = draftService.exportMarkdown(for: skill)
        let didCopy = NSPasteboard.general.setString(markdown, forType: .string)
        showToastMsg(didCopy ? "Copied SKILL.md" : "Failed to copy SKILL.md", alertType: didCopy ? .complete(.green) : .error(.red))
    }

    func installDraft() {
        isInstalling = true
        let agents = selectedAgents.isEmpty ? AgentWorkflow.defaultTargets : Array(selectedAgents).sorted { $0.rawValue < $1.rawValue }
        Task {
            do {
                try await draftService.installDraft(skill, scope: installScope, targetAgents: agents, in: modelContext)
                isInstalling = false
                showToastMsg("Installed \(skill.displayName)", alertType: .complete(.green))
            } catch {
                isInstalling = false
                showToastMsg("Failed to install draft: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    func showToastMsg(_ message: String, alertType: AlertToast.AlertType = .error(.red)) {
        toastTitle = message; toastType = alertType; showToast = true
    }
}
