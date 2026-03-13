import Foundation

public enum SkillMarkdownDocument {
    public static func parse(markdown: String) -> (metadata: [String: Any], instructions: String)? {
        let lines = markdown.components(separatedBy: .newlines)
        guard let openingIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "---" }),
              openingIndex == 0,
              let closingIndex = lines[(openingIndex + 1)...].firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "---" }) else {
            return nil
        }

        let frontMatterLines = Array(lines[(openingIndex + 1)..<closingIndex])
        let instructionLines = Array(lines[(closingIndex + 1)...])
        let metadata = parseFrontMatter(frontMatterLines.joined(separator: "\n"))
        let instructions = instructionLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (metadata, instructions)
    }

    public static func parseFrontMatter(_ yaml: String) -> [String: Any] {
        var index = 0
        let lines = yaml.components(separatedBy: .newlines)
        let root = parseMapping(lines, index: &index, baseIndent: 0)
        return root.reduce(into: [String: Any]()) { partialResult, entry in
            partialResult[entry.key] = entry.value.asAny
        }
    }

    public static func generate(metadata: [String: Any], instructions: String) -> String {
        let normalized = metadata.compactMapValues(Node.init)
        var lines = ["---"]
        lines.append(contentsOf: serializeMapping(normalized, indent: 0, keyOrder: orderedKeys(for: normalized)))
        lines.append("---")

        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInstructions.isEmpty {
            lines.append("")
            lines.append(trimmedInstructions)
        }

        return lines.joined(separator: "\n")
    }

    public static func stringValue(for key: String, in markdown: String) -> String? {
        guard let (metadata, _) = parse(markdown: markdown) else {
            return nil
        }
        return stringValue(for: key, in: metadata)
    }

    public static func stringValue(for key: String, in metadata: [String: Any]) -> String? {
        guard let value = metadata[key] else {
            return nil
        }

        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }

        if let int = value as? Int {
            return String(int)
        }

        if let double = value as? Double {
            return String(double)
        }

        return nil
    }

    public static func stringArrayValue(for key: String, in metadata: [String: Any]) -> [String] {
        if let strings = metadata[key] as? [String] {
            return strings
        }

        if let values = metadata[key] as? [Any] {
            return values.compactMap { value in
                if let string = value as? String {
                    return string
                }
                if let int = value as? Int {
                    return String(int)
                }
                if let bool = value as? Bool {
                    return bool ? "true" : "false"
                }
                if let double = value as? Double {
                    return String(double)
                }
                return nil
            }
        }

        if let commaSeparated = metadata[key] as? String {
            return commaSeparated
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        return []
    }

    private static func parseMapping(
        _ lines: [String],
        index: inout Int,
        baseIndent: Int
    ) -> [String: Node] {
        var result: [String: Node] = [:]

        while let current = nextMeaningfulLine(in: lines, from: index) {
            let rawLine = lines[current]
            let indent = indentation(of: rawLine)
            if indent < baseIndent {
                break
            }
            if indent > baseIndent {
                index = current
                break
            }

            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard let colonIndex = mappingColonIndex(in: trimmed) else {
                index = current + 1
                continue
            }

            let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            index = current + 1

            if rawValue == "|" || rawValue == ">" {
                let block = parseBlockString(lines, index: &index, parentIndent: indent, folded: rawValue == ">")
                result[key] = .string(block)
                continue
            }

            if !rawValue.isEmpty {
                result[key] = parseScalarOrInline(rawValue)
                continue
            }

            guard let next = nextMeaningfulLine(in: lines, from: index) else {
                result[key] = .string("")
                continue
            }

            let nextIndent = indentation(of: lines[next])
            if nextIndent <= indent {
                result[key] = .string("")
                continue
            }

            if lines[next].trimmingCharacters(in: .whitespaces).hasPrefix("-") {
                result[key] = .array(parseArray(lines, index: &index, baseIndent: nextIndent))
            } else {
                result[key] = .object(parseMapping(lines, index: &index, baseIndent: nextIndent))
            }
        }

        return result
    }

    private static func parseArray(
        _ lines: [String],
        index: inout Int,
        baseIndent: Int
    ) -> [Node] {
        var items: [Node] = []

        while let current = nextMeaningfulLine(in: lines, from: index) {
            let rawLine = lines[current]
            let indent = indentation(of: rawLine)
            if indent < baseIndent {
                break
            }
            if indent > baseIndent {
                index = current
                break
            }

            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("-") else {
                break
            }

            let remainder = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            index = current + 1

            if remainder == "|" || remainder == ">" {
                let block = parseBlockString(lines, index: &index, parentIndent: indent, folded: remainder == ">")
                items.append(.string(block))
                continue
            }

            if remainder.isEmpty {
                if let next = nextMeaningfulLine(in: lines, from: index) {
                    let nextIndent = indentation(of: lines[next])
                    if nextIndent > indent {
                        if lines[next].trimmingCharacters(in: .whitespaces).hasPrefix("-") {
                            items.append(.array(parseArray(lines, index: &index, baseIndent: nextIndent)))
                        } else {
                            items.append(.object(parseMapping(lines, index: &index, baseIndent: nextIndent)))
                        }
                        continue
                    }
                }

                items.append(.string(""))
                continue
            }

            if let colonIndex = mappingColonIndex(in: remainder) {
                let key = String(remainder[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                let rawValue = String(remainder[remainder.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                var object: [String: Node] = [:]

                if rawValue == "|" || rawValue == ">" {
                    let block = parseBlockString(lines, index: &index, parentIndent: indent, folded: rawValue == ">")
                    object[key] = .string(block)
                } else if rawValue.isEmpty {
                    if let next = nextMeaningfulLine(in: lines, from: index) {
                        let nextIndent = indentation(of: lines[next])
                        if nextIndent > indent {
                            if lines[next].trimmingCharacters(in: .whitespaces).hasPrefix("-") {
                                object[key] = .array(parseArray(lines, index: &index, baseIndent: nextIndent))
                            } else {
                                object[key] = .object(parseMapping(lines, index: &index, baseIndent: nextIndent))
                            }
                        } else {
                            object[key] = .string("")
                        }
                    } else {
                        object[key] = .string("")
                    }
                } else {
                    object[key] = parseScalarOrInline(rawValue)
                }

                if let next = nextMeaningfulLine(in: lines, from: index) {
                    let nextIndent = indentation(of: lines[next])
                    if nextIndent > indent && !lines[next].trimmingCharacters(in: .whitespaces).hasPrefix("-") {
                        let nested = parseMapping(lines, index: &index, baseIndent: nextIndent)
                        for (nestedKey, nestedValue) in nested {
                            object[nestedKey] = nestedValue
                        }
                    }
                }

                items.append(.object(object))
                continue
            }

            items.append(parseScalarOrInline(remainder))
        }

        return items
    }

    private static func parseBlockString(
        _ lines: [String],
        index: inout Int,
        parentIndent: Int,
        folded: Bool
    ) -> String {
        let blockIndent = parentIndent + 1
        var collected: [String] = []

        while index < lines.count {
            let rawLine = lines[index]
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            let indent = indentation(of: rawLine)

            if !trimmed.isEmpty && indent <= parentIndent {
                break
            }

            if trimmed.isEmpty {
                collected.append("")
                index += 1
                continue
            }

            let contentStart = min(rawLine.count, max(blockIndent, min(indent, rawLine.count)))
            let value = String(rawLine.dropFirst(contentStart))
            collected.append(value)
            index += 1
        }

        if folded {
            return foldBlockString(collected)
        }

        return collected.joined(separator: "\n")
    }

    private static func foldBlockString(_ lines: [String]) -> String {
        var folded: [String] = []
        var previousWasBlank = false

        for line in lines {
            if line.isEmpty {
                folded.append("")
                previousWasBlank = true
                continue
            }

            if folded.isEmpty || previousWasBlank {
                folded.append(line)
            } else {
                folded[folded.count - 1] += " \(line)"
            }
            previousWasBlank = false
        }

        return folded.joined(separator: "\n")
    }

    private static func parseScalarOrInline(_ rawValue: String) -> Node {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if value == "null" || value == "~" {
            return .null
        }

        if value == "true" {
            return .bool(true)
        }

        if value == "false" {
            return .bool(false)
        }

        if value.hasPrefix("[") && value.hasSuffix("]") {
            let inner = String(value.dropFirst().dropLast())
            let components = splitInlineList(inner)
            return .array(components.map(parseScalarOrInline))
        }

        if value.hasPrefix("{") && value.hasSuffix("}") {
            let inner = String(value.dropFirst().dropLast())
            let entries = splitInlineList(inner)
            var object: [String: Node] = [:]
            for entry in entries {
                guard let colonIndex = mappingColonIndex(in: entry) else { continue }
                let key = String(entry[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                let nestedRaw = String(entry[entry.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                object[key] = parseScalarOrInline(nestedRaw)
            }
            return .object(object)
        }

        if let quoted = parseQuotedString(value) {
            return .string(quoted)
        }

        if let intValue = Int(value), !value.contains(".") {
            return .int(intValue)
        }

        if let doubleValue = Double(value) {
            return .double(doubleValue)
        }

        return .string(value)
    }

    private static func parseQuotedString(_ value: String) -> String? {
        guard value.count >= 2 else {
            return nil
        }

        if value.hasPrefix("\""), value.hasSuffix("\"") {
            let inner = String(value.dropFirst().dropLast())
            return inner
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\t", with: "\t")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }

        if value.hasPrefix("'"), value.hasSuffix("'") {
            let inner = String(value.dropFirst().dropLast())
            return inner.replacingOccurrences(of: "''", with: "'")
        }

        return nil
    }

    private static func splitInlineList(_ value: String) -> [String] {
        var components: [String] = []
        var current = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var nestedDepth = 0

        for character in value {
            switch character {
            case "'" where !inDoubleQuote:
                inSingleQuote.toggle()
                current.append(character)
            case "\"" where !inSingleQuote:
                inDoubleQuote.toggle()
                current.append(character)
            case "[" where !inSingleQuote && !inDoubleQuote:
                nestedDepth += 1
                current.append(character)
            case "{" where !inSingleQuote && !inDoubleQuote:
                nestedDepth += 1
                current.append(character)
            case "]" where !inSingleQuote && !inDoubleQuote:
                nestedDepth -= 1
                current.append(character)
            case "}" where !inSingleQuote && !inDoubleQuote:
                nestedDepth -= 1
                current.append(character)
            case "," where !inSingleQuote && !inDoubleQuote && nestedDepth == 0:
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    components.append(trimmed)
                }
                current = ""
            default:
                current.append(character)
            }
        }

        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            components.append(trimmed)
        }

        return components
    }

    private static func serializeMapping(
        _ mapping: [String: Node],
        indent: Int,
        keyOrder: [String]? = nil
    ) -> [String] {
        let keys = keyOrder ?? mapping.keys.sorted()
        var lines: [String] = []

        for key in keys {
            guard let value = mapping[key] else { continue }
            lines.append(contentsOf: serializeEntry(key: key, value: value, indent: indent))
        }

        return lines
    }

    private static func serializeEntry(key: String, value: Node, indent: Int) -> [String] {
        let prefix = String(repeating: " ", count: indent)

        switch value {
        case .string(let stringValue):
            if stringValue.contains("\n") {
                let lines = stringValue.components(separatedBy: .newlines)
                return [prefix + "\(key): |"] + lines.map { prefix + "  " + $0 }
            }
            return [prefix + "\(key): " + formatScalarString(stringValue)]
        case .bool(let boolValue):
            return [prefix + "\(key): " + (boolValue ? "true" : "false")]
        case .int(let intValue):
            return [prefix + "\(key): \(intValue)"]
        case .double(let doubleValue):
            return [prefix + "\(key): \(doubleValue)"]
        case .null:
            return [prefix + "\(key): null"]
        case .array(let values):
            guard !values.isEmpty else {
                return [prefix + "\(key): []"]
            }

            var lines = [prefix + "\(key):"]
            for value in values {
                lines.append(contentsOf: serializeArrayItem(value, indent: indent + 2))
            }
            return lines
        case .object(let object):
            guard !object.isEmpty else {
                return [prefix + "\(key): {}"]
            }

            var lines = [prefix + "\(key):"]
            lines.append(contentsOf: serializeMapping(object, indent: indent + 2))
            return lines
        }
    }

    private static func serializeArrayItem(_ value: Node, indent: Int) -> [String] {
        let prefix = String(repeating: " ", count: indent)

        switch value {
        case .string(let stringValue):
            if stringValue.contains("\n") {
                let lines = stringValue.components(separatedBy: .newlines)
                return [prefix + "- |"] + lines.map { prefix + "  " + $0 }
            }
            return [prefix + "- " + formatScalarString(stringValue)]
        case .bool(let boolValue):
            return [prefix + "- " + (boolValue ? "true" : "false")]
        case .int(let intValue):
            return [prefix + "- \(intValue)"]
        case .double(let doubleValue):
            return [prefix + "- \(doubleValue)"]
        case .null:
            return [prefix + "- null"]
        case .array(let values):
            guard !values.isEmpty else {
                return [prefix + "- []"]
            }

            var lines = [prefix + "-"]
            for value in values {
                lines.append(contentsOf: serializeArrayItem(value, indent: indent + 2))
            }
            return lines
        case .object(let object):
            guard !object.isEmpty else {
                return [prefix + "- {}"]
            }

            var lines = [prefix + "-"]
            lines.append(contentsOf: serializeMapping(object, indent: indent + 2))
            return lines
        }
    }

    private static func formatScalarString(_ value: String) -> String {
        if value.isEmpty {
            return "\"\""
        }

        let lowercased = value.lowercased()
        let shouldQuoteKeyword = ["true", "false", "null", "~"].contains(lowercased)
        let isNumeric = Int(value) != nil || Double(value) != nil
        let safeCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._/- "))
        let containsOnlySafeCharacters = value.unicodeScalars.allSatisfy { safeCharacters.contains($0) }
        let hasLeadingOrTrailingWhitespace = value != value.trimmingCharacters(in: .whitespaces)

        if containsOnlySafeCharacters && !shouldQuoteKeyword && !isNumeric && !hasLeadingOrTrailingWhitespace {
            return value
        }

        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    private static func orderedKeys(for metadata: [String: Node]) -> [String] {
        let preferred = [
            "name",
            "description",
            "version",
            "category",
            "identifier",
            "tags",
            "inputSchema",
            "outputSchema",
            "safetyPolicy"
        ]
        let remainder = metadata.keys
            .filter { !preferred.contains($0) }
            .sorted()
        return preferred.filter { metadata[$0] != nil } + remainder
    }

    private static func nextMeaningfulLine(in lines: [String], from index: Int) -> Int? {
        var current = index
        while current < lines.count {
            let trimmed = lines[current].trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                return current
            }
            current += 1
        }
        return nil
    }

    private static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    private static func mappingColonIndex(in line: String) -> String.Index? {
        var inSingleQuote = false
        var inDoubleQuote = false
        var previousCharacter: Character?

        for index in line.indices {
            let character = line[index]
            switch character {
            case "'" where !inDoubleQuote:
                if previousCharacter != "\\" {
                    inSingleQuote.toggle()
                }
            case "\"" where !inSingleQuote:
                if previousCharacter != "\\" {
                    inDoubleQuote.toggle()
                }
            case ":" where !inSingleQuote && !inDoubleQuote:
                return index
            default:
                break
            }
            previousCharacter = character
        }

        return nil
    }

    private enum Node {
        case string(String)
        case bool(Bool)
        case int(Int)
        case double(Double)
        case array([Node])
        case object([String: Node])
        case null

        init?(_ value: Any) {
            switch value {
            case let string as String:
                self = .string(string)
            case let bool as Bool:
                self = .bool(bool)
            case let int as Int:
                self = .int(int)
            case let double as Double:
                self = .double(double)
            case let array as [String]:
                self = .array(array.compactMap(Node.init))
            case let array as [Any]:
                self = .array(array.compactMap(Node.init))
            case let object as [String: Any]:
                var normalized: [String: Node] = [:]
                for (key, value) in object {
                    guard let node = Node(value) else { continue }
                    normalized[key] = node
                }
                self = .object(normalized)
            default:
                return nil
            }
        }

        var asAny: Any {
            switch self {
            case .string(let value):
                return value
            case .bool(let value):
                return value
            case .int(let value):
                return value
            case .double(let value):
                return value
            case .array(let values):
                return values.map(\.asAny)
            case .object(let values):
                return values.reduce(into: [String: Any]()) { partialResult, entry in
                    partialResult[entry.key] = entry.value.asAny
                }
            case .null:
                return NSNull()
            }
        }
    }
}
