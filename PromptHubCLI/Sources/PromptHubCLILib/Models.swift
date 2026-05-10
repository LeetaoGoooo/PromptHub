import Foundation

// MARK: - Domain Models

/// A prompt asset read from `~/.prompthub/prompts/<uuid>.md`.
public struct PromptAsset: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let slug: String
    public let description: String?
    public let link: String?
    public let exportedAt: String?
    /// Raw body content (everything after the YAML front-matter).
    public let body: String

    public init(id: UUID, name: String, slug: String, description: String? = nil,
                link: String? = nil, exportedAt: String? = nil, body: String) {
        self.id = id; self.name = name; self.slug = slug
        self.description = description; self.link = link
        self.exportedAt = exportedAt; self.body = body
    }
}

/// A skill asset read from `~/.prompthub/skills/<uuid>.md`.
public struct SkillAsset: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let slug: String
    public let description: String?
    public let category: String?
    public let tags: [String]
    public let exportedAt: String?
    /// Raw skill instructions body.
    public let body: String

    public init(id: UUID, name: String, slug: String, description: String? = nil,
                category: String? = nil, tags: [String] = [], exportedAt: String? = nil, body: String) {
        self.id = id; self.name = name; self.slug = slug
        self.description = description; self.category = category
        self.tags = tags; self.exportedAt = exportedAt; self.body = body
    }
}
