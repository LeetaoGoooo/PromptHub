import Foundation
import Yams

// MARK: - SkillEvaluation Suite/Task YAML Parser (P2.2)
//
// Translates the on-disk YAML format used in `eval/eval.yaml` and
// `eval/tasks/*.yaml` into the normalized public types defined in P2.1.
//
// The parser intentionally delegates scalar typing to Yams' default
// resolver (`Node.bool`, `Node.int`, `Node.float`, `Node.string`,
// `Node.isNull`). Those accessors honor explicit YAML tags (e.g. the
// author writing `!!str true` keeps it as a string) and quote style
// (quoted `"2"` resolves to `!!str`, plain `2` to `!!int`). Re-inferring
// types from raw text would lose that information and silently misparse
// legitimate YAML.
//
// Schema validation (e.g. "json_schema requires a `schema` parameter",
// "≥1 grader per task") is the next todo (P2.3); filesystem discovery
// is P2.4. This layer only guarantees: inputs that parse here yield
// well-formed model objects.

extension SkillEvaluation {

    /// Manifest-level metadata parsed from `eval/eval.yaml`. Tasks are
    /// referenced by id (typically the file basename) and resolved
    /// separately into the public `Suite` shape.
    public struct Manifest: Sendable, Equatable {
        public let name: String
        public let version: String?
        public let taskRefs: [String]

        public init(name: String, version: String?, taskRefs: [String]) {
            self.name = name
            self.version = version
            self.taskRefs = taskRefs
        }
    }

    /// Errors raised during YAML parsing.
    ///
    /// Each case carries enough context for an authoring UI (P5) and
    /// the schema-validation layer (P2.3) to surface a precise message.
    /// The `field` / `at` strings use a dotted/indexed convention,
    /// e.g. `graders[1].parameters.schema.properties.id.type`.
    public enum SuiteParseError: Error, Equatable, CustomStringConvertible {
        case yamlSyntax(String)
        case missingField(String)
        case wrongFieldType(field: String, expected: String)
        case unknownGraderKind(String, at: String)
        case nonFiniteNumericScalar(String, at: String)
        case duplicateMappingKey(String, at: String)
        case unknownTaskRef(String)

        public var description: String {
            switch self {
            case .yamlSyntax(let m): return "YAML syntax error: \(m)"
            case .missingField(let f): return "Missing required field: \(f)"
            case .wrongFieldType(let f, let exp): return "Field '\(f)' must be \(exp)"
            case .unknownGraderKind(let k, let at): return "Unknown grader kind '\(k)' at \(at)"
            case .nonFiniteNumericScalar(let v, let at): return "Non-finite numeric scalar '\(v)' at \(at)"
            case .duplicateMappingKey(let k, let at): return "Duplicate mapping key '\(k)' at \(at)"
            case .unknownTaskRef(let r): return "Manifest references unknown task: \(r)"
            }
        }
    }

    /// Top-level YAML parser entry points.
    public enum SuiteParser {

        // MARK: Manifest

        public static func parseManifest(yaml: String) throws -> Manifest {
            let root = try loadRoot(yaml)
            let map = try mappingDict(root, path: "<manifest>")
            let name = try requireString(map, key: "name", fieldPath: "name")
            let version = try optionalString(map, key: "version", fieldPath: "version")
            let taskRefs = try requireStringList(map, key: "tasks", fieldPath: "tasks")
            return Manifest(name: name, version: version, taskRefs: taskRefs)
        }

        // MARK: Task

        public static func parseTask(yaml: String, defaultID: String) throws -> Task {
            let root = try loadRoot(yaml)
            let map = try mappingDict(root, path: "<task>")
            let id = try optionalString(map, key: "id", fieldPath: "id") ?? defaultID
            let title = try requireString(map, key: "title", fieldPath: "title")
            let input = try parseInput(map["input"], path: "input")
            guard let gradersNode = map["graders"] else {
                throw SuiteParseError.missingField("graders")
            }
            guard case .sequence(let gradersSeq) = gradersNode else {
                throw SuiteParseError.wrongFieldType(field: "graders", expected: "sequence")
            }
            var graders: [GraderSpec] = []
            graders.reserveCapacity(gradersSeq.count)
            for (idx, node) in gradersSeq.enumerated() {
                graders.append(try parseGraderSpec(node, path: "graders[\(idx)]"))
            }
            return Task(id: id, title: title, input: input, graders: graders)
        }

        // MARK: Resolve

