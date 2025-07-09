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
    var id: UUID = UUID()
    var name: String = ""
    var desc: String?
    var link: String?
        
    @Relationship(deleteRule: .cascade, inverse: \ExternalSource.prompt)
    var externalSources: [ExternalSource]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \PromptHistory.prompt)
    var history: [PromptHistory]? = []

    init(id: UUID = UUID(), name: String, desc: String? = nil, link: String? = nil, externalSource: [Data]? = nil) {
        self.id = id
        self.name = name
        self.desc = desc
        self.link = link
        
        if let data = externalSource {
            for dataItem in data {
                let source = ExternalSource(data: dataItem)
                externalSources?.append(source)
            }
        }
    }
}

extension Prompt {
    var externalSource: [Data]? {
        get { 
            let data = externalSources?.map { $0.data }
            return data?.isEmpty ?? true ? nil : data
        }
        set { 

            externalSources?.removeAll()
            
            if let newData = newValue {
                for data in newData {
                    let externalSource = ExternalSource(data: data)
                    externalSources?.append(externalSource)
                }
            }
        }
    }
    
    func createHistory(prompt: String, version: Int) -> PromptHistory {
        let history = PromptHistory(promptText: prompt, version: version)
        history.prompt = self
        return history
    }
    
    func getLatestPromptContent() -> String {
        let sortedHistory = history?.sorted { $0.version > $1.version }
        return sortedHistory?.first?.promptText ?? ""
    }
}

