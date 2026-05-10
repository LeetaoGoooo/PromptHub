import AppKit
import PromptHubSkillKit
import SwiftUI

// MARK: - Sub Views

extension SkillUpdateDiffSheet {

    @ViewBuilder
    func mainContent(_ preview: SkillUpdatePreview) -> some View {
        VStack(spacing: 0) {
            statusBar(preview)
            Divider()
            if preview.status == .upToDate {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 32)).foregroundStyle(.green)
                    Text("Already up to date").font(.headline)
                    Text("The local SKILL.md matches the remote version.").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if preview.status == .updateAvailable, !preview.diffLines.isEmpty {
                diffScrollView(preview)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill").font(.system(size: 32)).foregroundStyle(.secondary)
                    Text(statusDescription(preview.status)).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
            }
            Divider()
            actionBar(preview)
        }
    }

    @ViewBuilder
    func statusBar(_ preview: SkillUpdatePreview) -> some View {
        HStack(spacing: 16) {
            statusBadge(preview.status)
            if preview.status == .updateAvailable {
                Divider().frame(height: 20)
                Label("\(preview.addedLines) added", systemImage: "plus").font(.caption).foregroundStyle(.green)
                Label("\(preview.removedLines) removed", systemImage: "minus").font(.caption).foregroundStyle(.red)
            }
            Spacer()
            if hasBackup {
                Label("Rollback available", systemImage: "arrow.uturn.backward.circle.fill").font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8).background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    func statusBadge(_ status: SkillUpdateStatus) -> some View {
        let (icon, label, color): (String, String, Color) = {
            switch status {
            case .upToDate:         return ("checkmark.circle.fill", "Up to date", .green)
            case .updateAvailable:  return ("arrow.down.circle.fill", "Update available", .blue)
            case .remoteUnavailable: return ("wifi.slash", "Remote unavailable", Color(NSColor.secondaryLabelColor))
            case .noRemoteSource:   return ("internaldrive", "No remote source", Color(NSColor.secondaryLabelColor))
            case .notInstalled:     return ("xmark.circle.fill", "Not installed locally", .red)
            }
        }()
        Label(label, systemImage: icon).font(.callout.weight(.medium)).foregroundStyle(color)
    }

    @ViewBuilder
    func diffScrollView(_ preview: SkillUpdatePreview) -> some View {
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
    func diffLineRow(_ line: SkillDiffLine) -> some View {
        let (bg, fg): (Color, Color) = {
            switch line {
            case .added:   return (Color.green.opacity(0.12), .green)
            case .removed: return (Color.red.opacity(0.12), .red)
            case .context: return (.clear, Color(NSColor.labelColor).opacity(0.7))
            }
        }()
        HStack(alignment: .top, spacing: 0) {
            Text(line.prefix).foregroundStyle(fg).frame(width: 18, alignment: .center).padding(.vertical, 1).background(bg.opacity(0.6))
            Text(line.text).foregroundStyle(fg).padding(.leading, 6).padding(.vertical, 1).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(bg)
    }

    @ViewBuilder
    func actionBar(_ preview: SkillUpdatePreview) -> some View {
        HStack(spacing: 10) {
            if let success = successMessage {
                Label(success, systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.callout)
            }
            Spacer()
            if hasBackup {
                Button { Task { await performRollback(preview) } } label: {
                    isRollingBack ? Label("Rolling back…", systemImage: "hourglass") : Label("Rollback to Previous", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered).disabled(isApplying || isRollingBack)
            }
            Button("Cancel", action: onDismiss).keyboardShortcut(.escape)
            if preview.status == .updateAvailable {
                Button { Task { await performApply(preview) } } label: {
                    isApplying ? Label("Applying…", systemImage: "hourglass") : Label("Apply Update", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent).disabled(isApplying || isRollingBack)
            }
        }
        .padding(16)
    }

    func statusDescription(_ status: SkillUpdateStatus) -> String {
        switch status {
        case .upToDate:           return "Local and remote versions match."
        case .updateAvailable:    return "An update is available."
        case .remoteUnavailable:  return "Remote source could not be reached."
        case .noRemoteSource:     return "No remote GitHub source for this skill."
        case .notInstalled:       return "Local SKILL.md not found."
        }
    }
}
