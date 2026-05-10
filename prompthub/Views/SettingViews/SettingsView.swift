//
//  SettingView.swift
//  prompthub
//
//  Created by leetao on 2025/3/7.
//

import SwiftUI
import LaunchAtLogin
import KeyboardShortcuts

// MARK: - Settings Tab Enum

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case aiService = "AI Service"
    case privateSources = "Sources"
}

// MARK: - SettingsView

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                Group {
                    switch selectedTab {
                    case .general:      GeneralTab()
                    case .aiService:    AIServiceTab()
                    case .privateSources: PrivateSkillSourcesView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .navigationTitle("Settings")
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    var body: some View {
        VStack(spacing: 16) {
            // Startup + Keyboard Shortcuts
            SettingsSection(title: "General", icon: "gearshape") {
                SettingsRow(title: "Launch at login", detail: "Start PromptHub when you log in") {
                    LaunchAtLogin.Toggle()
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Divider().padding(.vertical, 2)

                SettingsRow(title: "Quick Search", detail: "Search prompts from anywhere on your Mac") {
                    KeyboardShortcuts.Recorder(for: KeyboardShortcuts.Name.toggleSearch)
                }
            }

            // About
            AboutSection()
        }
    }
}

// MARK: - AI Service Tab

private struct AIServiceTab: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var showTemplateEditor = false

    var body: some View {
        VStack(spacing: 16) {
            SettingsSection(title: "AI Provider", icon: "cpu") {
                ServicesView()
                    .padding(.vertical, 4)
            }

            SettingsSection(title: "System Prompt", icon: "text.quote") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(appSettings.prompt)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                        )

                    HStack {
                        Button("Reset to Default") { appSettings.resetPromptToDefault() }
                            .controlSize(.small)
                        Spacer()
                        Button { showTemplateEditor = true } label: {
                            Label("Edit", systemImage: "pencil.line")
                        }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .sheet(isPresented: $showTemplateEditor) {
                PromptTemplateEditor(text: $appSettings.prompt)
            }
        }
    }
}

// MARK: - Shared Sub-Views

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
            )
        }
    }
}

private struct SettingsRow<Control: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            control()
        }
        .padding(.vertical, 4)
    }
}

private struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("About", systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    Image("whale")
                        .resizable()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 11))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("PromptHub").font(.title3.bold())
                        HStack(spacing: 6) {
                            Text("v\(SystemInfo.majorVersion as! String)")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("Build \(SystemInfo.minorVersion as! String)")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                }

                Divider()

                HStack(spacing: 0) {
                    Link(destination: URL(string: "https://github.com/LeetaoGoooo/PromptHub")!) {
                        Label("GitHub", systemImage: "link").font(.caption)
                    }
                    .padding(.trailing, 14)

                    Link(destination: URL(string: "https://leetao.me")!) {
                        Label("Website", systemImage: "globe").font(.caption)
                    }

                    Spacer()

                    Link(destination: URL(string: "https://t.me/prompt_box")!) {
                        Image("telegram").resizable().scaledToFit().frame(width: 18, height: 18)
                    }
                    .help("Join Telegram")
                    .padding(.trailing, 10)

                    Link(destination: URL(string: "https://mp.weixin.qq.com/s/fxJXAQ9xapOxYy_97GNfmA")!) {
                        Image("wechat").resizable().scaledToFit().frame(width: 18, height: 18)
                    }
                    .help("Join WeChat")
                }

                Text("© 2025 Leetao. All rights reserved.")
                    .font(.caption2).foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Prompt Template Editor

private struct PromptTemplateEditor: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit System Prompt").font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .frame(minWidth: 560, minHeight: 400)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
        .frame(width: 600, height: 500)
}

