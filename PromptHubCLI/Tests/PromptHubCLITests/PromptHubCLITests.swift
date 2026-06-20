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

@Test func searchPromptsMatchesAcrossFields() throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let promptsRoot = base.appendingPathComponent(".prompthub/prompts", isDirectory: true)
    try fileManager.createDirectory(at: promptsRoot, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    try """
    ---
    id: A1111111-1111-1111-1111-111111111111
    name: Landing Page Review
    slug: landing-page-review
    description: Review a launch page
    tags:
      - marketing
      - launch
    ---

    Inspect the hero copy and CTA button.
    """.write(
        to: promptsRoot.appendingPathComponent("A1111111-1111-1111-1111-111111111111.md"),
        atomically: true,
        encoding: .utf8
    )

    try """
    ---
    id: B2222222-2222-2222-2222-222222222222
    name: Incident Triage
    slug: incident-triage
    ---

    Start with the timeline.
    """.write(
        to: promptsRoot.appendingPathComponent("B2222222-2222-2222-2222-222222222222.md"),
        atomically: true,
        encoding: .utf8
    )

    let service = PromptHubCLIService(
        environment: PromptHubCLIEnvironment(homeDirectoryURL: base),
        fileManager: fileManager
    )

    // Body match.
    let cta = try service.searchPrompts(query: "CTA")
    #expect(cta.map(\.slug) == ["landing-page-review"])

    // Slug match.
    let slugHit = try service.searchPrompts(query: "incident")
    #expect(slugHit.map(\.slug) == ["incident-triage"])

    // Tag match (case-insensitive).
    let tagHit = try service.searchPrompts(query: "MARKETING")
    #expect(tagHit.map(\.slug) == ["landing-page-review"])

    // Empty query returns all prompts (sorted by name).
    let all = try service.searchPrompts(query: "   ")
    #expect(all.count == 2)

    // Misses return empty.
    let miss = try service.searchPrompts(query: "nope")
    #expect(miss.isEmpty)
}

@Test func renderPromptSubstitutesVariablesAndReportsMissing() throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let promptsRoot = base.appendingPathComponent(".prompthub/prompts", isDirectory: true)
    try fileManager.createDirectory(at: promptsRoot, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    try """
    ---
    id: C3333333-3333-3333-3333-333333333333
    name: Greet
    slug: greet
    ---

    Hello {{name}}, today is {{ day }}. Greetings, {{name}}!
    """.write(
        to: promptsRoot.appendingPathComponent("C3333333-3333-3333-3333-333333333333.md"),
        atomically: true,
        encoding: .utf8
    )

    let service = PromptHubCLIService(
        environment: PromptHubCLIEnvironment(homeDirectoryURL: base),
        fileManager: fileManager
    )

    let rendered = try service.renderPrompt(
        identifier: "greet",
        variables: ["name": "Ada", "day": "Tuesday"]
    )
    #expect(rendered.rendered == "Hello Ada, today is Tuesday. Greetings, Ada!")
    #expect(rendered.declaredVariables == ["name", "day"])
    #expect(rendered.variables == ["name": "Ada", "day": "Tuesday"])

    // Missing variables surface as a typed error.
    do {
        _ = try service.renderPrompt(identifier: "greet", variables: ["name": "Ada"])
        Issue.record("expected missingPromptVariables error")
    } catch let error as PromptHubCLIError {
        #expect(error == .missingPromptVariables(identifier: "greet", missing: ["day"]))
    }
}

