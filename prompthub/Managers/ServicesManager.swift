//
//  ServicesManager.swift
//  prompthub
//
//  Created by leetao on 2025/7/7.
//


import Foundation
import Observation
import GenKit
import SwiftUI


@Observable
@MainActor
class ServicesManager {
    
    var services: [Service] {
        didSet {
            storage.saveServices(services)
        }
    }
    
    var selectedServiceID: String {
        didSet {
            storage.saveSelectedServiceID(selectedServiceID)
        }
    }
    
    private let storage = ServiceStorage()
    
    init() {
        self.services = storage.loadServices()
        self.selectedServiceID = storage.loadSelectedServiceID()
    }

    func get(_ serviceID: String?) -> Service? {
        services.first(where: { $0.id == serviceID })
    }

    func update(service: Service) {
        guard let index = services.firstIndex(where: { $0.id == service.id }) else { return }
        services[index] = service
    }
    
    func resetToDefaults() {
        self.services = Defaults.services
        self.selectedServiceID = "openAI"
    }
}
