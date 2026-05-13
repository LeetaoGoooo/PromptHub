import Foundation
import SwiftData

/// Writes PromptHub assets (prompts and skill drafts) to `~/.prompthub/` so the
/// standalone PromptHub CLI can read them without the App being running.
///
/// Files are keyed by the model's stable UUID to avoid slug collisions and
/// orphan files when the user renames an item.
///
/// Directory layout:
/// ```
/// ~/.prompthub/
///   prompts/
///     <uuid>.md        — YAML front-matter + prompt body
///   skills/
///     <uuid>/          — exported skill package (SKILL.md + sibling files)
/// ```
@MainActor
final class PromptHubBridge {

    static let shared = PromptHubBridge()

    private let fileManager: FileManager
    private let packageStore: SkillDraftPackageStore
    private let baseURL: URL

    init(
        fileManager: FileManager = .default,
        packageStore: SkillDraftPackageStore = .shared,
        baseURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.packageStore = packageStore
        self.baseURL = baseURL ?? Self.defaultBaseURL
    }

    // MARK: - Paths

    private static var defaultBaseURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".prompthub", isDirectory: true)
    }

    static var promptsURL: URL { defaultBaseURL.appendingPathComponent("prompts", isDirectory: true) }
    static var skillsURL:  URL { defaultBaseURL.appendingPathComponent("skills",  isDirectory: true) }

    private var promptsURL: URL { baseURL.appendingPathComponent("prompts", isDirectory: true) }
    private var skillsURL: URL { baseURL.appendingPathComponent("skills", isDirectory: true) }

    // MARK: - Bootstrap

    /// Creates the `~/.prompthub/` directory tree if needed. Safe to call repeatedly.
    func ensureDirectories() {
        for url in [promptsURL, skillsURL] {
            if !fileManager.fileExists(atPath: url.path) {
                try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - Prompt export

    /// Writes (or overwrites) `~/.prompthub/prompts/<uuid>.md`.
    func exportPrompt(_ prompt: Prompt) {
        ensureDirectories()
        let content = promptMarkdown(prompt)
        let url = promptsURL.appendingPathComponent("\(prompt.id.uuidString).md")
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Removes `~/.prompthub/prompts/<uuid>.md`.
    func removePrompt(_ prompt: Prompt) {
        let url = promptsURL.appendingPathComponent("\(prompt.id.uuidString).md")
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Skill export

    /// Writes (or overwrites) `~/.prompthub/skills/<uuid>/`.
    func exportSkill(_ skill: Skill) {
        ensureDirectories()
        let content = skillMarkdown(skill)
        let targetDirectoryURL = skillsURL.appendingPathComponent(skill.id.uuidString, isDirectory: true)
        let legacyFileURL = skillsURL.appendingPathComponent("\(skill.id.uuidString).md")

        do {
            try packageStore.syncSkillMarkdown(content, for: skill)
            let sourceDirectoryURL = try packageStore.packageRootURL(for: skill)
            try removeItemIfExists(at: legacyFileURL)
            try removeItemIfExists(at: targetDirectoryURL)
            try fileManager.copyItem(at: sourceDirectoryURL, to: targetDirectoryURL)
        } catch {
            try? removeItemIfExists(at: targetDirectoryURL)
            try? content.write(to: legacyFileURL, atomically: true, encoding: .utf8)
        }
    }

    /// Removes `~/.prompthub/skills/<uuid>/` and any legacy flat export.
    func removeSkill(_ skill: Skill) {
        let directoryURL = skillsURL.appendingPathComponent(skill.id.uuidString, isDirectory: true)
        let legacyFileURL = skillsURL.appendingPathComponent("\(skill.id.uuidString).md")
        try? removeItemIfExists(at: directoryURL)
        try? removeItemIfExists(at: legacyFileURL)
    }

    // MARK: - Bulk sync

    /// Re-exports all prompts and skill drafts and prunes any stale files.
    /// Call once on app launch — not on every view appearance.
    func syncAll(prompts: [Prompt], skills: [Skill]) {
        ensureDirectories()
        prompts.forEach { exportPrompt($0) }
        skills.forEach  { exportSkill($0)  }
        pruneOrphans(livePromptIDs: Set(prompts.map { $0.id }), liveSkillIDs: Set(skills.map { $0.id }))
    }

    // MARK: - Helpers

    /// Converts a display name to a URL-safe slug for the front-matter only.
    static func slug(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    // MARK: - Private

    private func promptMarkdown(_ prompt: Prompt) -> String {
        let body   = prompt.getLatestPromptContent()
        let date   = ISO8601DateFormatter().string(from: Date())

        var lines: [String] = ["---"]
        lines.append("id: \(prompt.id.uuidString)")
        lines.append("name: \(yamlScalar(prompt.name))")
        lines.append("slug: \(Self.slug(for: prompt.name))")
        if let desc = prompt.desc, !desc.isEmpty { lines.append("description: \(yamlScalar(desc))") }
        if let link = prompt.link, !link.isEmpty  { lines.append("link: \(yamlScalar(link))") }
        lines.append("exported_at: \(date)")
        lines.append("---")
        lines.append("")
        lines.append(body)
        return lines.joined(separator: "\n")
    }

    private func skillMarkdown(_ skill: Skill) -> String {
        let body = skill.latestVersion?.instructions ?? ""
        let date = ISO8601DateFormatter().string(from: Date())

        var lines: [String] = ["---"]
        lines.append("id: \(skill.id.uuidString)")
        lines.append("name: \(yamlScalar(skill.displayName))")
        lines.append("slug: \(skill.installationName)")
        if let desc = skill.desc, !desc.isEmpty { lines.append("description: \(yamlScalar(desc))") }
        lines.append("category: \(yamlScalar(skill.category))")
        if !skill.tags.isEmpty { lines.append("tags: [\(skill.tags.map { yamlScalar($0) }.joined(separator: ", "))]") }
        lines.append("exported_at: \(date)")
        lines.append("---")
        lines.append("")
        lines.append(body)
        return lines.joined(separator: "\n")
    }

    /// Wraps a YAML scalar value in double-quotes if it contains unsafe characters,
    /// escaping any existing double-quotes inside.
    private func yamlScalar(_ value: String) -> String {
        let needsQuoting = value.contains(":") || value.contains("#") ||
                           value.contains("\n") || value.contains("\"") ||
                           value.hasPrefix(" ") || value.hasSuffix(" ") ||
                           value.hasPrefix("---")
        guard needsQuoting else { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
                           .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    /// Deletes any `~/.prompthub/prompts/*.md` or `~/.prompthub/skills/*`
    /// whose UUID filename does not correspond to a live model.
    private func pruneOrphans(livePromptIDs: Set<UUID>, liveSkillIDs: Set<UUID>) {
        pruneDirectory(promptsURL, liveIDs: livePromptIDs)
        pruneDirectory(skillsURL, liveIDs: liveSkillIDs, includeDirectories: true)
    }

    private func pruneDirectory(_ url: URL, liveIDs: Set<UUID>, includeDirectories: Bool = false) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for entry in contents {
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory && !includeDirectories {
                continue
            }
            if !isDirectory && entry.pathExtension.lowercased() != "md" {
                continue
            }

            let stem = isDirectory ? entry.lastPathComponent : entry.deletingPathExtension().lastPathComponent
            if let uuid = UUID(uuidString: stem), !liveIDs.contains(uuid) {
                try? fileManager.removeItem(at: entry)
            }
        }
    }

    private func removeItemIfExists(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.removeItem(at: url)
    }
}