@Test func renderPromptJSONHasStableShape() throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let promptsRoot = base.appendingPathComponent(".prompthub/prompts", isDirectory: true)
    try fileManager.createDirectory(at: promptsRoot, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    try """
    ---
    id: D4444444-4444-4444-4444-444444444444
    name: Echo
    slug: echo
    ---

    {{message}}
    """.write(
        to: promptsRoot.appendingPathComponent("D4444444-4444-4444-4444-444444444444.md"),
        atomically: true,
        encoding: .utf8
    )

    let service = PromptHubCLIService(
        environment: PromptHubCLIEnvironment(homeDirectoryURL: base),
        fileManager: fileManager
    )

    let result = try service.renderPrompt(identifier: "echo", variables: ["message": "hi"])
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(result)
    let json = String(data: data, encoding: .utf8) ?? ""

    // Stable contract: every field the CLI promises must appear with these exact keys.
    for key in ["declaredVariables", "id", "name", "path", "rendered", "slug", "variables"] {
        #expect(json.contains("\"\(key)\""), "JSON missing key \(key): \(json)")
    }
    #expect(json.contains("\"rendered\":\"hi\""))
}

@Test func parseVariableAssignmentRejectsMalformedInput() throws {
    let (key, value) = try PromptHubCLIService.parseVariableAssignment("name=Ada")
    #expect(key == "name")
    #expect(value == "Ada")

    // Equal sign inside the value is preserved.
    let (k2, v2) = try PromptHubCLIService.parseVariableAssignment("snippet=a=b=c")
    #expect(k2 == "snippet")
    #expect(v2 == "a=b=c")

    // Empty value is allowed.
    let (k3, v3) = try PromptHubCLIService.parseVariableAssignment("flag=")
    #expect(k3 == "flag")
    #expect(v3 == "")

    do {
        _ = try PromptHubCLIService.parseVariableAssignment("invalid")
        Issue.record("expected invalidVariableAssignment error")
    } catch let error as PromptHubCLIError {
        #expect(error == .invalidVariableAssignment("invalid"))
    }
}

