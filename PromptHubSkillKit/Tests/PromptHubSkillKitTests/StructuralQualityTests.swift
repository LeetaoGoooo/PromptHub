import Foundation
import Testing
@testable import PromptHubSkillKit

// MARK: - StructuralQuality (formerly Effectiveness)
//
// P1.1 of the skill evaluation plan renames the audit layer concept from
// "effectiveness" (which over-claims behavioral proof) to "structural quality"
// (which honestly describes what the SKILL.md heuristics measure).
//
// These tests pin down the new public API and ensure the deprecated typealiases
// still resolve so app-side callers can migrate incrementally.

@Test func structuralQualityReportNotFoundIsExposed() {
    let report = SkillStructuralQualityReport.notFound
    #expect(report.fileFound == false)
    #expect(report.checks.isEmpty)
    #expect(report.score == 0)
    #expect(report.tier == .poor)
}

@Test func structuralQualityTierLabelsAndIcons() {
    #expect(StructuralQualityTier.excellent.label == "Excellent")
    #expect(StructuralQualityTier.good.label == "Good")
    #expect(StructuralQualityTier.fair.label == "Fair")
    #expect(StructuralQualityTier.poor.label == "Poor")
    #expect(StructuralQualityTier.excellent.systemImage == "checkmark.seal.fill")
}

@Test func checkStructuralQualityProducesReportForFullSkill() async throws {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let codexGlobal = base.appendingPathComponent(".codex/skills", isDirectory: true)
    let skillDir = codexGlobal.appendingPathComponent("demo-skill", isDirectory: true)
    try fileManager.createDirectory(at: skillDir, withIntermediateDirectories: true)

    let skillBody = """
    ---
    name: demo-skill
    description: A complete demo skill that exercises every structural check.
    ---

    # Demo Skill

    ## When to use

    Use this skill when working with files, commands, or tools that produce
    sufficiently long context to satisfy the substantial-content heuristic.

    ```bash
    echo hello
    ```
    """
    try skillBody.write(
        to: skillDir.appendingPathComponent("SKILL.md"),
        atomically: true,
        encoding: .utf8
    )

    let service = SkillCatalogService(
        session: .shared,
        fileManager: fileManager,
        apiBaseURL: URL(string: "https://skills.invalid"),
        installRootURL: base.appendingPathComponent("installs", isDirectory: true),
        agentSkillRoots: [
            .codex: .init(global: codexGlobal, project: codexGlobal)
        ],
        localSkillRoots: [],
        skillLockFileURLs: []
    )

    let report = await service.checkStructuralQuality(skillName: "acme/toolbox@demo-skill", isGlobal: true)

    #expect(report.fileFound == true)
    // The fixture above intentionally satisfies every structural check.
    // Pin the count and tier so heuristic drift surfaces as a failing test.
    #expect(report.checks.count == 7)
    let passedCount = report.checks.filter { $0.passed }.count
    #expect(passedCount == 7)
    #expect(report.score == 1.0)
    #expect(report.tier == .excellent)

    // Deprecated alias must produce the exact same result during the
    // P1.2 migration window. This guards the source-compatibility wrapper.
    let legacyReport = await service.checkEffectiveness(skillName: "acme/toolbox@demo-skill", isGlobal: true)
    #expect(legacyReport == report)
}

@Test func checkStructuralQualityReportsNotFoundWhenMissing() async {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: base) }

    let service = SkillCatalogService(
        session: .shared,
        fileManager: fileManager,
        apiBaseURL: URL(string: "https://skills.invalid"),
        installRootURL: base.appendingPathComponent("installs", isDirectory: true),
        agentSkillRoots: [
            .codex: .init(
                global: base.appendingPathComponent(".codex/skills", isDirectory: true),
                project: base.appendingPathComponent("project/.agents/skills", isDirectory: true)
            )
        ],
        localSkillRoots: [],
        skillLockFileURLs: []
    )

    let report = await service.checkStructuralQuality(skillName: "acme/toolbox@missing-skill", isGlobal: true)
    #expect(report.fileFound == false)
}

@Test func deprecatedEffectivenessAliasesStillResolve() {
    // Source-compatibility net for app-side callers that still reference the
    // legacy Effectiveness names. These typealiases are deprecated and will
    // be removed once all callers migrate (tracked under P1.2 / P1.3).
    let _: SkillEffectivenessReport.Type = SkillStructuralQualityReport.self
    let _: SkillEffectivenessCheck.Type = SkillStructuralQualityCheck.self
    let _: EffectivenessTier.Type = StructuralQualityTier.self
}
