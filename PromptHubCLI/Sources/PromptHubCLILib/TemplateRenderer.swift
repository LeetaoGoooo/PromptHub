import Foundation

// MARK: - Template Renderer

/// Simple `{{variable}}` template renderer.
public enum TemplateRenderer {

    /// Replaces `{{variable}}` placeholders in `template` with values from `variables`.
    /// Unmatched placeholders are left unchanged.
    public static func render(_ template: String, variables: [String: String]) -> String {
        var result = template
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
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
