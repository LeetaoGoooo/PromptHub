import Foundation
import PromptHubCLILib
import Testing

// CLI-18: regression coverage for the Homebrew formula and release
// workflow staying in sync. These tests run without brew/network and
// fail loudly when Formula/ph.rb or the release workflow drifts away
// from the install contract documented in docs/cli-release.md.

private func repoRoot() throws -> URL {
    var url = URL(fileURLWithPath: #filePath)
    // .../PromptHubCLI/Tests/PromptHubCLITests/ReleaseContractTests.swift
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
    try #require(FileManager.default.fileExists(atPath: path.path))
    return try String(contentsOf: path, encoding: .utf8)
}

// MARK: - Formula

@Test func formulaPointsAtLeetaoGooooOrg() throws {
    let formula = try readFile("Formula/ph.rb")
    #expect(formula.contains("homepage \"https://github.com/LeetaoGoooo/PromptHub\""))
    #expect(formula.contains("https://github.com/LeetaoGoooo/PromptHub.git"))
    // Old org must not leak back in via a copy/paste.
    #expect(!formula.contains("DoSomeForFun"))
}

@Test func formulaDeclaresStableVersionAndArchive() throws {
    let formula = try readFile("Formula/ph.rb")
    #expect(formula.contains("STABLE_VERSION ="))
    #expect(formula.contains("STABLE_ARM64_URL"))
    #expect(formula.contains("STABLE_ARM64_SHA"))
    #expect(formula.contains("ph-macos-arm64.tar.gz"))
    #expect(formula.contains("releases/download/ph-v"))
}

@Test func formulaSupportsBottleEnvOverride() throws {
    // The release workflow and tools/homebrew/verify-formula.sh both
    // depend on these env vars to smoke-install the formula against a
    // locally-built archive before the real release URL exists.
    let formula = try readFile("Formula/ph.rb")
    #expect(formula.contains("HOMEBREW_PROMPTHUB_BOTTLE_URL"))
    #expect(formula.contains("HOMEBREW_PROMPTHUB_BOTTLE_SHA256"))
    #expect(formula.contains("HOMEBREW_PROMPTHUB_BOTTLE_VERSION"))
}

@Test func formulaKeepsHeadInstallPath() throws {
    let formula = try readFile("Formula/ph.rb")
    // HEAD path must still build from source, otherwise Intel mac users
    // lose their only supported install path in v1.
    #expect(formula.contains("head \"https://github.com/LeetaoGoooo/PromptHub.git\""))
    #expect(formula.contains("swift"))
    #expect(formula.contains("PromptHubCLI"))
    #expect(formula.contains("--product"))
}

@Test func formulaRestrictsToArm64() throws {
    let formula = try readFile("Formula/ph.rb")
    // v1 ships only Apple Silicon binaries.
    #expect(formula.contains("depends_on arch: :arm64"))
}

// MARK: - CLI version (CLI-23)

@Test func cliVersionMatchesFormulaStableVersion() throws {
    // `ph --version` reports PromptHubCLIVersion; it must stay in lockstep
    // with the Homebrew formula's STABLE_VERSION so a brew-installed binary
    // never lies about which release it is.
    let formula = try readFile("Formula/ph.rb")
    let pattern = #"STABLE_VERSION\s*=\s*"([^"]+)""#
    let regex = try NSRegularExpression(pattern: pattern)
    let range = NSRange(formula.startIndex..<formula.endIndex, in: formula)
    let match = try #require(regex.firstMatch(in: formula, range: range))
    let versionRange = try #require(Range(match.range(at: 1), in: formula))
    let formulaVersion = String(formula[versionRange])
    #expect(PromptHubCLIVersion == formulaVersion)
}

@Test func cliVersionIsSemver() throws {
    let pattern = #"^\d+\.\d+\.\d+$"#
    let regex = try NSRegularExpression(pattern: pattern)
    let range = NSRange(PromptHubCLIVersion.startIndex..<PromptHubCLIVersion.endIndex, in: PromptHubCLIVersion)
    #expect(regex.firstMatch(in: PromptHubCLIVersion, range: range) != nil)
}

// MARK: - Release workflow

@Test func releaseWorkflowProducesContractedArtifacts() throws {
    let workflow = try readFile(".github/workflows/prompthub-cli-release.yml")
    #expect(workflow.contains("ph-macos-arm64.tar.gz"))
    #expect(workflow.contains("ph-macos-arm64.sha256"))
    #expect(workflow.contains("shasum -a 256"))
    #expect(workflow.contains("ph-v"))
}

@Test func releaseWorkflowSmokeInstallsFormula() throws {
    let workflow = try readFile(".github/workflows/prompthub-cli-release.yml")
    // The smoke step must exercise the same env override contract the
    // formula reads, so a broken formula fails the release before
    // publish, not after.
    #expect(workflow.contains("HOMEBREW_PROMPTHUB_BOTTLE_URL"))
    #expect(workflow.contains("HOMEBREW_PROMPTHUB_BOTTLE_SHA256"))
    #expect(workflow.contains("HOMEBREW_PROMPTHUB_BOTTLE_VERSION"))
    #expect(workflow.contains("brew install"))
    #expect(workflow.contains("brew test"))
}

@Test func releaseWorkflowRunsTestsBeforePublish() throws {
    let workflow = try readFile(".github/workflows/prompthub-cli-release.yml")
    #expect(workflow.contains("swift test --package-path PromptHubCLI"))
}

// MARK: - Local verify script

@Test func verifyFormulaScriptExistsAndIsExecutable() throws {
    let root = try repoRoot()
    let script = root.appendingPathComponent("tools/homebrew/verify-formula.sh")
    let attrs = try FileManager.default.attributesOfItem(atPath: script.path)
    let perms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
    #expect(perms & 0o111 != 0, "tools/homebrew/verify-formula.sh must be executable")

    let body = try String(contentsOf: script, encoding: .utf8)
    #expect(body.contains("HOMEBREW_PROMPTHUB_BOTTLE_URL"))
    #expect(body.contains("ph-macos-arm64.tar.gz"))
    #expect(body.contains("brew install"))
}

// MARK: - Docs

@Test func releaseDocsCoverSupportMatrixAndInstall() throws {
    let docs = try readFile("docs/cli-release.md")
    #expect(docs.contains("Apple Silicon"))
    #expect(docs.contains("Intel"))
    #expect(docs.contains("brew tap leetaogoooo/prompthub"))
    #expect(docs.contains("brew install leetaogoooo/prompthub/ph"))
    #expect(docs.contains("brew install --HEAD leetaogoooo/prompthub/ph"))
    #expect(docs.contains("ph-macos-arm64.tar.gz"))
    #expect(docs.contains("ph-macos-arm64.sha256"))
    #expect(docs.contains("tools/homebrew/verify-formula.sh"))
}
