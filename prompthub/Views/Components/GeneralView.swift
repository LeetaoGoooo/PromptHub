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

            Section(header: Text("OpenAI Configuration")) {
                VStack(alignment: .leading) {
                    Text("API Key")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    SecureField("Enter your OpenAI API Key", text: settings.$openaiApiKey)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom, 5)
                        .onChange(of: settings.openaiApiKey) { _ in
                            updateTestButtonStatus()
                        }

                    Text("Base URL (OpenAI API)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    TextField("Enter your Base URL", text: settings.$baseURL)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom, 5)
                        .onChange(of: settings.baseURL) { _ in
                            updateTestButtonStatus()
                        }

                    Text("Model")
                       .font(.subheadline)
                        .foregroundColor(.gray)
                     
                    Picker("", selection: settings.$model) {
                        ForEach(OpenAIModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 5)
                        
                    Text("Template")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    TextEditor(text: settings.$prompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 160)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom, 5)
                }
                .padding(.vertical, 2)
            }
            .padding(.bottom, 10)

            HStack {
                Spacer()
                Button("Test") {
                    testConnectivityToOpenAI()
                }
                .buttonStyle(.borderedProminent)
                .disabled(testButtonDisabled)
                .overlay(alignment: .center) {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }
                }


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
        .onAppear {
            updateTestButtonStatus()
        }
    }

    private func updateTestButtonStatus() {
        testButtonDisabled = settings.openaiApiKey.isEmpty || settings.baseURL.isEmpty
    
        if testButtonDisabled {
            settings.isTestPassed = false
        }
    }


    private func testConnectivityToOpenAI() {
        guard !settings.baseURL.isEmpty, !settings.openaiApiKey.isEmpty else { return }

        isTesting = true
        testResultAlert = nil

        let urlString = settings.baseURL.starts(with: "http") ? settings.baseURL : "https://" + settings.baseURL
        guard let url = URL(string: urlString + "/models") else {
            showTestResult(success: false, message: "Invalid URL format.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(settings.openaiApiKey)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isTesting = false
                if let error = error {
                    let errorMessage = "Network error: \(error.localizedDescription)"
                    updateTestResultInAppStorage(success: false, message: errorMessage)
                    showTestResult(success: false, message: errorMessage)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    let errorMessage = "Invalid response from OpenAI API."
                    updateTestResultInAppStorage(success: false, message: errorMessage)
                    showTestResult(success: false, message: errorMessage)
                    return
                }

                if (200...299).contains(httpResponse.statusCode) {
                    let successMessage = "OpenAI API connectivity test successful! Status code: \(httpResponse.statusCode)"
                    updateTestResultInAppStorage(success: true, message: successMessage)
                    showTestResult(success: true, message: successMessage)
                } else {
                    var errorMessage = "OpenAI API connectivity test failed. Status code: \(httpResponse.statusCode)"
                    if let data = data, let errorDetails = String(data: data, encoding: .utf8) {
                        errorMessage += "\nDetails: \(errorDetails)"
                    }
                    updateTestResultInAppStorage(success: false, message: errorMessage)
                    showTestResult(success: false, message: errorMessage)
                }
            }
        }.resume()
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
}
