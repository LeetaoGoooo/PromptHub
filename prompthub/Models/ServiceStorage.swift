//
//  ServiceStorage.swift
//  prompthub
//
//  Created by leetao on 2025/7/9.
//

import GenKit
import Foundation


struct ServiceStorage {
    private struct PersistedService: Codable {
        let id: String
        let name: String
        let host: String
        let token: String
        let preferredChatModel: String?
        let preferredImageModel: String?
        let preferredEmbeddingModel: String?
        let preferredTranscriptionModel: String?
        let preferredSpeechModel: String?
        let preferredSummarizationModel: String?

        init(service: Service) {
            id = service.id
            name = service.name
            host = service.host
            token = service.token
            preferredChatModel = service.preferredChatModel
            preferredImageModel = service.preferredImageModel
            preferredEmbeddingModel = service.preferredEmbeddingModel
            preferredTranscriptionModel = service.preferredTranscriptionModel
            preferredSpeechModel = service.preferredSpeechModel
            preferredSummarizationModel = service.preferredSummarizationModel
        }

        func makeService() -> Service? {
            guard let serviceID = Service.ServiceID(rawValue: id) else {
                return nil
            }

            return Service(
                id: serviceID,
                name: name,
                host: host,
                token: token,
                models: [],
                preferredChatModel: preferredChatModel,
                preferredImageModel: preferredImageModel,
                preferredEmbeddingModel: preferredEmbeddingModel,
                preferredTranscriptionModel: preferredTranscriptionModel,
                preferredSpeechModel: preferredSpeechModel,
                preferredSummarizationModel: preferredSummarizationModel
            )
        }
    }

    private static let servicesKey = "savedServices"
    private static let selectedServiceIDKey = "selectedServiceID"
    
    func loadServices() -> [Service] {
        guard let data = UserDefaults.standard.data(forKey: Self.servicesKey) else {
            return Defaults.services
        }
        
        do {
            let persisted = try JSONDecoder().decode([PersistedService].self, from: data)
            return persisted.compactMap { $0.makeService() }
        } catch {
            print("decoder error: \(error)")
            return Defaults.services
        }
    }
    
    func saveServices(_ services: [Service]) {
        do {
            let persisted = services.map(PersistedService.init(service:))
            let data = try JSONEncoder().encode(persisted)
            UserDefaults.standard.set(data, forKey: Self.servicesKey)
        } catch {
            print("encoder error: \(error)")
        }
    }
    
    func loadSelectedServiceID() -> String {
        return UserDefaults.standard.string(forKey: Self.selectedServiceIDKey) ?? "openAI"
    }
    
    func saveSelectedServiceID(_ id: String) {
        UserDefaults.standard.set(id, forKey: Self.selectedServiceIDKey)
    }
}
