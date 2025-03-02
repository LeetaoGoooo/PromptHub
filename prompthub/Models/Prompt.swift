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
    
    init(id: UUID = UUID(), name: String) {
        self.id = id;
        self.name = name;
    }
    
}


