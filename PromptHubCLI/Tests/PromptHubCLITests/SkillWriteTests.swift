import Foundation
import PromptHubCLILib
import PromptHubSkillKit
import Testing

private func makeSkillTempBase() -> (FileManager, URL) {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let skillsRoot = base.appendingPathComponent(".prompthub/skills", isDirectory: true)
    try? fileManager.createDirectory(at: skillsRoot, withIntermediateDirectories: true)
    return (fileManager, base)
}

@Test func createSkillRoundtripsThroughExports() throws {
    let (fileManager, base) = makeSkillTempBase()
    defer { try? fileManager.removeItem(at: base) }

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))
    let created = try service.createSkill(
        name: "UX Reviewer",
        description: "Review UI and UX decisions.",
        body: "## Usage\nAudit the screen.",
        category: "Design",
        tags: ["ux", "review"],
        id: nil
    )

    let fetched = try service.showExportedSkill(identifier: "ux-reviewer")
    #expect(fetched.id == created.id)
    #expect(fetched.name == "UX Reviewer")
    #expect(fetched.installationName == "ux-reviewer")
    #expect(fetched.summary == "Review UI and UX decisions.")
    #expect(fetched.category == "Design")
    #expect(fetched.tags == ["ux", "review"])
    #expect(fetched.body == "## Usage\nAudit the screen.")
    #expect(fileManager.fileExists(atPath: URL(fileURLWithPath: created.path).appendingPathComponent("SKILL.md").path))
}

@Test func createSkillWritesBridgeCompatiblePackageLayout() throws {
    let (fileManager, base) = makeSkillTempBase()
    defer { try? fileManager.removeItem(at: base) }

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))
    let created = try service.createSkill(
        name: "Bridge Parity: Skill",
        description: "weird # chars",
        body: "Use carefully.",
        category: "General",
        tags: ["design review", "macOS"],
        id: nil
    )

    let skillFile = URL(fileURLWithPath: created.path).appendingPathComponent("SKILL.md")
    let raw = try String(contentsOf: skillFile, encoding: .utf8)
    #expect(raw.contains("name: \"Bridge Parity: Skill\""))
    #expect(raw.contains("description: \"weird # chars\""))
    #expect(raw.contains("slug: bridge-parity-skill"))
    #expect(raw.contains("tags: [design review, macOS]") || raw.contains("tags: [\"design review\", macOS]"))
}

@Test func createSkillRejectsDuplicateIDAndSlug() throws {
    let (fileManager, base) = makeSkillTempBase()
    defer { try? fileManager.removeItem(at: base) }

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))
    let fixedID = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    _ = try service.createSkill(name: "First Skill", description: nil, body: "x", category: "General", tags: [], id: fixedID)

    do {
        _ = try service.createSkill(name: "Second Skill", description: nil, body: "y", category: "General", tags: [], id: fixedID)
        Issue.record("expected skillIDCollision")
    } catch let error as PromptHubCLIError {
        if case .skillIDCollision = error {} else { Issue.record("unexpected error \(error)") }
    }

    do {
        _ = try service.createSkill(name: "First Skill", description: nil, body: "z", category: "General", tags: [], id: nil)
        Issue.record("expected skillSlugCollision")
    } catch let error as PromptHubCLIError {
        if case .skillSlugCollision = error {} else { Issue.record("unexpected error \(error)") }
    }
}

@Test func createSkillIsInstallable() async throws {
    let (fileManager, base) = makeSkillTempBase()
    defer { try? fileManager.removeItem(at: base) }

    let projectRoot = base.appendingPathComponent("project", isDirectory: true)
    try fileManager.createDirectory(at: projectRoot, withIntermediateDirectories: true)

    let agentRoot = base.appendingPathComponent(".codex", isDirectory: true)
    let codexGlobal = agentRoot.appendingPathComponent("skills", isDirectory: true)
    let codexProject = projectRoot.appendingPathComponent(".agents/skills", isDirectory: true)

    let environment = PromptHubCLIEnvironment(
        homeDirectoryURL: base,
        projectRootURL: projectRoot,
        agentSkillRoots: [
            .codex: AgentSkillRoots(global: codexGlobal, project: codexProject)
        ],
        localSkillRoots: [codexGlobal, codexProject],
        sharedLocalRoots: [codexProject],
        skillLockFileURLs: []
    )

    let service = PromptHubCLIService(environment: environment)
    _ = try service.createSkill(
        name: "Lifecycle Reviewer",
        description: "Created in CLI",
        body: "## Usage\nRun checks.",
        category: "General",
        tags: [],
        id: nil
    )

    let installed = try await service.installSkill(
        reference: "lifecycle-reviewer",
        scope: .project,
        agents: [.codex],
        projectRootURL: projectRoot
    )

    #expect(installed.package == "lifecycle-reviewer")
    #expect(installed.scope == .project)
    #expect(installed.agents == ["codex"])
    #expect(fileManager.fileExists(atPath: codexProject.appendingPathComponent("lifecycle-reviewer/SKILL.md").path))
}
