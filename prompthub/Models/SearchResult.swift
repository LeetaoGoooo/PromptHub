//
//  SearchResult.swift
//  prompthub
//
//  Created by leetao on 2025/4/5.
//

import Foundation
import SwiftData

enum SearchResultType: String, CaseIterable {
    case user = "User Prompt"
    case shared = "Shared Creation"
    case gallery = "Gallery Prompt"
    
    var icon: String {
        switch self {
        case .user:
            return "person.crop.circle.fill"
        case .shared:
            return "square.and.arrow.up.fill"
        case .gallery:
            return "globe"
        }
    }
    
    var color: String {
        switch self {
        case .user:
            return "blue"
        case .shared:
            return "orange"
        case .gallery:
            return "systemGray"
        }
    }
}

// MARK: - SearchableItem Protocol
// We won't directly implement this protocol on the model classes to avoid conflicts
// Instead, we'll create wrapper structs when needed

struct SearchablePrompt: SearchableItem, Identifiable {
    let prompt: Prompt
    
    var id: String {
        prompt.id.uuidString
    }
    
    var name: String {
        prompt.name
    }
    
    var description: String? {
        prompt.desc
    }
    
    var content: String {
        prompt.getLatestPromptContent()
    }
    
    var type: SearchResultType { .user }
}

struct SearchableSharedCreation: SearchableItem, Identifiable {
    let creation: SharedCreation
    
    var id: String {
        creation.id.uuidString
    }
    
    var name: String {
        creation.name
    }
    
    var description: String? {
        creation.desc
    }
    
    var content: String {
        creation.prompt
    }
    
    var type: SearchResultType { .shared }
}

struct SearchableGalleryPrompt: SearchableItem, Identifiable {
    let galleryPrompt: GalleryPrompt
    
    var id: String {
        galleryPrompt.id
    }
    
    var name: String {
        galleryPrompt.name
    }
    
    var description: String? {
        galleryPrompt.description
    }
    
    var content: String {
        galleryPrompt.prompt
    }
    
    var type: SearchResultType { .gallery }
}

protocol SearchableItem: Identifiable {
    var name: String { get }
    var description: String? { get }
    var content: String { get }
    var type: SearchResultType { get }
}
