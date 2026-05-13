import Foundation

// MARK: - SkillEvaluation Suite / Task Models (P2.1)
//
// P2.1 introduces the value types that describe an evaluation suite living
// inside a skill package under `eval/`. No parser, no validator, no runner
// at this layer — those arrive in P2.2 (YAML parser), P2.3 (schema
// validation with clear errors), P2.4 (suite discovery), and P3 (graders +
// runner).
//
// These are *normalized* domain models, not raw on-disk DTOs. P2.2 will
// introduce internal manifest / task DTOs that decode the YAML and then
// resolve into the public `Suite`/`Task` shape declared here. The Codable
// conformance on these types is for run-result archives and IPC, not for
// directly decoding `eval.yaml`.
//
// `GraderSpec.Kind` raw values and the `GraderSpec.Parameter` envelope are
// part of the wire format consumed by the run-result archive in P3, so
// their tests act as canaries for accidental wire-format breaks.

extension SkillEvaluation {

    /// Top-level evaluation suite, parsed from `eval/eval.yaml` plus the
    /// individual task files referenced by it.
    public struct Suite: Sendable, Equatable, Codable {
        /// Human-readable suite name. By convention this matches the skill's
        /// display name, but no rule forces that.
        public let name: String
        /// Optional suite version, allowing authors to evolve the suite over
        /// time without breaking historical run records.
        public let version: String?
        /// Directory inside the skill package that contains this suite.
        /// Defaults to the conventional `eval` folder; preserved so future
        /// alternative layouts can be expressed without recomputing the path.
        public let directoryName: String
        /// Resolved tasks, in declaration order.
        public let tasks: [Task]

        public init(
            name: String,
            version: String?,
            directoryName: String = "eval",
            tasks: [Task]
        ) {
            self.name = name
            self.version = version
            self.directoryName = directoryName
            self.tasks = tasks
        }
    }

    /// A single scenario task, parsed from one YAML file under
    /// `eval/tasks/`. Identifiable so SwiftUI lists in P4 can use it
    /// directly without a wrapper.
    public struct Task: Sendable, Equatable, Codable, Identifiable {
        /// Stable task identifier. By convention this is the YAML file
        /// basename (without extension); explicit `id:` fields in the YAML
        /// override that convention.
        public let id: String
        /// Short, user-presentable title.
        public let title: String
        /// Declared task input (prompt and/or fixture attachments).
        public let input: Input
        /// One or more graders that decide pass/fail for this task.
        public let graders: [GraderSpec]

        public init(id: String, title: String, input: Input, graders: [GraderSpec]) {
            self.id = id
            self.title = title
            self.input = input
            self.graders = graders
        }
    }

    /// Declared input for a task. Both fields are optional so file-only
    /// post-condition tasks (e.g. `file_exists`) can omit a prompt entirely.
    public struct Input: Sendable, Equatable, Codable {
        public let prompt: String?
        /// Relative paths from the **suite root** (i.e. the directory
        /// referenced by `Suite.directoryName`, conventionally `eval/`).
        /// Authors typically place fixtures under `eval/fixtures/`, but this
        /// type does not require that subdirectory; P2.3 owns the policy
        /// check that the referenced files exist and stay within the suite
        /// root.
        public let attachments: [String]

        public init(prompt: String?, attachments: [String]) {
            self.prompt = prompt
            self.attachments = attachments
        }
    }

    /// Declarative grader specification. The concrete grader implementation
    /// lives in P3; this layer keeps an open-ended parameter bag so the
    /// model layer does not need to know how each grader interprets its
    /// arguments.
    public struct GraderSpec: Sendable, Equatable, Codable {
        public let kind: Kind
        public let parameters: [String: Parameter]

        public init(kind: Kind, parameters: [String: Parameter]) {
            self.kind = kind
            self.parameters = parameters
        }

        /// V1 grader vocabulary. Raw values are the snake_case strings used
        /// in `eval/tasks/*.yaml`; renaming them would be a wire-format
        /// break.
        public enum Kind: String, Sendable, Codable, CaseIterable {
            case textContains = "text_contains"
            case textExact = "text_exact"
            case jsonSchema = "json_schema"
            case fileExists = "file_exists"
            case fileDiff = "file_diff"
            case validatorExit = "validator_exit"
        }

        /// Recursive, JSON-shaped parameter value. The set of variants is
        /// closed for v1 (unknown discriminators fail decode); adding a new
        /// variant is therefore a deliberate wire-format change and must be
        /// matched by a migration in the run-result archive.
        ///
        /// The recursive `array` and `object` cases let graders such as
        /// `json_schema` carry an inline schema without escaping back to
        /// `Any`.
        public indirect enum Parameter: Sendable, Equatable, Codable {
            case string(String)
            case int(Int)
            case double(Double)
            case bool(Bool)
            case null
            case array([Parameter])
            case object([String: Parameter])

            // MARK: Codable

            private enum CodingKeys: String, CodingKey {
                case kind
                case value
            }

            private enum Kind: String, Codable {
                case string
                case int
                case double
                case bool
                case null
                case array
                case object
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let kind = try container.decode(Kind.self, forKey: .kind)
                switch kind {
                case .string:
                    self = .string(try container.decode(String.self, forKey: .value))
                case .int:
                    self = .int(try container.decode(Int.self, forKey: .value))
                case .double:
                    self = .double(try container.decode(Double.self, forKey: .value))
                case .bool:
                    self = .bool(try container.decode(Bool.self, forKey: .value))
                case .null:
                    self = .null
                case .array:
                    self = .array(try container.decode([Parameter].self, forKey: .value))
                case .object:
                    self = .object(try container.decode([String: Parameter].self, forKey: .value))
                }
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                switch self {
                case .string(let v):
                    try container.encode(Kind.string, forKey: .kind)
                    try container.encode(v, forKey: .value)
                case .int(let v):
                    try container.encode(Kind.int, forKey: .kind)
                    try container.encode(v, forKey: .value)
                case .double(let v):
                    try container.encode(Kind.double, forKey: .kind)
                    try container.encode(v, forKey: .value)
                case .bool(let v):
                    try container.encode(Kind.bool, forKey: .kind)
                    try container.encode(v, forKey: .value)
                case .null:
                    try container.encode(Kind.null, forKey: .kind)
                case .array(let v):
                    try container.encode(Kind.array, forKey: .kind)
                    try container.encode(v, forKey: .value)
                case .object(let v):
                    try container.encode(Kind.object, forKey: .kind)
                    try container.encode(v, forKey: .value)
                }
            }
        }
    }
}
