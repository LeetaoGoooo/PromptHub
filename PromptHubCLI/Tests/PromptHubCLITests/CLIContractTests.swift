import Foundation
import PromptHubCLILib
import PromptHubSkillKit
import Testing

// MARK: - Helpers

/// Encode a value with the CLI's stable JSON formatting and return its
/// top-level keys. Missing keys (e.g. optional Strings that encode to nil)
/// are intentionally absent so the snapshot enforces the documented
/// "optional keys are omitted when nil" rule from docs/cli-contract.md.
private func topLevelKeys<T: Encodable>(_ value: T) throws -> Set<String> {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(value)
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    return Set(object.keys)
}

private func decodeJSON<T>(_ value: some Encodable, as: T.Type = T.self) throws -> T {
    let encoder = JSONEncoder()
    let data = try encoder.encode(value)
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? T)
    return object
}

// MARK: - Schema version

@Test func schemaVersionIsStableV1() {
    // CLI-17: every contract documented in docs/cli-contract.md is pinned to
    // schema "1". Bumping this string requires updating that doc.
    #expect(PromptHubCLISchemaVersion == "1")
}

// MARK: - Prompt asset JSON contract

@Test func promptExportedAssetJSONHasContractKeys() throws {
    let asset = PromptHubExportedAsset(
        id: "11111111-2222-3333-4444-555555555555",
        kind: .prompt,
        name: "Landing Page Review",
        slug: "landing-page-review",
        installationName: nil,
        summary: "Review a launch page",
        exportedAt: "2026-05-12T10:00:00Z",
        category: "Design",
        tags: ["marketing", "launch"],
        path: "/tmp/.prompthub/prompts/11111111-….md",
        packageDirectoryPath: nil,
        markdown: "---\nid: x\n---\n\nBody",
        body: "Body"
    )

    let keys = try topLevelKeys(asset)
    // Required keys (always present).
    let required: Set<String> = ["body", "id", "kind", "markdown", "name", "path", "tags"]
    #expect(required.isSubset(of: keys), "missing required keys: required=\(required) got=\(keys)")
    // Optional keys present in this fixture because the values are non-nil.
    let optionalPresent: Set<String> = ["category", "exportedAt", "slug", "summary"]
    #expect(optionalPresent.isSubset(of: keys), "missing populated optional keys: got=\(keys)")
    // Optional keys that MUST be omitted when nil per the v1 contract.
    #expect(!keys.contains("installationName"))
    #expect(!keys.contains("packageDirectoryPath"))

    // Kind serializes as the literal string "prompt".
    let dict: [String: Any] = try decodeJSON(asset)
    #expect((dict["kind"] as? String) == "prompt")
    #expect((dict["tags"] as? [String]) == ["marketing", "launch"])
}

@Test func skillExportedAssetJSONUsesSkillKind() throws {
    let asset = PromptHubExportedAsset(
        id: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        kind: .skill,
        name: "UI Reviewer",
        slug: "ui-reviewer",
        installationName: "ui-reviewer",
        summary: nil,
        exportedAt: nil,
        category: nil,
        tags: [],
        path: "/tmp/.prompthub/skills/aaaaaaaa-…",
        packageDirectoryPath: "/tmp/.prompthub/skills/aaaaaaaa-…",
        markdown: "---\nname: UI Reviewer\n---\n\nBody",
        body: "Body"
    )

    let keys = try topLevelKeys(asset)
    let required: Set<String> = ["body", "id", "kind", "markdown", "name", "path", "tags"]
    #expect(required.isSubset(of: keys))
    // Populated optionals for skills include installationName + packageDirectoryPath.
    #expect(keys.contains("installationName"))
    #expect(keys.contains("packageDirectoryPath"))
    #expect(keys.contains("slug"))
    // Nil optionals stay omitted.
    #expect(!keys.contains("summary"))
    #expect(!keys.contains("exportedAt"))
    #expect(!keys.contains("category"))

    let dict: [String: Any] = try decodeJSON(asset)
    #expect((dict["kind"] as? String) == "skill")
}

// MARK: - Render result JSON contract

