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

        let service = SkillCLIService(
            session: session,
            fileManager: .default,
            apiBaseURL: URL(string: "https://mock.skills.local")!,
            installRootURL: root
        )

        let workspace = SkillWorkspaceService(cliService: service)

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

        let package = "vercel-labs/agent-skills@vercel-react-best-practices"
        try await service.addSkill(package: package, isGlobal: true)

        let installedAfterAdd = try await service.listInstalledSkills()
        #expect(installedAfterAdd.count == 1)
        #expect(installedAfterAdd[0].name == package)
        #expect(installedAfterAdd[0].isGlobal == true)
        #expect(installedAfterAdd[0].description.contains("Vercel React optimization guidance"))

        try await service.removeSkill(name: package, isGlobal: true)
        let installedAfterRemove = try await service.listInstalledSkills()
        #expect(installedAfterRemove.isEmpty)
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

        let package = "vercel-labs/agent-skills@vercel-react-best-practices"
        try await service.addSkill(
            package: package,
            isGlobal: false,
            targetAgents: [.codex, .geminiCLI]
        )

        let snapshots = try await workspace.listInstalledSkills()

        #expect(snapshots.count == 1)
        #expect(snapshots[0].packageName == package)
        #expect(snapshots[0].scope == .project)
        #expect(snapshots[0].agents == [.codex, .geminiCLI])
        #expect(snapshots[0].summary.contains("Vercel React optimization guidance"))
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
                    isManagedByPromptHub: true
                ),
                InstalledSkillSnapshot(
                    package: package,
                    packageName: package.rawValue,
                    summary: "Global install",
                    scope: .global,
                    agents: [.geminiCLI, .codex],
                    url: nil,
                    isManagedByPromptHub: true
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
            #expect(url.path == "/api/skills")

            let payload = """
            {
              "skills": []
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

        let state = try await workspace.installLocalSkill(
            at: skillDirectory,
            scope: .project,
            targetAgents: [.codex]
        )

        #expect(state.catalogSkills.isEmpty)
        #expect(state.installedSkills.count == 1)
        #expect(state.installedSkills[0].packageName == "local-review-skill")
        #expect(state.installedSkills[0].isGlobal == false)
        #expect(state.installedSkills[0].agents == [.codex])
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
