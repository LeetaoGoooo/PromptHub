import Foundation
import PromptHubSkillKit
import Testing
@testable import prompthub

/// Verifies that `PromptHubBridge` writes the on-disk format the standalone
/// `ph` CLI expects to parse. The contractual surface is documented in
/// `docs/cli-parity.md`. The matching CLI-side coverage lives in
/// `PromptHubCLI/Tests/PromptHubCLITests/PromptHubCLITests.swift`
/// (`cliParsesBridgeFixtureFormat`).
@MainActor
struct CLIParityTests {

    @MainActor
    private struct Sandbox {
        let fileManager: FileManager
        let rootURL: URL
        let exportsRootURL: URL
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
            self.packageStore = SkillDraftPackageStore(fileManager: fileManager, baseURL: packageRootURL)
            self.bridge = PromptHubBridge(fileManager: fileManager, packageStore: packageStore, baseURL: exportsRootURL)
        }

        var promptsURL: URL { exportsRootURL.appendingPathComponent("prompts", isDirectory: true) }
        var skillsURL: URL  { exportsRootURL.appendingPathComponent("skills",  isDirectory: true) }

        func cleanup() { try? fileManager.removeItem(at: rootURL) }
    }

    /// Every field that the CLI's `PromptHubExportedAsset` decoder relies on
    /// must be present in the markdown the bridge writes for prompts.
    @Test func bridgePromptExportCarriesCLIContractFields() throws {
        let sandbox = Sandbox()
        defer { sandbox.cleanup() }

        let prompt = makePrompt(name: "Landing Page Review", body: "Inspect the hero copy.")
        prompt.desc = "Review a launch page"
        sandbox.bridge.exportPrompt(prompt)

        let promptURL = sandbox.promptsURL.appendingPathComponent("\(prompt.id.uuidString).md")
        let markdown = try String(contentsOf: promptURL, encoding: .utf8)
        let parsed = try #require(SkillMarkdownDocument.parse(markdown: markdown))

        // The CLI resolves prompts by id, slug, name, and installation name.
        // Every one of these MUST be readable from the bridge output.
        #expect(SkillMarkdownDocument.stringValue(for: "id", in: parsed.metadata) == prompt.id.uuidString)
        #expect(SkillMarkdownDocument.stringValue(for: "name", in: parsed.metadata) == "Landing Page Review")
        #expect(SkillMarkdownDocument.stringValue(for: "slug", in: parsed.metadata) == "landing-page-review")
        #expect(SkillMarkdownDocument.stringValue(for: "description", in: parsed.metadata) == "Review a launch page")
        // exported_at is opaque on the CLI side but must be present so the JSON shape is stable.
        #expect(SkillMarkdownDocument.stringValue(for: "exported_at", in: parsed.metadata) != nil)
        #expect(parsed.instructions == "Inspect the hero copy.")
        // The UUID stem is the bridge's stable identity contract.
        #expect(promptURL.deletingPathExtension().lastPathComponent == prompt.id.uuidString)
    }

    /// The same parity for an exported skill package directory.
    @Test func bridgeSkillExportCarriesCLIContractFields() throws {
        let sandbox = Sandbox()
        defer { sandbox.cleanup() }

        let skill = makeSkill(name: "UI Reviewer", instructions: "Check the hierarchy.")
        skill.tags = ["design", "ux"]

        // Seed a sibling file so we can confirm the bridge preserves arbitrary package contents.
        let packageURL = try sandbox.packageStore.ensurePackage(
            for: skill,
            canonicalSkillMarkdown: try #require(skill.latestVersion).toSkillMarkdown()
        )
        let scriptURL = packageURL.appendingPathComponent("scripts/run.sh")
        try sandbox.fileManager.createDirectory(at: scriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\necho ok\n".write(to: scriptURL, atomically: true, encoding: .utf8)

        sandbox.bridge.exportSkill(skill)

        let pkgDir = sandbox.skillsURL.appendingPathComponent(skill.id.uuidString, isDirectory: true)
        let skillMDURL = pkgDir.appendingPathComponent("SKILL.md")
        let copiedScriptURL = pkgDir.appendingPathComponent("scripts/run.sh")

        #expect(sandbox.fileManager.fileExists(atPath: skillMDURL.path))
        #expect(sandbox.fileManager.fileExists(atPath: copiedScriptURL.path))

        let markdown = try String(contentsOf: skillMDURL, encoding: .utf8)
        let parsed = try #require(SkillMarkdownDocument.parse(markdown: markdown))

        #expect(SkillMarkdownDocument.stringValue(for: "id", in: parsed.metadata) == skill.id.uuidString)
        #expect(SkillMarkdownDocument.stringValue(for: "name", in: parsed.metadata) == "UI Reviewer")
        // The bridge writes Skill.installationName as the slug, which is also the package directory name.
        #expect(SkillMarkdownDocument.stringValue(for: "slug", in: parsed.metadata) == skill.installationName)
        #expect(SkillMarkdownDocument.stringValue(for: "description", in: parsed.metadata) == "Test skill")
        #expect(SkillMarkdownDocument.stringValue(for: "category", in: parsed.metadata) == "Testing")
        #expect(SkillMarkdownDocument.stringArrayValue(for: "tags", in: parsed.metadata) == ["design", "ux"])
        #expect(SkillMarkdownDocument.stringValue(for: "exported_at", in: parsed.metadata) != nil)
        #expect(parsed.instructions.contains("Check the hierarchy."))
        // The UUID directory name is the install-side identity contract.
        #expect(pkgDir.lastPathComponent == skill.id.uuidString)
    }

    private func makeSkill(name: String, instructions: String) -> Skill {
        let skill = Skill(name: name, desc: "Test skill", category: "Testing")
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
