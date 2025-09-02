//
//  SinglePromptTestView.swift
//  prompthub
//
//  Created by leetao on 2025/9/2.
//

import AlertToast
import GenKit
import SwiftUI

struct SinglePromptTestView: View {
    let prompt: String
    
    @State private var userInput: String = ""
    @State private var selectedServiceModels: Set<ServiceModel> = []
    @State private var testResults: [ServiceModel: TestResult] = [:]
    @State private var isGenerating = false
    
    @State private var showToast = false
    @State private var toastTitle = ""
    @State private var toastType: AlertToast.AlertType = .regular
    
    @Environment(ServicesManager.self) private var servicesManager
    @Environment(\.dismiss) private var dismiss
    
    struct ServiceModel: Hashable, Identifiable {
        let service: Service
        let model: Model
        
        // Use meaningful ID instead of random UUID
        var id: String {
            "\(service.id)-\(model.id)"
        }
        
        var displayName: String {
            "\(service.name) - \(model.id)"
        }
        
        // Proper equality based on actual content
        func hash(into hasher: inout Hasher) {
            hasher.combine(service.id)
            hasher.combine(model.id)
        }
        
        static func == (lhs: ServiceModel, rhs: ServiceModel) -> Bool {
            lhs.service.id == rhs.service.id && lhs.model.id == rhs.model.id
        }
    }
    
    struct TestResult {
        var content: String = ""
        var isLoading: Bool = false
        var error: String? = nil
    }
    
    // Cache the service models to avoid recreation
    @State private var cachedServiceModels: [ServiceModel] = []
    
    var availableServiceModels: [ServiceModel] {
        if cachedServiceModels.isEmpty {
            // Only compute once, then cache
            return generateServiceModels()
        }
        return cachedServiceModels
    }
    
    private func generateServiceModels() -> [ServiceModel] {
        var models: [ServiceModel] = []
        for service in servicesManager.services {
            for model in service.models {
                models.append(ServiceModel(service: service, model: model))
            }
        }
        return models
    }
    
    var configuredServiceModels: [ServiceModel] {
        return availableServiceModels.filter { !$0.service.token.isEmpty }
    }
    
