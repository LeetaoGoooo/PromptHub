import Foundation

// MARK: - Minimal YAML Front-matter Parser

/// Parses the `---` / `---` YAML front-matter block at the start of a markdown file.
/// Only handles simple `key: value` scalar pairs (no nested YAML).
public enum FrontMatterParser {

    /// Splits a markdown document into front-matter key-value pairs and the body.
    /// - Returns: `(fields: [String:String], body: String)` where `body` is everything
    ///   after the closing `---`.
    public static func parse(_ content: String) -> (fields: [String: String], body: String) {
        let lines = content.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return ([:], content)
        }

        var fields: [String: String] = [:]
        var closingIndex: Int? = nil

        for (index, line) in lines.dropFirst().enumerated() {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                closingIndex = index + 1 // +1 because we dropped first
                break
            }
            if let colonRange = line.range(of: ":") {
                let key = line[line.startIndex ..< colonRange.lowerBound]
                    .trimmingCharacters(in: .whitespaces)
                var value = line[colonRange.upperBound...]
                    .trimmingCharacters(in: .whitespaces)
                // Strip surrounding double-quotes and unescape
                if value.hasPrefix("\"") && value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                    value = value.replacingOccurrences(of: "\\\"", with: "\"")
                    value = value.replacingOccurrences(of: "\\n", with: "\n")
                }
                fields[key] = value
            }
        }

        let body: String
        if let idx = closingIndex {
            let bodyLines = Array(lines.dropFirst(idx + 1))
            body = bodyLines.joined(separator: "\n")
                .trimmingCharacters(in: .init(charactersIn: "\n"))
        } else {
            body = content
        }

        return (fields, body)
    }
}
