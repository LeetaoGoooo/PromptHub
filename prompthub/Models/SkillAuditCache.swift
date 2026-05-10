import Foundation
import PromptHubSkillKit

// MARK: - Cached Audit Result

/// Persisted snapshot of a completed skill audit, stored as JSON in Application Support.
struct SkillAuditCache: Codable {
    var auditedAt: Date
    var skillCount: Int
    var visibilityMap: [String: [SkillAgentVisibility]]
    var integrityMap: [String: SkillSourceIntegrity]
    var effectivenessMap: [String: SkillEffectivenessReport]
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
