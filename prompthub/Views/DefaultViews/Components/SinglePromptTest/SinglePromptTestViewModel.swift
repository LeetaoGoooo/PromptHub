//
//  SinglePromptTestViewModel.swift
//  prompthub
//
//  Created by leetao on 2025/9/2.
//

import Foundation
import GenKit
import SwiftUI
import AlertToast

@MainActor
@Observable
class SinglePromptTestViewModel {
    // MARK: - Core Data
    var userInput: String = ""
    var selectedServiceModels: Set<ServiceModel> = []
    var testResults: [ServiceModel: TestResult] = [:]
    var isGenerating = false
    
    // MARK: - UI State
    var showGlobalComparisonView = false
    var showToast = false
    var toastTitle = ""
    var toastType: AlertToast.AlertType = .regular
    
    // MARK: - Computed Properties
    private let servicesManager: ServicesManager
    private var cachedServiceModels: [ServiceModel] = []
    
    init(servicesManager: ServicesManager) {
        self.servicesManager = servicesManager
        self.cachedServiceModels = generateServiceModels()
        initializeDefaultSelection()
    }
    
    var availableServiceModels: [ServiceModel] {
        cachedServiceModels
    }
    
    var configuredServiceModels: [ServiceModel] {
        availableServiceModels.filter { !$0.service.token.isEmpty }
    }
    
    var unconfiguredServices: [Service] {
        Array(Set(availableServiceModels.filter { $0.service.token.isEmpty }.map { $0.service }))
    }
    
    var canRunTests: Bool {
        !userInput.isEmpty && !selectedServiceModels.isEmpty && !isGenerating && !configuredServiceModels.isEmpty
    }
    
    var canCompareAll: Bool {
        !testResults.isEmpty
    }
    
    // MARK: - Actions
    func toggleSelection(for serviceModel: ServiceModel) {
        if selectedServiceModels.contains(serviceModel) {
            selectedServiceModels.remove(serviceModel)
        } else {
            selectedServiceModels.insert(serviceModel)
        }
    }
    
    func selectAllModels() {
        selectedServiceModels = Set(configuredServiceModels)
    }
    
    func clearAllSelection() {
        selectedServiceModels.removeAll()
    }
    
    func runTests(with prompt: String) async {
        guard canRunTests else { return }
        
        isGenerating = true
        
        for serviceModel in selectedServiceModels {
            testResults[serviceModel] = TestResult(isLoading: true)
        }
        
        await withTaskGroup(of: Void.self) { group in
            for serviceModel in selectedServiceModels {
                group.addTask {
                    await self.runSingleTest(for: serviceModel, prompt: prompt)
                }
            }
        }
        
        isGenerating = false
    }
    
    func showToastMessage(_ message: String, type: AlertToast.AlertType = .error(Color.red)) {
        toastTitle = message
        toastType = type
        showToast = true
    }
    
    // MARK: - Private Methods
    private func generateServiceModels() -> [ServiceModel] {
        var models: [ServiceModel] = []
        for service in servicesManager.services {
            for model in service.models {
                models.append(ServiceModel(service: service, model: model))
            }
        }
        return models
    }
    
    private func initializeDefaultSelection() {
        let selectedServiceID = servicesManager.selectedServiceID
        if let selectedService = servicesManager.get(selectedServiceID),
           !selectedService.token.isEmpty,
           let preferredModelID = selectedService.preferredChatModel,
           let preferredModel = selectedService.models.first(where: { $0.id == preferredModelID }) {
            let defaultServiceModel = ServiceModel(service: selectedService, model: preferredModel)
            selectedServiceModels.insert(defaultServiceModel)
        }
    }
    
    private func runSingleTest(for serviceModel: ServiceModel, prompt: String) async {
        do {
            guard let chatService = serviceModel.service.modelService(session: nil) as? ChatService else {
                testResults[serviceModel] = TestResult(error: "Service does not support chat completion")
                return
            }
            
            var streamRequest = ChatSessionRequest(service: chatService, model: serviceModel.model)
            streamRequest.with(system: prompt)
            streamRequest.with(history: [Message(role: .user, content: userInput)])
            
            for try await message in ChatSession.shared.stream(streamRequest) {
                if let contentChunk = message.content {
                    testResults[serviceModel]?.content = contentChunk
                }
            }
            
            testResults[serviceModel]?.isLoading = false
            
        } catch {
            
            testResults[serviceModel] = TestResult(error: error.localizedDescription)
        }
    }
}
