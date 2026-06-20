import Foundation
import PromptHubCLILib
import PromptHubSkillKit
import Testing

// MARK: - URLProtocol stub

/// Thread-local-style responder for the URLProtocol stub. Each test sets a
/// `responder` closure that maps incoming URL → (HTTP status, body bytes).
/// Returning nil for an unmatched URL forwards a 404 so unmocked endpoints
/// fail loudly during the test run.
final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var responder: ((URL) -> (status: Int, body: Data)?)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let pair = Self.responder?(url) ?? (status: 404, body: Data())
        let response = HTTPURLResponse(
            url: url,
            statusCode: pair.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: pair.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// URLProtocol stub that simulates a hard network failure for every request.
final class FailingProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}

private func stubbedSession(protocolType: AnyClass) -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [protocolType] + (config.protocolClasses ?? [])
    return URLSession(configuration: config)
}

private func snapshotJSON(skills: [(owner: String, repo: String, skillID: String, installs: Int, displayName: String?)]) -> Data {
    var skillObjects: [[String: Any]] = []
    for skill in skills {
        var obj: [String: Any] = [
            "source": "\(skill.owner)/\(skill.repo)",
            "skillId": skill.skillID,
            "name": "\(skill.repo) \(skill.skillID)",
            "installs": skill.installs,
            "owner": skill.owner,
            "repo": skill.repo,
            "githubUrl": "https://github.com/\(skill.owner)/\(skill.repo)"
        ]
        if let displayName = skill.displayName {
            obj["displayName"] = displayName
        }
        skillObjects.append(obj)
    }
    let snapshot: [String: Any] = [
        "scrapedAt": ISO8601DateFormatter().string(from: Date()),
        "totalSkills": skillObjects.count,
        "skills": skillObjects
    ]
    return try! JSONSerialization.data(withJSONObject: snapshot, options: [.sortedKeys])
}

private func makeTempBase() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeService(session: URLSession, base: URL) -> PromptHubCLIService {
    let env = PromptHubCLIEnvironment(
        homeDirectoryURL: base,
        installRootURL: base.appendingPathComponent("install", isDirectory: true),
        projectRootURL: base.appendingPathComponent("project", isDirectory: true),
        agentSkillRoots: [:],
        localSkillRoots: [],
        sharedLocalRoots: [],
        skillLockFileURLs: []
    )
    return PromptHubCLIService(environment: env, session: session)
}

// MARK: - Tests