@Test func placeholdersTolerateWhitespaceAndDedupe() {
    let body = "Hi {{name}} and {{ name }} on {{day}}, {{name}}."
    #expect(PromptHubCLIService.placeholders(in: body) == ["name", "day"])
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

@Test func showExportedSkillReturnsFullAsset() throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let skillsRoot = base.appendingPathComponent(".prompthub/skills", isDirectory: true)
    let pkgDir = skillsRoot.appendingPathComponent("F6666666-6666-6666-6666-666666666666", isDirectory: true)
    try fileManager.createDirectory(at: pkgDir, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    try """
    ---
    id: F6666666-6666-6666-6666-666666666666
    name: UX Reviewer
    slug: ux-reviewer
    description: Reviews UX copy
    category: Design
    tags:
      - design
      - ux
    ---

    Look at the call-to-action first.
    """.write(
        to: pkgDir.appendingPathComponent("SKILL.md"),
        atomically: true,
        encoding: .utf8
    )

    let service = PromptHubCLIService(
        environment: PromptHubCLIEnvironment(homeDirectoryURL: base),
        fileManager: fileManager
    )

    let skill = try service.showExportedSkill(identifier: "ux-reviewer")
    #expect(skill.name == "UX Reviewer")
    #expect(skill.installationName == "ux-reviewer")
    #expect(skill.category == "Design")
    #expect(skill.tags == ["design", "ux"])
    #expect(skill.packageDirectoryPath != nil)
    #expect(skill.body == "Look at the call-to-action first.")
}

@Test func inspectInstalledSkillReportsPathsAndScopes() async throws {
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
    id: A7777777-7777-7777-7777-777777777777
    name: Repo Review
    slug: repo-review
    description: Review repository changes
    ---

    Check behavior first.
    """.write(
        to: skillsRoot.appendingPathComponent("A7777777-7777-7777-7777-777777777777.md"),
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

    // Install in two scopes so inspect must dedupe per scope and report paths for each.
    _ = try await service.installSkill(reference: "repo-review", scope: .global, agents: [.codex], projectRootURL: projectRoot)
    _ = try await service.installSkill(reference: "repo-review", scope: .project, agents: [.codex], projectRootURL: projectRoot)

    let allScopes = try await service.inspectInstalledSkill(package: "repo-review", scope: nil, projectRootURL: projectRoot)
    #expect(allScopes.count == 2)
    #expect(Set(allScopes.map(\.scope)) == Set([.global, .project]))
    #expect(allScopes.allSatisfy { $0.agents == ["codex"] })
    #expect(allScopes.allSatisfy { $0.isManagedByPromptHub })
    #expect(allScopes.allSatisfy { !$0.installedPaths.isEmpty })

    // Case-insensitive lookup and scope filter.
    let global = try await service.inspectInstalledSkill(package: "REPO-REVIEW", scope: .global, projectRootURL: projectRoot)
    #expect(global.count == 1)
    #expect(global[0].scope == .global)

    // Missing package surfaces a typed error.
    do {
        _ = try await service.inspectInstalledSkill(package: "not-installed", scope: nil, projectRootURL: projectRoot)
        Issue.record("expected installedSkillNotFound error")
    } catch let error as PromptHubCLIError {
        #expect(error == .installedSkillNotFound(package: "not-installed"))
    }
}

@Test func inspectAndListShareSameSummaryShape() async throws {
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
    id: B8888888-8888-8888-8888-888888888888
    name: Layout Reviewer
    slug: layout-reviewer
    description: Review layout choices
    ---

    Check the hierarchy.
    """.write(
        to: skillsRoot.appendingPathComponent("B8888888-8888-8888-8888-888888888888.md"),
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

    let summary = try await service.installSkill(reference: "layout-reviewer", scope: .global, agents: [.codex], projectRootURL: projectRoot)
    #expect(summary.package == "layout-reviewer")

    // The same record must round-trip through list and inspect with identical shape.
    let listed = try await service.listInstalledSkills(scopeFilter: .global, projectRootURL: projectRoot)
    let inspected = try await service.inspectInstalledSkill(package: "layout-reviewer", scope: .global, projectRootURL: projectRoot)

    let listedMatch = try #require(listed.first(where: { $0.package == "layout-reviewer" }))
    let inspectedMatch = try #require(inspected.first)
    #expect(listedMatch == inspectedMatch)

    // JSON output must include the documented overlap fields for tooling.
    // `url` is omitted when nil and `id` is a computed Identifiable accessor — neither is part
    // of the JSON contract.
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let json = String(data: try encoder.encode(inspectedMatch), encoding: .utf8) ?? ""
    for key in ["agents", "description", "installedPaths", "isManagedByPromptHub", "package", "scope"] {
        #expect(json.contains("\"\(key)\""), "JSON missing key \(key): \(json)")
    }
}

@Test func doctorReportsHealthyEnvironment() throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let exportsRoot = base.appendingPathComponent(".prompthub", isDirectory: true)
    let promptsRoot = exportsRoot.appendingPathComponent("prompts", isDirectory: true)
    let skillsRoot = exportsRoot.appendingPathComponent("skills", isDirectory: true)
    let projectRoot = base.appendingPathComponent("workspace", isDirectory: true)
    let codexGlobal = base.appendingPathComponent(".codex/skills", isDirectory: true)
    let codexProject = projectRoot.appendingPathComponent(".agents/skills", isDirectory: true)
    let installRoot = base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true)

    for dir in [promptsRoot, skillsRoot, projectRoot, codexGlobal, codexProject, installRoot] {
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    defer { try? fileManager.removeItem(at: base) }

    // Drop a fake skill package so the visible-skill counter is exercised.
    let pkgDir = codexGlobal.appendingPathComponent("demo", isDirectory: true)
    try fileManager.createDirectory(at: pkgDir, withIntermediateDirectories: true)
    try "---\ndescription: x\n---\n\nbody".write(
        to: pkgDir.appendingPathComponent("SKILL.md"),
        atomically: true,
        encoding: .utf8
    )

    let environment = PromptHubCLIEnvironment(
        homeDirectoryURL: base,
        installRootURL: installRoot,
        projectRootURL: projectRoot,
        agentSkillRoots: [
            .codex: AgentSkillRoots(global: codexGlobal, project: codexProject)
        ]
    )
    let service = PromptHubCLIService(environment: environment, fileManager: fileManager)

    let report = service.runDoctor(projectRootURL: projectRoot)

    #expect(report.exportsRoot.exists)
    #expect(report.promptsRoot.exists)
    #expect(report.skillsRoot.exists)
    #expect(report.installRoot?.exists == true)
    #expect(report.projectRoot.exists)
    #expect(report.agents.count == 1)
    #expect(report.agents.first?.visibleSkillCount == 1)
    #expect(report.findings.count == 1)
    #expect(report.findings.first?.severity == .ok)
    #expect(report.findings.first?.code == "healthy")
    #expect(report.topSeverity == .ok)
}

@Test func doctorReportsMissingExportsAndProjectRoot() throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    let missingProject = base.appendingPathComponent("missing-workspace", isDirectory: true)
    let codexGlobal = base.appendingPathComponent(".codex/skills", isDirectory: true)
    let codexProject = missingProject.appendingPathComponent(".agents/skills", isDirectory: true)
    defer { try? fileManager.removeItem(at: base) }

    let environment = PromptHubCLIEnvironment(
        homeDirectoryURL: base,
        projectRootURL: missingProject,
        agentSkillRoots: [
            .codex: AgentSkillRoots(global: codexGlobal, project: codexProject)
        ]
    )
    let service = PromptHubCLIService(environment: environment, fileManager: fileManager)

    let report = service.runDoctor(projectRootURL: missingProject)
    let codes = Set(report.findings.map(\.code))

    #expect(codes.contains("exports_root_missing"))
    #expect(codes.contains("project_root_missing"))
    #expect(codes.contains("agent_paths_missing"))
    #expect(codes.contains("no_agent_paths"))
    #expect(report.findings.contains { $0.severity == .error && $0.code == "project_root_missing" })
    #expect(report.topSeverity == .error)
}