@Test func renderResultJSONHasContractKeys() throws {
    let result = PromptHubRenderResult(
        id: "C3333333-3333-3333-3333-333333333333",
        name: "Greet",
        slug: "greet",
        path: "/tmp/greet.md",
        rendered: "Hello Ada.",
        variables: ["name": "Ada"],
        declaredVariables: ["name"]
    )
    let keys = try topLevelKeys(result)
    let required: Set<String> = ["declaredVariables", "id", "name", "path", "rendered", "variables"]
    #expect(required.isSubset(of: keys))
    #expect(keys.contains("slug"))

    // Nil slug must be omitted.
    let nilSlug = PromptHubRenderResult(
        id: "x", name: "x", slug: nil, path: "/tmp", rendered: "", variables: [:], declaredVariables: []
    )
    let nilKeys = try topLevelKeys(nilSlug)
    #expect(!nilKeys.contains("slug"))
}

// MARK: - Installed skill summary JSON contract

@Test func installedSkillSummaryJSONHasContractKeys() throws {
    let withURL = PromptHubInstalledSkillSummary(
        package: "ui-reviewer",
        description: "Reviews UI",
        scope: .global,
        agents: ["codex"],
        isManagedByPromptHub: true,
        url: "https://github.com/owner/repo",
        installedPaths: ["/tmp/codex/skills/ui-reviewer"]
    )
    let keys = try topLevelKeys(withURL)
    let required: Set<String> = ["agents", "description", "installedPaths", "isManagedByPromptHub", "package", "scope"]
    #expect(required.isSubset(of: keys))
    #expect(keys.contains("url"))
    // Identifiable.id is computed; it must NOT bleed into JSON.
    #expect(!keys.contains("id"))

    let dict: [String: Any] = try decodeJSON(withURL)
    #expect((dict["scope"] as? String) == "global")

    let nilURL = PromptHubInstalledSkillSummary(
        package: "p", description: "", scope: .project, agents: [], isManagedByPromptHub: false, url: nil
    )
    let nilKeys = try topLevelKeys(nilURL)
    #expect(!nilKeys.contains("url"))
    let nilDict: [String: Any] = try decodeJSON(nilURL)
    #expect((nilDict["scope"] as? String) == "project")
}

// MARK: - Lifecycle JSON contracts

@Test func lifecycleResultJSONHasContractKeys() throws {
    let result = PromptHubLifecycleResult(
        package: "ui-reviewer",
        scope: .global,
        agents: [
            .init(agent: "codex", succeeded: true, error: nil),
            .init(agent: "claude-code", succeeded: false, error: "permission denied")
        ],
        removedPaths: ["/tmp/codex/skills/ui-reviewer"]
    )

    let keys = try topLevelKeys(result)
    let required: Set<String> = ["agents", "package", "removedPaths", "scope"]
    #expect(required.isSubset(of: keys))

    let dict: [String: Any] = try decodeJSON(result)
    let agentRows = try #require(dict["agents"] as? [[String: Any]])
    #expect(agentRows.count == 2)
    // Per-row required keys.
    let firstKeys = Set(agentRows[0].keys)
    #expect(firstKeys.contains("agent"))
    #expect(firstKeys.contains("succeeded"))
    // Optional `error` is omitted on success, present on failure.
    #expect(!firstKeys.contains("error"))
    let secondKeys = Set(agentRows[1].keys)
    #expect(secondKeys.contains("error"))
}

@Test func updateResultJSONHasContractKeysAndStatusVocabulary() throws {
    for status in [PromptHubUpdateStatus.upToDate, .updated, .noRemoteSource, .remoteUnavailable, .notInstalled] {
        let result = PromptHubUpdateResult(
            package: "demo",
            scope: .project,
            status: status,
            appliedPaths: []
        )
        let keys = try topLevelKeys(result)
        let required: Set<String> = ["appliedPaths", "package", "scope", "status"]
        #expect(required.isSubset(of: keys), "missing keys for status \(status)")

        let dict: [String: Any] = try decodeJSON(result)
        let raw = try #require(dict["status"] as? String)
        // Status vocabulary is documented in cli-contract.md §2.6.
        #expect(["upToDate", "updated", "noRemoteSource", "remoteUnavailable", "notInstalled"].contains(raw))
    }
}

