import SwiftUI

struct CLIAccessManagerView: View {
    @ObservedObject private var accessManager = CLIDirectoryAccessManager.shared
    @Environment(\.dismiss) private var dismiss

    private var grantedCount: Int { accessManager.grantedDirectories.count }
    private var totalCount: Int { CLIDirectory.allCases.count }
    private var allGranted: Bool { grantedCount == totalCount }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ───────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("CLI File Access", systemImage: "lock.shield")
                        .font(.title2.bold())
                    Spacer()
                    // Overall status badge
                    HStack(spacing: 5) {
                        Circle()
                            .fill(grantedCount > 0 ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text("\(grantedCount)/\(totalCount) Authorized")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Capsule())
                }

                Text("PromptHub needs permission to read and write each agent's config directory. Press **Cmd+Shift+.** in the Finder panel to show hidden folders.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()

            // ── Agent list ───────────────────────────────────────────────
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(CLIDirectory.allCases) { directory in
                        CLIAccessRow(
                            directory: directory,
                            isGranted: accessManager.grantedDirectories.contains(directory),
                            onGrant: { accessManager.requestAccess(for: directory) },
                            onRevoke: { accessManager.revokeAccess(for: directory) }
                        )
                        if directory != CLIDirectory.allCases.last {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
            }
            .frame(minHeight: 300)

            Divider()

            // ── Footer ───────────────────────────────────────────────────
            HStack {
                if !allGranted {
                    Button {
                        for dir in CLIDirectory.allCases where !accessManager.grantedDirectories.contains(dir) {
                            accessManager.requestAccess(for: dir)
                        }
                    } label: {
                        Label("Authorize All", systemImage: "lock.open")
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Row

private struct CLIAccessRow: View {
    let directory: CLIDirectory
    let isGranted: Bool
    let onGrant: () -> Void
    let onRevoke: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Status circle
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.12) : Color(NSColor.separatorColor).opacity(0.25))
                    .frame(width: 38, height: 38)
                Image(systemName: isGranted ? "checkmark.lock.fill" : "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isGranted ? .green : .secondary)
            }

            // Name + path
            VStack(alignment: .leading, spacing: 2) {
                Text(directory.displayName)
                    .font(.callout.weight(.medium))
                Text("~/\(directory.rawValue)/")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }

            Spacer()

            // Action button
            if isGranted {
                Button("Revoke") { onRevoke() }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
            } else {
                Button("Grant Access") { onGrant() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

