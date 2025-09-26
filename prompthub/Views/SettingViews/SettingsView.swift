//
//  SettingView.swift
//  prompthub
//
//  Created by leetao on 2025/3/7.
//

import SwiftUI
import LaunchAtLogin
import KeyboardShortcuts

struct SettingsView: View {
    @State private var selectedSetting: SettingItem? = .general

    enum SettingItem: String, CaseIterable, Identifiable {
        case general = "General"
        case about = "About"

        var id: Self { self }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingItem.allCases) { setting in // Sidebar List
                NavigationLink(
                    destination: settingView(for: setting), // Content view based on selected setting
                    tag: setting,
                    selection: $selectedSetting
                ) {
                    Text(setting.rawValue)
                }
            }
        } detail: {
            settingView(for: selectedSetting ?? .general)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func settingView(for setting: SettingItem) -> some View {
        Group {  // Use Group to simplify the view construction
            switch setting {
                case .general:
                    GeneralFormView()
                case .about:
                    AboutContentView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)  // Apply consistent padding to all views
    }

    private struct GeneralFormView: View {
        @EnvironmentObject var settings: AppSettings
        @State private var isQuitting: Bool = false

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // General Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("General Settings")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Text("Launch:")
                            Spacer()
                            LaunchAtLogin.Toggle()
                        }
                        .padding(.vertical, 2)
                    }
                    
                    // Keyboard Shortcuts
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Keyboard Shortcuts")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Quick Search:")
                                Spacer()
                                KeyboardShortcuts.Recorder(for: KeyboardShortcuts.Name.toggleSearch)
                            }
                            
                            Text("Press the keyboard shortcut to quickly search for prompts from anywhere in the app.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 128)
                        }
                    }
                    
                    // AI Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading) {
                            ServicesView()
                            
                            VStack(alignment:.leading){
                                Text("Template")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)

                                TextEditor(text: $settings.prompt)
                                     .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minHeight: 160)
                                    .padding(.bottom, 5)
                                    .padding(.leading, 6)
                                
                            }
                        }
                        .padding(.top, 8)
                    }

                    Spacer() // Push the quit button to the bottom

                    HStack {
                        Spacer()
                        Button("Quit") {
                            isQuitting = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.top, 8) // Add some top padding to match header spacing
            }
            .scrollIndicators(.never)
            .alert(isPresented: $isQuitting) {
                Alert(
                    title: Text("Quit Application?"),
                    message: Text("Are you sure you want to quit?"),
                    primaryButton: .destructive(Text("Quit")) {
                        NSApplication.shared.terminate(self)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

#Preview {
    return SettingsView()
        .environmentObject(AppSettings())
}
