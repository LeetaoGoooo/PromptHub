import Foundation

// MARK: - Asset Store

/// Reads prompt and skill assets written by the PromptHub macOS app from
/// `~/.prompthub/`. All operations are synchronous and file-system based —
/// the CLI works without the App running.
public final class AssetStore: Sendable {

    public let baseURL: URL

    public static let shared = AssetStore()

    public init(baseURL: URL? = nil) {
        self.baseURL = baseURL ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".prompthub", isDirectory: true)
    }

    var promptsURL: URL { baseURL.appendingPathComponent("prompts", isDirectory: true) }
    var skillsURL:  URL { baseURL.appendingPathComponent("skills",  isDirectory: true) }

    // MARK: - Prompts

    /// Returns all prompts sorted by name.
    public func listPrompts() -> [PromptAsset] {
        markdownFiles(in: promptsURL)
            .compactMap { parsePrompt(at: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Finds a prompt by exact name or slug (case-insensitive).
    public func findPrompt(named query: String) -> PromptAsset? {
        let q = query.lowercased()
        return listPrompts().first {
            $0.name.lowercased() == q || $0.slug.lowercased() == q
        }
    }

    /// Searches prompts whose name, slug, or body contains `query`.
    public func searchPrompts(query: String) -> [PromptAsset] {
        let q = query.lowercased()
        return listPrompts().filter {
            $0.name.lowercased().contains(q) ||
            $0.slug.lowercased().contains(q) ||
            ($0.description?.lowercased().contains(q) ?? false) ||
            $0.body.lowercased().contains(q)
        }
    }

    // MARK: - Skills

    /// Returns all skill drafts sorted by name.
    public func listSkills() -> [SkillAsset] {
        markdownFiles(in: skillsURL)
            .compactMap { parseSkill(at: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Finds a skill by exact name or slug (case-insensitive).
    public func findSkill(named query: String) -> SkillAsset? {
        let q = query.lowercased()
        return listSkills().first {
            $0.name.lowercased() == q || $0.slug.lowercased() == q
        }
    }

    /// Searches skills whose name, slug, description, or body contains `query`.
    public func searchSkills(query: String) -> [SkillAsset] {
        let q = query.lowercased()
        return listSkills().filter {
            $0.name.lowercased().contains(q) ||
            $0.slug.lowercased().contains(q) ||
            ($0.description?.lowercased().contains(q) ?? false) ||
            $0.body.lowercased().contains(q)
        }
    }

    // MARK: - Private Helpers

    private func markdownFiles(in directory: URL) -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return contents.filter { url in
            guard url.pathExtension == "md" else { return false }
            // Reject symlinks to prevent directory traversal via ~/.prompthub/
            let isSymlink = (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
            let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            return isRegular && !isSymlink
        }
    }

    private func parsePrompt(at url: URL) -> PromptAsset? {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let (fields, body) = FrontMatterParser.parse(raw)
        guard let idString = fields["id"], let uuid = UUID(uuidString: idString),
              let name = fields["name"], !name.isEmpty else { return nil }
        return PromptAsset(
            id: uuid,
            name: name,
            slug: fields["slug"] ?? "",
            description: fields["description"],
            link: fields["link"],
            exportedAt: fields["exported_at"],
            body: body
        )
    }

    private func parseSkill(at url: URL) -> SkillAsset? {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let (fields, body) = FrontMatterParser.parse(raw)
        guard let idString = fields["id"], let uuid = UUID(uuidString: idString),
              let name = fields["name"], !name.isEmpty else { return nil }
        let tags: [String]
        if let tagsRaw = fields["tags"] {
            // Parse YAML array shorthand: [tag1, tag2]
            let stripped = tagsRaw.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            tags = stripped.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else {
            tags = []
        }
        return SkillAsset(
            id: uuid,
            name: name,
            slug: fields["slug"] ?? "",
            description: fields["description"],
            category: fields["category"],
            tags: tags,
            exportedAt: fields["exported_at"],
            body: body
        )
    }
}
