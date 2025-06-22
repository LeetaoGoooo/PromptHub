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
    @Attribute(.externalStorage)
    var data: Data
    var createdAt: Date
    
    var prompt: Prompt?

    init(data: Data, createdAt: Date = .now) {
        self.data = data
        self.createdAt = createdAt
    }
}
