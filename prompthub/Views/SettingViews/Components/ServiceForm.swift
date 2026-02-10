//
//  ServiceForm.swift
//  prompthub
//
//  Created by leetao on 2025/7/7.
//

import GenKit
import OSLog
import SwiftUI

struct ServiceForm: View {
    @Binding var service: Service
    @Environment(ServicesManager.self) private var servicesManager

    @State private var isLoadingModels = false
    @State private var showToken = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Host
            VStack(alignment: .leading, spacing: 4) {
                Text("Host")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                TextField("https://api.openai.com/v1", text: $service.host)
                    .autocorrectionDisabled()
                    .textContentType(.URL)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: service.host) { _ in
                        servicesManager.update(service: service)
                    }
            }

            // Token
            VStack(alignment: .leading, spacing: 4) {
                Text("Token")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                HStack(spacing: 6) {
                    if showToken {
                        TextField("sk-...", text: $service.token)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("sk-...", text: $service.token)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button {
                        showToken.toggle()
                    } label: {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(showToken ? "Hide token" : "Show token")
                }
                .onChange(of: service.token) { _ in
                    servicesManager.update(service: service)
                }
            }

            // Models
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Model")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    if isLoadingModels {
                        ProgressView()
                            .scaleEffect(0.5)
                    } else {
                        Button {
                            handleLoadModels()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Refresh models")
                    }
                }
                ServiceModelPicker(service.models, selection: $service.preferredChatModel, onSelectionChange: {
                    servicesManager.update(service: service)
                })
            }
        }
        .onAppear(perform: handleLoadModels)
    }

    func handleLoadModels() {
        guard !isLoadingModels else { return }
        isLoadingModels = true
        Task {
            do {
                let client = service.modelService(session: nil)
                let fetchedModels = try await client.models()
                self.service.models = fetchedModels
                servicesManager.update(service: service)
            } catch {
                print("Failed to load models for \(service.name): \(error)")
            }
            isLoadingModels = false
        }
    }
}

struct ServiceModelPicker: View {
    let models: [Model]
    @Binding var selection: String?
    let onSelectionChange: () -> Void

    init(_ models: [Model], selection: Binding<String?>, onSelectionChange: @escaping () -> Void = {}) {
        self.models = models
        self._selection = selection
        self.onSelectionChange = onSelectionChange
    }

    var body: some View {
        Picker("", selection: $selection) {
            Text("Not Set").tag(String?.none)
            Divider()
            ForEach(models.sorted(by: { $0.id < $1.id })) { model in
                Text(model.name ?? model.id).tag(model.id as String?)
            }
        }
        .onChange(of: selection) { _ in
            onSelectionChange()
        }
    }
}
