import Foundation

extension String {
    /// Converts kebab-case or snake_case string to Title Case.
    /// Example: "apple-ios-design-expert" -> "Apple Ios Design Expert"
    var titleCased: String {
        let raw = self.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        
        return raw.split(separator: " ")
            .map { word -> String in
                let lower = word.lowercased()
                switch lower {
                case "ios": return "iOS"
                case "macos": return "macOS"
                case "cli": return "CLI"
                case "sh": return "sh"
                default: return lower.capitalized
                }
            }
            .joined(separator: " ")
    }
}
