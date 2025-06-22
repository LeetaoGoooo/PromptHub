//
//  PromptHistory.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import SwiftData
import Foundation

@Model
final class PromptHistory {
    var id: UUID = UUID()
    var promptText: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var version: Int = 0
    
    var legacyPromptId: UUID?
    
    @Relationship var prompt: Prompt?
    
    init(id: UUID = UUID(), promptText: String, createdAt: Date = Date(), updatedAt: Date = Date(), version: Int = 0) {
        self.id = id
        self.promptText = promptText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }
}

extension PromptHistory {
    var content: String {
        get { promptText }
        set { promptText = newValue }
    }
}