        /// Combine a parsed manifest with the parsed tasks (keyed by id).
        /// The resolved `Suite.tasks` array follows manifest order.
        public static func resolve(
            manifest: Manifest,
            tasksByID: [String: Task],
            directoryName: String = "eval"
        ) throws -> Suite {
            var resolved: [Task] = []
            resolved.reserveCapacity(manifest.taskRefs.count)
            for ref in manifest.taskRefs {
                guard let task = tasksByID[ref] else {
                    throw SuiteParseError.unknownTaskRef(ref)
                }
                resolved.append(task)
            }
            return Suite(
                name: manifest.name,
                version: manifest.version,
                directoryName: directoryName,
                tasks: resolved
            )
        }

        // MARK: - YAML loading

        private static func loadRoot(_ yaml: String) throws -> Yams.Node {
            do {
                guard let node = try Yams.compose(yaml: yaml) else {
                    throw SuiteParseError.yamlSyntax("empty document")
                }
                return node
            } catch let e as SuiteParseError {
                throw e
            } catch {
                throw SuiteParseError.yamlSyntax(String(describing: error))
            }
        }

        // MARK: - Mapping / field helpers

        /// Convert a YAML mapping node into a `[String: Yams.Node]`
        /// dictionary while detecting duplicate keys post-stringification.
        ///
        /// Note on key policy: keys are coerced to their raw scalar
        /// string regardless of resolved tag (so `1: a` becomes the
        /// key `"1"`). Duplicate-key detection runs after
        /// stringification, so `1: a` and `!!str "1": b` collide and
        /// raise an error rather than silently dropping one.
        private static func mappingDict(_ node: Yams.Node, path: String) throws -> [String: Yams.Node] {
            guard case .mapping(let m) = node else {
                throw SuiteParseError.wrongFieldType(field: path, expected: "mapping")
            }
            var dict: [String: Yams.Node] = [:]
            for (keyNode, valueNode) in m {
                guard case .scalar(let keyScalar) = keyNode else {
                    throw SuiteParseError.wrongFieldType(
                        field: path, expected: "string-keyed mapping"
                    )
                }
                let key = keyScalar.string
                if dict[key] != nil {
                    throw SuiteParseError.duplicateMappingKey(key, at: path)
                }
                dict[key] = valueNode
            }
            return dict
        }

        private static func requireString(
            _ map: [String: Yams.Node], key: String, fieldPath: String
        ) throws -> String {
            guard let node = map[key] else {
                throw SuiteParseError.missingField(fieldPath)
            }
            return try resolveString(node, fieldPath: fieldPath)
        }

        private static func optionalString(
            _ map: [String: Yams.Node], key: String, fieldPath: String
        ) throws -> String? {
            guard let node = map[key] else { return nil }
            return try resolveString(node, fieldPath: fieldPath)
        }

        private static func requireStringList(
            _ map: [String: Yams.Node], key: String, fieldPath: String
        ) throws -> [String] {
            guard let node = map[key] else {
                throw SuiteParseError.missingField(fieldPath)
            }
            guard case .sequence(let seq) = node else {
                throw SuiteParseError.wrongFieldType(field: fieldPath, expected: "sequence")
            }
            var out: [String] = []
            out.reserveCapacity(seq.count)
            for (idx, element) in seq.enumerated() {
                out.append(try resolveString(element, fieldPath: "\(fieldPath)[\(idx)]"))
            }
            return out
        }

        /// Resolve a `Yams.Node` to a string, accepting any value Yams'
        /// default resolver classifies as `!!str` (quoted scalars,
        /// explicit `!!str` tag, or plain scalars that don't match
        /// bool / int / float / null patterns). Anything else surfaces
        /// as a type error so a typo like `name: 2` doesn't silently
        /// become the string "2".
        private static func resolveString(_ node: Yams.Node, fieldPath: String) throws -> String {
            guard case .scalar(let scalar) = node else {
                throw SuiteParseError.wrongFieldType(field: fieldPath, expected: "string")
            }
            if hasExplicitStringTag(scalar) {
                return scalar.string
            }
            if node.null != nil || node.bool != nil || node.int != nil || node.float != nil {
                throw SuiteParseError.wrongFieldType(field: fieldPath, expected: "string")
            }
            return scalar.string
        }

        // MARK: - Input

        private static func parseInput(_ node: Yams.Node?, path: String) throws -> Input {
            guard let node else {
                return Input(prompt: nil, attachments: [])
            }
            let map = try mappingDict(node, path: path)
            let prompt = try optionalString(map, key: "prompt", fieldPath: "\(path).prompt")
            let attachments: [String]
            if let attachmentsNode = map["attachments"] {
                guard case .sequence(let seq) = attachmentsNode else {
                    throw SuiteParseError.wrongFieldType(
                        field: "\(path).attachments", expected: "sequence"
                    )
                }
                var collected: [String] = []
                collected.reserveCapacity(seq.count)
                for (idx, element) in seq.enumerated() {
                    collected.append(try resolveString(element, fieldPath: "\(path).attachments[\(idx)]"))
                }
                attachments = collected
            } else {
                attachments = []
            }
            return Input(prompt: prompt, attachments: attachments)
        }

