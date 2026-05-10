import Foundation
import SwiftData

/// Writes PromptHub assets (prompts and skill drafts) to `~/.prompthub/` so the
/// standalone PromptHub CLI can read them without the App being running.
///
/// Directory layout:
/// ```
/// ~/.prompthub/
///   prompts/
///     <slug>.md        — prompt content with YAML front-matter
///   skills/
///     <slug>/
///       SKILL.md       — full skill markdown
/// ```
final class PromptHubBridge: @unchecked Sendable {

    static let shared = PromptHubBridge()

    // MARK: - Paths

    private static var baseURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".prompthub", isDirectory: true)
    }

    static var promptsURL: URL { baseURL.appendingPathComponent("prompts", isDirectory: true) }
    static var skillsURL:  URL { baseURL.appendingPathComponent("skills",  isDirectory: true) }

    // MARK: - Bootstrap

    /// Creates the `~/.prompthub/` directory tree if needed. Safe to call repeatedly.
    func ensureDirectories() {
        let fm = FileManager.default
        for url in [Self.promptsURL, Self.skillsURL] {
            if !fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - Prompt export

    /// Writes (or overwrites) `~/.prompthub/prompts/<slug>.md`.
    func exportPrompt(_ prompt: Prompt) {
        ensureDirectories()
        let slug = Self.slug(for: prompt.name)
        guard !slug.isEmpty else { return }
        let content = promptMarkdown(prompt)
        let url = Self.promptsURL.appendingPathComponent("\(slug).md")
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Removes `~/.prompthub/prompts/<slug>.md`.
    func removePrompt(_ prompt: Prompt) {
        let slug = Self.slug(for: prompt.name)
        guard !slug.isEmpty else { return }
        let url = Self.promptsURL.appendingPathComponent("\(slug).md")
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Skill export

    /// Writes (or overwrites) `~/.prompthub/skills/<slug>/SKILL.md`.
    func exportSkill(_ skill: Skill) {
        ensureDirectories()
        let slug = skill.installationName
        guard !slug.isEmpty else { return }
        let dirURL = Self.skillsURL.appendingPathComponent(slug, isDirectory: true)
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        let content = skill.latestVersion?.instructions ?? ""
        let url = dirURL.appendingPathComponent("SKILL.md")
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Removes `~/.prompthub/skills/<slug>/`.
    func removeSkill(_ skill: Skill) {
        let slug = skill.installationName
        guard !slug.isEmpty else { return }
        let dirURL = Self.skillsURL.appendingPathComponent(slug, isDirectory: true)
        try? FileManager.default.removeItem(at: dirURL)
    }

    // MARK: - Bulk sync

    /// Re-exports all prompts and skill drafts. Call on app launch or after migration.
    func syncAll(prompts: [Prompt], skills: [Skill]) {
        ensureDirectories()
        prompts.forEach { exportPrompt($0) }
        skills.forEach  { exportSkill($0)  }
    }

    // MARK: - Helpers

    /// Converts a display name to a stable URL-safe slug.
    static func slug(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private func promptMarkdown(_ prompt: Prompt) -> String {
        let content = prompt.getLatestPromptContent()
        let desc    = prompt.desc ?? ""
        let link    = prompt.link ?? ""
        let slug    = Self.slug(for: prompt.name)
        let date    = ISO8601DateFormatter().string(from: Date())

        var fm = "---\n"
        fm += "name: \(prompt.name)\n"
        fm += "slug: \(slug)\n"
        if !desc.isEmpty  { fm += "description: \(desc)\n" }
        if !link.isEmpty  { fm += "link: \(link)\n" }
        fm += "exported_at: \(date)\n"
        fm += "---\n\n"
        return fm + content
    }
}
