import Foundation
import PromptHubCLILib
import PromptHubSkillKit
import Testing

@Test func listPromptsReadsPromptHubExports() throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let promptsRoot = base.appendingPathComponent(".prompthub/prompts", isDirectory: true)
    try fileManager.createDirectory(at: promptsRoot, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let promptFile = promptsRoot.appendingPathComponent("8C11E38A-6DDE-42F4-B7B8-94B5D11C0F4C.md")
    try """
    ---
    id: 8C11E38A-6DDE-42F4-B7B8-94B5D11C0F4C
    name: Landing Page Review
    slug: landing-page-review
    description: Review a launch page
    exported_at: 2026-05-12T10:00:00Z
    ---

    Inspect the hero copy.
    """.write(to: promptFile, atomically: true, encoding: .utf8)

    let service = PromptHubCLIService(
        environment: PromptHubCLIEnvironment(homeDirectoryURL: base),
        fileManager: fileManager
    )

    let prompts = try service.listPrompts()
    #expect(prompts.count == 1)
    #expect(prompts[0].name == "Landing Page Review")
    #expect(prompts[0].slug == "landing-page-review")
    #expect(prompts[0].body == "Inspect the hero copy.")
}

@Test func showPromptResolvesBySlug() throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let promptsRoot = base.appendingPathComponent(".prompthub/prompts", isDirectory: true)
    try fileManager.createDirectory(at: promptsRoot, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    try """
    ---
    id: 0F53E6D6-C3C0-4BFA-9B27-358A5A37B5A5
    name: Incident Triage
    slug: incident-triage
    ---

    Start with the timeline.
    """.write(
        to: promptsRoot.appendingPathComponent("0F53E6D6-C3C0-4BFA-9B27-358A5A37B5A5.md"),
        atomically: true,
        encoding: .utf8
    )

    let service = PromptHubCLIService(
        environment: PromptHubCLIEnvironment(homeDirectoryURL: base),
        fileManager: fileManager
    )

    let prompt = try service.showPrompt(identifier: "incident-triage")
    #expect(prompt.id == "0F53E6D6-C3C0-4BFA-9B27-358A5A37B5A5")
    #expect(prompt.body == "Start with the timeline.")
}

@Test func listPromptsSkipsMalformedExports() throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let promptsRoot = base.appendingPathComponent(".prompthub/prompts", isDirectory: true)
    try fileManager.createDirectory(at: promptsRoot, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    try """
    ---
    id: 30EBA86D-4110-4F9A-B5D9-D6855071A7CB
    name: Healthy Prompt
    slug: healthy-prompt
    ---

    Keep the valid file.
    """.write(
        to: promptsRoot.appendingPathComponent("30EBA86D-4110-4F9A-B5D9-D6855071A7CB.md"),
        atomically: true,
        encoding: .utf8
    )

    try "Malformed frontmatter".write(
        to: promptsRoot.appendingPathComponent("broken.md"),
        atomically: true,
        encoding: .utf8
    )

    let service = PromptHubCLIService(
        environment: PromptHubCLIEnvironment(homeDirectoryURL: base),
        fileManager: fileManager
    )

    let prompts = try service.listPrompts()
    #expect(prompts.count == 1)
    #expect(prompts[0].name == "Healthy Prompt")
}

@Test func installSkillUsesExportedPromptHubSkill() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let skillsRoot = base.appendingPathComponent(".prompthub/skills", isDirectory: true)
    let projectRoot = base.appendingPathComponent("workspace", isDirectory: true)
    let installRoot = base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true)
    let codexGlobal = base.appendingPathComponent(".codex/skills", isDirectory: true)
    let codexProject = projectRoot.appendingPathComponent(".agents/skills", isDirectory: true)
    try fileManager.createDirectory(at: skillsRoot, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: projectRoot, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    try """
    ---
    id: 55A35F78-59E4-4A66-95C3-3B6FC90C4B37
    name: UI Reviewer
    slug: ui-reviewer
    description: Reviews UI copy and layout decisions
    category: Design
    exported_at: 2026-05-12T10:00:00Z
    ---

    Check the hierarchy before polishing visuals.
    """.write(
        to: skillsRoot.appendingPathComponent("55A35F78-59E4-4A66-95C3-3B6FC90C4B37.md"),
        atomically: true,
        encoding: .utf8
    )

    let environment = PromptHubCLIEnvironment(
        homeDirectoryURL: base,
        installRootURL: installRoot,
        projectRootURL: projectRoot,
        agentSkillRoots: [
            .codex: AgentSkillRoots(global: codexGlobal, project: codexProject)
        ],
        localSkillRoots: [],
        sharedLocalRoots: [],
        skillLockFileURLs: []
    )
    let service = PromptHubCLIService(environment: environment, fileManager: fileManager)

    let summary = try await service.installSkill(
        reference: "ui-reviewer",
        scope: .global,
        agents: [.codex],
        projectRootURL: projectRoot
    )

    #expect(summary.package == "ui-reviewer")
    #expect(summary.scope == .global)
    #expect(summary.agents == ["codex"])
    #expect(
        fileManager.fileExists(
            atPath: codexGlobal.appendingPathComponent("ui-reviewer/SKILL.md").path
        )
    )
}

