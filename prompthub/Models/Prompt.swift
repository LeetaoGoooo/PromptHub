//
//  Prompt.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import Foundation
import SwiftData

@Model
class Prompt {
    var id: UUID;
    var name: String;
    var link:String?;
    @Attribute(.externalStorage)
    var externalSource: [Data]?
    
    init(id: UUID = UUID(), name: String, link: String? = nil, externalSource: [Data]? = nil) {
        self.id = id;
        self.name = name;
        self.link = link;
        self.externalSource = externalSource;
    }
    
}


