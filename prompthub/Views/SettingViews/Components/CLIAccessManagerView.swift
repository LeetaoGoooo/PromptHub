import SwiftUI

struct CLIAccessManagerView: View {
    @ObservedObject private var accessManager = CLIDirectoryAccessManager.shared
    @Environment(\.dismiss) private var dismiss

    private var grantedCount: Int { accessManager.grantedDirectories.count }
    private var totalCount: Int { CLIDirectory.allCases.count }
    private var allGranted: Bool { grantedCount == totalCount }

    var body: some View {
        VStack(spacing: 0) {
            SettingsScreenContainer {
                SettingsHero(
                    eyebrow: "Permissions",
                    title: "CLI File Access",
                    description: "PromptHub needs directory access for each agent config location. In the Finder picker, press Cmd+Shift+. to reveal hidden folders.",
                    actions: AnyView(SettingsTag(text: "\(grantedCount)/\(totalCount) Authorized", tint: allGranted ? PH.Color.statusOK : PH.Color.statusWarn))
                )

                SettingsCard(title: "Directories", icon: "folder.badge.gearshape") {
                    VStack(spacing: 10) {
                        ForEach(CLIDirectory.allCases) { directory in
                            CLIAccessRow(
                                directory: directory,
                                isGranted: accessManager.grantedDirectories.contains(directory),
                                onGrant: { accessManager.requestAccess(for: directory) },
                                onRevoke: { accessManager.revokeAccess(for: directory) }
                            )
                        }
                    }
                }
            }

            Divider()

            HStack {
                if !allGranted {
                    Button("Authorize All") {
                        for dir in CLIDirectory.allCases where !accessManager.grantedDirectories.contains(dir) {
                            accessManager.requestAccess(for: dir)
                        }
                    }
                    .buttonStyle(PHChromeButtonStyle(emphasis: .standard))
                }

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(PHChromeButtonStyle(emphasis: .accent))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(PH.Color.windowBg)
        }
        .frame(width: 620, height: 560)
        .background(PH.Color.windowBg)
    }
}

private struct CLIAccessRow: View {
    let directory: CLIDirectory
    let isGranted: Bool
    let onGrant: () -> Void
    let onRevoke: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((isGranted ? PH.Color.statusOK : PH.Color.tertiary).opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: isGranted ? "checkmark.lock.fill" : "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isGranted ? PH.Color.statusOK : PH.Color.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(directory.displayName)
                    .font(PH.Font.rowName)
                    .foregroundStyle(PH.Color.primary)
                Text("~/\(directory.rawValue)/")
                    .font(PH.Font.mono)
                    .foregroundStyle(PH.Color.secondary)
            }

            Spacer()

            Button(isGranted ? "Revoke" : "Grant Access") {
                isGranted ? onRevoke() : onGrant()
            }
            .buttonStyle(PHChromeButtonStyle(emphasis: isGranted ? .standard : .accent))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(PH.Color.buttonBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PH.Color.buttonBorder, lineWidth: 1)
        )
    }
}
