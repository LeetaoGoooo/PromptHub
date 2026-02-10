import Foundation
import SwiftData

@Model
final class Skill {
    var id: UUID = UUID()
    var name: String = ""
    var desc: String?
    var category: String = "General"
    var tags: [String] = []
    var identifier: String = "" // Reverse DNS style: com.user.skillName
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Core Configuration
    var outputSchema: String? // JSON Schema definition for the output
    var inputSchema: String?  // Expected input variables schema
    var safetyPolicy: String? 
    
    // Budget & Governance
    var budgetLimit: Double?
    var isVerified: Bool = false
    
    @Relationship(deleteRule: .cascade, inverse: \SkillVersion.skill)
    var versions: [SkillVersion]? = []
    
    init(name: String, desc: String? = nil, identifier: String = "") {
        self.name = name
        self.desc = desc
        self.identifier = identifier
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class SkillVersion {
    var id: UUID = UUID()
    var version: String = "1.0.0" 
    var instructions: String = "" 
    var changelog: String?
    var createdAt: Date = Date()
    
    // Test Cases as stored JSON strings for simulation
    var testCasesJSON: String?
    
    // Snapshot of configuration
    var schemaSnapshot: String? 
    var toolsConfig: [String] = [] 
    
    var parentSkillID: UUID?
    @Relationship var skill: Skill?
    
    init(version: String, instructions: String, skill: Skill? = nil) {
        self.version = version
        self.instructions = instructions
        self.skill = skill
        self.createdAt = Date()
    }
    
    // Helper to decode test cases
    var testCases: [[String: String]] {
        guard let data = testCasesJSON?.data(using: .utf8),
              let cases = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            return []
        }
        return cases
    }
    
    // MARK: - SKILL.md Conversion
    
    func toSkillMarkdown() -> String {
        var metadata: [String: Any] = [
            "name": skill?.name ?? "",
            "description": skill?.desc ?? "",
            "version": version,
            "category": skill?.category ?? "General",
            "identifier": skill?.identifier ?? ""
        ]
        
        if let outputSchema = skill?.outputSchema {
            metadata["outputSchema"] = outputSchema
        }
        
        return SkillParser.generate(metadata: metadata, instructions: instructions)
    }
    
    static func fromSkillMarkdown(_ markdown: String) -> SkillVersion? {
        guard let (metadata, instructions) = SkillParser.parse(markdown: markdown) else {
            return nil
        }
        
        let versionStr = (metadata["version"] as? String) ?? "1.0.0"
        let skillVersion = SkillVersion(version: versionStr, instructions: instructions)
        
        // Metadata also informs the parent Skill
        let name = (metadata["name"] as? String) ?? "Imported Skill"
        let desc = (metadata["description"] as? String)
        let identifier = (metadata["identifier"] as? String) ?? ""
        
        let skill = Skill(name: name, desc: desc, identifier: identifier)
        skill.category = (metadata["category"] as? String) ?? "General"
        skill.outputSchema = metadata["outputSchema"] as? String
        
        skillVersion.skill = skill
        return skillVersion
    }
}
