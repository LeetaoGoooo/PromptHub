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

    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text("Host")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                TextField("", text: $service.host)
                    .autocorrectionDisabled()
                    .textContentType(.URL)
                    .padding(.leading, 6)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: service.host) { _ in
                        servicesManager.update(service: service)
                    }
            }

            VStack(alignment: .leading) {
                Text("Token")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                TextField("", text: $service.token)
                    .autocorrectionDisabled()
                    .padding(.leading, 6)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: service.token) { _ in
                        servicesManager.update(service: service)
                    }
            }

            VStack(alignment: .center) {
                HStack {
                    Text("Models")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    if isLoadingModels {
                        ProgressView()
                            .scaleEffect(0.5)
                    } else {
                        Spacer()
                        Button {
                            handleLoadModels()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                    }
                }
                ServiceModelPicker(service.models, selection: $service.preferredChatModel, onSelectionChange: {
                    servicesManager.update(service: service)
                })
            }
        }
        .navigationTitle(service.name)
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
