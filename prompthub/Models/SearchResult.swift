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
    case skill = "Skill Draft"
    
    var icon: String {
        switch self {
        case .user:
            return "person.crop.circle.fill"
        case .shared:
            return "square.and.arrow.up.fill"
        case .gallery:
            return "globe"
        case .skill:
            return "wand.and.stars"
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
        case .skill:
            return "mint"
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

    var stableID: String {
        id
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

    var searchableContent: String {
        content
    }
    
    var type: SearchResultType { .user }

    var navigationTarget: SearchNavigationTarget? {
        .prompt(prompt.id)
    }
}

struct SearchableSharedCreation: SearchableItem, Identifiable {
    let creation: SharedCreation
    
    var id: String {
        creation.id.uuidString
    }

    var stableID: String {
        id
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

    var searchableContent: String {
        content
    }
    
    var type: SearchResultType { .shared }

    var navigationTarget: SearchNavigationTarget? {
        nil
    }
}

struct SearchableGalleryPrompt: SearchableItem, Identifiable {
    let galleryPrompt: GalleryPrompt
    
    var id: String {
        galleryPrompt.id
    }

    var stableID: String {
        id
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

    var searchableContent: String {
        content
    }
    
    var type: SearchResultType { .gallery }

    var navigationTarget: SearchNavigationTarget? {
        nil
    }
}

struct SearchableSkillDraft: SearchableItem, Identifiable {
    let skill: Skill

    var id: String {
        skill.id.uuidString
    }

    var stableID: String {
        id
    }

    var name: String {
        skill.displayName
    }

    var description: String? {
        skill.desc
    }

    var content: String {
        if let latestVersion = skill.latestVersion {
            return latestVersion.toSkillMarkdown()
        }

        return SkillParser.generate(
            metadata: [
                "name": skill.displayName,
                "description": skill.desc ?? "",
                "category": skill.category,
                "identifier": skill.identifier
            ],
            instructions: ""
        )
    }

    var searchableContent: String {
        [
            skill.displayName,
            skill.desc ?? "",
            skill.category,
            skill.identifier,
            skill.tags.joined(separator: " "),
            skill.latestVersion?.instructions ?? ""
        ]
        .joined(separator: "\n")
    }

    var type: SearchResultType { .skill }

    var navigationTarget: SearchNavigationTarget? {
        .skill(skill.id)
    }
}

protocol SearchableItem: Identifiable {
    var stableID: String { get }
    var name: String { get }
    var description: String? { get }
    var content: String { get }
    var searchableContent: String { get }
    var type: SearchResultType { get }
    var navigationTarget: SearchNavigationTarget? { get }
}