@Test func doctorReportsMissingInstallRootOverride() throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let exportsRoot = base.appendingPathComponent(".prompthub/prompts", isDirectory: true)
    try fileManager.createDirectory(at: exportsRoot, withIntermediateDirectories: true)
    let skillsRoot = base.appendingPathComponent(".prompthub/skills", isDirectory: true)
    try fileManager.createDirectory(at: skillsRoot, withIntermediateDirectories: true)
    let projectRoot = base.appendingPathComponent("workspace", isDirectory: true)
    try fileManager.createDirectory(at: projectRoot, withIntermediateDirectories: true)
    let bogusInstall = base.appendingPathComponent("does-not-exist", isDirectory: true)
    defer { try? fileManager.removeItem(at: base) }

    let environment = PromptHubCLIEnvironment(
        homeDirectoryURL: base,
        installRootURL: bogusInstall,
        projectRootURL: projectRoot,
        agentSkillRoots: [:]
    )
    let service = PromptHubCLIService(environment: environment, fileManager: fileManager)

    let report = service.runDoctor(projectRootURL: projectRoot)
    let codes = Set(report.findings.map(\.code))
    #expect(codes.contains("install_root_missing"))
    #expect(report.findings.first(where: { $0.code == "install_root_missing" })?.severity == .warning)
}

@Test func doctorJSONHasStableShape() throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let environment = PromptHubCLIEnvironment(
        homeDirectoryURL: base,
        projectRootURL: base,
        agentSkillRoots: [:]
    )
    let service = PromptHubCLIService(environment: environment, fileManager: fileManager)
    let report = service.runDoctor(projectRootURL: base)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let json = String(data: try encoder.encode(report), encoding: .utf8) ?? ""
    for key in ["agents", "exportsRoot", "findings", "githubTokenPresent", "homeDirectory", "projectRoot", "promptsRoot", "skillsRoot"] {
        #expect(json.contains("\"\(key)\""), "JSON missing key \(key): \(json)")
    }
}

