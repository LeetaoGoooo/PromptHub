import Foundation
import Testing
@testable import PromptHubSkillKit

// MARK: - SkillEvaluation boundary types (P1.3)
//
// Pins the public contract of the SkillEvaluation namespace. The richer
// EvalSuite / EvalTask / EvalRunResult types arrive in P2-P4; these tests
// only guard the seam between the audit layer and the upcoming evaluation
// layer so later phases can build on top without reshaping it.

@Test func skillEvaluationStatusCasesAreDistinct() {
    let statuses: [SkillEvaluation.Status] = [
        .notEvaluated,
        .inProgress,
        .passed,
        .failed,
        .error(.init(code: "boom", message: "crash"))
    ]
    let unique = Set(statuses.map(\.discriminator))
    #expect(unique.count == statuses.count)
}

@Test func skillEvaluationStatusErrorPayloadRoundTrips() throws {
    let original = SkillEvaluation.Status.error(.init(code: "parser_error", message: "Invalid YAML"))
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let data = try encoder.encode(original)

    // The {kind, failure} envelope must persist both the stable code and the
    // user-presentable message.
    let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(json["kind"] as? String == "error")
    let failureBlock = try #require(json["failure"] as? [String: Any])
    #expect(failureBlock["code"] as? String == "parser_error")
    #expect(failureBlock["message"] as? String == "Invalid YAML")

    let decoded = try decoder.decode(SkillEvaluation.Status.self, from: data)
    #expect(decoded == original)
}

@Test func skillEvaluationStatusSimpleCasesRoundTrip() throws {
    let cases: [SkillEvaluation.Status] = [.notEvaluated, .inProgress, .passed, .failed]
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    for status in cases {
        let data = try encoder.encode(status)
        let decoded = try decoder.decode(SkillEvaluation.Status.self, from: data)
        #expect(decoded == status)
    }
}

// MARK: - Summary factories

@Test func skillEvaluationSummaryNotEvaluatedSentinel() {
    let summary = SkillEvaluation.Summary.notEvaluated
    #expect(summary.status == .notEvaluated)
    #expect(summary.lastRunAt == nil)
    #expect(summary.passed == 0)
    #expect(summary.failed == 0)
    #expect(summary.total == 0)
}

@Test func skillEvaluationSummaryCompletedDerivesPassed() throws {
    let now = Date()
    let summary = try SkillEvaluation.Summary.completed(
        lastRunAt: now,
        passed: 3,
        failed: 0,
        total: 3
    )
    #expect(summary.status == .passed)
    #expect(summary.lastRunAt == now)
}

@Test func skillEvaluationSummaryCompletedDerivesFailed() throws {
    let summary = try SkillEvaluation.Summary.completed(
        lastRunAt: Date(),
        passed: 2,
        failed: 1,
        total: 3
    )
    #expect(summary.status == .failed)
}

@Test func skillEvaluationSummaryCompletedRejectsNegativeCounts() {
    #expect(throws: SkillEvaluation.Summary.InvariantError.negativeCount) {
        _ = try SkillEvaluation.Summary.completed(lastRunAt: Date(), passed: -1, failed: 0, total: 0)
    }
}

@Test func skillEvaluationSummaryCompletedRejectsZeroTaskRun() {
    // A "terminal" run that executed zero tasks is meaningless; reserve that
    // shape for `.notEvaluated` instead.
    #expect(throws: SkillEvaluation.Summary.InvariantError.zeroTaskTerminal) {
        _ = try SkillEvaluation.Summary.completed(lastRunAt: Date(), passed: 0, failed: 0, total: 0)
    }
}

@Test func skillEvaluationSummaryCompletedRejectsCountMismatch() {
    #expect(throws: SkillEvaluation.Summary.InvariantError.incompleteTerminalRun) {
        _ = try SkillEvaluation.Summary.completed(lastRunAt: Date(), passed: 1, failed: 1, total: 3)
    }
}

@Test func skillEvaluationSummaryInProgressFactory() throws {
    let now = Date()
    let summary = try SkillEvaluation.Summary.inProgress(lastRunAt: now, passed: 1, failed: 0, total: 3)
    #expect(summary.status == .inProgress)
    #expect(summary.lastRunAt == now)
    #expect(summary.passed == 1)
    #expect(summary.total == 3)
}

@Test func skillEvaluationSummaryInProgressRejectsCountsExceedingTotal() {
    #expect(throws: SkillEvaluation.Summary.InvariantError.transientCountsExceedTotal) {
        _ = try SkillEvaluation.Summary.inProgress(passed: 2, failed: 2, total: 3)
    }
}

