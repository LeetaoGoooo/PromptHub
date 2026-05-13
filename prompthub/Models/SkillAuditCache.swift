import Foundation
import PromptHubSkillKit

// MARK: - Cached Audit Result

/// Persisted snapshot of a completed skill audit, stored as JSON in Application Support.
struct SkillAuditCache: Codable {
    var auditedAt: Date
    var skillCount: Int
    var visibilityMap: [String: [SkillAgentVisibility]]
    var integrityMap: [String: SkillSourceIntegrity]
    var structuralQualityMap: [String: SkillStructuralQualityReport]

    init(
        auditedAt: Date,
        skillCount: Int,
        visibilityMap: [String: [SkillAgentVisibility]],
        integrityMap: [String: SkillSourceIntegrity],
        structuralQualityMap: [String: SkillStructuralQualityReport]
    ) {
        self.auditedAt = auditedAt
        self.skillCount = skillCount
        self.visibilityMap = visibilityMap
        self.integrityMap = integrityMap
        self.structuralQualityMap = structuralQualityMap
    }

    private enum CodingKeys: String, CodingKey {
        case auditedAt
        case skillCount
        case visibilityMap
        case integrityMap
        case structuralQualityMap
        // Legacy key from before the P1.2 rename. Kept so caches written by
        // earlier app versions still decode after upgrade.
        case effectivenessMap
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        auditedAt = try container.decode(Date.self, forKey: .auditedAt)
        skillCount = try container.decode(Int.self, forKey: .skillCount)
        visibilityMap = try container.decode([String: [SkillAgentVisibility]].self, forKey: .visibilityMap)
        integrityMap = try container.decode([String: SkillSourceIntegrity].self, forKey: .integrityMap)
        if let modern = try container.decodeIfPresent([String: SkillStructuralQualityReport].self, forKey: .structuralQualityMap) {
            structuralQualityMap = modern
        } else if let legacy = try container.decodeIfPresent([String: SkillStructuralQualityReport].self, forKey: .effectivenessMap) {
            structuralQualityMap = legacy
        } else {
            structuralQualityMap = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(auditedAt, forKey: .auditedAt)
        try container.encode(skillCount, forKey: .skillCount)
        try container.encode(visibilityMap, forKey: .visibilityMap)
        try container.encode(integrityMap, forKey: .integrityMap)
        try container.encode(structuralQualityMap, forKey: .structuralQualityMap)
    }
}

// MARK: - Cache Store

enum SkillAuditCacheStore {

    private static var cacheURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent("PromptHub", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("skill_audit_cache.json")
    }

    static func load() -> SkillAuditCache? {
        guard let url = cacheURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SkillAuditCache.self, from: data)
    }

    static func save(_ cache: SkillAuditCache) {
        guard let url = cacheURL,
              let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func clear() {
        guard let url = cacheURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
