import Foundation
import Testing
@testable import prompthub
import PromptHubSkillKit

// MARK: - SkillAuditCache decode compatibility (P1.2)
//
// The on-disk JSON format used the legacy key `effectivenessMap`. After the
// P1.2 rename, the in-memory model exposes `structuralQualityMap`. To avoid
// invalidating users' caches across upgrade, the decoder must still accept
// the legacy key. These tests pin that contract.

struct SkillAuditCacheCompatibilityTests {

    @Test func decodesLegacyEffectivenessMapKey() throws {
        let auditedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let auditedAtString = isoFormatter.string(from: auditedAt)

        let legacyJSON = """
        {
          "auditedAt": "\(auditedAtString)",
          "skillCount": 1,
          "visibilityMap": {},
          "integrityMap": {},
          "effectivenessMap": {
            "skill-id": {
              "checks": [],
              "score": 1.0,
              "tier": "excellent",
              "fileFound": true
            }
          }
        }
        """

        let data = Data(legacyJSON.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withFractionalSeconds

        let cache = try decoder.decode(SkillAuditCache.self, from: data)

        #expect(cache.skillCount == 1)
        #expect(cache.structuralQualityMap.count == 1)
        let report = try #require(cache.structuralQualityMap["skill-id"])
        #expect(report.score == 1.0)
        #expect(report.tier == .excellent)
        #expect(report.fileFound == true)
    }

    @Test func decodesNewStructuralQualityMapKey() throws {
        let auditedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let auditedAtString = isoFormatter.string(from: auditedAt)

        let newJSON = """
        {
          "auditedAt": "\(auditedAtString)",
          "skillCount": 0,
          "visibilityMap": {},
          "integrityMap": {},
          "structuralQualityMap": {
            "skill-id": {
              "checks": [],
              "score": 0.5,
              "tier": "fair",
              "fileFound": true
            }
          }
        }
        """

        let data = Data(newJSON.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withFractionalSeconds

        let cache = try decoder.decode(SkillAuditCache.self, from: data)
        #expect(cache.structuralQualityMap["skill-id"]?.tier == .fair)
    }

    @Test func modernKeyWinsWhenBothPresent() throws {
        let auditedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let auditedAtString = isoFormatter.string(from: auditedAt)

        let dualJSON = """
        {
          "auditedAt": "\(auditedAtString)",
          "skillCount": 0,
          "visibilityMap": {},
          "integrityMap": {},
          "structuralQualityMap": {
            "skill-id": {
              "checks": [],
              "score": 0.9,
              "tier": "excellent",
              "fileFound": true
            }
          },
          "effectivenessMap": {
            "skill-id": {
              "checks": [],
              "score": 0.1,
              "tier": "poor",
              "fileFound": true
            }
          }
        }
        """

        let data = Data(dualJSON.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withFractionalSeconds

        let cache = try decoder.decode(SkillAuditCache.self, from: data)
        let report = try #require(cache.structuralQualityMap["skill-id"])
        // Modern key must win to avoid silently regressing to the legacy snapshot.
        #expect(report.tier == .excellent)
        #expect(report.score == 0.9)
    }

    @Test func roundTripUsesNewKey() throws {
        let report = SkillStructuralQualityReport(
            checks: [],
            score: 0.0,
            tier: .poor,
            fileFound: false
        )
        let cache = SkillAuditCache(
            auditedAt: Date(timeIntervalSince1970: 0),
            skillCount: 1,
            visibilityMap: [:],
            integrityMap: [:],
            structuralQualityMap: ["x": report]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cache)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("structuralQualityMap"))
        #expect(json.contains("effectivenessMap") == false)
    }
}

private extension JSONDecoder.DateDecodingStrategy {
    static var iso8601withFractionalSeconds: JSONDecoder.DateDecodingStrategy {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = formatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date: \(string)"
            )
        }
    }
}
