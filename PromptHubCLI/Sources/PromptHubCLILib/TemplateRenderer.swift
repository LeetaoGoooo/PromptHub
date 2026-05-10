import Foundation

// MARK: - Template Renderer

/// Simple `{{variable}}` template renderer.
public enum TemplateRenderer {

    /// Replaces `{{variable}}` placeholders in `template` with values from `variables`.
    /// Uses a single-pass regex scan to avoid substituting inside replacement values.
    /// Unmatched placeholders are left unchanged.
    public static func render(_ template: String, variables: [String: String]) -> String {
        guard !variables.isEmpty else { return template }
        guard let regex = try? NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}") else {
            return template
        }

        var result = ""
        var lastEnd = template.startIndex
        let nsTemplate = template as NSString
        let fullRange = NSRange(template.startIndex..., in: template)

        regex.enumerateMatches(in: template, range: fullRange) { match, _, _ in
            guard let match else { return }
            // Append literal text before this match
            if let matchRange = Range(match.range, in: template) {
                result += template[lastEnd ..< matchRange.lowerBound]
                lastEnd = matchRange.upperBound
            }
            // Resolve the placeholder name
            if let captureRange = Range(match.range(at: 1), in: template) {
                let key = String(template[captureRange]).trimmingCharacters(in: .whitespaces)
                if let value = variables[key] {
                    result += value
                } else {
                    // Leave unresolved placeholder as-is
                    result += nsTemplate.substring(with: match.range)
                }
            }
        }
        // Append remaining text after last match
        result += template[lastEnd...]
        return result
    }

    /// Returns all `{{placeholder}}` names still present in a string.
    public static func findPlaceholders(in text: String) -> [String] {
        var found: [String] = []
        let pattern = "\\{\\{([^}]+)\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match,
                  let captureRange = Range(match.range(at: 1), in: text) else { return }
            let name = String(text[captureRange]).trimmingCharacters(in: .whitespaces)
            if !found.contains(name) { found.append(name) }
        }
        return found
    }
}
