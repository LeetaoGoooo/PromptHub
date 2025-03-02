//
//  PromptHistory.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import SwiftData
import Foundation

@Model
class PromptHistory {
    var id: UUID;
    var promptId: UUID;
    var prompt:String;
    var createdAt: Date;
    var updatedAt: Date;
    var version: Int;
    
    init(id: UUID = UUID(), promptId: UUID, prompt: String, createdAt: Date = Date(), updatedAt: Date = Date(), version: Int = 0) {
        self.id = id;
        self.promptId = promptId;
        self.prompt = prompt;
        self.createdAt = createdAt;
        self.updatedAt = updatedAt;
        self.version = version;        
    }
}