/// Serialized because the URLProtocol stub holds static responder state that
/// would otherwise race across parallel tests.
@Suite(.serialized)
struct RemoteSearchTests {

@Test func searchReturnsRemotePackagesMatchingQuery() async throws {
    let base = makeTempBase()
    defer { try? FileManager.default.removeItem(at: base) }

    StubProtocol.responder = { url in
        // The catalog hits the registry snapshot URL on raw.githubusercontent.com.
        if url.host == "raw.githubusercontent.com" {
            return (
                status: 200,
                body: snapshotJSON(skills: [
                    (owner: "octo", repo: "alpha", skillID: "writer", installs: 9, displayName: "Writer Pro"),
                    (owner: "octo", repo: "beta", skillID: "review", installs: 4, displayName: "Code Review"),
                    (owner: "octo", repo: "beta", skillID: "summarize", installs: 1, displayName: nil)
                ])
            )
        }
        return nil
    }
    defer { StubProtocol.responder = nil }

    let service = makeService(session: stubbedSession(protocolType: StubProtocol.self), base: base)
    let results = try await service.searchRemoteSkills(query: "review")
    #expect(results.count == 1)
    #expect(results[0].package == "octo/beta@review")
    #expect(results[0].url == "https://github.com/octo/beta")
    #expect(results[0].isInstalled == false)
    // The package field is install-ready as documented in cli-contract.md §2.x.
    // Mimic the install command's reference parser to confirm.
    #expect(results[0].package.contains("@"))
    #expect(results[0].package.split(separator: "/").count == 2)
}

@Test func emptyQueryReturnsAllRegistryEntries() async throws {
    let base = makeTempBase()
    defer { try? FileManager.default.removeItem(at: base) }

    StubProtocol.responder = { url in
        if url.host == "raw.githubusercontent.com" {
            return (
                status: 200,
                body: snapshotJSON(skills: [
                    (owner: "a", repo: "repo", skillID: "one", installs: 5, displayName: nil),
                    (owner: "b", repo: "repo", skillID: "two", installs: 3, displayName: nil)
                ])
            )
        }
        return nil
    }
    defer { StubProtocol.responder = nil }

    let service = makeService(session: stubbedSession(protocolType: StubProtocol.self), base: base)
    let results = try await service.searchRemoteSkills(query: "")
    #expect(results.count == 2)
    // Most-installed first ordering preserved from the catalog.
    #expect(results.map(\.package) == ["a/repo@one", "b/repo@two"])
}

@Test func searchEmptyMatchesReturnsEmptyListNotError() async throws {
    let base = makeTempBase()
    defer { try? FileManager.default.removeItem(at: base) }

    StubProtocol.responder = { url in
        if url.host == "raw.githubusercontent.com" {
            return (
                status: 200,
                body: snapshotJSON(skills: [
                    (owner: "a", repo: "repo", skillID: "one", installs: 5, displayName: nil)
                ])
            )
        }
        return nil
    }
    defer { StubProtocol.responder = nil }

    let service = makeService(session: stubbedSession(protocolType: StubProtocol.self), base: base)
    let results = try await service.searchRemoteSkills(query: "no-such-thing-anywhere")
    #expect(results.isEmpty)
}

@Test func searchSurfacesHTTPFailureAsActionableError() async throws {
    let base = makeTempBase()
    defer { try? FileManager.default.removeItem(at: base) }

    StubProtocol.responder = { _ in
        return (status: 503, body: Data("{\"error\":\"upstream offline\"}".utf8))
    }
    defer { StubProtocol.responder = nil }

    let service = makeService(session: stubbedSession(protocolType: StubProtocol.self), base: base)
    do {
        _ = try await service.searchRemoteSkills(query: "any")
        Issue.record("expected remoteCatalogUnavailable")
    } catch let error as PromptHubCLIError {
        if case .remoteCatalogUnavailable = error {
            // Error message must point at the local fallback so users see what
            // still works when the remote is down.
            let description = error.errorDescription ?? ""
            #expect(description.contains("ph skill exports"))
            #expect(description.contains("ph skill list"))
        } else {
            Issue.record("unexpected error \(error)")
        }
    }
}

@Test func searchSurfacesMalformedJSONAsActionableError() async throws {
    let base = makeTempBase()
    defer { try? FileManager.default.removeItem(at: base) }

    StubProtocol.responder = { _ in
        return (status: 200, body: Data("{not really json".utf8))
    }
    defer { StubProtocol.responder = nil }

    let service = makeService(session: stubbedSession(protocolType: StubProtocol.self), base: base)
    do {
        _ = try await service.searchRemoteSkills(query: "any")
        Issue.record("expected remoteCatalogUnavailable")
    } catch let error as PromptHubCLIError {
        if case .remoteCatalogUnavailable = error {} else { Issue.record("unexpected error \(error)") }
    }
}

@Test func searchSurfacesNetworkFailureCleanly() async throws {
    let base = makeTempBase()
    defer { try? FileManager.default.removeItem(at: base) }

    let service = makeService(session: stubbedSession(protocolType: FailingProtocol.self), base: base)
    do {
        _ = try await service.searchRemoteSkills(query: "any")
        Issue.record("expected remoteCatalogUnavailable")
    } catch let error as PromptHubCLIError {
        if case .remoteCatalogUnavailable = error {} else { Issue.record("unexpected error \(error)") }
    }
}

// MARK: - JSON contract

@Test func remoteSkillSummaryJSONHasContractKeys() throws {
    let row = PromptHubRemoteSkillSummary(
        package: "owner/repo@skill",
        description: "demo",
        url: "https://github.com/owner/repo",
        isInstalled: false
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(row)
    let dict = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let keys = Set(dict.keys)

    // Required keys.
    #expect(keys.contains("package"))
    #expect(keys.contains("description"))
    #expect(keys.contains("isInstalled"))
    #expect(keys.contains("url"))
    // Identifiable.id MUST stay out of JSON.
    #expect(!keys.contains("id"))

    // Optional `url` is omitted when nil.
    let nilRow = PromptHubRemoteSkillSummary(package: "x@y", description: "", url: nil, isInstalled: false)
    let nilData = try encoder.encode(nilRow)
    let nilDict = try #require(try JSONSerialization.jsonObject(with: nilData) as? [String: Any])
    #expect(!Set(nilDict.keys).contains("url"))
}

} // end RemoteSearchTests
