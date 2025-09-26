//
//  GeneralView.swift
//  prompthub
//
//  Created by leetao on 2025/3/7.
//

import SwiftUI
import LaunchAtLogin
import UniformTypeIdentifiers
import KeyboardShortcuts

struct IdentifiableAlert: Identifiable {
    let id = UUID()
    let alert: Alert
}

struct GeneralView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var isQuitting: Bool = false;
    @State private var testButtonDisabled: Bool = true;
    @State private var isTesting: Bool = false;
    @State private var testResultAlert: IdentifiableAlert? = nil;

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 20) {
                // General Settings
                HStack {
                    Text("Launch:")
                    Spacer()
                    LaunchAtLogin.Toggle()
                }
                
                // Keyboard Shortcuts
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
                
                // AI Section
                VStack(alignment: .leading) {
                    ServicesView()
                    
                    VStack(alignment:.leading){
                        Text("Template")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        TextEditor(text: settings.$prompt)
                             .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 160)
                            .padding(.bottom, 5)
                            .padding(.leading, 6)
                        
                    }
                }
                .padding(.vertical, 2)

                HStack {
                    Spacer()
                    Button("Quit") {
                        isQuitting = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
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
        .alert(item: $testResultAlert) { identifiableAlert in
            identifiableAlert.alert
        }
    }



    private func updateTestResultInAppStorage(success: Bool, message: String) {
        settings.isTestPassed = success
    }

    private func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

#Preview {
    GeneralView()
        .environmentObject(AppSettings())
        .environment(ServicesManager())
}