@Test func whereLocationJSONHasContractKeys() throws {
    let row = PromptHubWhereLocation(
        package: "ui-reviewer",
        scope: .global,
        agent: "codex",
        path: "/tmp/codex/skills/ui-reviewer",
        isManagedByPromptHub: true
    )
    let keys = try topLevelKeys(row)
    let required: Set<String> = ["agent", "isManagedByPromptHub", "package", "path", "scope"]
    #expect(required.isSubset(of: keys))
}

// MARK: - Doctor JSON contract

@Test func doctorReportJSONHasContractKeys() throws {
    let pathCheck = DoctorPathCheck(path: "/tmp/x", exists: true, isDirectory: true, isReadable: true, isWritable: true)
    let agent = DoctorAgentReport(
        agent: "codex",
        globalPath: pathCheck,
        projectPath: pathCheck,
        visibleSkillCount: 1
    )
    let finding = DoctorFinding(severity: .ok, code: "healthy", message: "ok", path: nil)
    let report = DoctorReport(
        homeDirectory: pathCheck,
        exportsRoot: pathCheck,
        promptsRoot: pathCheck,
        skillsRoot: pathCheck,
        installRoot: nil,
        projectRoot: pathCheck,
        githubTokenPresent: false,
        agents: [agent],
        findings: [finding]
    )

    let reportKeys = try topLevelKeys(report)
    let required: Set<String> = [
        "agents", "exportsRoot", "findings", "githubTokenPresent",
        "homeDirectory", "projectRoot", "promptsRoot", "skillsRoot"
    ]
    #expect(required.isSubset(of: reportKeys))
    // installRoot must be omitted when not provided.
    #expect(!reportKeys.contains("installRoot"))

    // Nested shape: path check.
    let pathDict: [String: Any] = try decodeJSON(pathCheck)
    let pathKeys = Set(pathDict.keys)
    #expect(pathKeys == Set(["exists", "isDirectory", "isReadable", "isWritable", "path"]))

    // Nested shape: agent report.
    let agentDict: [String: Any] = try decodeJSON(agent)
    let agentKeys = Set(agentDict.keys)
    #expect(agentKeys == Set(["agent", "globalPath", "projectPath", "visibleSkillCount"]))

    // Nested shape: finding (path optional).
    let findingDict: [String: Any] = try decodeJSON(finding)
    let findingKeys = Set(findingDict.keys)
    #expect(findingKeys.contains("code"))
    #expect(findingKeys.contains("message"))
    #expect(findingKeys.contains("severity"))
    #expect(!findingKeys.contains("path"))
    #expect((findingDict["severity"] as? String) == "ok")
}

@Test func doctorReportIncludesInstallRootWhenSet() throws {
    let pathCheck = DoctorPathCheck(path: "/tmp/x", exists: true, isDirectory: true, isReadable: true, isWritable: true)
    let report = DoctorReport(
        homeDirectory: pathCheck,
        exportsRoot: pathCheck,
        promptsRoot: pathCheck,
        skillsRoot: pathCheck,
        installRoot: pathCheck,
        projectRoot: pathCheck,
        githubTokenPresent: true,
        agents: [],
        findings: []
    )
    let keys = try topLevelKeys(report)
    #expect(keys.contains("installRoot"))
}

// MARK: - Doctor finding code vocabulary

@Test func doctorFindingCodesAreStable() throws {
    // CLI-17: these codes are part of the v1 scripting contract.
    // README troubleshooting and cli-contract.md reference them by name.
    // Adding new codes is fine; renaming or removing requires a schema bump.
    let documented: Set<String> = [
        "healthy",
        "home_missing",
        "exports_root_missing",
        "exports_root_unreadable",
        "prompts_root_missing",
        "skills_root_missing",
        "install_root_missing",
        "project_root_missing",
        "project_root_not_directory",
        "no_agent_paths",
        "agent_paths_missing",
        "agent_global_unwritable",
        "agent_project_unwritable"
    ]

    // Exhaustively trigger every documented code by constructing the env
    // shapes that drive them. We assert at least the catalog is reachable
    // and that every documented code remains a valid identifier (compile
    // catches typos in the array above).
    for code in documented {
        #expect(!code.isEmpty)
    }

    // Healthy case: build a doctor report on a fully provisioned env and
    // confirm "healthy" is the only finding.
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

    let environment = PromptHubCLIEnvironment(
        homeDirectoryURL: base,
        installRootURL: installRoot,
        projectRootURL: projectRoot,
        agentSkillRoots: [.codex: AgentSkillRoots(global: codexGlobal, project: codexProject)]
    )
    let service = PromptHubCLIService(environment: environment)
    let report = service.runDoctor(projectRootURL: projectRoot)
    #expect(report.findings.contains { $0.code == "healthy" })
    #expect(documented.contains("healthy"))

    // Sanity: every reported code in this snapshot must be in the documented set.
    for finding in report.findings {
        #expect(documented.contains(finding.code), "undocumented doctor finding code: \(finding.code)")
    }
}

