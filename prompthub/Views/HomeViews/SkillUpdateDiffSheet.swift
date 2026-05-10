import PromptHubSkillKit
import SwiftUI

/// Sheet that shows a line-by-line diff between the current local SKILL.md and the remote
/// version, then lets the user confirm (apply update) or cancel.
struct SkillUpdateDiffSheet: View {
    let skill: InstalledSkillSnapshot
    let onDismiss: () -> Void

    @State private var preview: SkillUpdatePreview?
    @State private var isLoading = true
    @State private var isApplying = false
    @State private var isRollingBack = false
    @State private var hasBackup = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let workspaceService = SkillWorkspaceService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Update \(skill.displayName)")
                        .font(.headline)
                    Text(skill.isGlobal ? "Global skill" : "Project skill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close", action: onDismiss)
                    .keyboardShortcut(.escape)
            }
            .padding(16)

            Divider()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView("Fetching remote SKILL.md…")
                    Text("Comparing with local installation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if let preview {
                mainContent(preview)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .task {
            await loadPreview()
        }
        .task {
            hasBackup = await workspaceService.hasRollbackBackup(for: skill)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(_ preview: SkillUpdatePreview) -> some View {
        VStack(spacing: 0) {
            // Status / summary bar
            statusBar(preview)

            Divider()

            // Diff view
            if preview.status == .upToDate {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                    Text("Already up to date")
                        .font(.headline)
                    Text("The local SKILL.md matches the remote version.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if preview.status == .updateAvailable, !preview.diffLines.isEmpty {
                diffScrollView(preview)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(statusDescription(preview.status))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }

            Divider()

            // Action bar
            actionBar(preview)
        }
    }

    // MARK: - Status Bar

    @ViewBuilder
    private func statusBar(_ preview: SkillUpdatePreview) -> some View {
        HStack(spacing: 16) {
            statusBadge(preview.status)

            if preview.status == .updateAvailable {
                Divider().frame(height: 20)
                Label("\(preview.addedLines) added", systemImage: "plus")
                    .font(.caption)
                    .foregroundStyle(.green)
                Label("\(preview.removedLines) removed", systemImage: "minus")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            if hasBackup {
                Label("Rollback available", systemImage: "arrow.uturn.backward.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func statusBadge(_ status: SkillUpdateStatus) -> some View {
        let (icon, label, color): (String, String, Color) = {
            switch status {
            case .upToDate: return ("checkmark.circle.fill", "Up to date", .green)
            case .updateAvailable: return ("arrow.down.circle.fill", "Update available", .blue)
            case .remoteUnavailable: return ("wifi.slash", "Remote unavailable", .secondary)
            case .noRemoteSource: return ("internaldrive", "No remote source", .secondary)
            case .notInstalled: return ("xmark.circle.fill", "Not installed locally", .red)
            }
        }()
        Label(label, systemImage: icon)
            .font(.callout.weight(.medium))
            .foregroundStyle(color)
    }

    // MARK: - Diff Scroll View

    @ViewBuilder
    private func diffScrollView(_ preview: SkillUpdatePreview) -> some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(preview.diffLines.enumerated()), id: \.offset) { _, line in
                    diffLineRow(line)
                }
            }
            .font(.system(size: 12, design: .monospaced))
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    @ViewBuilder
    private func diffLineRow(_ line: SkillDiffLine) -> some View {
        let (bg, fg): (Color, Color) = {
            switch line {
            case .added: return (Color.green.opacity(0.12), .green)
            case .removed: return (Color.red.opacity(0.12), .red)
            case .context: return (.clear, Color(NSColor.labelColor).opacity(0.7))
            }
        }()
        HStack(alignment: .top, spacing: 0) {
            Text(line.prefix)
                .foregroundStyle(fg)
                .frame(width: 18, alignment: .center)
                .padding(.vertical, 1)
                .background(bg.opacity(0.6))
            Text(line.text)
                .foregroundStyle(fg)
                .padding(.leading, 6)
                .padding(.vertical, 1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(bg)
    }

    // MARK: - Action Bar

    @ViewBuilder
    private func actionBar(_ preview: SkillUpdatePreview) -> some View {
        HStack(spacing: 10) {
            if let success = successMessage {
                Label(success, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            }

            Spacer()

            if hasBackup {
                Button {
                    Task { await performRollback(preview) }
                } label: {
                    if isRollingBack {
                        Label("Rolling back…", systemImage: "hourglass")
                    } else {
                        Label("Rollback to Previous", systemImage: "arrow.uturn.backward")
                    }
                }
                .disabled(isApplying || isRollingBack)
            }

            Button("Cancel", action: onDismiss)

            if preview.status == .updateAvailable {
                Button {
                    Task { await performApply(preview) }
                } label: {
                    if isApplying {
                        Label("Applying…", systemImage: "hourglass")
                    } else {
                        Label("Apply Update", systemImage: "arrow.down.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isApplying || isRollingBack)
            }
        }
        .padding(16)
    }

    // MARK: - Actions

    private func loadPreview() async {
        isLoading = true
        errorMessage = nil
        let result = await workspaceService.previewUpdate(for: skill)
        isLoading = false
        preview = result

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

    private func performApply(_ preview: SkillUpdatePreview) async {
        isApplying = true
        errorMessage = nil
        do {
            try await workspaceService.applyUpdate(preview: preview)
            hasBackup = await workspaceService.hasRollbackBackup(for: skill)
            successMessage = "Update applied successfully."
            NotificationCenter.default.post(name: .skillInstallationsDidChange, object: nil)
            // Refresh preview to show new state.
            let refreshed = await workspaceService.previewUpdate(for: skill)
            self.preview = refreshed
        } catch {
            errorMessage = "Failed to apply update: \(error.localizedDescription)"
        }
        isApplying = false
    }

    private func performRollback(_ preview: SkillUpdatePreview) async {
        isRollingBack = true
        errorMessage = nil
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

    private func statusDescription(_ status: SkillUpdateStatus) -> String {
        switch status {
        case .upToDate: return "Local and remote versions match."
        case .updateAvailable: return "An update is available."
        case .remoteUnavailable: return "Remote source could not be reached."
        case .noRemoteSource: return "No remote GitHub source for this skill."
        case .notInstalled: return "Local SKILL.md not found."
        }
    }
}