@Test func installSkillUsesExportedPromptHubSkillPackageDirectory() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let skillsRoot = base.appendingPathComponent(".prompthub/skills", isDirectory: true)
    let projectRoot = base.appendingPathComponent("workspace", isDirectory: true)
    let installRoot = base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true)
    let codexGlobal = base.appendingPathComponent(".codex/skills", isDirectory: true)
    let codexProject = projectRoot.appendingPathComponent(".agents/skills", isDirectory: true)
    let exportedSkillDirectory = skillsRoot.appendingPathComponent("55A35F78-59E4-4A66-95C3-3B6FC90C4B37", isDirectory: true)
    let scriptsDirectory = exportedSkillDirectory.appendingPathComponent("scripts", isDirectory: true)

    try fileManager.createDirectory(at: scriptsDirectory, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: projectRoot, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    try """
    ---
    id: 55A35F78-59E4-4A66-95C3-3B6FC90C4B37
    name: UI Reviewer Package
    slug: ui-reviewer-package
    description: Reviews UI copy and layout decisions
    category: Design
    exported_at: 2026-05-13T10:00:00Z
    ---

    Check the hierarchy before polishing visuals.
    """.write(
        to: exportedSkillDirectory.appendingPathComponent("SKILL.md"),
        atomically: true,
        encoding: .utf8
    )

    try "echo package".write(
        to: scriptsDirectory.appendingPathComponent("run.sh"),
        atomically: true,
        encoding: .utf8
    )

    let environment = PromptHubCLIEnvironment(
        homeDirectoryURL: base,
        installRootURL: installRoot,
        projectRootURL: projectRoot,
        agentSkillRoots: [
            .codex: AgentSkillRoots(global: codexGlobal, project: codexProject)
        ],
        localSkillRoots: [],
        sharedLocalRoots: [],
        skillLockFileURLs: []
    )
    let service = PromptHubCLIService(environment: environment, fileManager: fileManager)

    let exportedSkills = try service.listExportedSkills()
    let exportedSkill = try #require(exportedSkills.first(where: { $0.slug == "ui-reviewer-package" }))
    #expect(
        URL(fileURLWithPath: try #require(exportedSkill.packageDirectoryPath)).standardizedFileURL.path
            == exportedSkillDirectory.standardizedFileURL.path
    )

    let summary = try await service.installSkill(
        reference: "ui-reviewer-package",
        scope: .global,
        agents: [.codex],
        projectRootURL: projectRoot
    )

    #expect(summary.package == "ui-reviewer-package")
    #expect(summary.scope == .global)
    #expect(summary.agents == ["codex"])
    #expect(
        fileManager.fileExists(
            atPath: codexGlobal.appendingPathComponent("ui-reviewer-package/SKILL.md").path
        )
    )
    #expect(
        fileManager.fileExists(
            atPath: codexGlobal.appendingPathComponent("ui-reviewer-package/scripts/run.sh").path
        )
    )
}

@Test func listInstalledSkillsReportsScopeAndAgents() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let installRoot = base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true)
    let codexGlobal = base.appendingPathComponent(".codex/skills", isDirectory: true)
    let codexProject = base.appendingPathComponent("workspace/.agents/skills", isDirectory: true)
    let projectRoot = base.appendingPathComponent("workspace", isDirectory: true)
    defer { try? fileManager.removeItem(at: base) }

    let environment = PromptHubCLIEnvironment(
        homeDirectoryURL: base,
        installRootURL: installRoot,
        projectRootURL: projectRoot,
        agentSkillRoots: [
            .codex: AgentSkillRoots(global: codexGlobal, project: codexProject)
        ],
        localSkillRoots: [],
        sharedLocalRoots: [],
        skillLockFileURLs: []
    )
    let service = PromptHubCLIService(environment: environment, fileManager: fileManager)

    let catalog = environment.makeCatalog(fileManager: fileManager, projectRootURL: projectRoot)
    try await catalog.installLocal(
        name: "repo-review",
        markdown: "---\ndescription: Review repository changes\n---\n\nCheck behavior first.",
        isGlobal: false,
        targetAgents: [.codex]
    )

    let installed = try await service.listInstalledSkills(scopeFilter: .project, projectRootURL: projectRoot)
    #expect(installed.count == 1)
    #expect(installed[0].package == "repo-review")
    #expect(installed[0].scope == .project)
    #expect(installed[0].agents == ["codex"])
}