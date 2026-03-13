import Foundation
import SwiftData

@Model
final class Skill {
    var id: UUID = UUID()
    var name: String = ""
    var slug: String = ""
    var desc: String?
    var category: String = "General"
    var tags: [String] = []
    var identifier: String = ""
    var originPromptID: UUID?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var lastInstalledAt: Date?

    // Core configuration mirrored into exported SKILL.md metadata.
    var outputSchema: String?
    var inputSchema: String?
    var safetyPolicy: String?

    // Optional governance metadata kept for future authoring flows.
    var budgetLimit: Double?
    var isVerified: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \SkillVersion.skill)
    var versions: [SkillVersion]? = []

    init(
        name: String,
        desc: String? = nil,
        category: String = "General",
        identifier: String = "",
        originPromptID: UUID? = nil
    ) {
        self.name = name
        self.slug = Self.makeSlug(from: name)
        self.desc = desc
        self.category = category
        self.identifier = identifier
        self.originPromptID = originPromptID
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Skill" : trimmed
    }

    var sortedVersions: [SkillVersion] {
        (versions ?? []).sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.version.compare(rhs.version, options: .numeric) == .orderedDescending
        }
    }

    var latestVersion: SkillVersion? {
        sortedVersions.first
    }

    var installationName: String {
        let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSlug.isEmpty {
            return trimmedSlug
        }
        return Self.makeSlug(from: displayName)
    }

    func touch() {
        updatedAt = Date()
    }

    func createVersion(version: String? = nil, instructions: String) -> SkillVersion {
        touch()
        let nextVersion = version ?? Self.nextVersionLabel(after: latestVersion?.version)
        let skillVersion = SkillVersion(version: nextVersion, instructions: instructions, skill: self)
        if versions == nil {
            versions = []
        }
        versions?.append(skillVersion)
        return skillVersion
    }

    static func nextVersionLabel(after previous: String?) -> String {
        guard let previous, !previous.isEmpty else {
            return "1.0.0"
        }

        let numericComponents = previous
            .split(separator: ".")
            .compactMap { Int($0) }

        guard !numericComponents.isEmpty else {
            return "1.0.0"
        }

        var padded = Array(numericComponents.prefix(3))
        while padded.count < 3 {
            padded.append(0)
        }
        padded[2] += 1
        return padded.map(String.init).joined(separator: ".")
    }

    static func makeSlug(from name: String) -> String {
        let lowered = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !lowered.isEmpty else {
            return ""
        }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let normalized = lowered
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }

        let collapsed = String(normalized)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return collapsed
    }
}

@Model
final class SkillVersion {
    var id: UUID = UUID()
    var version: String = "1.0.0"
    var instructions: String = ""
    var changelog: String?
    var createdAt: Date = Date()

    // Test cases are stored as JSON for now to keep the authoring model lightweight.
    var testCasesJSON: String?

    // Snapshot fields kept to preserve authoring metadata across versions.
    var schemaSnapshot: String?
    var toolsConfig: [String] = []

    var parentSkillID: UUID?
    @Relationship var skill: Skill?

    init(version: String, instructions: String, skill: Skill? = nil) {
        self.version = version
        self.instructions = instructions
        self.skill = skill
        self.parentSkillID = skill?.id
        self.createdAt = Date()
    }

    var testCases: [[String: String]] {
        guard let data = testCasesJSON?.data(using: .utf8),
              let cases = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            return []
        }
        return cases
    }

    func toSkillMarkdown() -> String {
        var metadata: [String: Any] = [
            "name": skill?.displayName ?? "",
            "description": skill?.desc ?? "",
            "version": version,
            "category": skill?.category ?? "General",
            "identifier": skill?.identifier ?? ""
        ]

        if let tags = skill?.tags, !tags.isEmpty {
            metadata["tags"] = tags
        }

        if let inputSchema = skill?.inputSchema, !inputSchema.isEmpty {
            metadata["inputSchema"] = inputSchema
        }

        if let outputSchema = skill?.outputSchema, !outputSchema.isEmpty {
            metadata["outputSchema"] = outputSchema
        }

        if let safetyPolicy = skill?.safetyPolicy, !safetyPolicy.isEmpty {
            metadata["safetyPolicy"] = safetyPolicy
        }

        return SkillParser.generate(metadata: metadata, instructions: instructions)
    }

    static func fromSkillMarkdown(_ markdown: String) -> SkillVersion? {
        guard let (metadata, instructions) = SkillParser.parse(markdown: markdown) else {
            return nil
        }

        let versionString = (metadata["version"] as? String) ?? "1.0.0"
        let name = (metadata["name"] as? String) ?? "Imported Skill"
        let desc = metadata["description"] as? String
        let identifier = (metadata["identifier"] as? String) ?? ""

        let skill = Skill(
            name: name,
            desc: desc,
            category: (metadata["category"] as? String) ?? "General",
            identifier: identifier
        )
        skill.tags = SkillParser.stringArrayValue(for: "tags", in: metadata)
        skill.inputSchema = metadata["inputSchema"] as? String
        skill.outputSchema = metadata["outputSchema"] as? String
        skill.safetyPolicy = metadata["safetyPolicy"] as? String

        let skillVersion = skill.createVersion(version: versionString, instructions: instructions)
        return skillVersion
    }
}
