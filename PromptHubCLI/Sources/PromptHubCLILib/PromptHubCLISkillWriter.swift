import Foundation

extension PromptHubCLIService {
    /// Create a new exported skill package under `~/.prompthub/skills/<uuid>/SKILL.md`.
    @discardableResult
    public func createSkill(
        name: String,
        description: String? = nil,
        body: String = "",
        category: String = "General",
        tags: [String] = [],
        id: String? = nil
    ) throws -> PromptHubExportedAsset {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw PromptHubCLIError.invalidSkillName(name)
        }

        let resolvedID = try normalizeSkillUUID(id) ?? UUID().uuidString.uppercased()
        let slug = trimmedName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let trimmedDescription = {
            let value = description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? nil : value
        }()
        let trimmedCategory = {
            let value = category.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? "General" : value
        }()
        let normalizedTags = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let existing = (try? listExportedSkills()) ?? []
        if let collide = existing.first(where: { $0.id.lowercased() == resolvedID.lowercased() }) {
            throw PromptHubCLIError.skillIDCollision(id: resolvedID, existingName: collide.name)
        }
        if let collide = existing.first(where: { $0.installationName?.lowercased() == slug.lowercased() }) {
            throw PromptHubCLIError.skillSlugCollision(slug: slug, existingID: collide.id)
        }

        let skillsURL = environment.skillsURL
        let targetDirectoryURL = skillsURL.appendingPathComponent(resolvedID, isDirectory: true)
        let targetMarkdownURL = targetDirectoryURL.appendingPathComponent("SKILL.md")
        let markdown = Self.renderSkillMarkdown(
            id: resolvedID,
            name: trimmedName,
            slug: slug,
            description: trimmedDescription,
            category: trimmedCategory,
            tags: normalizedTags,
            body: body,
            exportedAt: ISO8601DateFormatter().string(from: Date())
        )

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: skillsURL.path) {
            try fileManager.createDirectory(at: skillsURL, withIntermediateDirectories: true)
        }
        do {
            if fileManager.fileExists(atPath: targetDirectoryURL.path) {
                try fileManager.removeItem(at: targetDirectoryURL)
            }
            try fileManager.createDirectory(at: targetDirectoryURL, withIntermediateDirectories: true)
            try markdown.write(to: targetMarkdownURL, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            throw PromptHubCLIError.skillWriteFailed(path: targetMarkdownURL.path, underlying: error.localizedDescription)
        }

        return PromptHubExportedAsset(
            id: resolvedID,
            kind: .skill,
            name: trimmedName,
            slug: slug,
            installationName: slug,
            summary: trimmedDescription,
            exportedAt: nil,
            category: trimmedCategory,
            tags: normalizedTags,
            path: targetDirectoryURL.path,
            packageDirectoryPath: targetDirectoryURL.path,
            markdown: markdown,
            body: body
        )
    }

    public static func renderSkillMarkdown(
        id: String,
        name: String,
        slug: String,
        description: String?,
        category: String,
        tags: [String],
        body: String,
        exportedAt: String
    ) -> String {
        var lines: [String] = ["---"]
        lines.append("id: \(id)")
        lines.append("name: \(yamlScalar(name))")
        lines.append("slug: \(slug)")
        if let description, !description.isEmpty { lines.append("description: \(yamlScalar(description))") }
        lines.append("category: \(yamlScalar(category))")
        if !tags.isEmpty {
            lines.append("tags: [\(tags.map { yamlScalar($0) }.joined(separator: ", "))]")
        }
        lines.append("exported_at: \(exportedAt)")
        lines.append("---")
        lines.append("")
        lines.append(body)
        return lines.joined(separator: "\n")
    }

    private func normalizeSkillUUID(_ raw: String?) throws -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UUID(uuidString: trimmed) != nil else {
            throw PromptHubCLIError.invalidSkillID(trimmed)
        }
        return trimmed.uppercased()
    }
}
