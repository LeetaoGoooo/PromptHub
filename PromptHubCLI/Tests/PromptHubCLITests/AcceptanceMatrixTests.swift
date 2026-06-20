import Foundation
import Testing

// CLI-20: enforce that docs/cli-acceptance-matrix.md keeps describing
// every shipped `ph` subcommand. If you add a new command without
// extending the matrix or the smoke entry point, this suite fails.

private func repoRoot() throws -> URL {
    var url = URL(fileURLWithPath: #filePath)
    // .../PromptHubCLI/Tests/PromptHubCLITests/AcceptanceMatrixTests.swift
    for _ in 0..<4 {
        url.deleteLastPathComponent()
    }
    let candidate = url.appendingPathComponent("Formula/ph.rb")
    try #require(FileManager.default.fileExists(atPath: candidate.path))
    return url
}

private func readFile(_ relative: String) throws -> String {
    let root = try repoRoot()
    let path = root.appendingPathComponent(relative)
    try #require(FileManager.default.fileExists(atPath: path.path), "missing \(relative)")
    return try String(contentsOf: path, encoding: .utf8)
}

/// Every public `ph` subcommand pair as it appears in user-facing help.
/// Update this list when you ship a new subcommand AND add a matching
/// row to docs/cli-acceptance-matrix.md.
private let publicCommands: [String] = [
    "ph prompt list",
    "ph prompt show",
    "ph prompt search",
    "ph prompt render",
    "ph prompt create",
    "ph prompt update",
    "ph prompt delete",
    "ph skill exports",
    "ph skill show",
    "ph skill list",
    "ph skill inspect",
    "ph skill install",
    "ph skill uninstall",
    "ph skill update",
    "ph skill reinstall",
    "ph skill where",
    "ph skill search",
    "ph doctor",
]

// MARK: - Matrix doc covers every shipped command

@Test func acceptanceMatrixCoversEveryShippedCommand() throws {
    let matrix = try readFile("docs/cli-acceptance-matrix.md")
    for command in publicCommands {
        #expect(
            matrix.contains(command),
            "docs/cli-acceptance-matrix.md does not mention '\(command)' — add a path or contract row before shipping it"
        )
    }
}

@Test func acceptanceMatrixListsAllSmokeScripts() throws {
    let matrix = try readFile("docs/cli-acceptance-matrix.md")
    let smokeRoot = try repoRoot().appendingPathComponent("PromptHubCLI/Tests/Smoke")
    let entries = try FileManager.default.contentsOfDirectory(atPath: smokeRoot.path)
        .filter { $0.hasSuffix(".sh") }
        .sorted()

    for entry in entries {
        #expect(
            matrix.contains(entry),
            "smoke script \(entry) is not referenced from docs/cli-acceptance-matrix.md"
        )
    }
}

// MARK: - Smoke entry point includes every smoke script

@Test func runAllSmokeIncludesEveryShellSmoke() throws {
    let runAll = try readFile("PromptHubCLI/Tests/Smoke/run-all.sh")
    let smokeRoot = try repoRoot().appendingPathComponent("PromptHubCLI/Tests/Smoke")
    let entries = try FileManager.default.contentsOfDirectory(atPath: smokeRoot.path)
        .filter { $0.hasSuffix(".sh") }
        .filter { $0 != "run-all.sh" }
        .sorted()

    for entry in entries {
        #expect(
            runAll.contains(entry),
            "PromptHubCLI/Tests/Smoke/run-all.sh does not run \(entry) — add it to the scripts array"
        )
    }
}

// MARK: - CI / release workflows actually invoke the matrix

@Test func ciWorkflowInvokesAcceptanceMatrix() throws {
    let ci = try readFile(".github/workflows/prompthub-cli-ci.yml")
    #expect(
        ci.contains("PromptHubCLI/Tests/Smoke/run-all.sh"),
        "CI workflow does not run PromptHubCLI/Tests/Smoke/run-all.sh — acceptance matrix would not gate PRs"
    )
}

@Test func releaseWorkflowInvokesAcceptanceMatrix() throws {
    let release = try readFile(".github/workflows/prompthub-cli-release.yml")
    #expect(
        release.contains("PromptHubCLI/Tests/Smoke/run-all.sh"),
        "release workflow does not run PromptHubCLI/Tests/Smoke/run-all.sh — release would not be gated on the matrix"
    )
}

// MARK: - All smoke scripts are executable

@Test func smokeScriptsAreExecutable() throws {
    let smokeRoot = try repoRoot().appendingPathComponent("PromptHubCLI/Tests/Smoke")
    let entries = try FileManager.default.contentsOfDirectory(atPath: smokeRoot.path)
        .filter { $0.hasSuffix(".sh") }

    for entry in entries {
        let path = smokeRoot.appendingPathComponent(entry).path
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        #expect(perms & 0o111 != 0, "smoke script \(entry) is not executable")
    }
}
