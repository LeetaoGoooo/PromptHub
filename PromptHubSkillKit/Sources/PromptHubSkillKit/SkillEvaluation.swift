import Foundation

// MARK: - SkillEvaluation Boundary (P1.3)
//
// PromptHub separates two layers of skill quality signal:
//
//   - Audit (SkillAgentVisibilityReport, SkillSourceIntegrityReport,
//     SkillStructuralQualityReport): static checks over the skill package
//     itself — does it exist, is it parseable, does the SKILL.md follow the
//     authoring conventions. Audits never execute the skill.
//
//   - Evaluation (this namespace): scenario-driven behavior proof — declared
//     in eval suites under the skill package, executed by an EvalRunner, and
//     graded by deterministic local graders. Evaluation answers "does this
//     skill actually do what its frontmatter promises".
//
// P1.3 only introduces the type-level boundary so app code and later phases
// (P2 suite parsing, P3 grader/runner, P4 UI/cache) can compile and surface
// states against a stable contract. The richer Suite / Task / run result
// types ship in subsequent phases; see SkillEvaluation+Suite.swift (P2.1).

/// Namespace for evaluation-layer types. Kept as a caseless enum so it cannot
/// be instantiated and stays a stable extension point.
public enum SkillEvaluation: Sendable {}

extension SkillEvaluation {

    /// Coarse-grained evaluation status surfaced to the UI and persistence
    /// layer. Per-task results live in the (future) per-task run record
    /// model.
    ///
    /// Terminal states (`.passed`, `.failed`) are intended for durable
    /// persistence. Transient states (`.inProgress`, `.error`) are also
    /// codable so they can survive process restarts when needed, but callers
    /// should treat them as recoverable rather than authoritative.
    public enum Status: Sendable, Equatable, Codable {
        /// No evaluation has ever been recorded for this skill.
        case notEvaluated
        /// A run is currently executing.
        case inProgress
        /// The most recent run completed with at least one task executed and
        /// zero failed tasks.
        case passed
        /// The most recent run completed with one or more failed tasks.
        case failed
        /// The most recent run could not complete (parser error, runner
        /// crash, missing dependency, etc.).
        case error(Failure)

        /// Structured runner-side failure. Future phases may extend the set
        /// of `code` values; the envelope itself stays stable.
        public struct Failure: Sendable, Equatable, Codable {
            /// Stable machine-readable failure category.
            public let code: String
            /// Short user-presentable description.
            public let message: String

            public init(code: String, message: String) {
                self.code = code
                self.message = message
            }
        }

        // MARK: Codable

        private enum CodingKeys: String, CodingKey {
            case kind
            case failure
        }

        private enum Kind: String, Codable {
            case notEvaluated
            case inProgress
            case passed
            case failed
            case error
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try container.decode(Kind.self, forKey: .kind)
            switch kind {
            case .notEvaluated: self = .notEvaluated
            case .inProgress: self = .inProgress
            case .passed: self = .passed
            case .failed: self = .failed
            case .error:
                let failure = try container.decode(Failure.self, forKey: .failure)
                self = .error(failure)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .notEvaluated: try container.encode(Kind.notEvaluated, forKey: .kind)
            case .inProgress: try container.encode(Kind.inProgress, forKey: .kind)
            case .passed: try container.encode(Kind.passed, forKey: .kind)
            case .failed: try container.encode(Kind.failed, forKey: .kind)
            case .error(let failure):
                try container.encode(Kind.error, forKey: .kind)
                try container.encode(failure, forKey: .failure)
            }
        }
    }

    /// A small, persistable summary of the most recent evaluation run for a
    /// single skill. Designed for cheap encoding into the audit / eval cache
    /// and for quick display in lists and badges.
    ///
    /// Construction routes:
    ///   - `Summary.notEvaluated` — sentinel for "never ran".
    ///   - `Summary.completed(...)` — terminal, throws if invariants are
    ///     violated. Status is derived from counts.
    ///   - `Summary.inProgress(...)` / `Summary.error(...)` — transient
    ///     factories. They never carry terminal counts.
    public struct Summary: Sendable, Equatable, Codable {
        public let lastRunAt: Date?
        public let passed: Int
        public let failed: Int
        public let total: Int
        public let status: Status

        /// Errors raised when callers try to build a summary that violates
        /// the public invariants. Decoded summaries that violate the
        /// invariants surface as `DecodingError.dataCorrupted`.
        public enum InvariantError: Error, Equatable {
            case negativeCount
            case zeroTaskTerminal
            case incompleteTerminalRun
            /// Transient state reported `passed + failed` greater than
            /// `total`, which can never happen during a real run.
            case transientCountsExceedTotal
        }

        // MARK: Factories

        /// Sentinel for skills with no recorded evaluation. Always pinned to
        /// `lastRunAt == nil` and zero counts.
        public static let notEvaluated = Summary(
            unsafeLastRunAt: nil,
            passed: 0,
            failed: 0,
            total: 0,
            status: .notEvaluated
        )

        /// Build a terminal summary from a finished run. Validates that the
        /// counts are internally consistent and that the run actually
        /// executed at least one task.
        public static func completed(
            lastRunAt: Date,
            passed: Int,
            failed: Int,
            total: Int
        ) throws -> Summary {
            guard passed >= 0, failed >= 0, total >= 0 else {
                throw InvariantError.negativeCount
            }
            guard total > 0 else {
                throw InvariantError.zeroTaskTerminal
            }
            guard passed + failed == total else {
                throw InvariantError.incompleteTerminalRun
            }
            return Summary(
                unsafeLastRunAt: lastRunAt,
                passed: passed,
                failed: failed,
                total: total,
                status: failed == 0 ? .passed : .failed
            )
        }

