//
//  GeneralView.swift
//  prompthub
//
//  Created by leetao on 2025/3/7.
//

import SwiftUI
import LaunchAtLogin
import UniformTypeIdentifiers

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
        VStack(alignment: .leading) {
            Text("General Settings")
                .font(.title)
                .padding(.bottom)

            HStack {
                Text("Launch:")
                Spacer()
                LaunchAtLogin.Toggle()
            }
            .padding(.bottom, 5)

            Section(header: Text("AI")) {
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
            }
            .padding(.bottom, 10)

            HStack {
                Spacer()
                Button("Quit") {
                    isQuitting = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 2)

            Section(header:
                        HStack(spacing: 12) {
                            Text("Test Result:")
                            if settings.isTestPassed  {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "x.circle")
                                    .foregroundColor(.red)
                            }
                        }
                    ) {
            }
            .padding(.bottom, 10)


        }
        .padding()
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



    private func showTestResult(success: Bool, message: String) {
        testResultAlert = IdentifiableAlert(
            alert: Alert(
                title: Text(success ? "Test Successful" : "Test Failed"),
                message: Text(message),
                dismissButton: .default(Text("OK"))
            )
        )
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
