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
    case shortcuts = "Shortcuts"
    case privateSources = "Private Sources"
}

// MARK: - SettingsView

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented Control
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            Divider()
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .general:
                        GeneralTab()
                    case .aiService:
                        AIServiceTab()
                    case .shortcuts:
                        ShortcutsTab()
                    case .privateSources:
                        PrivateSkillSourcesView()
                    }
                }
                .padding(24)
                .frame(maxWidth: 540, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Settings")
        .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    var body: some View {
        // Launch at Login
        GroupBox {
            HStack {
                Text("Launch at login")
                Spacer()
                LaunchAtLogin.Toggle()
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.vertical, 4)
        } label: {
            Label("Startup", systemImage: "power")
                .font(.headline)
        }
        
        // About
        GroupBox {
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    Image("whale")
                        .resizable()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PromptHub")
                            .font(.title3.bold())
                        HStack(spacing: 4) {
                            Text("v\(SystemInfo.majorVersion as! String)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("· Build \(SystemInfo.minorVersion as! String)")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                HStack(spacing: 16) {
                    Link(destination: URL(string: "https://github.com/LeetaoGoooo/PromptHub")!) {
                        Label("GitHub", systemImage: "link")
                            .font(.caption)
                    }
                    
                    Link(destination: URL(string: "https://leetao.me")!) {
                        Label("Website", systemImage: "globe")
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Link(destination: URL(string: "https://t.me/prompt_box")!) {
                        Image("telegram")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                    .help("Join Telegram")
                    
                    Link(destination: URL(string: "https://mp.weixin.qq.com/s/fxJXAQ9xapOxYy_97GNfmA")!) {
                        Image("wechat")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                    .help("Join WeChat")
                }
                
                Text("© 2025 Leetao. All rights reserved.")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.5))
            }
        } label: {
            Label("About", systemImage: "info.circle")
                .font(.headline)
        }
    }
}

// MARK: - AI Service Tab

private struct AIServiceTab: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var showTemplateEditor = false
    
    var body: some View {
        // Service Configuration
        GroupBox {
            ServicesView()
        } label: {
            Label("Provider", systemImage: "cpu")
                .font(.headline)
        }
        
        // Prompt Template
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                // Preview (collapsed, 3 lines)
                Text(appSettings.prompt)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                
                HStack {
                    Button("Reset to Default") {
                        appSettings.resetPromptToDefault()
                    }
                    .controlSize(.small)
                    
                    Spacer()
                    
                    Button {
                        showTemplateEditor = true
                    } label: {
                        Label("Edit Template", systemImage: "pencil.line")
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                }
            }
        } label: {
            Label("System Prompt", systemImage: "text.quote")
                .font(.headline)
        }
        .sheet(isPresented: $showTemplateEditor) {
            PromptTemplateEditor(text: $appSettings.prompt)
        }
    }
}

// MARK: - Prompt Template Editor (Sheet)

private struct PromptTemplateEditor: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit System Prompt")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Editor
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .frame(minWidth: 560, minHeight: 400)
        }
    }
}

// MARK: - Shortcuts Tab

private struct ShortcutsTab: View {
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quick Search")
                            .font(.body)
                        Text("Search prompts from anywhere in the app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    KeyboardShortcuts.Recorder(for: KeyboardShortcuts.Name.toggleSearch)
                }
                .padding(.vertical, 4)
            }
        } label: {
            Label("Keyboard Shortcuts", systemImage: "keyboard")
                .font(.headline)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
        .frame(width: 600, height: 500)
}
