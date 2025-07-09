//
//  ServiceStorage.swift
//  prompthub
//
//  Created by leetao on 2025/7/9.
//

import GenKit
import Foundation


struct ServiceStorage {
    private static let servicesKey = "savedServices"
    private static let selectedServiceIDKey = "selectedServiceID"
    
    func loadServices() -> [Service] {
        guard let data = UserDefaults.standard.data(forKey: Self.servicesKey) else {
            return Defaults.services
        }
        
        do {
            return try JSONDecoder().decode([Service].self, from: data)
        } catch {
            print("decoder error: \(error)")
            return Defaults.services
        }
    }
    
    func saveServices(_ services: [Service]) {
        do {
            let data = try JSONEncoder().encode(services)
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