/// Parity guard against `PromptHubBridge` output. The fixture below is
/// byte-equivalent to what `PromptHubBridge.promptMarkdown` and
/// `PromptHubBridge.skillMarkdown` produce. The full parity matrix
/// lives in `docs/cli-parity.md`. The matching app-side test is
/// `prompthubTests/CLIParityTests.swift`.
@Test func cliParsesBridgeFixtureFormat() throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let promptsRoot = base.appendingPathComponent(".prompthub/prompts", isDirectory: true)
    let skillsRoot = base.appendingPathComponent(".prompthub/skills", isDirectory: true)
    try fileManager.createDirectory(at: promptsRoot, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    // Exact fixture format produced by PromptHubBridge.promptMarkdown.
    let promptID = "C9A1F2A4-1111-2222-3333-444444444444"
    let promptMarkdown = """
    ---
    id: \(promptID)
    name: Landing Page Review
    slug: landing-page-review
    description: Review a launch page
    exported_at: 2026-05-12T10:00:00Z
    ---

    Inspect the hero copy.
    """
    try promptMarkdown.write(
        to: promptsRoot.appendingPathComponent("\(promptID).md"),
        atomically: true,
        encoding: .utf8
    )

    // Exact fixture format produced by PromptHubBridge.skillMarkdown,
    // packaged in a UUID directory with a sibling file (matching exportSkill).
    let skillID = "D4B5C6D7-1111-2222-3333-555555555555"
    let skillDir = skillsRoot.appendingPathComponent(skillID, isDirectory: true)
    try fileManager.createDirectory(at: skillDir.appendingPathComponent("scripts"), withIntermediateDirectories: true)
    let skillMarkdown = """
    ---
    id: \(skillID)
    name: UI Reviewer
    slug: ui-reviewer
    description: Reviews UI copy and layout decisions
    category: Design
    tags: [design, ux]
    exported_at: 2026-05-12T10:00:00Z
    ---

    Check the hierarchy before polishing visuals.
    """
    try skillMarkdown.write(
        to: skillDir.appendingPathComponent("SKILL.md"),
        atomically: true,
        encoding: .utf8
    )
    try "#!/bin/sh\necho ok\n".write(
        to: skillDir.appendingPathComponent("scripts/run.sh"),
        atomically: true,
        encoding: .utf8
    )

    let service = PromptHubCLIService(
        environment: PromptHubCLIEnvironment(homeDirectoryURL: base),
        fileManager: fileManager
    )

    // Prompt parity: every column flagged "Must match: yes" in cli-parity.md must round-trip.
    let prompts = try service.listPrompts()
    #expect(prompts.count == 1)
    let prompt = try #require(prompts.first)
    #expect(prompt.id == promptID)
    #expect(prompt.name == "Landing Page Review")
    #expect(prompt.slug == "landing-page-review")
    #expect(prompt.summary == "Review a launch page")
    #expect(prompt.exportedAt == "2026-05-12T10:00:00Z")
    #expect(prompt.body == "Inspect the hero copy.")

    // Skill parity: package directory shape, tag array, category, and sibling file must all be visible.
    let skills = try service.listExportedSkills()
    #expect(skills.count == 1)
    let skill = try #require(skills.first)
    #expect(skill.id == skillID)
    #expect(skill.name == "UI Reviewer")
    #expect(skill.slug == "ui-reviewer")
    #expect(skill.installationName == "ui-reviewer")
    #expect(skill.summary == "Reviews UI copy and layout decisions")
    #expect(skill.category == "Design")
    #expect(skill.tags == ["design", "ux"])
    #expect(skill.body == "Check the hierarchy before polishing visuals.")
    #expect(skill.packageDirectoryPath != nil)
    #expect(fileManager.fileExists(atPath: skillDir.appendingPathComponent("scripts/run.sh").path))
}

