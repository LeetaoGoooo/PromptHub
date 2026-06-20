import Foundation
import Testing
@testable import prompthub

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

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

// `.serialized` is required: every test installs its own
// `MockURLProtocol.requestHandler` into a process-wide `static` slot, so
// running the cases in parallel lets one test's handler answer another
// test's request (e.g. a 404-HTML handler bleeding into a JSON test).
@Suite(.serialized)
struct SkillCLIServiceTests {

    private func makeService(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) throws -> (SkillCLIService, SkillWorkspaceService, URL) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        MockURLProtocol.requestHandler = handler

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        // Pin every agent skill directory under `root` so discovery/install
        // never touches the host's real ~/.agents, ~/.codex, etc. Without this
        // listInstalledSkills() would return the developer's actual installed
        // skills via security-scoped bookmarks resolved by the shared manager.
        let accessDefaults = UserDefaults(suiteName: "CLIAccess.\(UUID().uuidString)")!
        let accessManager = CLIDirectoryAccessManager(
            defaults: accessDefaults,
            directoryBaseOverride: root.appendingPathComponent("home", isDirectory: true)
        )

        let service = SkillCLIService(
            session: session,
            fileManager: .default,
            apiBaseURL: URL(string: "https://mock.skills.local")!,
            installRootURL: root,
            cliAccessManager: accessManager
        )

        // Inject an isolated UserDefaults-backed selection store so project
        // scope does not depend on whatever project root happens to be
        // persisted in `UserDefaults.standard` on the host machine.
        let defaults = UserDefaults(suiteName: "SkillCLIServiceTests.\(UUID().uuidString)")!
        let selectionStore = SkillProjectSelectionStore(defaults: defaults)
        let workspace = SkillWorkspaceService(
            cliService: service,
            projectSelectionStore: selectionStore
        )

