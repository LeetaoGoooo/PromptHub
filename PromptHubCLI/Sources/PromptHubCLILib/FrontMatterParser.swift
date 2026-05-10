import Foundation

// MARK: - Minimal YAML Front-matter Parser

/// Parses the `---` / `---` YAML front-matter block at the start of a markdown file.
/// Only handles simple `key: value` scalar pairs (no nested YAML).
public enum FrontMatterParser {

    /// Splits a markdown document into front-matter key-value pairs and the body.
    /// - Returns: `(fields: [String:String], body: String)` where `body` is everything
    ///   after the closing `---`.
    public static func parse(_ content: String) -> (fields: [String: String], body: String) {
        // Normalize CRLF to LF so Windows-edited files parse correctly
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return ([:], content)
        }

        var fields: [String: String] = [:]
        var closingIndex: Int? = nil

        for (index, line) in lines.dropFirst().enumerated() {
            if line.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
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
                if !key.isEmpty { fields[key] = value }
            }
        }

        // Treat unclosed front matter as invalid — return no fields and full content as body
        guard let idx = closingIndex else {
            return ([:], content)
        }

        // Preserve body bytes exactly after the closing delimiter
        let bodyLines = Array(lines.dropFirst(idx + 1))
        let body = bodyLines.joined(separator: "\n")

        return (fields, body)
    }
}