    var unconfiguredServices: [Service] {
        return Array(Set(availableServiceModels.filter { $0.service.token.isEmpty }.map { $0.service }))
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar for model selection
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Models")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Choose one or more models to test")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        // Configured models
                        if !configuredServiceModels.isEmpty {
                            ForEach(configuredServiceModels, id: \.id) { serviceModel in
                                HStack(alignment: .top, spacing: 12) {
                                    Button {
                                        if selectedServiceModels.contains(serviceModel) {
                                            selectedServiceModels.remove(serviceModel)
                                        } else {
                                            selectedServiceModels.insert(serviceModel)
                                        }
                                    } label: {
                                        Image(systemName: selectedServiceModels.contains(serviceModel) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(selectedServiceModels.contains(serviceModel) ? .accentColor : .secondary)
                                            .font(.system(size: 16))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(serviceModel.service.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(serviceModel.model.id)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // Unconfigured services section
                        if !unconfiguredServices.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Unconfigured Services")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                
                                Text("These services need API tokens to be used:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            ForEach(unconfiguredServices, id: \.id) { service in
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 14))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(service.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text("API token required")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Configure") {
                                        // TODO: Open settings to configure this service
                                        showToastMsg(msg: "Please configure \(service.name) in Settings", alertType: .regular)
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                Spacer()
                
                if !configuredServiceModels.isEmpty {
                    VStack(spacing: 12) {
                        Button("Select All") {
                            selectedServiceModels = Set(configuredServiceModels)
                        }
                        .buttonStyle(.borderless)
                        .disabled(selectedServiceModels.count == configuredServiceModels.count)
                        
                        Button("Clear All") {
                            selectedServiceModels.removeAll()
                        }
                        .buttonStyle(.borderless)
                        .disabled(selectedServiceModels.isEmpty)
                    }
                }
            }
            .padding(16)
            .frame(minWidth: 250)
        } detail: {
            // Main content area
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Single Prompt Test")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text("Test your prompt across multiple models")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .background(Color.clear)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Close")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Test input section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test Content")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextEditor(text: $userInput)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .frame(minHeight: 120, maxHeight: 200)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                // Control buttons
                HStack {
                    if configuredServiceModels.isEmpty {
                        Text("No configured services available")
                            .foregroundColor(.orange)
                            .font(.caption)
                    } else {
                        Text("\(selectedServiceModels.count) of \(configuredServiceModels.count) models selected")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Button {
                        Task {
                            await runTests()
                        }
                    } label: {
                        Label("Run Tests", systemImage: "play.fill")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(8)
                    }
                    .disabled(userInput.isEmpty || selectedServiceModels.isEmpty || isGenerating || configuredServiceModels.isEmpty)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                
                // Results section
                if !testResults.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(selectedServiceModels).sorted(by: { $0.displayName < $1.displayName }), id: \.id) { serviceModel in
                                resultCard(for: serviceModel)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, minHeight: 700)
        .toast(isPresenting: $showToast) {
            AlertToast(type: toastType, title: toastTitle)
        }
        .onAppear {
            // Initialize the cache first
            cachedServiceModels = generateServiceModels()
            
            // Auto-select the currently configured service/model if available
            let selectedServiceID = servicesManager.selectedServiceID
            if let selectedService = servicesManager.get(selectedServiceID),
               !selectedService.token.isEmpty,
               let preferredModelID = selectedService.preferredChatModel,
               let preferredModel = selectedService.models.first(where: { $0.id == preferredModelID }) {
                let defaultServiceModel = ServiceModel(service: selectedService, model: preferredModel)
                selectedServiceModels.insert(defaultServiceModel)
            }
        }
    }
    
    @ViewBuilder
    private func resultCard(for serviceModel: ServiceModel) -> some View {
        let result = testResults[serviceModel] ?? TestResult()
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(serviceModel.service.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(serviceModel.model.id)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if result.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if result.error != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }
            
            if let error = result.error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            } else {
                ScrollView {
                    Text(result.content.isEmpty ? "No result yet..." : result.content)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(result.content.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .frame(maxHeight: 300)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func runTests() async {
        guard !selectedServiceModels.isEmpty && !userInput.isEmpty else { return }
        
        isGenerating = true
        
        // Initialize results for all selected models
        for serviceModel in selectedServiceModels {
            testResults[serviceModel] = TestResult(isLoading: true)
        }
        
        // Run tests concurrently
        await withTaskGroup(of: Void.self) { group in
            for serviceModel in selectedServiceModels {
                group.addTask {
                    await self.runSingleTest(for: serviceModel)
                }
            }
        }
        
        isGenerating = false
    }
    
    private func runSingleTest(for serviceModel: ServiceModel) async {
        do {
            guard let chatService = serviceModel.service.modelService(session: nil) as? ChatService else {
                await MainActor.run {
                    testResults[serviceModel] = TestResult(error: "Service does not support chat completion")
                }
                return
            }
            
            var streamRequest = ChatSessionRequest(service: chatService, model: serviceModel.model)
            streamRequest.with(system: prompt)
            streamRequest.with(history: [Message(role: .user, content: userInput)])
            
            var accumulatedContent = ""
            
            for try await message in ChatSession.shared.stream(streamRequest) {
                if let contentChunk = message.content {
                    accumulatedContent = contentChunk
                    await MainActor.run {
                        testResults[serviceModel] = TestResult(content: accumulatedContent, isLoading: true)
                    }
                }
            }
            
            await MainActor.run {
                testResults[serviceModel] = TestResult(content: accumulatedContent, isLoading: false)
            }
            
        } catch {
            await MainActor.run {
                testResults[serviceModel] = TestResult(error: error.localizedDescription)
            }
        }
    }
    
    @MainActor
    private func showToastMsg(msg: String, alertType: AlertToast.AlertType = .error(Color.red)) {
        showToast.toggle()
        toastTitle = msg
        toastType = alertType
    }
}

#Preview {
    SinglePromptTestView(prompt: "You are a helpful AI assistant. Please respond to the user's question clearly and concisely.")
        .environment(ServicesManager())
}