        /// Transient "run is currently executing" summary. Counts default
        /// to zero; callers that already partially executed a run can
        /// supply progress counts but cannot pretend the run is terminal
        /// (`passed + failed` must stay `<= total`).
        public static func inProgress(
            lastRunAt: Date? = nil,
            passed: Int = 0,
            failed: Int = 0,
            total: Int = 0
        ) throws -> Summary {
            try validateTransientCounts(passed: passed, failed: failed, total: total)
            return Summary(
                unsafeLastRunAt: lastRunAt,
                passed: passed,
                failed: failed,
                total: total,
                status: .inProgress
            )
        }

        /// Transient "run could not complete" summary. Carries a structured
        /// failure payload so the UI can render a stable category alongside
        /// the message. Counts may describe how far the run got before
        /// failing; like `inProgress`, `passed + failed` must stay
        /// `<= total`.
        public static func error(
            _ failure: Status.Failure,
            lastRunAt: Date? = nil,
            passed: Int = 0,
            failed: Int = 0,
            total: Int = 0
        ) throws -> Summary {
            try validateTransientCounts(passed: passed, failed: failed, total: total)
            return Summary(
                unsafeLastRunAt: lastRunAt,
                passed: passed,
                failed: failed,
                total: total,
                status: .error(failure)
            )
        }

        private static func validateTransientCounts(
            passed: Int,
            failed: Int,
            total: Int
        ) throws {
            guard passed >= 0, failed >= 0, total >= 0 else {
                throw InvariantError.negativeCount
            }
            // total == 0 is allowed (e.g. a parser failure before any task
            // ran); passed/failed must then also be 0.
            if total == 0 {
                guard passed == 0, failed == 0 else {
                    throw InvariantError.transientCountsExceedTotal
                }
            } else if passed + failed > total {
                throw InvariantError.transientCountsExceedTotal
            }
        }

        // MARK: Internals

        private init(
            unsafeLastRunAt lastRunAt: Date?,
            passed: Int,
            failed: Int,
            total: Int,
            status: Status
        ) {
            self.lastRunAt = lastRunAt
            self.passed = passed
            self.failed = failed
            self.total = total
            self.status = status
        }

        // MARK: Codable

        private enum CodingKeys: String, CodingKey {
            case lastRunAt
            case passed
            case failed
            case total
            case status
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let lastRunAt = try container.decodeIfPresent(Date.self, forKey: .lastRunAt)
            let passed = try container.decode(Int.self, forKey: .passed)
            let failed = try container.decode(Int.self, forKey: .failed)
            let total = try container.decode(Int.self, forKey: .total)
            let status = try container.decode(Status.self, forKey: .status)

            try Summary.validatePersisted(
                status: status,
                lastRunAt: lastRunAt,
                passed: passed,
                failed: failed,
                total: total,
                container: container
            )

            self.lastRunAt = lastRunAt
            self.passed = passed
            self.failed = failed
            self.total = total
            self.status = status
        }

        private static func validatePersisted(
            status: Status,
            lastRunAt: Date?,
            passed: Int,
            failed: Int,
            total: Int,
            container: KeyedDecodingContainer<CodingKeys>
        ) throws {
            guard passed >= 0, failed >= 0, total >= 0 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .total,
                    in: container,
                    debugDescription: "Counts must be non-negative."
                )
            }

            switch status {
            case .notEvaluated:
                guard lastRunAt == nil, passed == 0, failed == 0, total == 0 else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .status,
                        in: container,
                        debugDescription: ".notEvaluated must have no run timestamp and zero counts."
                    )
                }
            case .passed, .failed:
                guard lastRunAt != nil else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .lastRunAt,
                        in: container,
                        debugDescription: "Terminal status requires a lastRunAt timestamp."
                    )
                }
                guard total > 0 else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .total,
                        in: container,
                        debugDescription: "Terminal status requires total > 0."
                    )
                }
                guard passed + failed == total else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .total,
                        in: container,
                        debugDescription: "Terminal status requires passed + failed == total."
                    )
                }
                if status == .passed, failed != 0 {
                    throw DecodingError.dataCorruptedError(
                        forKey: .status,
                        in: container,
                        debugDescription: ".passed cannot have failed > 0."
                    )
                }
                if status == .failed, failed == 0 {
                    throw DecodingError.dataCorruptedError(
                        forKey: .status,
                        in: container,
                        debugDescription: ".failed requires failed > 0."
                    )
                }
            case .inProgress, .error:
                // Transient states do not require a lastRunAt timestamp,
                // but their counts must still be internally consistent.
                if total == 0 {
                    guard passed == 0, failed == 0 else {
                        throw DecodingError.dataCorruptedError(
                            forKey: .total,
                            in: container,
                            debugDescription: "Transient status with total == 0 must have zero passed/failed."
                        )
                    }
                } else if passed + failed > total {
                    throw DecodingError.dataCorruptedError(
                        forKey: .total,
                        in: container,
                        debugDescription: "Transient status requires passed + failed <= total."
                    )
                }
            }
        }
    }
}
