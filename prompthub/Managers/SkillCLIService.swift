import Foundation
import Observation

@Observable
class SkillCLIService {
    static let shared = SkillCLIService()
    
    enum CLIError: LocalizedError, Equatable {
        case commandFailed(String)
        case decodingError
        case envNotFound
        
        var errorDescription: String? {
            switch self {
            case .commandFailed(let msg): return msg.isEmpty ? "Command execution failed" : msg
            case .decodingError: return "Failed to decode CLI output"
            case .envNotFound: return "Node environment not found"
            }
        }
    }
    
    struct SkillInfo: Codable, Identifiable, Equatable {
        var id: String { "\(name)-\(isGlobal)" }
        let name: String
        let description: String
        var isInstalled: Bool = false
        var isGlobal: Bool = false
        var url: String? // Added property
    }
    
    private let executor: CommandLineExecutor
    
    init(executor: CommandLineExecutor = RealCommandLineExecutor()) {
        self.executor = executor
    }
    
    /// Executes `npx skills find [query]` and parses the output
    func findSkills(query: String = "") async throws -> [SkillInfo] {
        let effectiveQuery = query.isEmpty ? "." : query
        let args = ["skills", "find", effectiveQuery, "--list"]
        let output = try await runCommand(args: args)
        return parseFindOutput(output)
    }
    
    /// Executes `npx skills list` and `npx skills list -g` and merges them
    func listInstalledSkills() async throws -> [SkillInfo] {
        // Fetch project skills
        let projectOutput = try await runCommand(args: ["skills", "list"])
        let projectSkills = parseListOutput(projectOutput, isGlobal: false)
        
        // Fetch global skills
        let globalOutput = try await runCommand(args: ["skills", "list", "-g"])
        let globalSkills = parseListOutput(globalOutput, isGlobal: true)
        
        var merged = projectSkills
        // Add global skills, avoiding duplicates if any overlap occurs (though unlikely for same name in different scopes)
        for gSkill in globalSkills {
            if !merged.contains(where: { $0.name == gSkill.name && $0.isGlobal == gSkill.isGlobal }) {
                merged.append(gSkill)
            }
        }
        
        return merged
    }
    
    /// Executes `npx skills add [package]`
    func addSkill(package: String, isGlobal: Bool = true) async throws {
        var args = ["skills", "add", package, "--yes"]
        if isGlobal {
            args.append("-g")
        }
        _ = try await runCommand(args: args)
    }
    
    /// Executes `npx skills remove [name]`
    func removeSkill(name: String, isGlobal: Bool = true) async throws {
        var args = ["skills", "remove", name, "--yes"]
        if isGlobal {
            args.append("-g")
        }
        _ = try await runCommand(args: args)
    }
    
    // MARK: - Private Helpers
    
    private func runCommand(args: [String]) async throws -> String {
        do {
            let output = try await executor.execute(args: args)
            return stripAnsiCodes(output)
        } catch let error as RealCommandLineExecutor.ExecutorError {
            switch error {
            case .decodingError:
                throw CLIError.decodingError
            case .commandFailed(let msg):
                throw CLIError.commandFailed(stripAnsiCodes(msg))
            }
        } catch {
            throw error
        }
    }
    
    private func stripAnsiCodes(_ input: String) -> String {
        // More robust ANSI escape sequence regex
        // Matches ESC [ ... m/K/G/etc
        let pattern = "\\u001B\\[[0-9;]*[a-zA-Z]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return input }
        let range = NSRange(location: 0, length: input.utf16.count)
        return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: "")
    }
    
    private func parseFindOutput(_ output: String) -> [SkillInfo] {
        let lines = output.components(separatedBy: .newlines)
        var skills: [SkillInfo] = []
        
        for i in 0..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("█") || line.contains("skills.sh") || line.contains("Skills") {
                continue
            }
            
            // Format: package@skill
            //         └ https://skills.sh/...
            if (line.contains("@") || (line.contains("/") && line.contains("skills.sh"))) && !line.hasPrefix("└") {
                let name = line
                var description = "No description available"
                var skillUrl: String? = nil
                
                if i + 1 < lines.count {
                    let nextLine = lines[i+1].trimmingCharacters(in: .whitespaces)
                    if nextLine.hasPrefix("└") {
                        let potentialUrl = nextLine.replacingOccurrences(of: "└ ", with: "")
                        if potentialUrl.starts(with: "http") {
                            skillUrl = potentialUrl
                        }
                    }
                }
                skills.append(SkillInfo(name: name, description: description, isInstalled: false, isGlobal: false, url: skillUrl))
            }
        }
        return skills
    }
    
    private func parseListOutput(_ output: String, isGlobal: Bool) -> [SkillInfo] {
        let lines = output.components(separatedBy: .newlines)
        var skills: [SkillInfo] = []
        var currentName: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Stronger exclusion for headers, tips, and ASCII art
            let low = trimmed.lowercased()
            if trimmed.isEmpty || 
               low.contains("global skills") || 
               low.contains("no project") ||
               low.contains("try listing") ||
               low.contains("skills.sh") ||
               low.contains("install with npx") ||
               trimmed.contains("█") ||
               trimmed.contains("╚") ||
               trimmed.contains("╔") ||
               trimmed.contains("║") ||
               trimmed.contains("╝") ||
               trimmed.contains("═") {
                continue
            }
            
            if line.hasPrefix("  ") {
                // This is likely a detail line (e.g., "Agents: ...")
                if let name = currentName, let index = skills.firstIndex(where: { $0.name == name }) {
                    let detail = trimmed
                    // If it's a path line, can be part of description or just skipped if redundant
                    if !detail.starts(with: "/") && !detail.starts(with: "~") {
                        let currentDesc = skills[index].description
                        let newDesc = currentDesc.isEmpty ? detail : "\(currentDesc) (\(detail))"
                        skills[index] = SkillInfo(name: name, description: newDesc, isInstalled: true, isGlobal: isGlobal)
                    }
                }
            } else {
                // Skill name line usually looks like: "name /path/to/skill" or just "name"
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let name = parts.first {
                    // Ignore lines starting with drawing characters
                    if !name.hasPrefix("└") && !name.hasPrefix("─") && !name.contains(":") && !name.hasPrefix("[") {
                        currentName = name
                        skills.append(SkillInfo(name: name, description: "", isInstalled: true, isGlobal: isGlobal))
                    }
                }
            }
        }
        return skills
    }
}
