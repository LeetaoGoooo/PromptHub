import Foundation
import Testing
@testable import PromptHubSkillKit

final class SkillKitMockURLProtocol: URLProtocol, @unchecked Sendable {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Test func defaultAgentTargetsContainCodex() {
    #expect(AgentWorkflow.defaultTargets.contains(.codex))
}

@Test func installUsesGitHubDefaultBranchWhenMainMasterMiss() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [SkillKitMockURLProtocol.self]
    let session = URLSession(configuration: configuration)

    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer {
        SkillKitMockURLProtocol.requestHandler = nil
        try? fileManager.removeItem(at: base)
    }

    let installRoot = base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true)
    let codexGlobal = base.appendingPathComponent(".codex/skills", isDirectory: true)
    let codexProject = base.appendingPathComponent("project/.agents/skills", isDirectory: true)

    SkillKitMockURLProtocol.requestHandler = { request in
        let url = try #require(request.url)
        let path = url.path

        if url.host == "api.github.com", path == "/repos/acme/toolbox" {
            let body = #"{"default_branch":"develop","html_url":"https://github.com/acme/toolbox","stargazers_count":42}"#
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(body.utf8))
        }

        if url.host == "api.github.com", path == "/repos/acme/toolbox/git/trees/develop" {
            let body = #"{"tree":[{"path":"plugins/devops/skills/demo-skill/SKILL.md","type":"blob"}]}"#
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(body.utf8))
        }

        if url.host == "raw.githubusercontent.com",
           path == "/acme/toolbox/develop/plugins/devops/skills/demo-skill/SKILL.md" {
            let body = """
            ---
            name: demo-skill
            description: Installed from default branch
            ---

            # Demo
            """
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/plain"])!
            return (response, Data(body.utf8))
        }

        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        return (response, Data(#"{"message":"Not found"}"#.utf8))
    }

    let service = SkillCatalogService(
        session: session,
        fileManager: fileManager,
        apiBaseURL: URL(string: "https://skills.invalid"),
        installRootURL: installRoot,
        agentSkillRoots: [
            .codex: .init(global: codexGlobal, project: codexProject)
        ],
        localSkillRoots: []
    )

    try await service.install(
        request: SkillInstallRequest(
            source: "acme/toolbox",
            skillNames: ["demo-skill"],
            targetAgents: [.codex],
            isGlobal: true
        )
    )

    let installed = try await service.listInstalledSkills()
    #expect(installed.contains(where: { $0.name == "acme/toolbox@demo-skill" && $0.installedAgents == [.codex] }))
    #expect(
        fileManager.fileExists(
            atPath: codexGlobal.appendingPathComponent("demo-skill/SKILL.md").path
        )
    )
}

