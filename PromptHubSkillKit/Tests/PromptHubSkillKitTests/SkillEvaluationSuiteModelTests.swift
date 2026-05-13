import Foundation
import Testing
@testable import PromptHubSkillKit

// MARK: - SkillEvaluation suite/task models (P2.1)
//
// P2.1 only introduces the value types that P2.2 (YAML parser),
// P2.3 (schema validation), P2.4 (discovery), and P3 (runner/graders) build
// on top of. The grader Kind raw values must be stable because they appear
// verbatim in the YAML files authors write under eval/.

@Test func evalSuiteRoundTripsThroughCodable() throws {
    let suite = SkillEvaluation.Suite(
        name: "example",
        version: "1",
        directoryName: "eval",
        tasks: [
            SkillEvaluation.Task(
                id: "should-trigger",
                title: "Triggers on summarise request",
                input: SkillEvaluation.Input(
                    prompt: "summarise this article",
                    // Path is documented as relative to the suite root
                    // (Suite.directoryName, conventionally `eval/`).
                    attachments: ["fixtures/article.md"]
                ),
                graders: [
                    SkillEvaluation.GraderSpec(
                        kind: .textContains,
                        parameters: [
                            "needle": .string("TL;DR"),
                            "case_sensitive": .bool(false)
                        ]
                    )
                ]
            )
        ]
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let decoder = JSONDecoder()

    let data = try encoder.encode(suite)
    let decoded = try decoder.decode(SkillEvaluation.Suite.self, from: data)
    #expect(decoded == suite)
}

@Test func evalGraderKindRawValuesAreStable() {
    // These strings appear verbatim in eval/tasks/*.yaml and in persisted
    // run results. Changing them is a wire-format break.
    #expect(SkillEvaluation.GraderSpec.Kind.textContains.rawValue == "text_contains")
    #expect(SkillEvaluation.GraderSpec.Kind.textExact.rawValue == "text_exact")
    #expect(SkillEvaluation.GraderSpec.Kind.jsonSchema.rawValue == "json_schema")
    #expect(SkillEvaluation.GraderSpec.Kind.fileExists.rawValue == "file_exists")
    #expect(SkillEvaluation.GraderSpec.Kind.fileDiff.rawValue == "file_diff")
    #expect(SkillEvaluation.GraderSpec.Kind.validatorExit.rawValue == "validator_exit")
}

@Test func evalGraderKindCoversV1Subset() {
    // The plan locks v1 to six deterministic grader kinds. Any drift in
    // either direction (added or removed) is a deliberate phase decision and
    // should be reflected by updating this test.
    let v1Kinds: Set<SkillEvaluation.GraderSpec.Kind> = [
        .textContains, .textExact, .jsonSchema,
        .fileExists, .fileDiff, .validatorExit
    ]
    #expect(Set(SkillEvaluation.GraderSpec.Kind.allCases) == v1Kinds)
}

@Test func evalParameterRoundTripsAllCases() throws {
    let parameters: [SkillEvaluation.GraderSpec.Parameter] = [
        .string("hello"),
        .int(42),
        .double(0.75),
        .bool(true),
        .null,
        .array([.string("a"), .int(1), .bool(true)]),
        // Inline `json_schema` payload — the use case that motivated the
        // recursive Parameter shape.
        .object([
            "type": .string("object"),
            "required": .array([.string("id")]),
            "properties": .object([
                "id": .object(["type": .string("string")])
            ])
        ])
    ]
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    for param in parameters {
        let data = try encoder.encode(param)
        let decoded = try decoder.decode(SkillEvaluation.GraderSpec.Parameter.self, from: data)
        #expect(decoded == param)
    }
}

@Test func evalParameterDiscriminatorsAreStable() throws {
    // Each discriminator string is part of the run-result archive wire
    // format; pin every variant.
    let cases: [(SkillEvaluation.GraderSpec.Parameter, String)] = [
        (.string("x"), "string"),
        (.int(1), "int"),
        (.double(1.5), "double"),
        (.bool(true), "bool"),
        (.null, "null"),
        (.array([]), "array"),
        (.object([:]), "object")
    ]
    let encoder = JSONEncoder()
    for (param, expectedKind) in cases {
        let data = try encoder.encode(param)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["kind"] as? String == expectedKind)
    }
}

@Test func evalParameterRejectsUnknownDiscriminator() {
    // Unknown kinds must fail decode loudly; that is what makes the wire
    // format stable rather than silently lossy.
    let bogus = #"{"kind":"future_kind","value":42}"#
    let data = Data(bogus.utf8)
    #expect(throws: DecodingError.self) {
        _ = try JSONDecoder().decode(SkillEvaluation.GraderSpec.Parameter.self, from: data)
    }
}

@Test func evalTaskIsIdentifiableById() {
    let task = SkillEvaluation.Task(
        id: "abc",
        title: "t",
        input: SkillEvaluation.Input(prompt: nil, attachments: []),
        graders: []
    )
    // Identifiable conformance is what the SwiftUI list rows in P4 will use.
    #expect(task.id == "abc")
}

@Test func evalSuiteDefaultsToConventionalDirectory() {
    let suite = SkillEvaluation.Suite(name: "x", version: nil, tasks: [])
    #expect(suite.directoryName == "eval")
}

@Test func evalInputAllowsNoPromptAndNoAttachments() {
    // Some tasks (e.g. file-exists graders) only check post-conditions and
    // may not need an explicit input prompt.
    let input = SkillEvaluation.Input(prompt: nil, attachments: [])
    #expect(input.prompt == nil)
    #expect(input.attachments.isEmpty)
}
