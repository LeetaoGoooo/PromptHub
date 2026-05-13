import Foundation
import PromptHubSkillKit

// MARK: - Installation Operations

extension SkillCLIService {

    func addSkill(package: String, isGlobal: Bool = true, targetAgents: [AgentWorkflow] = AgentWorkflow.defaultTargets, projectRootURL: URL? = nil) async throws {
        do {
            guard let parsed = SkillPackageReference(rawValue: package).remoteInstallDescriptor else {
                throw CLIError.invalidSkillPackage
            }
            let request = SkillInstallRequest(source: parsed.source, skillNames: [parsed.skillName], targetAgents: targetAgents, isGlobal: isGlobal)
            try await cliAccessManager.withAccess { try await self.makeCatalog(projectRootURL: projectRootURL).install(request: request) }
        } catch { throw mapError(error) }
    }

    func addSkills(source: String, skillNames: [String], targetAgents: [AgentWorkflow] = AgentWorkflow.defaultTargets, isGlobal: Bool = true, projectRootURL: URL? = nil) async throws {
        do {
            let request = SkillInstallRequest(source: source, skillNames: skillNames, targetAgents: targetAgents, isGlobal: isGlobal)
            try await cliAccessManager.withAccess { try await self.makeCatalog(projectRootURL: projectRootURL).install(request: request) }
        } catch { throw mapError(error) }
    }

    func addLocalSkill(name: String, markdown: String, packageDirectoryURL: URL? = nil, isGlobal: Bool = true, targetAgents: [AgentWorkflow] = AgentWorkflow.defaultTargets, projectRootURL: URL? = nil) async throws {
        do {
            try await cliAccessManager.withAccess {
                try await self.makeCatalog(projectRootURL: projectRootURL).installLocal(name: name, markdown: markdown, packageDirectoryURL: packageDirectoryURL, isGlobal: isGlobal, targetAgents: targetAgents)
            }
        } catch { throw mapError(error) }
    }

    func addInstalledSkill(name: String, isGlobal: Bool = true, targetAgents: [AgentWorkflow] = AgentWorkflow.defaultTargets, projectRootURL: URL? = nil) async throws {
        do {
            try await cliAccessManager.withAccess {
                try await self.makeCatalog(projectRootURL: projectRootURL).installExisting(name: name, isGlobal: isGlobal, targetAgents: targetAgents)
            }
        } catch { throw mapError(error) }
    }

    func removeSkill(name: String, isGlobal: Bool = true, targetAgents: [AgentWorkflow]? = nil, projectRootURL: URL? = nil) async throws {
        do {
            try await cliAccessManager.withAccess {
                try await self.makeCatalog(projectRootURL: projectRootURL).remove(name: name, isGlobal: isGlobal, targetAgents: targetAgents)
            }
        } catch { throw mapError(error) }
    }

    func loadInstalledMarkdown(name: String, isGlobal: Bool = true, projectRootURL: URL? = nil) async throws -> String? {
        do {
            return try await cliAccessManager.withAccess {
                try await self.makeCatalog(projectRootURL: projectRootURL).loadInstalledMarkdown(name: name, isGlobal: isGlobal)
            }
        } catch { throw mapError(error) }
    }

    // MARK: - Private Sources

    func installFromPrivateSource(source: PrivateSkillSource, skillNames: [String], isGlobal: Bool = true, targetAgents: [AgentWorkflow] = AgentWorkflow.defaultTargets, projectRootURL: URL? = nil) async throws {
        switch source.type {
        case .githubPrivate:
            guard let ownerRepo = source.githubOwnerRepo else { throw CLIError.invalidSkillPackage }
            let token = PrivateSkillSourceStore.shared.loadToken(for: source.id)
            let catalog = cliAccessManager.makeCatalog(session: session, fileManager: fileManager, apiBaseURL: apiBaseURL, installRootURL: installRootURL, projectRootURL: projectRootURL, githubToken: token)
            let request = SkillInstallRequest(source: "\(ownerRepo.owner)/\(ownerRepo.repo)", skillNames: skillNames, targetAgents: targetAgents, isGlobal: isGlobal)
            do { try await cliAccessManager.withAccess { try await catalog.install(request: request) } }
            catch { throw mapError(error) }

        case .localShared:
            let sharedRoot = URL(fileURLWithPath: source.location, isDirectory: true)
            for skillName in skillNames {
                let packageDirectoryURL = sharedRoot.appendingPathComponent(skillName, isDirectory: true)
                let skillFile = packageDirectoryURL.appendingPathComponent("SKILL.md")
                guard let markdown = try? String(contentsOf: skillFile, encoding: .utf8), !markdown.isEmpty else {
                    throw CLIError.fileIOError("SKILL.md not found at \(skillFile.path)")
                }
                do {
                    try await cliAccessManager.withAccess {
                        try await self.makeCatalog(projectRootURL: projectRootURL).installLocal(name: skillName, markdown: markdown, packageDirectoryURL: packageDirectoryURL, isGlobal: isGlobal, targetAgents: targetAgents)
                    }
                } catch { throw mapError(error) }
            }
        }
    }

    func listSkillsInSharedPath(_ path: String) -> [String] {
        let root = URL(fileURLWithPath: path, isDirectory: true)
        guard let children = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
        return children
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("SKILL.md").path) }
            .map { $0.lastPathComponent }
            .sorted()
    }
}
