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
    case installedSkill = "Installed Skill"
    case catalogSkill = "Catalog Skill"
    case action = "Action"
    
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
        case .installedSkill:
            return "square.stack.3d.up.fill"
        case .catalogSkill:
            return "sparkles.rectangle.stack"
        case .action:
            return "command"
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
        case .installedSkill:
            return "green"
        case .catalogSkill:
            return "purple"
        case .action:
            return "accent"
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
        .selection(.prompts(.shared), query: creation.name)
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
        .selection(.prompts(.explore), query: galleryPrompt.name)
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

struct SearchableInstalledSkill: SearchableItem, Identifiable {
    let skill: InstalledSkillSnapshot

    var id: String {
        skill.id
    }

    var stableID: String {
        id
    }

    var name: String {
        skill.displayName
    }

    var description: String? {
        skill.summary
    }

    var content: String {
        [skill.displayName, skill.summary, skill.packageName].joined(separator: "\n")
    }

    var searchableContent: String {
        [
            skill.displayName,
            skill.summary,
            skill.packageName,
            skill.displaySource ?? "",
            skill.scope.displayName,
            skill.agents.map(\.displayName).joined(separator: " ")
        ]
        .joined(separator: "\n")
    }

    var type: SearchResultType { .installedSkill }

    var navigationTarget: SearchNavigationTarget? {
        .selection(.skills(.installed), query: skill.displayName)
    }
}

struct SearchableCatalogSkill: SearchableItem, Identifiable {
    let skill: CatalogSkill

    var id: String {
        skill.id
    }

    var stableID: String {
        id
    }

    var name: String {
        skill.displayName
    }

    var description: String? {
        skill.summary
    }

    var content: String {
        [skill.displayName, skill.summary].joined(separator: "\n")
    }

    var searchableContent: String {
        [
            skill.displayName,
            skill.summary,
            skill.displaySource ?? "",
            skill.hintedScopes.map(\.displayName).joined(separator: " "),
            skill.hintedAgents.map(\.displayName).joined(separator: " ")
        ]
        .joined(separator: "\n")
    }

    var type: SearchResultType { .catalogSkill }

    var navigationTarget: SearchNavigationTarget? {
        .selection(.skills(.store), query: skill.displayName)
    }
}

struct SearchableShortcut: SearchableItem, Identifiable {
    let id: String
    let name: String
    let description: String?
    let content: String
    let searchableContent: String
    let navigationTarget: SearchNavigationTarget?

    var stableID: String { id }

    var type: SearchResultType { .action }
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