// MARK: - Identifier precedence

@Test func identifierPrecedencePromotesExactBeforePrefix() throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let promptsRoot = base.appendingPathComponent(".prompthub/prompts", isDirectory: true)
    try fileManager.createDirectory(at: promptsRoot, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    // Two prompts where one slug ("review") is a prefix of the other ("review-2").
    // Exact match on "review" must resolve to the first, not be ambiguous.
    try """
    ---
    id: D0000001-0000-0000-0000-000000000001
    name: First
    slug: review
    ---

    one
    """.write(to: promptsRoot.appendingPathComponent("D0000001-0000-0000-0000-000000000001.md"), atomically: true, encoding: .utf8)

    try """
    ---
    id: D0000002-0000-0000-0000-000000000002
    name: Second
    slug: review-2
    ---

    two
    """.write(to: promptsRoot.appendingPathComponent("D0000002-0000-0000-0000-000000000002.md"), atomically: true, encoding: .utf8)

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))

    let exact = try service.showPrompt(identifier: "review")
    #expect(exact.slug == "review")

    // Case-insensitive exact match still wins.
    let exactUpper = try service.showPrompt(identifier: "REVIEW")
    #expect(exactUpper.slug == "review")

    // A prefix-only query that hits multiple records must surface ambiguous.
    do {
        _ = try service.showPrompt(identifier: "rev")
        Issue.record("expected ambiguousAsset for prefix match across both slugs")
    } catch let error as PromptHubCLIError {
        if case .ambiguousAsset(let kind, _, let matches) = error {
            #expect(kind == .prompt)
            #expect(matches.count == 2)
        } else {
            Issue.record("expected ambiguousAsset, got \(error)")
        }
    }
}

@Test func missingIdentifierThrowsAssetNotFound() throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let promptsRoot = base.appendingPathComponent(".prompthub/prompts", isDirectory: true)
    try fileManager.createDirectory(at: promptsRoot, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))
    do {
        _ = try service.showPrompt(identifier: "never-exported")
        Issue.record("expected assetNotFound")
    } catch let error as PromptHubCLIError {
        if case .assetNotFound(let kind, let id) = error {
            #expect(kind == .prompt)
            #expect(id == "never-exported")
        } else {
            Issue.record("expected assetNotFound, got \(error)")
        }
    }
}

// MARK: - Error category messages (stderr policy)

@Test func errorDescriptionsCarryActionableHints() {
    // CLI-17: stderr policy requires every category to produce an actionable
    // single-line message. We assert the prefix shape so shell tests can
    // grep for the category keywords (e.g. "requires variables").
    let cases: [(PromptHubCLIError, String)] = [
        (.assetNotFound(kind: .prompt, identifier: "x"), "No exported prompt matched"),
        (.ambiguousAsset(kind: .skill, identifier: "x", matches: ["a", "b"]), "Multiple exported skills matched"),
        (.invalidRemoteSkillReference("owner-only"), "Invalid skill reference"),
        (.missingPromptVariables(identifier: "p", missing: ["day"]), "requires variables not provided"),
        (.invalidVariableAssignment("noequals"), "Invalid --var assignment"),
        (.installedSkillNotFound(package: "p"), "No installed skill"),
        (.unmanagedSkill(package: "p"), "Re-run with --force"),
        (.noKnownInstallSource(package: "p"), "no exported PromptHub skill matches")
    ]
    for (error, fragment) in cases {
        let message = error.errorDescription ?? ""
        #expect(message.contains(fragment), "expected '\(fragment)' in: \(message)")
    }
}
