import Foundation
import Testing

// CLI-19: copy parity guard. Every user-facing surface that mentions
// the ph install path must use the same brew tap, same supported
// platform story, and must not regress to the old "CLI installer is
// pending release" copy.

private func repoRoot() throws -> URL {
    var url = URL(fileURLWithPath: #filePath)
    // .../PromptHubCLI/Tests/PromptHubCLITests/DocsParityTests.swift
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
    try #require(
        FileManager.default.fileExists(atPath: path.path),
        "missing parity surface: \(relative)"
    )
    return try String(contentsOf: path, encoding: .utf8)
}

/// The user-facing surfaces that must tell the same `ph` story.
private let parityCopyPaths: [String] = [
    "README.md",
    "PromptHubCLI/README.md",
    "docs/cli-release.md",
    "prompthub/Views/HomeViews/CLIDashboardView.swift",
    "prompthub/Views/HomeViews/OnboardingView.swift",
]

// MARK: - Outdated copy must not regress

@Test func noSurfaceClaimsCLIIsUnpublished() throws {
    let banned = [
        "PromptHub CLI is not publicly released yet",
        "public PromptHub CLI installer is still pending release",
        "public PromptHub CLI installer has not shipped yet",
        "packaged installer ships",
    ]
    for path in parityCopyPaths {
        let body = try readFile(path)
        for phrase in banned {
            #expect(
                !body.contains(phrase),
                "stale copy '\(phrase)' still present in \(path)"
            )
        }
    }
}

@Test func noSurfaceReferencesOldGitHubOrg() throws {
    for path in parityCopyPaths {
        let body = try readFile(path)
        #expect(
            !body.contains("DoSomeForFun"),
            "old org reference still present in \(path)"
        )
    }
}

// MARK: - Install copy must agree

@Test func installCopyAgreesAcrossDocs() throws {
    let surfaces = [
        "README.md",
        "PromptHubCLI/README.md",
        "docs/cli-release.md",
        "prompthub/Views/HomeViews/CLIDashboardView.swift",
        "prompthub/Views/HomeViews/OnboardingView.swift",
    ]

    for path in surfaces {
        let body = try readFile(path)
        #expect(
            body.contains("leetaogoooo/prompthub/ph"),
            "missing canonical brew install command in \(path)"
        )
    }
}

@Test func brewTapDocsCallOutLeetaoGooooOrg() throws {
    // The full tap command (with the git URL) must appear in every long-form
    // doc so a user landing on any of them can copy-paste a working install.
    let longFormDocs = [
        "README.md",
        "PromptHubCLI/README.md",
        "docs/cli-release.md",
    ]
    let tapCommand = "brew tap leetaogoooo/prompthub https://github.com/LeetaoGoooo/PromptHub.git"
    for path in longFormDocs {
        let body = try readFile(path)
        #expect(
            body.contains(tapCommand),
            "missing canonical brew tap command in \(path)"
        )
    }
}

@Test func intelSupportStoryIsConsistent() throws {
    // v1 prebuilt only ships arm64; Intel users must be pointed at --HEAD.
    let surfaces = [
        "PromptHubCLI/README.md",
        "docs/cli-release.md",
        "README.md",
    ]
    for path in surfaces {
        let body = try readFile(path)
        #expect(body.contains("--HEAD"), "missing --HEAD install path in \(path)")
        #expect(body.contains("Intel"), "missing Intel platform note in \(path)")
    }
}

// MARK: - App vs CLI framing

@Test func appVsCLIFramingExistsInBothReadmes() throws {
    let root = try readFile("README.md")
    let cli = try readFile("PromptHubCLI/README.md")
    let release = try readFile("docs/cli-release.md")

    // The phrase "app" + scripting/automation/CI must coexist so a reader
    // understands where each surface belongs. We assert each doc carries an
    // explicit "App vs" header or sentence and at least one
    // scripting-or-automation keyword.
    for (path, body) in [("README.md", root), ("PromptHubCLI/README.md", cli), ("docs/cli-release.md", release)] {
        #expect(
            body.lowercased().contains("app vs") || body.lowercased().contains("when to use the app vs"),
            "missing 'App vs ph' framing in \(path)"
        )
        let hasScriptingWord =
            body.lowercased().contains("script") ||
            body.lowercased().contains("automation") ||
            body.lowercased().contains("automate") ||
            body.contains(" CI")
        #expect(hasScriptingWord, "missing scripting/automation framing in \(path)")
    }
}

// MARK: - Terminology

@Test func exportRootTerminologyIsConsistent() throws {
    let surfaces = [
        "README.md",
        "PromptHubCLI/README.md",
        "docs/cli-release.md",
        "prompthub/Views/HomeViews/CLIDashboardView.swift",
    ]
    for path in surfaces {
        let body = try readFile(path)
        #expect(
            body.contains("~/.prompthub/"),
            "missing canonical export root terminology '~/.prompthub/' in \(path)"
        )
    }
}
