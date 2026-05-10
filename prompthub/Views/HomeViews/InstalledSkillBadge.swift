import SwiftUI

struct InstalledSkillBadge: View {
    let title: String
    let icon: String
    let foreground: Color
    let background: Color

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
    }
}

// MARK: - CLI Status Indicator

struct CLIStatusIndicator: View {
    @ObservedObject var manager: CLIDirectoryAccessManager
    let onTap: () -> Void

    private var statusColor: Color {
        let total = CLIDirectory.allCases.count
        let granted = manager.grantedDirectories.count
        if granted == 0 { return .red }
        if granted < total { return .orange }
        return .green
    }

    private var statusLabel: String {
        let total = CLIDirectory.allCases.count
        let granted = manager.grantedDirectories.count
        if granted == 0 { return "No CLI access — tap to configure" }
        if granted < total { return "\(granted)/\(total) CLI directories accessible" }
        return "All CLI directories accessible"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                    .shadow(color: statusColor.opacity(0.5), radius: 2, x: 0, y: 0)
                Text("CLI")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help(statusLabel)
    }
}
