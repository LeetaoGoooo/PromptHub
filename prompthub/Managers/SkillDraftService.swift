import Foundation
import PromptHubSkillKit
import SwiftData

@MainActor
final class SkillDraftService {
    static let shared = SkillDraftService()

    enum DraftError: LocalizedError {
        case invalidInstalledMarkdown

        var errorDescription: String? {
            switch self {
            case .invalidInstalledMarkdown:
                return "The installed skill could not be converted into a draft."
            }
        }
    }

    private let cliService: SkillCLIService

    init(cliService: SkillCLIService = .shared) {
        self.cliService = cliService
    }

    func createDraft(
        name: String = "Untitled Skill",
        description: String? = nil,
        instructions: String = "",
        originPromptID: UUID? = nil,
        in context: ModelContext
    ) throws -> Skill {
        let draft = Skill(
            name: name,
            desc: description,
            identifier: makeIdentifier(for: name),
            originPromptID: originPromptID
        )
        let initialVersion = draft.createVersion(version: "1.0.0", instructions: instructions)
        context.insert(draft)
        context.insert(initialVersion)
        try context.save()
        PromptHubBridge.shared.exportSkill(draft)
        return draft
    }

    func createDraft(from prompt: Prompt, in context: ModelContext) throws -> Skill {
        let promptName = prompt.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let draftName = promptName.isEmpty ? "Untitled Skill" : promptName
        let instructions = prompt.getLatestPromptContent()

        return try createDraft(
            name: draftName,
            description: prompt.desc,
            instructions: instructions,
            originPromptID: prompt.id,
            in: context
        )
    }

    func ensureLatestVersion(for draft: Skill, in context: ModelContext) throws -> SkillVersion {
        if let latest = draft.latestVersion {
            return latest
        }

        let created = draft.createVersion(version: "1.0.0", instructions: "")
        context.insert(created)
        try context.save()
        return created
    }

    func snapshotVersion(for draft: Skill, using instructions: String, in context: ModelContext) throws -> SkillVersion {
        let version = draft.createVersion(instructions: instructions)
        context.insert(version)
        try context.save()
        PromptHubBridge.shared.exportSkill(draft)
        return version
    }

    func exportMarkdown(for draft: Skill) -> String {
        if let latest = draft.latestVersion {
            return latest.toSkillMarkdown()
        }

        let ephemeralVersion = SkillVersion(version: "1.0.0", instructions: "", skill: draft)
        return ephemeralVersion.toSkillMarkdown()
    }

    func installDraft(
        _ draft: Skill,
        scope: SkillInstallScope,
        targetAgents: [AgentWorkflow],
        in context: ModelContext
    ) async throws {
        let markdown = exportMarkdown(for: draft)
        try await cliService.addLocalSkill(
            name: draft.installationName,
            markdown: markdown,
            isGlobal: scope == .global,
            targetAgents: targetAgents
        )
        draft.lastInstalledAt = Date()
        draft.touch()
        try context.save()
    }

    func deleteDraft(_ draft: Skill, in context: ModelContext) throws {
        PromptHubBridge.shared.removeSkill(draft)
        context.delete(draft)
        try context.save()
    }

    func matchingDraft(
        for installedSkill: InstalledSkillSnapshot,
        in drafts: [Skill]
    ) -> Skill? {
        let installedName = normalized(installedSkill.packageName)
        let shortName = normalized(installedSkill.package.skillName)

        return drafts.first { draft in
            let installationName = normalized(draft.installationName)
            let slug = normalized(draft.slug)
            let identifier = normalized(draft.identifier)

            if !installedName.isEmpty, (installationName == installedName || slug == installedName) {
                return true
            }

            if !shortName.isEmpty, (installationName == shortName || slug == shortName) {
                return true
            }

            return !identifier.isEmpty && identifier == installedName
        }
    }

    func openOrCreateDraft(
        from installedSkill: InstalledSkillSnapshot,
        existingDrafts: [Skill],
        in context: ModelContext,
        projectRootURL: URL? = nil
    ) async throws -> Skill {
        if let existing = matchingDraft(for: installedSkill, in: existingDrafts) {
            return existing
        }

        guard let markdown = try await cliService.loadInstalledMarkdown(
            name: installedSkill.packageName,
            isGlobal: installedSkill.isGlobal,
            projectRootURL: projectRootURL
        ) else {
            throw DraftError.invalidInstalledMarkdown
        }

        let (importedSkill, importedVersion) = importDraft(from: markdown, fallback: installedSkill)

        if let existing = matchingDraft(for: installedSkill, in: existingDrafts + [importedSkill]) {
            return existing
        }

        importedSkill.lastInstalledAt = Date()
        importedSkill.touch()
        context.insert(importedSkill)
        context.insert(importedVersion)
        try context.save()
        return importedSkill
    }

    private func makeIdentifier(for name: String) -> String {
        let slug = Skill.makeSlug(from: name)
        guard !slug.isEmpty else {
            return ""
        }
        return "com.prompthub.skill.\(slug)"
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func importDraft(
        from markdown: String,
        fallback installedSkill: InstalledSkillSnapshot
    ) -> (Skill, SkillVersion) {
        let normalizedMarkdown = markdown.trimmingCharacters(in: .whitespacesAndNewlines)

        if let importedVersion = SkillVersion.fromSkillMarkdown(normalizedMarkdown),
           let importedSkill = importedVersion.skill {
            return (importedSkill, importedVersion)
        }

        let parsed = SkillParser.parse(markdown: normalizedMarkdown)
        let metadata = parsed?.metadata ?? [:]

        let name = SkillParser.stringValue(for: "name", in: metadata)
            ?? installedSkill.displayName
        let description = SkillParser.stringValue(for: "description", in: metadata)
            ?? nonEmpty(installedSkill.summary)
        let category = SkillParser.stringValue(for: "category", in: metadata) ?? "General"
        let identifier = SkillParser.stringValue(for: "identifier", in: metadata)
            ?? makeIdentifier(for: name)
        let versionLabel = SkillParser.stringValue(for: "version", in: metadata) ?? "1.0.0"
        let instructions = parsed?.instructions ?? normalizedMarkdown

        let skill = Skill(
            name: name,
            desc: description,
            category: category,
            identifier: identifier
        )
        skill.tags = SkillParser.stringArrayValue(for: "tags", in: metadata)
        skill.inputSchema = SkillParser.stringValue(for: "inputSchema", in: metadata)
        skill.outputSchema = SkillParser.stringValue(for: "outputSchema", in: metadata)
        skill.safetyPolicy = SkillParser.stringValue(for: "safetyPolicy", in: metadata)

        let version = skill.createVersion(version: versionLabel, instructions: instructions)
        return (skill, version)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
