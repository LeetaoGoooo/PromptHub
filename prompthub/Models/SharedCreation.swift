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
    var name: String = "";
    var prompt: String = "";
    var desc: String?
    @Attribute(.externalStorage)
    var externalSource: [Data]?
    var publicRecordName: String?
    var lastModifiedInCloudTimestamp: Data?

    init(id: UUID = UUID(), name: String, prompt: String, desc: String? = nil, externalSource: [Data]? = nil, publicRecordName: String? = nil, lastModifiedInCloudTimestamp: Data? = nil) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.desc = desc
        self.publicRecordName = publicRecordName
        self.lastModifiedInCloudTimestamp = lastModifiedInCloudTimestamp
    }

    func makeLocalCopy() -> (prompt: Prompt, promptHistory: PromptHistory) {
        let prompt = Prompt(name: self.name, desc: self.desc)
        let promptHistory = prompt.createHistory(prompt: self.prompt, version: 0)
        return (prompt, promptHistory)
    }
}