        // MARK: - Grader

        private static func parseGraderSpec(_ node: Yams.Node, path: String) throws -> GraderSpec {
            let map = try mappingDict(node, path: path)
            let kindRaw = try requireString(map, key: "kind", fieldPath: "\(path).kind")
            guard let kind = GraderSpec.Kind(rawValue: kindRaw) else {
                throw SuiteParseError.unknownGraderKind(kindRaw, at: "\(path).kind")
            }
            let parameters: [String: GraderSpec.Parameter]
            if let paramsNode = map["parameters"] {
                let paramPath = "\(path).parameters"
                let paramMap = try mappingDict(paramsNode, path: paramPath)
                var out: [String: GraderSpec.Parameter] = [:]
                for (k, v) in paramMap {
                    out[k] = try normalizeParameter(v, path: "\(paramPath).\(k)")
                }
                parameters = out
            } else {
                parameters = [:]
            }
            return GraderSpec(kind: kind, parameters: parameters)
        }

        // MARK: - Parameter normalization

        private static func normalizeParameter(_ node: Yams.Node, path: String) throws -> GraderSpec.Parameter {
            switch node {
            case .scalar:
                return try normalizeScalar(node, path: path)
            case .sequence(let seq):
                var arr: [GraderSpec.Parameter] = []
                arr.reserveCapacity(seq.count)
                for (idx, child) in seq.enumerated() {
                    arr.append(try normalizeParameter(child, path: "\(path)[\(idx)]"))
                }
                return .array(arr)
            case .mapping:
                let map = try mappingDict(node, path: path)
                var out: [String: GraderSpec.Parameter] = [:]
                for (k, v) in map {
                    out[k] = try normalizeParameter(v, path: "\(path).\(k)")
                }
                return .object(out)
            case .alias:
                // Defensive: Yams.compose normally dereferences aliases
                // before returning, so this branch should not fire for
                // valid input. Treated as a syntax error rather than
                // silently misparsing if Yams' behavior ever changes.
                throw SuiteParseError.yamlSyntax("YAML aliases are not supported (\(path))")
            }
        }

        /// Normalize a scalar `Yams.Node` into a `Parameter`. Type
        /// resolution is delegated to Yams' default resolver, whose
        /// accessors (`bool`, `int`, `float`, `null`) honor both the
        /// scalar's quote style and any explicit YAML tag — with one
        /// caveat: Yams' `Int.construct`, `Double.construct`, and
        /// `NSNull.construct` only inspect quote style and do not
        /// special-case explicit `!!str` / `!!null` tags. We therefore
        /// short-circuit those two tags before consulting the numeric
        /// accessors so `!!str 42` stays a string and `!!null "x"`
        /// stays null. (`!!bool` does check for `!!str` but has no
        /// quoted-style gate, so it works through `node.bool`.)
        private static func normalizeScalar(_ node: Yams.Node, path: String) throws -> GraderSpec.Parameter {
            guard case .scalar(let scalar) = node else {
                // Caller (`normalizeParameter`) already filters by case;
                // this is unreachable unless that contract is broken.
                throw SuiteParseError.wrongFieldType(field: path, expected: "scalar")
            }
            if hasExplicitTag(scalar, .str) {
                return .string(scalar.string)
            }
            if hasExplicitTag(scalar, .null) {
                return .null
            }
            if node.null != nil {
                return .null
            }
            if let b = node.bool {
                return .bool(b)
            }
            if let i = node.int {
                return .int(i)
            }
            if let d = node.float {
                guard d.isFinite else {
                    throw SuiteParseError.nonFiniteNumericScalar(scalar.string, at: path)
                }
                return .double(d)
            }
            return .string(scalar.string)
        }

        /// True if the scalar carries an explicit `!!str` tag. Tag's
        /// internal `name` property is not exposed, but Yams conforms
        /// `Tag` to `RawRepresentable` whose `rawValue` is the tag URI,
        /// so we compare against `Tag.Name.str.rawValue`.
        private static func hasExplicitStringTag(_ scalar: Yams.Node.Scalar) -> Bool {
            hasExplicitTag(scalar, .str)
        }

        private static func hasExplicitTag(_ scalar: Yams.Node.Scalar, _ name: Tag.Name) -> Bool {
            scalar.tag.rawValue == name.rawValue
        }
    }
}
