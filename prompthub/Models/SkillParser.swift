import Foundation// Note: Since I don't know the exact SPM dependencies, I'll implement a robust regex-based YAML parser for the frontmatter.

struct SkillParser {
    static func parse(markdown: String) -> (metadata: [String: Any], instructions: String)? {
        let pattern = "^---\\s*\\n([\\s\\S]*?)\\n---\\s*\\n([\\s\\S]*)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]),
              let match = regex.firstMatch(in: markdown, options: [], range: NSRange(markdown.startIndex..., in: markdown)) else {
            return nil
        }
        
        let yamlRange = match.range(at: 1)
        let instructionsRange = match.range(at: 2)
        
        guard let yamlContent = Range(yamlRange, in: markdown),
              let instructionsContent = Range(instructionsRange, in: markdown) else {
            return nil
        }
        
        let metadata = parseYAML(String(markdown[yamlContent]))
        let instructions = String(markdown[instructionsContent]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (metadata, instructions)
    }
    
    private static func parseYAML(_ yaml: String) -> [String: Any] {
        var result: [String: Any] = [:]
        let lines = yaml.components(separatedBy: .newlines)
        
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                let key = parts[0]
                let value = parts[1]
                
                // Basic type inference
                if value.lowercased() == "true" {
                    result[key] = true
                } else if value.lowercased() == "false" {
                    result[key] = false
                } else if let intValue = Int(value) {
                    result[key] = intValue
                } else if let doubleValue = Double(value) {
                    result[key] = doubleValue
                } else {
                    result[key] = value.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
                }
            }
        }
        return result
    }
    
    static func generate(metadata: [String: Any], instructions: String) -> String {
        var yaml = "---\n"
        for (key, value) in metadata {
            yaml += "\(key): \(value)\n"
        }
        yaml += "---\n\n"
        yaml += instructions
        return yaml
    }
}
