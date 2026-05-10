import Foundation
import PromptHubSkillKit

// MARK: - Actions

extension SkillUpdateDiffSheet {

    func loadPreview() async {
        isLoading = true; errorMessage = nil
        let result = await workspaceService.previewUpdate(for: skill)
        isLoading = false; preview = result

        switch result.status {
        case .remoteUnavailable:
            errorMessage = "Could not reach GitHub to fetch the remote SKILL.md.\nCheck your internet connection and try again."
        case .noRemoteSource:
            errorMessage = "This skill has no GitHub source URL — update is not available for locally-authored skills."
        case .notInstalled:
            errorMessage = "The local SKILL.md was not found. Re-install the skill first."
        default:
            break
        }
    }

    func performApply(_ preview: SkillUpdatePreview) async {
        isApplying = true; errorMessage = nil
        do {
            try await workspaceService.applyUpdate(preview: preview)
            hasBackup = await workspaceService.hasRollbackBackup(for: skill)
            successMessage = "Update applied successfully."
            NotificationCenter.default.post(name: .skillInstallationsDidChange, object: nil)
            let refreshed = await workspaceService.previewUpdate(for: skill)
            self.preview = refreshed
        } catch {
            errorMessage = "Failed to apply update: \(error.localizedDescription)"
        }
        isApplying = false
    }

    func performRollback(_ preview: SkillUpdatePreview) async {
        isRollingBack = true; errorMessage = nil
        do {
            let count = try await workspaceService.rollbackUpdate(preview: preview)
            hasBackup = await workspaceService.hasRollbackBackup(for: skill)
            successMessage = "Rolled back \(count) file\(count == 1 ? "" : "s")."
            NotificationCenter.default.post(name: .skillInstallationsDidChange, object: nil)
            let refreshed = await workspaceService.previewUpdate(for: skill)
            self.preview = refreshed
        } catch {
            errorMessage = "Rollback failed: \(error.localizedDescription)"
        }
        isRollingBack = false
    }
}
