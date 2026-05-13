import Foundation
import Testing
@testable import PromptHubSkillKit

// MARK: - SkillEvaluation YAML parser (P2.2)
//
// The on-disk YAML format used in `eval/eval.yaml` and `eval/tasks/*.yaml`
// uses naked scalars / sequences / mappings, NOT the {kind, value} envelope
// the model's Codable conformance produces. P2.2 owns the translation from
// YAML to the normalized public types declared in P2.1. P2.3 (schema
// validation) and P2.4 (suite discovery) build on top.
//
// Parser layer responsibilities pinned by these tests:
//   - reject malformed YAML
//   - require expected top-level shape and field types
//   - normalize YAML scalars into Parameter; reject NaN / +/- inf
//   - reject unknown grader kinds (Kind enum is closed)
//   - reject duplicate mapping keys (silently dropped keys would be a
//     correctness hole that P3 graders cannot recover from)
//   - parse a missing task `id:` as the supplied defaultID

// MARK: - Manifest

@Test func parseMinimalManifest() throws {
    let yaml = """
    name: my-skill-evals
    tasks:
      - should-trigger
      - should-produce-json
    """
    let manifest = try SkillEvaluation.SuiteParser.parseManifest(yaml: yaml)
    #expect(manifest.name == "my-skill-evals")
    #expect(manifest.version == nil)
    #expect(manifest.taskRefs == ["should-trigger", "should-produce-json"])
}

@Test func parseManifestWithVersion() throws {
    let yaml = """
    name: x
    version: "2"
    tasks: [a, b]
    """
    let manifest = try SkillEvaluation.SuiteParser.parseManifest(yaml: yaml)
    #expect(manifest.version == "2")
}

@Test func parseManifestRejectsMissingName() {
    let yaml = """
    tasks: [a]
    """
    #expect(throws: SkillEvaluation.SuiteParseError.self) {
        _ = try SkillEvaluation.SuiteParser.parseManifest(yaml: yaml)
    }
}

@Test func parseManifestRejectsMissingTasks() {
    let yaml = """
    name: x
    """
    #expect(throws: SkillEvaluation.SuiteParseError.self) {
        _ = try SkillEvaluation.SuiteParser.parseManifest(yaml: yaml)
    }
}

@Test func parseManifestRejectsWrongTaskListType() {
    let yaml = """
    name: x
    tasks: not-a-list
    """
    #expect(throws: SkillEvaluation.SuiteParseError.self) {
        _ = try SkillEvaluation.SuiteParser.parseManifest(yaml: yaml)
    }
}

@Test func parseManifestRejectsMalformedYAML() {
    let yaml = "name: [unterminated"
    #expect(throws: SkillEvaluation.SuiteParseError.self) {
        _ = try SkillEvaluation.SuiteParser.parseManifest(yaml: yaml)
    }
}

// MARK: - Task

@Test func parseTaskWithTextContainsGrader() throws {
    let yaml = """
    id: should-trigger
    title: "Triggers on summarise request"
    input:
      prompt: "summarise this article"
      attachments:
        - fixtures/article.md
    graders:
      - kind: text_contains
        parameters:
          needle: "TL;DR"
          case_sensitive: false
    """
    let task = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "fallback")
    #expect(task.id == "should-trigger")
    #expect(task.title == "Triggers on summarise request")
    #expect(task.input.prompt == "summarise this article")
    #expect(task.input.attachments == ["fixtures/article.md"])
    #expect(task.graders.count == 1)
    let grader = try #require(task.graders.first)
    #expect(grader.kind == .textContains)
    #expect(grader.parameters["needle"] == .string("TL;DR"))
    #expect(grader.parameters["case_sensitive"] == .bool(false))
}

@Test func parseTaskFallsBackToDefaultIDWhenMissing() throws {
    let yaml = """
    title: t
    input: {}
    graders:
      - kind: file_exists
        parameters:
          path: out.txt
    """
    let task = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "from-filename")
    #expect(task.id == "from-filename")
    #expect(task.input.prompt == nil)
    #expect(task.input.attachments.isEmpty)
}

