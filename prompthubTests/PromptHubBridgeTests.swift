import Foundation
import Testing
@testable import prompthub

@MainActor
struct PromptHubBridgeTests {

    @MainActor
    private struct Sandbox {
        let fileManager: FileManager
        let rootURL: URL
        let exportsRootURL: URL
        let packageRootURL: URL
        let packageStore: SkillDraftPackageStore
        let bridge: PromptHubBridge

        init() {
            let fileManager = FileManager.default
            let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let exportsRootURL = rootURL.appendingPathComponent(".prompthub", isDirectory: true)
            let packageRootURL = rootURL
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent("PromptHub", isDirectory: true)
                .appendingPathComponent("SkillDraftPackages", isDirectory: true)

            self.fileManager = fileManager
            self.rootURL = rootURL
            self.exportsRootURL = exportsRootURL
            self.packageRootURL = packageRootURL
            self.packageStore = SkillDraftPackageStore(fileManager: fileManager, baseURL: packageRootURL)
            self.bridge = PromptHubBridge(fileManager: fileManager, packageStore: packageStore, baseURL: exportsRootURL)
        }

        var promptsURL: URL {
            exportsRootURL.appendingPathComponent("prompts", isDirectory: true)
        }

        var skillsURL: URL {
            exportsRootURL.appendingPathComponent("skills", isDirectory: true)
        }

        func cleanup() {
            try? fileManager.removeItem(at: rootURL)
        }
    }

    @Test func exportSkillCopiesPackageDirectoryAndRemovesLegacyFile() throws {
        let sandbox = Sandbox()
        defer { sandbox.cleanup() }

        let skill = makeSkill(name: "UI Reviewer", instructions: "Check the hierarchy before polishing visuals.")
        let packageDirectoryURL = try sandbox.packageStore.ensurePackage(
            for: skill,
            canonicalSkillMarkdown: try #require(skill.latestVersion).toSkillMarkdown()
        )

        let scriptURL = packageDirectoryURL.appendingPathComponent("scripts/review.sh")
        try sandbox.fileManager.createDirectory(at: scriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\necho review\n".write(to: scriptURL, atomically: true, encoding: .utf8)

        sandbox.bridge.ensureDirectories()
        let legacyFileURL = sandbox.skillsURL.appendingPathComponent("\(skill.id.uuidString).md")
        try "legacy export".write(to: legacyFileURL, atomically: true, encoding: .utf8)

        sandbox.bridge.exportSkill(skill)

        let exportedDirectoryURL = sandbox.skillsURL.appendingPathComponent(skill.id.uuidString, isDirectory: true)
        let exportedMarkdownURL = exportedDirectoryURL.appendingPathComponent("SKILL.md")
        let exportedScriptURL = exportedDirectoryURL.appendingPathComponent("scripts/review.sh")

        #expect(sandbox.fileManager.fileExists(atPath: exportedMarkdownURL.path))
        #expect(sandbox.fileManager.fileExists(atPath: exportedScriptURL.path))
        #expect(!sandbox.fileManager.fileExists(atPath: legacyFileURL.path))

        let exportedMarkdown = try String(contentsOf: exportedMarkdownURL, encoding: .utf8)
        #expect(exportedMarkdown.contains("UI Reviewer"))
        #expect(exportedMarkdown.contains("Check the hierarchy before polishing visuals."))
    }

    @Test func removeSkillDeletesDirectoryAndLegacyExport() throws {
        let sandbox = Sandbox()
        defer { sandbox.cleanup() }

        let skill = makeSkill(name: "Remove Me", instructions: "Remove exported skill artifacts.")
        sandbox.bridge.ensureDirectories()

        let exportedDirectoryURL = sandbox.skillsURL.appendingPathComponent(skill.id.uuidString, isDirectory: true)
        try sandbox.fileManager.createDirectory(at: exportedDirectoryURL, withIntermediateDirectories: true)
        try "content".write(
            to: exportedDirectoryURL.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let legacyFileURL = sandbox.skillsURL.appendingPathComponent("\(skill.id.uuidString).md")
        try "legacy".write(to: legacyFileURL, atomically: true, encoding: .utf8)

        sandbox.bridge.removeSkill(skill)

        #expect(!sandbox.fileManager.fileExists(atPath: exportedDirectoryURL.path))
        #expect(!sandbox.fileManager.fileExists(atPath: legacyFileURL.path))
    }

    @Test func syncAllPrunesOrphanedPromptAndSkillExports() throws {
        let sandbox = Sandbox()
        defer { sandbox.cleanup() }

        let prompt = makePrompt(name: "Prompt Triage", body: "Start with the timeline.")
        let skill = makeSkill(name: "Skill Reviewer", instructions: "Inspect package contents.")
        let packageDirectoryURL = try sandbox.packageStore.ensurePackage(
            for: skill,
            canonicalSkillMarkdown: try #require(skill.latestVersion).toSkillMarkdown()
        )
        let notesURL = packageDirectoryURL.appendingPathComponent("docs/checklist.txt")
        try sandbox.fileManager.createDirectory(at: notesURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "Inspect sibling files too.".write(to: notesURL, atomically: true, encoding: .utf8)

        sandbox.bridge.ensureDirectories()

        let orphanPromptURL = sandbox.promptsURL.appendingPathComponent("\(UUID().uuidString).md")
        try "orphan prompt".write(to: orphanPromptURL, atomically: true, encoding: .utf8)

        let orphanSkillDirectoryURL = sandbox.skillsURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try sandbox.fileManager.createDirectory(at: orphanSkillDirectoryURL, withIntermediateDirectories: true)
        try "orphan skill".write(
            to: orphanSkillDirectoryURL.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let orphanLegacySkillURL = sandbox.skillsURL.appendingPathComponent("\(UUID().uuidString).md")
        try "legacy orphan".write(to: orphanLegacySkillURL, atomically: true, encoding: .utf8)

        sandbox.bridge.syncAll(prompts: [prompt], skills: [skill])

        let livePromptURL = sandbox.promptsURL.appendingPathComponent("\(prompt.id.uuidString).md")
        let liveSkillDirectoryURL = sandbox.skillsURL.appendingPathComponent(skill.id.uuidString, isDirectory: true)
        let liveSiblingURL = liveSkillDirectoryURL.appendingPathComponent("docs/checklist.txt")

        #expect(sandbox.fileManager.fileExists(atPath: livePromptURL.path))
        #expect(!sandbox.fileManager.fileExists(atPath: orphanPromptURL.path))
        #expect(sandbox.fileManager.fileExists(atPath: liveSkillDirectoryURL.path))
        #expect(sandbox.fileManager.fileExists(atPath: liveSiblingURL.path))
        #expect(!sandbox.fileManager.fileExists(atPath: orphanSkillDirectoryURL.path))
        #expect(!sandbox.fileManager.fileExists(atPath: orphanLegacySkillURL.path))
    }

    private func makeSkill(name: String, instructions: String) -> Skill {
        let skill = Skill(name: name, desc: "Test skill", category: "Testing")
        skill.tags = ["tests"]
        _ = skill.createVersion(version: "1.0.0", instructions: instructions)
        return skill
    }

    private func makePrompt(name: String, body: String) -> Prompt {
        let prompt = Prompt(name: name, desc: "Test prompt")
        let history = prompt.createHistory(prompt: body, version: 1)
        prompt.history = [history]
        return prompt
    }
}