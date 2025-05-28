//
//  SharedCreation.swift
//  prompthub
//
//  Created by leetao on 2025/5/28.
//

import Foundation
import SwiftData

@Model
final class SharedCreation {
//    @Attribute(.unique)
    var id: UUID = UUID() 
    var name: String = ""
    var prompt: String = ""
    var externalSource: [Data]? = nil
    
    init(id: UUID = UUID(), name: String, prompt: String, externalSource: [Data]? = nil) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.externalSource = externalSource
    }
    
    func makeLocalCopy() -> (prompt:Prompt, promptHistory: PromptHistory) {
        let promptId = UUID()
        let prompt = Prompt(name: self.name, externalSource: self.externalSource)
        let promptHistory = PromptHistory(promptId: promptId, prompt: self.prompt)
        return (prompt, promptHistory)
    }
}
