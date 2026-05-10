import Foundation
import PromptHubSkillKit

// MARK: - Audit & Update Operations

extension SkillCLIService {

    func checkAgentVisibility(skillName: String, isGlobal: Bool, projectRootURL: URL? = nil) async -> [SkillAgentVisibility] {
        await cliAccessManager.withAccess {
            await self.makeCatalog(projectRootURL: projectRootURL).checkAgentVisibility(skillName: skillName, isGlobal: isGlobal)
        }
    }

    func checkSourceIntegrity(skillName: String, isGlobal: Bool, projectRootURL: URL? = nil) async -> SkillSourceIntegrity {
        await cliAccessManager.withAccess {
            await self.makeCatalog(projectRootURL: projectRootURL).checkSourceIntegrity(skillName: skillName, isGlobal: isGlobal)
        }
    }

    func checkEffectiveness(skillName: String, isGlobal: Bool, projectRootURL: URL? = nil) async -> SkillEffectivenessReport {
        await cliAccessManager.withAccess {
            await self.makeCatalog(projectRootURL: projectRootURL).checkEffectiveness(skillName: skillName, isGlobal: isGlobal)
        }
    }

    func previewUpdate(skillName: String, isGlobal: Bool, projectRootURL: URL? = nil) async -> SkillUpdatePreview {
        await cliAccessManager.withAccess {
            await self.makeCatalog(projectRootURL: projectRootURL).previewUpdate(skillName: skillName, isGlobal: isGlobal)
        }
    }

    func applyUpdate(preview: SkillUpdatePreview, projectRootURL: URL? = nil) async throws {
        try await cliAccessManager.withAccess {
            try await self.makeCatalog(projectRootURL: projectRootURL).applyUpdate(preview: preview)
        }
    }

    @discardableResult
    func rollbackUpdate(preview: SkillUpdatePreview, projectRootURL: URL? = nil) async throws -> Int {
        try await cliAccessManager.withAccess {
            try await self.makeCatalog(projectRootURL: projectRootURL).rollbackUpdate(preview: preview)
        }
    }

    func hasRollbackBackup(skillName: String, isGlobal: Bool, projectRootURL: URL? = nil) async -> Bool {
        await cliAccessManager.withAccess {
            await self.makeCatalog(projectRootURL: projectRootURL).hasRollbackBackup(skillName: skillName, isGlobal: isGlobal)
        }
    }
}
