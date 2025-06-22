//
//  Prompt.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import Foundation
import SwiftData

@Model
final class Prompt {
    var id: UUID
    var name: String
    var desc: String?
    var link: String?
    
    var legacyExternalSource: [Data]?
    
    @Relationship(deleteRule: .cascade, inverse: \ExternalSource.prompt)
    var externalSources: [ExternalSource] = []
    
    @Relationship(deleteRule: .cascade, inverse: \PromptHistory.prompt)
    var history: [PromptHistory] = []

    init(id: UUID = UUID(), name: String, desc: String? = nil, link: String? = nil, externalSource: [Data]? = nil) {
        self.id = id
        self.name = name
        self.desc = desc
        self.link = link
        
        if let data = externalSource {
            for dataItem in data {
                let source = ExternalSource(data: dataItem)
                externalSources.append(source)
            }
        }
    }
}

extension Prompt {
    var externalSource: [Data]? {
        get { 
            let data = externalSources.map { $0.data }
            return data.isEmpty ? nil : data
        }
        set { 
            // Clear existing external sources
            externalSources.removeAll()
            
            // Add new external sources if provided
            if let newData = newValue {
                for data in newData {
                    let externalSource = ExternalSource(data: data)
                    externalSources.append(externalSource)
                }
            }
        }
    }
    
    func createHistory(prompt: String, version: Int) -> PromptHistory {
        let history = PromptHistory(promptText: prompt, version: version)
        history.prompt = self
        return history
    }
}