@Test func uninstallRemovesManagedSkill() async throws {
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
    id: 11111111-aaaa-aaaa-aaaa-111111111111
    name: Uninstall Demo
    slug: uninstall-demo
    description: Drop me
    ---

    body
    """.write(
        to: skillsRoot.appendingPathComponent("11111111-aaaa-aaaa-aaaa-111111111111.md"),
        atomically: true,
        encoding: .utf8
    )

    let environment = PromptHubCLIEnvironment(
        homeDirectoryURL: base,
        installRootURL: installRoot,
        projectRootURL: projectRoot,
        agentSkillRoots: [.codex: AgentSkillRoots(global: codexGlobal, project: codexProject)],
        localSkillRoots: [],
        sharedLocalRoots: [],
        skillLockFileURLs: []
    )
    let service = PromptHubCLIService(environment: environment, fileManager: fileManager)

    _ = try await service.installSkill(reference: "uninstall-demo", scope: .global, agents: [.codex], projectRootURL: projectRoot)
    let skillPath = codexGlobal.appendingPathComponent("uninstall-demo/SKILL.md").path
    #expect(fileManager.fileExists(atPath: skillPath))

    let result = try await service.uninstallSkill(
        package: "uninstall-demo",
        scope: .global,
        agents: [.codex],
        projectRootURL: projectRoot
    )
    #expect(result.package == "uninstall-demo")
    #expect(result.agents.allSatisfy { $0.succeeded })
    #expect(!result.partialFailure)
    #expect(!fileManager.fileExists(atPath: skillPath))
}

@Test func uninstallRefusesUnmanagedSkillWithoutForce() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let projectRoot = base.appendingPathComponent("workspace", isDirectory: true)
    let installRoot = base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true)
    let codexGlobal = base.appendingPathComponent(".codex/skills", isDirectory: true)
    let codexProject = projectRoot.appendingPathComponent(".agents/skills", isDirectory: true)
    try fileManager.createDirectory(at: codexGlobal.appendingPathComponent("hand-authored"), withIntermediateDirectories: true)
    try fileManager.createDirectory(at: projectRoot, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    // Drop a hand-authored skill file that PromptHub never installed.
    let unmanagedSkillPath = codexGlobal.appendingPathComponent("hand-authored/SKILL.md")
    try "---\ndescription: written by hand\n---\n\nbody".write(to: unmanagedSkillPath, atomically: true, encoding: .utf8)

    let environment = PromptHubCLIEnvironment(
        homeDirectoryURL: base,
        installRootURL: installRoot,
        projectRootURL: projectRoot,
        agentSkillRoots: [.codex: AgentSkillRoots(global: codexGlobal, project: codexProject)],
        localSkillRoots: [],
        sharedLocalRoots: [],
        skillLockFileURLs: []
    )
    let service = PromptHubCLIService(environment: environment, fileManager: fileManager)

    do {
        _ = try await service.uninstallSkill(package: "hand-authored", scope: .global, agents: [.codex], projectRootURL: projectRoot)
        Issue.record("expected unmanagedSkill error")
    } catch let error as PromptHubCLIError {
        #expect(error == .unmanagedSkill(package: "hand-authored"))
    }

    // File must still be there.
    #expect(fileManager.fileExists(atPath: unmanagedSkillPath.path))

    // --force should now delete it.
    let result = try await service.uninstallSkill(package: "hand-authored", scope: .global, agents: [.codex], projectRootURL: projectRoot, force: true)
    #expect(result.agents.allSatisfy { $0.succeeded })
    #expect(!fileManager.fileExists(atPath: unmanagedSkillPath.path))
}

@Test func reinstallFromExportedAssetRoundTrips() async throws {
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
    id: 22222222-aaaa-aaaa-aaaa-222222222222
    name: Reinstall Demo
    slug: reinstall-demo
    ---

    body
    """.write(
        to: skillsRoot.appendingPathComponent("22222222-aaaa-aaaa-aaaa-222222222222.md"),
        atomically: true,
        encoding: .utf8
    )

    let environment = PromptHubCLIEnvironment(
        homeDirectoryURL: base,
        installRootURL: installRoot,
        projectRootURL: projectRoot,
        agentSkillRoots: [.codex: AgentSkillRoots(global: codexGlobal, project: codexProject)],
        localSkillRoots: [],
        sharedLocalRoots: [],
        skillLockFileURLs: []
    )
    let service = PromptHubCLIService(environment: environment, fileManager: fileManager)

    _ = try await service.installSkill(reference: "reinstall-demo", scope: .global, agents: [.codex], projectRootURL: projectRoot)
    _ = try await service.uninstallSkill(package: "reinstall-demo", scope: .global, agents: [.codex], projectRootURL: projectRoot)
    #expect(!fileManager.fileExists(atPath: codexGlobal.appendingPathComponent("reinstall-demo/SKILL.md").path))

    let summary = try await service.reinstallSkill(package: "reinstall-demo", scope: .global, agents: [.codex], projectRootURL: projectRoot)
    #expect(summary.package == "reinstall-demo")
    #expect(fileManager.fileExists(atPath: codexGlobal.appendingPathComponent("reinstall-demo/SKILL.md").path))

    // A package name that doesn't match any export or remote shape must surface noKnownInstallSource.
    do {
        _ = try await service.reinstallSkill(package: "never-installed", scope: .global, agents: [.codex], projectRootURL: projectRoot)
        Issue.record("expected noKnownInstallSource error")
    } catch let error as PromptHubCLIError {
        #expect(error == .noKnownInstallSource(package: "never-installed"))
    }
}

