import Foundation

// MARK: - Skill Auditor

/// Static analysis checks for a SkillAsset's body (SKILL.md content).
public enum SkillAuditor {

    public struct Report: Sendable {
        public let passed: Bool
        public let warnings: [String]
    }

    /// Runs all quality checks and returns a report.
    public static func audit(_ skill: SkillAsset) -> Report {
        var warnings: [String] = []

        let body = skill.body

        // 1. Minimum length
        let wordCount = body.split { $0.isWhitespace }.count
        if wordCount < 30 {
            warnings.append("Body is very short (\(wordCount) words). Consider expanding the instructions.")
        }

        // 2. Required sections (look for markdown headings)
        let requiredHeadings = ["## ", "# "]
        let hasHeadings = requiredHeadings.contains { body.contains($0) }
        if !hasHeadings {
            warnings.append("No markdown headings found. Structure the skill with ## sections for clarity.")
        }

        // 3. Description presence
        if skill.description == nil || skill.description!.isEmpty {
            warnings.append("Missing description. Add a description in PromptHub.app for discoverability.")
        }

        // 4. Tag presence
        if skill.tags.isEmpty {
            warnings.append("No tags defined. Tags improve searchability for agents.")
        }

        // 5. Placeholder variables with no instructions
        let placeholders = findPlaceholders(in: body)
        if !placeholders.isEmpty {
            warnings.append("Unresolved template placeholders in body: \(placeholders.joined(separator: ", ")). Ensure these are documented.")
        }

        // 6. Slug must be non-empty
        if skill.slug.isEmpty {
            warnings.append("Empty slug. Ensure the skill name produces a valid slug in PromptHub.app.")
        }

        return Report(passed: warnings.isEmpty, warnings: warnings)
    }

    private static func findPlaceholders(in text: String) -> [String] {
        var found: [String] = []
        guard let regex = try? NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}") else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match, let r = Range(match.range(at: 1), in: text) else { return }
            let name = String(text[r]).trimmingCharacters(in: .whitespaces)
            if !found.contains(name) { found.append(name) }
        }
        return found
    }
}
