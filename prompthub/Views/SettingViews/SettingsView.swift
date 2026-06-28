import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI
import AppKit
import PromptHubSkillKit

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case aiService = "AI Service"
    case privateSources = "Sources"
    case cliSettings = "CLI Settings"
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            settingsToolbar
            Divider()

            SettingsScreenContainer {
                switch selectedTab {
                case .general:
                    GeneralTab()
                case .aiService:
                    AIServiceTab()
                case .privateSources:
                    PrivateSourcesTab()
                case .cliSettings:
                    CLISettingsTab()
                }
            }
        }
        .background(PH.Color.windowBg)
        .navigationTitle("Settings")
    }

    private var settingsToolbar: some View {
        HStack(spacing: 8) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                SettingsTabButton(
                    title: tab.rawValue,
                    isSelected: selectedTab == tab
                ) {
                    selectedTab = tab
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(PH.Color.windowBg)
    }
}

private struct GeneralTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsHero(
                eyebrow: "Preferences",
                title: "General",
                description: "Keep startup behavior and keyboard access in one place. These should stay quiet, obvious, and native."
            )

            SettingsCard(title: "Startup", icon: "power") {
                SettingsRow(
                    title: "Launch at login",
                    detail: "Start PromptHub automatically after you sign in."
                ) {
                    LaunchAtLogin.Toggle()
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            SettingsCard(title: "Keyboard", icon: "command") {
                SettingsRow(
                    title: "Quick Search",
                    detail: "Open global prompt search from anywhere on this Mac."
                ) {
                    KeyboardShortcuts.Recorder(for: KeyboardShortcuts.Name.toggleSearch)
                }
            }

            AboutSection()
        }
    }
}

private struct AIServiceTab: View {
    @EnvironmentObject private var appSettings: AppSettings
    @State private var showTemplateEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsHero(
                eyebrow: "Configuration",
                title: "AI Services",
                description: "Manage provider endpoints, tokens, and the default system prompt without mixing it into prompt browsing."
            )

            SettingsCard(title: "Providers", icon: "cpu") {
                ServicesView()
            }

            SettingsCard(title: "System Prompt", icon: "text.quote") {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView {
                        Text(appSettings.prompt)
                            .font(PH.Font.monoBody)
                            .foregroundStyle(PH.Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(12)
                    }
                    .frame(minHeight: 120, maxHeight: 220)
                    .background(PH.Color.buttonBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(PH.Color.buttonBorder, lineWidth: 1)
                    )

                    HStack {
                        Button("Reset to Default") {
                            appSettings.resetPromptToDefault()
                        }
                        .buttonStyle(PHChromeButtonStyle(emphasis: .standard))

                        Spacer()

                        Button("Edit Prompt") {
                            showTemplateEditor = true
                        }
                        .buttonStyle(PHChromeButtonStyle(emphasis: .accent))
                    }
                }
            }
        }
        .sheet(isPresented: $showTemplateEditor) {
            PromptTemplateEditor(text: $appSettings.prompt)
        }
    }
}

private struct PrivateSourcesTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsHero(
                eyebrow: "Team",
                title: "Private Sources",
                description: "Connect private GitHub repositories or shared folders so internal skills show up in the same workflow as public ones."
            )

            PrivateSkillSourcesView()
        }
    }
}

private struct CLISettingsTab: View {
    @ObservedObject private var cliAccessManager = CLIDirectoryAccessManager.shared
    private let workspaceService = SkillWorkspaceService.shared

    @State private var showingAccessManager = false
    @State private var selectedProjectRootURL: URL?

    private var grantedDirectorySummary: String {
        let names = cliAccessManager.grantedDirectories
            .map(\.displayName)
            .sorted()
        return names.isEmpty ? "No agent directories connected yet." : names.joined(separator: " · ")
    }