@Test func installFallsBackToAliasStrippedSkillName() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [SkillKitMockURLProtocol.self]
    let session = URLSession(configuration: configuration)

    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer {
        SkillKitMockURLProtocol.requestHandler = nil
        try? fileManager.removeItem(at: base)
    }

    let installRoot = base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true)
    let codexGlobal = base.appendingPathComponent(".codex/skills", isDirectory: true)
    let codexProject = base.appendingPathComponent("project/.agents/skills", isDirectory: true)

    SkillKitMockURLProtocol.requestHandler = { request in
        let url = try #require(request.url)
        let path = url.path

        if url.host == "skills.invalid",
           path.contains("/vercel-react-best-practices") {
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(#"{"message":"Not found"}"#.utf8))
        }

        if url.host == "api.github.com", path == "/repos/vercel-labs/agent-skills" {
            let body = #"{"default_branch":"main","html_url":"https://github.com/vercel-labs/agent-skills","stargazers_count":42}"#
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(body.utf8))
        }

        if url.host == "raw.githubusercontent.com",
           path == "/vercel-labs/agent-skills/main/skills/react-best-practices/SKILL.md" {
            let body = """
            ---
            name: react-best-practices
            description: Installed from alias fallback
            ---

            # Demo
            """
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/plain"])!
            return (response, Data(body.utf8))
        }

        if url.host == "api.github.com", path == "/repos/vercel-labs/agent-skills/git/trees/main" {
            let body = #"{"tree":[{"path":"skills/react-best-practices/SKILL.md","type":"blob"}]}"#
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(body.utf8))
        }

        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        return (response, Data(#"{"message":"Not found"}"#.utf8))
    }

    let service = SkillCatalogService(
        session: session,
        fileManager: fileManager,
        apiBaseURL: URL(string: "https://skills.invalid"),
        installRootURL: installRoot,
        agentSkillRoots: [
            .codex: .init(global: codexGlobal, project: codexProject)
        ],
        localSkillRoots: []
    )

    try await service.install(
        request: SkillInstallRequest(
            source: "vercel-labs/agent-skills",
            skillNames: ["vercel-react-best-practices"],
            targetAgents: [.codex],
            isGlobal: true
        )
    )

    let installed = try await service.listInstalledSkills()
    #expect(installed.contains(where: { $0.name == "vercel-labs/agent-skills@vercel-react-best-practices" }))
    #expect(
        fileManager.fileExists(
            atPath: codexGlobal.appendingPathComponent("vercel-react-best-practices/SKILL.md").path
        )
    )
}

@Test func listInstalledSkillsIncludesLocalRoots() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let localRoot = base.appendingPathComponent(".agents/skills", isDirectory: true)
    let skillDir = localRoot.appendingPathComponent("demo-skill", isDirectory: true)
    try fileManager.createDirectory(at: skillDir, withIntermediateDirectories: true)
    try """
    ---
    description: Demo local skill
    ---

    # Demo
    """.write(
        to: skillDir.appendingPathComponent("SKILL.md"),
        atomically: true,
        encoding: .utf8
    )

    let service = SkillCatalogService(
        session: .shared,
        fileManager: fileManager,
        apiBaseURL: nil,
        installRootURL: base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true),
        localSkillRoots: [localRoot]
    )

    let skills = try await service.listInstalledSkills()
    #expect(skills.contains(where: { $0.name == "demo-skill" && $0.isInstalled }))
}

@Test func listInstalledSkillsIncludesManagedInstallDirectories() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let installRoot = base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true)
    let managedDir = installRoot
        .appendingPathComponent("global", isDirectory: true)
        .appendingPathComponent("codex", isDirectory: true)
        .appendingPathComponent("owner_repo_demo-skill", isDirectory: true)
    try fileManager.createDirectory(at: managedDir, withIntermediateDirectories: true)
    try """
    ---
    name: demo-skill
    description: Managed install skill
    ---

    # Demo
    """.write(
        to: managedDir.appendingPathComponent("SKILL.md"),
        atomically: true,
        encoding: .utf8
    )

    let service = SkillCatalogService(
        session: .shared,
        fileManager: fileManager,
        apiBaseURL: nil,
        installRootURL: installRoot,
        localSkillRoots: []
    )

    let skills = try await service.listInstalledSkills()
    #expect(skills.contains(where: { $0.name == "demo-skill" && $0.isInstalled && $0.isGlobal }))
}

