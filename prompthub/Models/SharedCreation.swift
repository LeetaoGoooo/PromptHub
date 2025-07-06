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
    var id: UUID = UUID()
    var name: String = ""
    var prompt: String = ""
    var desc: String?
    
    @Relationship(deleteRule: .cascade, inverse: \DataSource.creation)
    var dataSources: [DataSource]? = []

    var publicRecordName: String?
    var lastModified: Date?
    
    var isPublic: Bool = false

    init(id: UUID = UUID(), name: String, prompt: String, desc: String? = nil, dataSources: [DataSource]? = [], publicRecordName: String? = nil, lastModified: Date? = .now, isPublic: Bool = false) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.desc = desc
        self.dataSources = dataSources
        self.publicRecordName = publicRecordName
        self.lastModified = lastModified
        self.isPublic = isPublic
    }

    func makeLocalCopy() -> (prompt: Prompt, promptHistory: PromptHistory) {
        let prompt = Prompt(name: self.name, desc: self.desc)
        let promptHistory = prompt.createHistory(prompt: self.prompt, version: 0)
        return (prompt, promptHistory)
    }
    
    /// Checks if this SharedCreation was created by the current user by looking for it in the local SwiftData store
    /// - Parameter modelContext: The ModelContext to query against
    /// - Returns: true if found locally (created by current user), false otherwise
    static func isCreatedByCurrentUser(id: UUID, modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<SharedCreation>(
            predicate: #Predicate<SharedCreation> { creation in
                creation.id == id
            }
        )
        
        do {
            let results = try modelContext.fetch(descriptor)
            return !results.isEmpty
        } catch {
            return false
        }
    }
    
    /// Checks if a similar prompt already exists locally to prevent duplicate imports
    /// - Parameters:
    ///   - name: The name of the prompt to check
    ///   - prompt: The content of the prompt to check
    ///   - modelContext: The ModelContext to query against
    /// - Returns: true if a similar prompt already exists locally, false otherwise
    static func hasSimilarPromptLocally(name: String, prompt: String, modelContext: ModelContext) -> Bool {
        // Check for existing prompts with same name and content
        let promptDescriptor = FetchDescriptor<Prompt>(
            predicate: #Predicate<Prompt> { existingPrompt in
                existingPrompt.name == name
            }
        )
        
        do {
            let existingPrompts = try modelContext.fetch(promptDescriptor)
            
            // Check if any existing prompt has the same content in its latest history
            for existingPrompt in existingPrompts {
                if let history = existingPrompt.history,
                   let latestHistory = history.max(by: { $0.version < $1.version }),
                   latestHistory.promptText == prompt {
                    return true
                }
            }
            return false
        } catch {
            return false
        }
    }
}