@Test func skillEvaluationSummaryInProgressRejectsNegativeCounts() {
    #expect(throws: SkillEvaluation.Summary.InvariantError.negativeCount) {
        _ = try SkillEvaluation.Summary.inProgress(passed: -1, failed: 0, total: 0)
    }
}

@Test func skillEvaluationSummaryErrorFactory() throws {
    let failure = SkillEvaluation.Status.Failure(code: "runner_crash", message: "boom")
    let summary = try SkillEvaluation.Summary.error(failure)
    #expect(summary.status == .error(failure))
    #expect(summary.lastRunAt == nil)
}

@Test func skillEvaluationSummaryErrorAllowsPartialCounts() throws {
    let failure = SkillEvaluation.Status.Failure(code: "timeout", message: "task 2 timed out")
    let summary = try SkillEvaluation.Summary.error(failure, passed: 1, failed: 1, total: 3)
    if case .error(let f) = summary.status {
        #expect(f == failure)
    } else {
        Issue.record("Expected .error status")
    }
    #expect(summary.passed + summary.failed <= summary.total)
}

@Test func skillEvaluationSummaryErrorRejectsCountsExceedingTotal() {
    let failure = SkillEvaluation.Status.Failure(code: "x", message: "y")
    #expect(throws: SkillEvaluation.Summary.InvariantError.transientCountsExceedTotal) {
        _ = try SkillEvaluation.Summary.error(failure, passed: 5, failed: 0, total: 3)
    }
}

// MARK: - Codable round trip + decode validation

@Test func skillEvaluationSummaryCompletedRoundTrips() throws {
    let summary = try SkillEvaluation.Summary.completed(
        lastRunAt: Date(timeIntervalSince1970: 1_700_000_000),
        passed: 2,
        failed: 1,
        total: 3
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let data = try encoder.encode(summary)
    let decoded = try decoder.decode(SkillEvaluation.Summary.self, from: data)
    #expect(decoded == summary)
}

@Test func skillEvaluationSummaryDecodeRejectsContradictoryStatus() {
    // `.passed` with failed > 0 must be rejected on decode so the cache
    // cannot silently surface contradictory state.
    let bogus = """
    {
      "lastRunAt": 0,
      "passed": 1,
      "failed": 1,
      "total": 2,
      "status": { "kind": "passed" }
    }
    """
    let data = Data(bogus.utf8)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    #expect(throws: DecodingError.self) {
        _ = try decoder.decode(SkillEvaluation.Summary.self, from: data)
    }
}

@Test func skillEvaluationSummaryDecodeRejectsTerminalWithoutTimestamp() {
    let bogus = """
    {
      "passed": 1,
      "failed": 0,
      "total": 1,
      "status": { "kind": "passed" }
    }
    """
    let data = Data(bogus.utf8)
    #expect(throws: DecodingError.self) {
        _ = try JSONDecoder().decode(SkillEvaluation.Summary.self, from: data)
    }
}

@Test func skillEvaluationSummaryDecodeRejectsNotEvaluatedWithRunData() {
    // `.notEvaluated` paired with a non-nil timestamp would let the UI
    // render "never run" next to a run time. Decode must reject it.
    let bogus = """
    {
      "lastRunAt": 0,
      "passed": 0,
      "failed": 0,
      "total": 0,
      "status": { "kind": "notEvaluated" }
    }
    """
    let data = Data(bogus.utf8)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    #expect(throws: DecodingError.self) {
        _ = try decoder.decode(SkillEvaluation.Summary.self, from: data)
    }
}

@Test func skillEvaluationSummaryDecodeRejectsTransientCountsExceedingTotal() {
    // `.inProgress` with passed + failed > total should never appear on disk.
    let bogus = """
    {
      "passed": 5,
      "failed": 0,
      "total": 3,
      "status": { "kind": "inProgress" }
    }
    """
    let data = Data(bogus.utf8)
    #expect(throws: DecodingError.self) {
        _ = try JSONDecoder().decode(SkillEvaluation.Summary.self, from: data)
    }
}

@Test func skillEvaluationSummaryDecodeRejectsTransientNonZeroCountsWithZeroTotal() {
    let bogus = """
    {
      "passed": 1,
      "failed": 0,
      "total": 0,
      "status": { "kind": "error", "failure": { "code": "x", "message": "y" } }
    }
    """
    let data = Data(bogus.utf8)
    #expect(throws: DecodingError.self) {
        _ = try JSONDecoder().decode(SkillEvaluation.Summary.self, from: data)
    }
}

private extension SkillEvaluation.Status {
    var discriminator: String {
        switch self {
        case .notEvaluated: return "notEvaluated"
        case .inProgress: return "inProgress"
        case .passed: return "passed"
        case .failed: return "failed"
        case .error: return "error"
        }
    }
}