@Test func removeSkillCanTargetSpecificAgent() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let installRoot = base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true)
    let codexDir = installRoot
        .appendingPathComponent("global/codex/owner_repo_demo-skill", isDirectory: true)
    let cursorDir = installRoot
        .appendingPathComponent("global/cursor/owner_repo_demo-skill", isDirectory: true)
    try fileManager.createDirectory(at: codexDir, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: cursorDir, withIntermediateDirectories: true)
    try "# Demo".write(to: codexDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    try "# Demo".write(to: cursorDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

    let registryURL = installRoot.appendingPathComponent("installed-skills.json")
    try fileManager.createDirectory(at: registryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let record: [[String: Any]] = [[
        "package": "owner/repo@demo-skill",
        "description": "Demo",
        "isGlobal": true,
        "url": "https://example.com",
        "agents": ["codex", "cursor"],
        "installDirectories": ["global/codex/owner_repo_demo-skill", "global/cursor/owner_repo_demo-skill"],
        "updatedAt": Date().timeIntervalSinceReferenceDate
    ]]
    let data = try JSONSerialization.data(withJSONObject: record, options: [])
    try data.write(to: registryURL, options: .atomic)

    let service = SkillCatalogService(
        session: .shared,
        fileManager: fileManager,
        apiBaseURL: nil,
        installRootURL: installRoot,
        localSkillRoots: []
    )

    try await service.remove(name: "owner/repo@demo-skill", isGlobal: true, targetAgents: [.codex])
    let skills = try await service.listInstalledSkills()
    let retained = try #require(skills.first(where: { $0.name == "owner/repo@demo-skill" }))
    #expect(retained.installedAgents == [.cursor])
    #expect(fileManager.fileExists(atPath: codexDir.path) == false)
    #expect(fileManager.fileExists(atPath: cursorDir.path))
}

@Test func listInstalledSkillsInfersAgentFromLocalCLIPaths() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let codexRoot = base.appendingPathComponent(".codex/skills", isDirectory: true)
    let cursorRoot = base.appendingPathComponent(".cursor/skills", isDirectory: true)
    let codexSkill = codexRoot.appendingPathComponent("demo-skill", isDirectory: true)
    let cursorSkill = cursorRoot.appendingPathComponent("demo-skill", isDirectory: true)
    try fileManager.createDirectory(at: codexSkill, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: cursorSkill, withIntermediateDirectories: true)
    try "# Demo".write(to: codexSkill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    try "# Demo".write(to: cursorSkill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

    let agentRoots: [AgentWorkflow: AgentSkillRoots] = [
        .codex: .init(global: codexRoot, project: base.appendingPathComponent("project/.codex/skills", isDirectory: true)),
        .cursor: .init(global: cursorRoot, project: base.appendingPathComponent("project/.cursor/skills", isDirectory: true))
    ]

    let service = SkillCatalogService(
        session: .shared,
        fileManager: fileManager,
        apiBaseURL: nil,
        installRootURL: base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true),
        agentSkillRoots: agentRoots,
        localSkillRoots: [codexRoot, cursorRoot]
    )

    let skills = try await service.listInstalledSkills()
    let skill = try #require(skills.first(where: { $0.name == "demo-skill" }))
    #expect(Set(skill.installedAgents) == Set([.codex, .cursor]))
    #expect(skill.installedScopes == [.global])
}

@Test func removeSkillAlsoRemovesMirroredExternalCLIPath() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let installRoot = base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true)
    let codexExternal = base.appendingPathComponent("cli/codex/skills/demo-skill", isDirectory: true)
    let cursorExternal = base.appendingPathComponent("cli/cursor/skills/demo-skill", isDirectory: true)
    try fileManager.createDirectory(at: codexExternal, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: cursorExternal, withIntermediateDirectories: true)
    try "# Demo".write(to: codexExternal.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    try "# Demo".write(to: cursorExternal.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

    let managedCodex = installRoot
        .appendingPathComponent("global/codex/owner_repo_demo-skill", isDirectory: true)
    let managedCursor = installRoot
        .appendingPathComponent("global/cursor/owner_repo_demo-skill", isDirectory: true)
    try fileManager.createDirectory(at: managedCodex, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: managedCursor, withIntermediateDirectories: true)
    try "# Demo".write(to: managedCodex.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    try "# Demo".write(to: managedCursor.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

    let registryURL = installRoot.appendingPathComponent("installed-skills.json")
    try fileManager.createDirectory(at: registryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let record: [[String: Any]] = [[
        "package": "owner/repo@demo-skill",
        "description": "Demo",
        "isGlobal": true,
        "url": "https://example.com",
        "agents": ["codex", "cursor"],
        "installDirectories": ["global/codex/owner_repo_demo-skill", "global/cursor/owner_repo_demo-skill"],
        "updatedAt": Date().timeIntervalSinceReferenceDate
    ]]
    let data = try JSONSerialization.data(withJSONObject: record, options: [])
    try data.write(to: registryURL, options: .atomic)

    let agentRoots: [AgentWorkflow: AgentSkillRoots] = [
        .codex: .init(
            global: base.appendingPathComponent("cli/codex/skills", isDirectory: true),
            project: base.appendingPathComponent("project/.codex/skills", isDirectory: true)
        ),
        .cursor: .init(
            global: base.appendingPathComponent("cli/cursor/skills", isDirectory: true),
            project: base.appendingPathComponent("project/.cursor/skills", isDirectory: true)
        )
    ]

    let service = SkillCatalogService(
        session: .shared,
        fileManager: fileManager,
        apiBaseURL: nil,
        installRootURL: installRoot,
        agentSkillRoots: agentRoots,
        localSkillRoots: []
    )

    try await service.remove(name: "owner/repo@demo-skill", isGlobal: true, targetAgents: [.codex])
    #expect(fileManager.fileExists(atPath: codexExternal.path) == false)
    #expect(fileManager.fileExists(atPath: cursorExternal.path))
}

@Test func localSharedRootCanInferMultipleAgents() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let sharedRoot = base.appendingPathComponent(".agents/skills", isDirectory: true)
    let skillDir = sharedRoot.appendingPathComponent("demo-skill", isDirectory: true)
    try fileManager.createDirectory(at: skillDir, withIntermediateDirectories: true)
    try "# Demo".write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

    let agentRoots: [AgentWorkflow: AgentSkillRoots] = [
        .codex: .init(global: sharedRoot, project: base.appendingPathComponent("project/.agents/skills", isDirectory: true)),
        .geminiCLI: .init(global: sharedRoot, project: base.appendingPathComponent("project/.agents/skills", isDirectory: true)),
        .iflow: .init(global: sharedRoot, project: base.appendingPathComponent("project/.iflow/skills", isDirectory: true)),
        .qwenCode: .init(global: sharedRoot, project: base.appendingPathComponent("project/.qwen/skills", isDirectory: true))
    ]

    let service = SkillCatalogService(
        session: .shared,
        fileManager: fileManager,
        apiBaseURL: nil,
        installRootURL: base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true),
        agentSkillRoots: agentRoots,
        localSkillRoots: [sharedRoot]
    )

    let skills = try await service.listInstalledSkills()
    let skill = try #require(skills.first(where: { $0.name == "demo-skill" }))
    #expect(Set(skill.installedAgents) == Set([.codex, .geminiCLI, .iflow, .qwenCode]))
}

@Test func sharedRootCanInferAgentsFromSkillLockFile() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let sharedRoot = base.appendingPathComponent(".agents/skills", isDirectory: true)
    let skillDir = sharedRoot.appendingPathComponent("demo-skill", isDirectory: true)
    try fileManager.createDirectory(at: skillDir, withIntermediateDirectories: true)
    try "# Demo".write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

    let lockFile = base.appendingPathComponent(".agents/.skill-lock.json")
    try fileManager.createDirectory(at: lockFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    let lockPayload: [String: Any] = [
        "version": 3,
        "lastSelectedAgents": ["codex", "gemini-cli", "opencode", "unknown-agent"]
    ]
    let lockData = try JSONSerialization.data(withJSONObject: lockPayload, options: [])
    try lockData.write(to: lockFile, options: .atomic)

    let service = SkillCatalogService(
        session: .shared,
        fileManager: fileManager,
        apiBaseURL: nil,
        installRootURL: base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true),
        agentSkillRoots: [:],
        localSkillRoots: [sharedRoot],
        sharedLocalRoots: [sharedRoot],
        skillLockFileURLs: [lockFile]
    )

    let skills = try await service.listInstalledSkills()
    let skill = try #require(skills.first(where: { $0.name == "demo-skill" }))
    #expect(Set(skill.installedAgents) == Set([.codex, .geminiCLI, .opencode]))
}

@Test func sharedRootMergesLockAgentsWithDiscoveredAgentRoots() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let sharedRoot = base.appendingPathComponent(".agents/skills", isDirectory: true)
    let iflowRoot = base.appendingPathComponent(".iflow/skills", isDirectory: true)
    let sharedSkillDir = sharedRoot.appendingPathComponent("demo-skill", isDirectory: true)
    let iflowSkillDir = iflowRoot.appendingPathComponent("demo-skill", isDirectory: true)
    try fileManager.createDirectory(at: sharedSkillDir, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: iflowSkillDir, withIntermediateDirectories: true)
    try "# Demo".write(to: sharedSkillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    try "# Demo".write(to: iflowSkillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

    let lockFile = base.appendingPathComponent(".agents/.skill-lock.json")
    try fileManager.createDirectory(at: lockFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    let lockPayload: [String: Any] = [
        "version": 3,
        "lastSelectedAgents": ["codex"]
    ]
    let lockData = try JSONSerialization.data(withJSONObject: lockPayload, options: [])
    try lockData.write(to: lockFile, options: .atomic)

    let service = SkillCatalogService(
        session: .shared,
        fileManager: fileManager,
        apiBaseURL: nil,
        installRootURL: base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true),
        agentSkillRoots: [
            .codex: .init(
                global: base.appendingPathComponent(".codex/skills", isDirectory: true),
                project: base.appendingPathComponent("project/.agents/skills", isDirectory: true)
            ),
            .iflow: .init(
                global: iflowRoot,
                project: base.appendingPathComponent("project/.iflow/skills", isDirectory: true)
            )
        ],
        localSkillRoots: [sharedRoot, iflowRoot],
        sharedLocalRoots: [sharedRoot],
        skillLockFileURLs: [lockFile]
    )

    let skills = try await service.listInstalledSkills()
    let skill = try #require(skills.first(where: { $0.name == "demo-skill" }))
    #expect(Set(skill.installedAgents) == Set([.codex, .iflow]))
}

@Test func sharedRootMapsCLIStyleAgentAliasesFromLockFile() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let sharedRoot = base.appendingPathComponent(".agents/skills", isDirectory: true)
    let skillDir = sharedRoot.appendingPathComponent("demo-skill", isDirectory: true)
    try fileManager.createDirectory(at: skillDir, withIntermediateDirectories: true)
    try "# Demo".write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

    let lockFile = base.appendingPathComponent(".agents/.skill-lock.json")
    try fileManager.createDirectory(at: lockFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    let lockPayload: [String: Any] = [
        "version": 3,
        "lastSelectedAgents": ["codex-cli", "qwen-cli", "opencode-cli"]
    ]
    let lockData = try JSONSerialization.data(withJSONObject: lockPayload, options: [])
    try lockData.write(to: lockFile, options: .atomic)

    let service = SkillCatalogService(
        session: .shared,
        fileManager: fileManager,
        apiBaseURL: nil,
        installRootURL: base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true),
        agentSkillRoots: [:],
        localSkillRoots: [sharedRoot],
        sharedLocalRoots: [sharedRoot],
        skillLockFileURLs: [lockFile]
    )

    let skills = try await service.listInstalledSkills()
    let skill = try #require(skills.first(where: { $0.name == "demo-skill" }))
    #expect(Set(skill.installedAgents) == Set([.codex, .qwenCode, .opencode]))
}

@Test func listInstalledSkillsFallsBackWhenRegistryIsInvalid() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let codexRoot = base.appendingPathComponent(".codex/skills", isDirectory: true)
    let skillDir = codexRoot.appendingPathComponent("demo-skill", isDirectory: true)
    try fileManager.createDirectory(at: skillDir, withIntermediateDirectories: true)
    try "# Demo".write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

    let installRoot = base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true)
    try fileManager.createDirectory(at: installRoot, withIntermediateDirectories: true)
    try "not-json".write(
        to: installRoot.appendingPathComponent("installed-skills.json"),
        atomically: true,
        encoding: .utf8
    )

    let service = SkillCatalogService(
        session: .shared,
        fileManager: fileManager,
        apiBaseURL: nil,
        installRootURL: installRoot,
        agentSkillRoots: [
            .codex: .init(
                global: codexRoot,
                project: base.appendingPathComponent("project/.codex/skills", isDirectory: true)
            )
        ],
        localSkillRoots: [codexRoot]
    )

    let skills = try await service.listInstalledSkills()
    #expect(skills.contains(where: { $0.name == "demo-skill" }))
}