@Test func parseTaskNormalizesNumericAndArrayParameters() throws {
    let yaml = """
    title: t
    input: {}
    graders:
      - kind: validator_exit
        parameters:
          expected_exit: 0
          allowed_exits: [0, 1]
          timeout: 1.5
    """
    let task = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "x")
    let grader = try #require(task.graders.first)
    #expect(grader.parameters["expected_exit"] == .int(0))
    #expect(grader.parameters["timeout"] == .double(1.5))
    if case .array(let elements) = grader.parameters["allowed_exits"] {
        #expect(elements == [.int(0), .int(1)])
    } else {
        Issue.record("expected .array for allowed_exits")
    }
}

@Test func parseTaskNormalizesNullScalar() throws {
    let yaml = """
    title: t
    input: {}
    graders:
      - kind: text_exact
        parameters:
          expected: "hi"
          extra: null
    """
    let task = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "x")
    let grader = try #require(task.graders.first)
    #expect(grader.parameters["extra"] == .null)
}

@Test func parseTaskNormalizesNestedJSONSchemaObject() throws {
    let yaml = """
    title: t
    input: {}
    graders:
      - kind: json_schema
        parameters:
          schema:
            type: object
            required: [id]
            properties:
              id:
                type: string
    """
    let task = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "x")
    let grader = try #require(task.graders.first)
    let schema = try #require(grader.parameters["schema"])
    let expected: SkillEvaluation.GraderSpec.Parameter = .object([
        "type": .string("object"),
        "required": .array([.string("id")]),
        "properties": .object([
            "id": .object(["type": .string("string")])
        ])
    ])
    #expect(schema == expected)
}

@Test func parseTaskRejectsUnknownGraderKind() {
    let yaml = """
    title: t
    input: {}
    graders:
      - kind: future_grader
        parameters: {}
    """
    #expect(throws: SkillEvaluation.SuiteParseError.self) {
        _ = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "x")
    }
}

@Test func parseTaskRejectsNaNScalar() {
    let yaml = """
    title: t
    input: {}
    graders:
      - kind: validator_exit
        parameters:
          timeout: .nan
    """
    #expect(throws: SkillEvaluation.SuiteParseError.self) {
        _ = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "x")
    }
}

@Test func parseTaskRejectsInfinityScalar() {
    let yaml = """
    title: t
    input: {}
    graders:
      - kind: validator_exit
        parameters:
          timeout: .inf
    """
    #expect(throws: SkillEvaluation.SuiteParseError.self) {
        _ = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "x")
    }
}

@Test func parseTaskRejectsMissingTitle() {
    let yaml = """
    input: {}
    graders:
      - kind: file_exists
        parameters: {}
    """
    #expect(throws: SkillEvaluation.SuiteParseError.self) {
        _ = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "x")
    }
}

@Test func parseTaskRejectsMissingGradersField() {
    let yaml = """
    title: t
    input: {}
    """
    #expect(throws: SkillEvaluation.SuiteParseError.self) {
        _ = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "x")
    }
}

// MARK: - Resolve

@Test func resolveCombinesManifestAndTasksInManifestOrder() throws {
    let manifest = SkillEvaluation.Manifest(
        name: "s", version: nil, taskRefs: ["b", "a"]
    )
    let taskA = SkillEvaluation.Task(
        id: "a", title: "A",
        input: SkillEvaluation.Input(prompt: nil, attachments: []),
        graders: []
    )
    let taskB = SkillEvaluation.Task(
        id: "b", title: "B",
        input: SkillEvaluation.Input(prompt: nil, attachments: []),
        graders: []
    )
    let suite = try SkillEvaluation.SuiteParser.resolve(
        manifest: manifest,
        tasksByID: ["a": taskA, "b": taskB]
    )
    // Manifest declared "b" before "a"; resolved suite must respect that.
    #expect(suite.tasks.map(\.id) == ["b", "a"])
    #expect(suite.directoryName == "eval")
}

@Test func resolveRejectsUnknownTaskRef() {
    let manifest = SkillEvaluation.Manifest(
        name: "s", version: nil, taskRefs: ["missing"]
    )
    #expect(throws: SkillEvaluation.SuiteParseError.self) {
        _ = try SkillEvaluation.SuiteParser.resolve(
            manifest: manifest, tasksByID: [:]
        )
    }
}

// MARK: - Review-driven additions (P2.2 GPT-5.4 review)