    private var selectedProjectLabel: String {
        selectedProjectRootURL?.path(percentEncoded: false) ?? "No project selected"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsHero(
                eyebrow: "Environment",
                title: "CLI Settings",
                description: "Manage agent-folder access and the active project folder used by project-scoped skill installs."
            )

            SettingsCard(title: "Agent Access", icon: "lock.shield") {
                SettingsRow(
                    title: "Authorized directories",
                    detail: grantedDirectorySummary
                ) {
                    Button("Grant Agent Access…") {
                        showingAccessManager = true
                    }
                    .buttonStyle(PHChromeButtonStyle(emphasis: .accent))
                }
            }

            SettingsCard(title: "Project Scope", icon: "folder.badge.gearshape") {
                SettingsRow(
                    title: "Active project folder",
                    detail: selectedProjectLabel
                ) {
                    HStack(spacing: 8) {
                        Button("Change…") {
                            chooseProjectRoot()
                        }
                        .buttonStyle(PHChromeButtonStyle(emphasis: .accent))

                        if selectedProjectRootURL != nil {
                            Button("Clear") {
                                workspaceService.setSelectedProjectRootURL(nil)
                                selectedProjectRootURL = nil
                            }
                            .buttonStyle(PHChromeButtonStyle(emphasis: .standard))
                        }
                    }
                }
            }
        }
        .task {
            selectedProjectRootURL = workspaceService.selectedProjectRootURL
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillProjectSelectionDidChange)) { _ in
            selectedProjectRootURL = workspaceService.selectedProjectRootURL
        }
        .sheet(isPresented: $showingAccessManager) {
            CLIAccessManagerView()
        }
    }

    private func chooseProjectRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose the project folder used for project-scoped skill installs."
        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        workspaceService.setSelectedProjectRootURL(selectedURL)
        selectedProjectRootURL = selectedURL
    }
}

private struct AboutSection: View {
    var body: some View {
        SettingsCard(title: "About", icon: "info.circle") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image("whale")
                        .resizable()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("PromptHub")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(PH.Color.primary)

                        HStack(spacing: 8) {
                            SettingsTag(text: "v\(SystemInfo.majorVersion as? String ?? "-")", tint: PH.Color.accent)
                            Text("Build \(SystemInfo.minorVersion as? String ?? "-")")
                                .font(PH.Font.rowSub)
                                .foregroundStyle(PH.Color.tertiary)
                        }
                    }

                    Spacer()
                }

                Divider()

                HStack(spacing: 10) {
                    Link("GitHub", destination: URL(string: "https://github.com/LeetaoGoooo/PromptHub")!)
                    Link("Website", destination: URL(string: "https://leetao.me")!)

                    Spacer()

                    Link(destination: URL(string: "https://t.me/prompt_box")!) {
                        Image("telegram")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                    .help("Telegram")

                    Link(destination: URL(string: "https://mp.weixin.qq.com/s/fxJXAQ9xapOxYy_97GNfmA")!) {
                        Image("wechat")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                    .help("WeChat")
                }
                .font(.system(size: 12, weight: .medium))

                Text("© 2025 Leetao. All rights reserved.")
                    .font(PH.Font.rowSub)
                    .foregroundStyle(PH.Color.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

private struct PromptTemplateEditor: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edit System Prompt")
                        .font(PH.Font.paneTitle)
                        .foregroundStyle(PH.Color.primary)
                    Text("Changes apply to new tests immediately.")
                        .font(PH.Font.rowSub)
                        .foregroundStyle(PH.Color.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(PHChromeButtonStyle(emphasis: .accent))
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(16)
            .background(PH.Color.windowBg)

            Divider()

            TextEditor(text: $text)
                .font(PH.Font.monoBody)
                .padding(12)
                .background(PH.Color.detailBg)
                .frame(minWidth: 620, minHeight: 420)
        }
        .background(PH.Color.windowBg)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
        .environment(ServicesManager())
        .frame(width: 760, height: 680)
}