@Test func findSkillsDoesNotMatchByShortNameAcrossDifferentSources() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let installRoot = base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true)
    try fileManager.createDirectory(at: installRoot, withIntermediateDirectories: true)

    let installedRecord: [[String: Any]] = [[
        "package": "owner-a/repo-a@app-planner",
        "description": "Installed from owner-a/repo-a",
        "isGlobal": true,
        "url": "https://skills.sh/owner-a/repo-a/app-planner",
        "agents": ["codex"],
        "installDirectories": [],
        "updatedAt": Date().timeIntervalSinceReferenceDate
    ]]
    let recordData = try JSONSerialization.data(withJSONObject: installedRecord, options: [])
    try recordData.write(to: installRoot.appendingPathComponent("installed-skills.json"), options: .atomic)

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [SkillKitMockURLProtocol.self]
    let session = URLSession(configuration: config)
    SkillKitMockURLProtocol.requestHandler = { request in
        let url = try #require(request.url)
        #expect(url.path == "/api/skills")
        let payload = """
        {
          "skills": [
            {
              "owner": "owner-b",
              "repo": "repo-b",
              "skill": "app-planner",
              "description": "Another app planner"
            }
          ]
        }
        """.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, payload)
    }

    let service = SkillCatalogService(
        session: session,
        fileManager: fileManager,
        apiBaseURL: URL(string: "https://mock.skills.local")!,
        installRootURL: installRoot,
        localSkillRoots: []
    )

    let skills = try await service.findSkills(query: "")
    let found = try #require(skills.first(where: { $0.name == "owner-b/repo-b@app-planner" }))
    #expect(found.isInstalled == false)
}

@Test func removeCanDeleteExternalLocalSkillWithoutRegistryRecord() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let codexRoot = base.appendingPathComponent(".codex/skills", isDirectory: true)
    let skillDir = codexRoot.appendingPathComponent("demo-skill", isDirectory: true)
    try fileManager.createDirectory(at: skillDir, withIntermediateDirectories: true)
    try "# Demo".write(
        to: skillDir.appendingPathComponent("SKILL.md"),
        atomically: true,
        encoding: .utf8
    )

    let service = SkillCatalogService(
        session: .shared,
        fileManager: fileManager,
        apiBaseURL: nil,
        installRootURL: base.appendingPathComponent("AppSupport/PromptHub/Skills", isDirectory: true),
        agentSkillRoots: [
            .codex: .init(
                global: codexRoot,
                project: base.appendingPathComponent("project/.codex/skills", isDirectory: true)
            )
        ],
        localSkillRoots: [codexRoot]
    )

    try await service.remove(name: "demo-skill", isGlobal: true, targetAgents: [.codex])
    #expect(fileManager.fileExists(atPath: skillDir.path) == false)
}