/// Explicit `!!str` tag must override the resolver's bool/int inference,
/// so `!!str true` stays the string "true". (Note: the symmetric
/// case `!!int "2"` cannot become Int(2) because Yams' `Int.construct`
/// requires plain-style scalars and rejects quoted ones regardless of
/// tag — `!!int "2"` therefore falls through to the string "2".)
@Test func parseTaskHonorsExplicitStringTagOverDefaultResolution() throws {
    let yaml = """
    title: t
    input: {}
    graders:
      - kind: text_contains
        parameters:
          flag: !!str true
          number: !!str 42
          quoted_intish: !!int "2"
    """
    let task = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "x")
    let params = task.graders[0].parameters
    #expect(params["flag"] == .string("true"))
    #expect(params["number"] == .string("42"))
    // Documents Yams' quoted-style rejection in Int.construct.
    #expect(params["quoted_intish"] == .string("2"))
}

/// Yams.compose dereferences anchors / aliases before the parser sees
/// the node, so a referenced parameter expands as if duplicated. This
/// test pins that behavior so future swaps to a non-expanding reader
/// don't silently change semantics.
@Test func parseTaskExpandsAliasesViaYamsCompose() throws {
    let yaml = """
    title: t
    input: {}
    graders:
      - kind: text_contains
        parameters:
          a: &shared "abc"
          b: *shared
    """
    let task = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "x")
    let params = task.graders[0].parameters
    #expect(params["a"] == .string("abc"))
    #expect(params["b"] == .string("abc"))
}

/// Pin Yams resolver behavior on YAML 1.1 numeric forms so authors get
/// predictable typing. `0x3A` and `0o17` resolve as int, `1_000` is
/// parsed with the underscore separator stripped, and `0123` stays an
/// int (Yams resolves it via the int regex, not as octal).
@Test func parseTaskResolvesYAML11NumericForms() throws {
    let yaml = """
    title: t
    input: {}
    graders:
      - kind: text_contains
        parameters:
          hex: 0x3A
          oct: 0o17
          underscore: 1_000
          leading_zero: 0123
    """
    let task = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "x")
    let params = task.graders[0].parameters
    #expect(params["hex"] == .int(0x3A))
    #expect(params["oct"] == .int(0o17))
    #expect(params["underscore"] == .int(1_000))
    // `0123` is YAML 1.1 octal in libyaml's resolver.
    #expect(params["leading_zero"] == .int(0o123))
}

/// Duplicate-key detection must survive key stringification: a plain
/// `1: a` and an explicit `!!str "1": b` collide in the same mapping
/// because the parser projects keys to String.
@Test func parseTaskDetectsDuplicateKeysAcrossStringification() {
    let yaml = """
    title: t
    input: {}
    graders:
      - kind: text_contains
        parameters:
          dupes:
            1: a
            !!str "1": b
    """
    #expect(throws: SkillEvaluation.SuiteParseError.self) {
        _ = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "x")
    }
}

/// Errors from nested grader parameters must carry the indexed/dotted
/// path so an authoring UI can point users at the offending field.
@Test func parseTaskErrorPathsIncludeIndexedGraderPosition() {
    let yaml = """
    title: t
    input: {}
    graders:
      - kind: text_contains
        parameters: {}
      - kind: text_contains
        parameters: []
    """
    do {
        _ = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "x")
        Issue.record("expected wrongFieldType for graders[1].parameters")
    } catch let SkillEvaluation.SuiteParseError.wrongFieldType(field, _) {
        #expect(field == "graders[1].parameters")
    } catch {
        Issue.record("unexpected error: \(error)")
    }
}

/// Yams' `NSNull.construct` only matches plain-style nulls, so an
/// explicit `!!null "x"` would otherwise fall through to a string.
/// The parser short-circuits explicit `!!null` tags symmetrically with
/// `!!str` to honor authors' intent.
@Test func parseTaskHonorsExplicitNullTagOverDefaultResolution() throws {
    let yaml = """
    title: t
    input: {}
    graders:
      - kind: text_contains
        parameters:
          quoted_null: !!null "x"
          plain_null: ~
    """
    let task = try SkillEvaluation.SuiteParser.parseTask(yaml: yaml, defaultID: "x")
    let params = task.graders[0].parameters
    #expect(params["quoted_null"] == .null)
    #expect(params["plain_null"] == .null)
}
