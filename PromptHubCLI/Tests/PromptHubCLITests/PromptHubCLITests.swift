import XCTest
@testable import PromptHubCLILib

final class FrontMatterParserTests: XCTestCase {

    func test_parse_simpleScalars() {
        let md = """
        ---
        id: 123E4567-E89B-12D3-A456-426614174000
        name: My Prompt
        slug: my-prompt
        ---
        Body text here.
        """
        let (fields, body) = FrontMatterParser.parse(md)
        XCTAssertEqual(fields["id"], "123E4567-E89B-12D3-A456-426614174000")
        XCTAssertEqual(fields["name"], "My Prompt")
        XCTAssertEqual(fields["slug"], "my-prompt")
        XCTAssertEqual(body, "Body text here.")
    }

    func test_parse_quotedValue_withColon() {
        let md = """
        ---
        id: 123E4567-E89B-12D3-A456-426614174000
        name: "Hello: World"
        ---
        Body.
        """
        let (fields, _) = FrontMatterParser.parse(md)
        XCTAssertEqual(fields["name"], "Hello: World")
    }

    func test_parse_noFrontMatter() {
        let md = "Just a body."
        let (fields, body) = FrontMatterParser.parse(md)
        XCTAssertTrue(fields.isEmpty)
        XCTAssertEqual(body, "Just a body.")
    }

    func test_parse_crlfLineEndings() {
        let md = "---\r\nid: 123E4567-E89B-12D3-A456-426614174000\r\nname: CRLF Test\r\nslug: crlf-test\r\n---\r\nBody.\r\n"
        let (fields, _) = FrontMatterParser.parse(md)
        XCTAssertEqual(fields["name"], "CRLF Test")
        XCTAssertEqual(fields["slug"], "crlf-test")
    }

    func test_parse_unclosedFrontMatter_treatedAsNoFrontMatter() {
        let md = "---\nid: abc\nname: Broken\n"
        let (fields, body) = FrontMatterParser.parse(md)
        XCTAssertTrue(fields.isEmpty, "Unclosed front matter should return empty fields")
        XCTAssertEqual(body, md)
    }
}

final class TemplateRendererTests: XCTestCase {

    func test_render_substitutesVariables() {
        let template = "Hello, {{name}}! Welcome to {{product}}."
        let result = TemplateRenderer.render(template, variables: ["name": "Alice", "product": "PromptHub"])
        XCTAssertEqual(result, "Hello, Alice! Welcome to PromptHub.")
    }

    func test_render_leavesUnknownPlaceholders() {
        let template = "Hello, {{name}}!"
        let result = TemplateRenderer.render(template, variables: [:])
        XCTAssertEqual(result, "Hello, {{name}}!")
    }

    func test_findPlaceholders_returnsDistinct() {
        let text = "{{a}} and {{b}} and {{a}} again."
        let found = TemplateRenderer.findPlaceholders(in: text)
        XCTAssertEqual(Set(found), Set(["a", "b"]))
    }

    func test_render_singlePass_doesNotSubstituteInsideValues() {
        // If variable 'a' expands to '{{b}}', 'b' should NOT be further substituted
        let template = "{{a}}"
        let result = TemplateRenderer.render(template, variables: ["a": "{{b}}", "b": "SUBSTITUTED"])
        XCTAssertEqual(result, "{{b}}", "Single-pass render must not substitute inside replacement values")
    }

    func test_render_overlappingKeysAreNotOrderDependent() {
        let template = "{{foo}} {{foobar}}"
        let result = TemplateRenderer.render(template, variables: ["foo": "FOO", "foobar": "FOOBAR"])
        XCTAssertEqual(result, "FOO FOOBAR")
    }
}

final class SkillAuditorTests: XCTestCase {

    private func skill(body: String, desc: String? = "A description", tags: [String] = ["tag1"]) -> SkillAsset {
        SkillAsset(
            id: UUID(),
            name: "Test Skill",
            slug: "test-skill",
            description: desc,
            category: nil,
            tags: tags,
            body: body
        )
    }

    func test_audit_pass_withGoodSkill() {
        let body = """
        ## Overview
        This skill does something useful. It handles edge cases and explains the underlying
        rationale so that downstream agents can rely on the output. Use it whenever you need
        to process structured data with clear instructions.

        ## Usage
        Invoke the skill with a well-formed input and expect JSON back.
        """
        let report = SkillAuditor.audit(skill(body: body))
        XCTAssertTrue(report.passed, "Expected pass but got warnings: \(report.warnings)")
        XCTAssertTrue(report.warnings.isEmpty)
    }

    func test_audit_warn_shortBody() {
        let report = SkillAuditor.audit(skill(body: "Short."))
        XCTAssertFalse(report.passed)
        XCTAssertTrue(report.warnings.contains { $0.contains("short") })
    }

    func test_audit_warn_missingDescription() {
        let body = "## Overview\nLong enough body with enough words to pass the word count check for sure here."
        let report = SkillAuditor.audit(skill(body: body, desc: nil))
        XCTAssertFalse(report.passed)
        XCTAssertTrue(report.warnings.contains { $0.contains("description") })
    }
}

final class AssetStoreTests: XCTestCase {

    private var tempDir: URL!
    private var store: AssetStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = AssetStore(baseURL: tempDir)
        try! FileManager.default.createDirectory(at: tempDir.appendingPathComponent("prompts"), withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: tempDir.appendingPathComponent("skills"), withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func writePromptFile(_ content: String, name: String = UUID().uuidString + ".md") {
        let url = tempDir.appendingPathComponent("prompts/\(name)")
        try! content.write(to: url, atomically: true, encoding: .utf8)
    }

    func test_listPrompts_returnsEmpty_whenNoFiles() {
        XCTAssertTrue(store.listPrompts().isEmpty)
    }

    func test_listPrompts_parsesValidFile() {
        let uuid = UUID()
        writePromptFile("""
        ---
        id: \(uuid.uuidString)
        name: Alpha
        slug: alpha
        ---
        Body text.
        """)
        let prompts = store.listPrompts()
        XCTAssertEqual(prompts.count, 1)
        XCTAssertEqual(prompts.first?.name, "Alpha")
        XCTAssertEqual(prompts.first?.slug, "alpha")
        XCTAssertEqual(prompts.first?.body, "Body text.")
    }

    func test_findPrompt_bySlug() {
        let uuid = UUID()
        writePromptFile("""
        ---
        id: \(uuid.uuidString)
        name: Beta
        slug: beta
        ---
        Body.
        """)
        XCTAssertNotNil(store.findPrompt(named: "beta"))
        XCTAssertNotNil(store.findPrompt(named: "Beta"))
        XCTAssertNotNil(store.findPrompt(named: "BETA"), "Slug lookup should be case-insensitive")
        XCTAssertNil(store.findPrompt(named: "gamma"))
    }

    func test_listPrompts_sortedByName() {
        for (i, name) in ["Zebra", "Alpha", "Mango"].enumerated() {
            writePromptFile("""
            ---
            id: \(UUID().uuidString)
            name: \(name)
            slug: \(name.lowercased())
            ---
            Body \(i).
            """, name: "\(i).md")
        }
        let names = store.listPrompts().map { $0.name }
        XCTAssertEqual(names, ["Alpha", "Mango", "Zebra"])
    }
}