@Test func whereSkillReportsAgentAndPathPerInstall() async throws {
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
    id: 33333333-aaaa-aaaa-aaaa-333333333333
    name: Where Demo
    slug: where-demo
    ---

    body
    """.write(
        to: skillsRoot.appendingPathComponent("33333333-aaaa-aaaa-aaaa-333333333333.md"),
        atomically: true,
        encoding: .utf8
    )

    let environment = PromptHubCLIEnvironment(
        homeDirectoryURL: base,
        installRootURL: installRoot,
        projectRootURL: projectRoot,
        agentSkillRoots: [.codex: AgentSkillRoots(global: codexGlobal, project: codexProject)],
        localSkillRoots: [],
        sharedLocalRoots: [],
        skillLockFileURLs: []
    )
    let service = PromptHubCLIService(environment: environment, fileManager: fileManager)

    _ = try await service.installSkill(reference: "where-demo", scope: .global, agents: [.codex], projectRootURL: projectRoot)
    let rows = try await service.whereSkill(package: "where-demo", scope: nil, projectRootURL: projectRoot)
    #expect(!rows.isEmpty)
    #expect(rows.allSatisfy { $0.package == "where-demo" })
    #expect(rows.allSatisfy { $0.isManagedByPromptHub })
    // At least one row must resolve to a known agent name (not "unknown").
    #expect(rows.contains { $0.agent == "codex" })
}

@Test func updateSkillReportsNoRemoteSourceForLocalInstall() async throws {
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
    id: 44444444-aaaa-aaaa-aaaa-444444444444
    name: Update Demo
    slug: update-demo
    ---

    body
    """.write(
        to: skillsRoot.appendingPathComponent("44444444-aaaa-aaaa-aaaa-444444444444.md"),
        atomically: true,
        encoding: .utf8
    )

    let environment = PromptHubCLIEnvironment(
        homeDirectoryURL: base,
        installRootURL: installRoot,
        projectRootURL: projectRoot,
        agentSkillRoots: [.codex: AgentSkillRoots(global: codexGlobal, project: codexProject)],
        localSkillRoots: [],
        sharedLocalRoots: [],
        skillLockFileURLs: []
    )
    let service = PromptHubCLIService(environment: environment, fileManager: fileManager)

    _ = try await service.installSkill(reference: "update-demo", scope: .global, agents: [.codex], projectRootURL: projectRoot)
    let result = try await service.updateSkill(package: "update-demo", scope: .global, projectRootURL: projectRoot)
    // Locally installed PromptHub skill has no owner/repo@skill source, so update should report noRemoteSource cleanly instead of crashing.
    #expect(result.status == .noRemoteSource)
    #expect(result.appliedPaths.isEmpty)
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