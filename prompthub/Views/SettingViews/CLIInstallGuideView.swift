import SwiftUI

// MARK: - CLI Install Guide View

/// An in-app guide that helps users install the PromptHub CLI.
/// Shown in Settings > General and as a dismissable startup banner.
struct CLIInstallGuideView: View {

    /// Whether the user has dismissed the banner for this session.
    @Binding var isDismissed: Bool

    @State private var cliPath: String? = nil
    @State private var copiedStep: Int? = nil

    private let brewCommand   = "brew install LeetaoGoooo/tap/prompthub"
    private let curlCommand   = """
        curl -fsSL https://raw.githubusercontent.com/LeetaoGoooo/PromptHub/main/install.sh | sh
        """
    private let verifyCommand = "prompthub agent doctor"

    var body: some View {
        if let path = cliPath {
            installedRow(path: path)
        } else {
            installGuide
        }
    }

    // MARK: - Installed State

    @ViewBuilder
    private func installedRow(path: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.green)
                .imageScale(.large)
            VStack(alignment: .leading, spacing: 2) {
                Text("PromptHub CLI is installed")
                    .font(.body.weight(.medium))
                Text(path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Install Guide

    private var installGuide: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header row
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.accentColor)
                    .imageScale(.large)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Install PromptHub CLI")
                        .font(.body.weight(.semibold))
                    Text("Give agents, scripts, and CI pipelines direct access to your prompts and skills — without opening the app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    isDismissed = true
                } label: {
                    Image(systemName: "xmark")
                        .imageScale(.small)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }

            Divider()

            // Option A — Homebrew
            installOption(
                step: 1,
                icon: "🍺",
                title: "Homebrew (recommended)",
                command: brewCommand
            )

            // Option B — curl
            installOption(
                step: 2,
                icon: "📦",
                title: "Manual (curl)",
                command: curlCommand
            )

            // Verify
            installOption(
                step: 3,
                icon: "✅",
                title: "Verify installation",
                command: verifyCommand
            )
        }
        .onAppear { refresh() }
    }

    // MARK: - Command Row

    @ViewBuilder
    private func installOption(step: Int, icon: String, title: String, command: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, image: "")
                .overlay(
                    HStack(spacing: 6) {
                        Text(icon)
                        Text(title)
                            .font(.caption.weight(.medium))
                    },
                    alignment: .leading
                )
                .font(.caption.weight(.medium))
                .opacity(0)  // invisible label used only for spacing

            HStack(spacing: 6) {
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.85))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    copiedStep = step
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if copiedStep == step { copiedStep = nil }
                    }
                } label: {
                    Image(systemName: copiedStep == step ? "checkmark" : "doc.on.doc")
                        .imageScale(.small)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help(copiedStep == step ? "Copied!" : "Copy to clipboard")
            }
        }
    }

    // MARK: - Helpers

    private func refresh() {
        cliPath = CLIDetector.installedPath()
    }
}

// MARK: - Startup Banner (one-time, dismissable)

/// A floating banner shown once per app session when CLI is not installed.
struct CLIStartupBanner: View {
    @AppStorage("cli_banner_dismissed_version") private var dismissedVersion: String = ""
    @State private var isDismissed: Bool = false

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        if !isDismissed && dismissedVersion != currentVersion && !CLIDetector.isInstalled() {
            VStack(alignment: .leading, spacing: 0) {
                CLIInstallGuideView(isDismissed: Binding(
                    get: { isDismissed },
                    set: {
                        isDismissed = $0
                        if $0 { dismissedVersion = currentVersion }
                    }
                ))
                .padding()
            }
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            .padding()
        }
    }
}

#Preview("Not installed") {
    CLIInstallGuideView(isDismissed: .constant(false))
        .frame(width: 480)
        .padding()
}
