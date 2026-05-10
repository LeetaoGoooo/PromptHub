import PromptHubSkillKit
import SwiftUI

/// Sheet that shows a line-by-line diff between the current local SKILL.md and the remote
/// version, then lets the user confirm (apply update) or cancel.
struct SkillUpdateDiffSheet: View {
    let skill: InstalledSkillSnapshot
    let onDismiss: () -> Void

    @State var preview: SkillUpdatePreview?
    @State var isLoading = true
    @State var isApplying = false
    @State var isRollingBack = false
    @State var hasBackup = false
    @State var errorMessage: String?
    @State var successMessage: String?

    let workspaceService = SkillWorkspaceService.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Update \(skill.displayName)").font(.headline)
                    Text(skill.isGlobal ? "Global skill" : "Project skill").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close", action: onDismiss).keyboardShortcut(.escape)
            }
            .padding(16)
            Divider()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView("Fetching remote SKILL.md…")
                    Text("Comparing with local installation").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 32)).foregroundStyle(.orange)
                    Text(error).font(.callout).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
            } else if let preview {
                mainContent(preview)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .task { await loadPreview() }
        .task { hasBackup = await workspaceService.hasRollbackBackup(for: skill) }
    }
}