        return (service, workspace, root)
    }

    @Test func testFindSkillsFromAPI() async throws {
        let (service, _, root) = try makeService { request in
            let url = try #require(request.url)
            #expect(url.path == "/api/skills")

            let payload = """
            {
              "skills": [
                {
                  "owner": "vercel-labs",
                  "repo": "agent-skills",
                  "skill": "vercel-react-best-practices",
                  "description": "React and Next.js performance best practices",
                  "url": "https://skills.sh/vercel-labs/agent-skills/vercel-react-best-practices"
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
        defer { try? FileManager.default.removeItem(at: root) }

        let skills = try await service.findSkills(query: "react")

        #expect(skills.count == 1)
        #expect(skills[0].name == "vercel-labs/agent-skills@vercel-react-best-practices")
        #expect(skills[0].description.contains("React and Next.js"))
        #expect(skills[0].url == "https://skills.sh/vercel-labs/agent-skills/vercel-react-best-practices")
    }

    @Test func testAddListAndRemoveSkill() async throws {
        let (service, _, root) = try makeService { request in
            let url = try #require(request.url)
            if url.path == "/api/skills/vercel-labs/agent-skills/vercel-react-best-practices/content" {
                let markdown = """
                ---
                name: vercel-react-best-practices
                description: Vercel React optimization guidance
                ---

                # Vercel React Best Practices
                """.data(using: .utf8)!

                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "text/plain"]
                )!
                return (response, markdown)
            }

            let response = HTTPURLResponse(
                url: url,
                statusCode: 404,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"error\":\"not found\"}".utf8))
        }
        defer { try? FileManager.default.removeItem(at: root) }

        // Install to a single agent so the round-trip is deterministic. A
        // multi-agent install fans copies across agents that share the same
        // on-disk skills directory, which is exercised separately below.
        let package = "vercel-labs/agent-skills@vercel-react-best-practices"
        try await service.addSkill(package: package, isGlobal: true, targetAgents: [.codex])

        // The managed record is authoritative for scope; discovered external
        // copies resolve to the same qualified name via the skill-lock source
        // map but are flagged unmanaged, so select on isManagedByPromptHub.
        let installedAfterAdd = try await service.listInstalledSkills()
        let managed = try #require(installedAfterAdd.first { $0.name == package && $0.isManagedByPromptHub })
        #expect(managed.isGlobal == true)
        #expect(managed.description.contains("Vercel React optimization guidance"))

        try await service.removeSkill(name: package, isGlobal: true, targetAgents: [.codex])
        let installedAfterRemove = try await service.listInstalledSkills()
        #expect(!installedAfterRemove.contains { $0.name == package && $0.isManagedByPromptHub })
    }

    @Test func testInstalledSnapshotsReflectScopeAndAgents() async throws {
        let (service, workspace, root) = try makeService { request in
            let url = try #require(request.url)
            if url.path == "/api/skills/vercel-labs/agent-skills/vercel-react-best-practices/content" {
                let markdown = """
                ---
                name: vercel-react-best-practices
                description: Vercel React optimization guidance
                ---

                # Vercel React Best Practices
                """.data(using: .utf8)!

                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "text/plain"]
                )!
                return (response, markdown)
            }

            let response = HTTPURLResponse(
                url: url,
                statusCode: 404,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("{\"error\":\"not found\"}".utf8))
        }
        defer { try? FileManager.default.removeItem(at: root) }

        // Project scope needs a confined project root on both the install and
        // the workspace listing so we never write into the repo working dir.
        let projectRoot = root.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        // setSelectedProjectRootURL posts a notification; run it on the main
        // actor so any @Published observers don't publish off the main thread.
        await MainActor.run { workspace.setSelectedProjectRootURL(projectRoot) }
        try #require(workspace.selectedProjectRootURL != nil)

        // Use agents with dedicated project paths (.cursor → .cursor/skills,
        // .claudeCode → .claude/skills). Agents like .codex/.geminiCLI/.opencode
        // share .agents/skills, which would attribute one file to several agents
        // and make the exact-agents assertion ambiguous.
        let package = "vercel-labs/agent-skills@vercel-react-best-practices"
        try await service.addSkill(
            package: package,
            isGlobal: false,
            targetAgents: [.cursor, .claudeCode],
            projectRootURL: projectRoot
        )

        // Select the managed snapshot (the registry is authoritative for the
        // requested scope and agents); discovered copies are flagged unmanaged.
        let snapshots = try await workspace.listInstalledSkills()
        let managed = try #require(snapshots.first { $0.packageName == package && $0.isManagedByPromptHub })
        #expect(managed.scope == .project)
        #expect(managed.agents == [.claudeCode, .cursor])
        #expect(managed.summary.contains("Vercel React optimization guidance"))
    }

    @Test func testInstallationRegistryAggregatesSnapshotsByPackage() async throws {
        let (_, workspace, root) = try makeService { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let package = SkillPackageReference(rawValue: "vercel-labs/agent-skills@vercel-react-best-practices")
        let registry = workspace.makeInstallationRegistry(
            from: [
                InstalledSkillSnapshot(
                    package: package,
                    packageName: package.rawValue,
                    summary: "Project install",
                    scope: .project,
                    agents: [.codex],
                    url: nil,
                    isManagedByPromptHub: true,
                    installedPaths: [],
                    projectDisplayNames: []
                ),
                InstalledSkillSnapshot(
                    package: package,
                    packageName: package.rawValue,
                    summary: "Global install",
                    scope: .global,
                    agents: [.geminiCLI, .codex],
                    url: nil,
                    isManagedByPromptHub: true,
                    installedPaths: [],
                    projectDisplayNames: []
                )
            ]
        )

        let state = workspace.installationState(for: package, registry: registry)
        let missing = workspace.installationState(
            for: SkillPackageReference(rawValue: "missing/skills@unknown"),
            registry: registry
        )

        #expect(state.isInstalled)
        #expect(state.scopes == [.project, .global])
        #expect(state.agents == [.codex, .geminiCLI])
        #expect(state.removableScopes == [.project, .global])
        #expect(missing == .notInstalled)
    }

    @Test func testSkillStoreInstallationInfoAggregatesInstalledMatches() async throws {
        let (_, workspace, root) = try makeService { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let catalogSkill = SkillCLIService.SkillInfo(
            name: "vercel-labs/agent-skills@vercel-react-best-practices",
            description: "Catalog entry",
            isInstalled: true,
            isGlobal: false,
            url: nil,
            installedAgents: [.codex],
            installedScopes: [.project]
        )

        let installedSkills = [
            SkillCLIService.SkillInfo(
                name: "vercel-labs/agent-skills@vercel-react-best-practices",
                description: "Project install",
                isInstalled: true,
                isGlobal: false,
                url: nil,
                installedAgents: [.codex],
                installedScopes: [.project]
            ),
            SkillCLIService.SkillInfo(
                name: "vercel-labs/agent-skills@vercel-react-best-practices",
                description: "Global install",
                isInstalled: true,
                isGlobal: true,
                url: nil,
                installedAgents: [.geminiCLI],
                installedScopes: [.global]
            )
        ]

        let info = workspace.skillStoreInstallationInfo(
            for: catalogSkill,
            installedSkills: installedSkills,
            installedSnapshotLoaded: true
        )

        #expect(info.isInstalled)
        #expect(info.scopes == [.project, .global])
        #expect(info.agents == [.codex, .geminiCLI])
        #expect(info.removableScopes == [.project, .global])
    }

    @Test func testInstallLocalSkillFromStoreLoadsDirectorySkill() async throws {
        let (_, workspace, root) = try makeService { request in
            let url = try #require(request.url)
            // The post-install store reload queries the catalog, which probes
            // both /api/skills and the crawler snapshot fallback. Return an
            // empty (but valid) skill list for any request so the reload yields
            // no catalog entries without erroring.
            let payload = Data("{\"skills\": []}".utf8)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, payload)
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let skillDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: skillDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: skillDirectory) }

        let markdown = """
        ---
        name: local-review-skill
        description: Local skill for testing
        ---

        # Local Review Skill
        """
        try markdown.write(
            to: skillDirectory.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        // Project scope requires a selected project root. Point it at a real
        // directory the sandbox can bookmark so the install path is exercised
        // end to end instead of failing with .projectRootRequired.
        let projectRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        await MainActor.run { workspace.setSelectedProjectRootURL(projectRoot) }
        try #require(workspace.selectedProjectRootURL != nil)

        // Use .cursor (project root .cursor/skills) so the install targets a
        // dedicated directory; agents like .codex/.geminiCLI/.opencode all share
        // .agents/skills, which would make per-agent attribution ambiguous.
        let state = try await workspace.installLocalSkill(
            at: skillDirectory,
            scope: .project,
            targetAgents: [.cursor]
        )

        #expect(state.catalogSkills.isEmpty)
        let installed = try #require(state.installedSkills.first { $0.packageName == "local-review-skill" })
        #expect(installed.isGlobal == false)
        #expect(installed.agents == [.cursor])
    }

    @Test func testInvalidPackageFormatThrows() async throws {
        let (service, _, root) = try makeService { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { try? FileManager.default.removeItem(at: root) }

        do {
            try await service.addSkill(package: "invalid-package", isGlobal: true)
            Issue.record("Expected invalidSkillPackage error")
        } catch let error as SkillCLIService.CLIError {
            #expect(error == .invalidSkillPackage)
        }
    }

    @Test func testFindSkillsHTMLFailureIsSanitized() async throws {
        let (service, _, root) = try makeService { request in
            let url = try #require(request.url)
            let html = """
            <!DOCTYPE html><html><head><title>Error</title></head><body>Not Found</body></html>
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: url,
                statusCode: 404,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/html"]
            )!
            return (response, html)
        }
        defer { try? FileManager.default.removeItem(at: root) }

        do {
            _ = try await service.findSkills(query: "react")
            Issue.record("Expected networkError for HTML response")
        } catch let error as SkillCLIService.CLIError {
            guard case let .networkError(message) = error else {
                Issue.record("Expected networkError, got \(error)")
                return
            }
            #expect(message.contains("skills-api 404"))
            #expect(message.contains("Received HTML"))
            #expect(!message.contains("<!DOCTYPE html>"))
        }
    }
}
