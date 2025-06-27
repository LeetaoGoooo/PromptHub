//
//  ExternalSource.swift
//  prompthub
//
//  Created by leetao on 2025/6/21.
//


import Foundation
import SwiftData

@Model
final class ExternalSource {
    var id: UUID = UUID()
    @Attribute(.externalStorage)
    var data: Data = Data()
    var createdAt: Date = Date()
    
    var prompt: Prompt?

    init(data: Data, createdAt: Date = .now) {
        self.data = data
        self.createdAt = createdAt
    }
}
