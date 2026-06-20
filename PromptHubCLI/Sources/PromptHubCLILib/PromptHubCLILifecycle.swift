import Foundation
import PromptHubSkillKit

public struct PromptHubAgentActionResult: Codable, Equatable, Sendable {
    public let agent: String
    public let succeeded: Bool
    public let error: String?

    public init(agent: String, succeeded: Bool, error: String? = nil) {
        self.agent = agent
        self.succeeded = succeeded
        self.error = error
    }
}

public struct PromptHubLifecycleResult: Codable, Equatable, Sendable {
    public let package: String
    public let scope: PromptHubInstallScope
    public let agents: [PromptHubAgentActionResult]
    public let removedPaths: [String]

    public var partialFailure: Bool {
        agents.contains(where: { !$0.succeeded }) && agents.contains(where: { $0.succeeded })
    }

    public var allFailed: Bool {
        !agents.isEmpty && agents.allSatisfy { !$0.succeeded }
    }

    public init(
        package: String,
        scope: PromptHubInstallScope,
        agents: [PromptHubAgentActionResult],
        removedPaths: [String]
    ) {
        self.package = package
        self.scope = scope
        self.agents = agents
        self.removedPaths = removedPaths
    }
}

public enum PromptHubUpdateStatus: String, Codable, Sendable {
    case upToDate
    case updated
    case noRemoteSource
    case remoteUnavailable
    case notInstalled
}

public struct PromptHubUpdateResult: Codable, Equatable, Sendable {
    public let package: String
    public let scope: PromptHubInstallScope
    public let status: PromptHubUpdateStatus
    public let appliedPaths: [String]

    public init(
        package: String,
        scope: PromptHubInstallScope,
        status: PromptHubUpdateStatus,
        appliedPaths: [String]
    ) {
        self.package = package
        self.scope = scope
        self.status = status
        self.appliedPaths = appliedPaths
    }
}

public struct PromptHubWhereLocation: Codable, Equatable, Sendable {
    public let package: String
    public let scope: PromptHubInstallScope
    public let agent: String
    public let path: String
    public let isManagedByPromptHub: Bool

    public init(
        package: String,
        scope: PromptHubInstallScope,
        agent: String,
        path: String,
        isManagedByPromptHub: Bool
    ) {
        self.package = package
        self.scope = scope
        self.agent = agent
        self.path = path
        self.isManagedByPromptHub = isManagedByPromptHub
    }
}

extension PromptHubCLIService {
    /// Uninstall a managed PromptHub install across the chosen scope and agents.
    /// Refuses to delete files that were not installed by PromptHub unless `force: true`,
    /// so users do not lose hand-authored skill files in agent directories by mistake.
    @discardableResult
    public func uninstallSkill(
        package: String,
        scope: PromptHubInstallScope,
        agents: [AgentWorkflow] = [],
        projectRootURL: URL? = nil,
        force: Bool = false
    ) async throws -> PromptHubLifecycleResult {
        let trimmed = package.trimmingCharacters(in: .whitespacesAndNewlines)

        // First check if the catalog knows about a managed install for this package/scope.
        let managed = try? await inspectInstalledSkill(package: trimmed, scope: scope, projectRootURL: projectRootURL)
        let snapshot = managed?.first

        let isManaged = snapshot?.isManagedByPromptHub ?? false
        let candidatePaths: [String]
        let candidateAgents: [AgentWorkflow]

        if let snapshot {
            candidatePaths = snapshot.installedPaths
            candidateAgents = snapshot.agents.compactMap { AgentWorkflow(rawValue: $0) }
        } else {
            // No catalog record at all. Probe agent skill roots directly so unmanaged hand-authored
            // files can either be refused (default) or removed (--force) without silently no-oping.
            let direct = scanAgentDirectoriesForPackage(
                package: trimmed,
                scope: scope,
                projectRootURL: projectRootURL
            )
            if direct.isEmpty {
                throw PromptHubCLIError.installedSkillNotFound(package: trimmed)
            }
            candidatePaths = direct.map(\.path)
            candidateAgents = direct.map(\.agent)
        }

        if !isManaged && !force {
            throw PromptHubCLIError.unmanagedSkill(package: trimmed)
        }

        let catalog = environment.makeCatalog(fileManager: .default, projectRootURL: projectRootURL)
        let effectiveAgents = resolveAgents(agents, defaulting: candidateAgents)

        var results: [PromptHubAgentActionResult] = []
        for agent in effectiveAgents {
            do {
                try await catalog.remove(name: trimmed, isGlobal: scope.isGlobal, targetAgents: [agent])
                results.append(.init(agent: agent.rawValue, succeeded: true))
            } catch {
                results.append(.init(agent: agent.rawValue, succeeded: false, error: error.localizedDescription))
            }
        }

        return PromptHubLifecycleResult(
            package: trimmed,
            scope: scope,
            agents: results.sorted(by: { $0.agent < $1.agent }),
            removedPaths: candidatePaths
        )
    }

    private struct AgentDirectoryHit {
        let agent: AgentWorkflow
        let path: String
    }

    private func scanAgentDirectoriesForPackage(
        package: String,
        scope: PromptHubInstallScope,
        projectRootURL: URL?
    ) -> [AgentDirectoryHit] {
        let agentRoots = environment.agentSkillRoots
            ?? PromptHubCLIEnvironment.defaultAgentSkillRoots(
                homeDirectoryURL: environment.homeDirectoryURL,
                projectRootURL: projectRootURL
                    ?? environment.projectRootURL
                    ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            )

        var hits: [AgentDirectoryHit] = []
        for (workflow, roots) in agentRoots {
            let root = scope == .global ? roots.global : roots.project
            let candidate = root.appendingPathComponent(package, isDirectory: true)
            let skillFile = candidate.appendingPathComponent("SKILL.md")
            if FileManager.default.fileExists(atPath: skillFile.path) {
                hits.append(AgentDirectoryHit(agent: workflow, path: candidate.path))
            }
        }
        return hits
    }

    /// Pull the latest remote content for a previously-installed skill and apply it.
    /// Status is reported back so callers can branch on `upToDate` / `updated` / failure modes
    /// without parsing error strings. Local-only installs surface as `noRemoteSource`.
    public func updateSkill(
        package: String,
        scope: PromptHubInstallScope,
        projectRootURL: URL? = nil
    ) async throws -> PromptHubUpdateResult {
        let trimmed = package.trimmingCharacters(in: .whitespacesAndNewlines)
        let catalog = environment.makeCatalog(fileManager: .default, projectRootURL: projectRootURL)
        let preview = await catalog.previewUpdate(skillName: trimmed, isGlobal: scope.isGlobal)
        let status = Self.mapUpdateStatus(preview.status)
        var applied = preview.localPaths

        if preview.status == .updateAvailable {
            try await catalog.applyUpdate(preview: preview)
        } else {
            applied = []
        }

        return PromptHubUpdateResult(
            package: trimmed,
            scope: scope,
            status: status,
            appliedPaths: applied
        )
    }

    /// Re-run the original install for a previously-installed skill.
    /// Routes by package shape: `owner/repo@skill` triggers the remote install path,
    /// any other package name resolves against the exported PromptHub assets.
    /// Throws `noKnownInstallSource` when neither path is available.
    @discardableResult
    public func reinstallSkill(
        package: String,
        scope: PromptHubInstallScope,
        agents: [AgentWorkflow] = AgentWorkflow.defaultTargets,
        projectRootURL: URL? = nil
    ) async throws -> PromptHubInstalledSkillSummary {
        let trimmed = package.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remote-shape package name uses the existing installSkill code path verbatim.
        if trimmed.contains("/") && trimmed.contains("@") {
            return try await installSkill(
                reference: trimmed,
                scope: scope,
                agents: agents,
                projectRootURL: projectRootURL
            )
        }

        // Local-shape: confirm an exported PromptHub asset exists before promising the user a reinstall.
        do {
            _ = try showExportedSkill(identifier: trimmed)
        } catch PromptHubCLIError.assetNotFound {
            throw PromptHubCLIError.noKnownInstallSource(package: trimmed)
        }

        return try await installSkill(
            reference: trimmed,
            scope: scope,
            agents: agents,
            projectRootURL: projectRootURL
        )
    }

    /// One row per (agent, on-disk path) for a previously-installed skill, intended
    /// for piping into shell tooling like `cd "$(ph skill where … | head -1 | awk …)"`.
    /// Surfaces `isManagedByPromptHub` so wrappers can refuse to mutate hand-authored files.
    public func whereSkill(
        package: String,
        scope: PromptHubInstallScope? = nil,
        projectRootURL: URL? = nil
    ) async throws -> [PromptHubWhereLocation] {
        let trimmed = package.trimmingCharacters(in: .whitespacesAndNewlines)
        let snapshots = try await inspectInstalledSkill(package: trimmed, scope: scope, projectRootURL: projectRootURL)
        let agentRoots = environment.agentSkillRoots
            ?? PromptHubCLIEnvironment.defaultAgentSkillRoots(
                homeDirectoryURL: environment.homeDirectoryURL,
                projectRootURL: projectRootURL
                    ?? environment.projectRootURL
                    ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            )

        var rows: [PromptHubWhereLocation] = []
        for snapshot in snapshots {
            for path in snapshot.installedPaths {
                let agent = Self.matchAgent(forPath: path, scope: snapshot.scope, agentRoots: agentRoots)
                rows.append(PromptHubWhereLocation(
                    package: snapshot.package,
                    scope: snapshot.scope,
                    agent: agent ?? "unknown",
                    path: path,
                    isManagedByPromptHub: snapshot.isManagedByPromptHub
                ))
            }
        }
        return rows.sorted { ($0.scope.rawValue, $0.agent, $0.path) < ($1.scope.rawValue, $1.agent, $1.path) }
    }

    // MARK: - Helpers

    private func resolveAgents(_ requested: [AgentWorkflow], defaulting fallback: [AgentWorkflow]) -> [AgentWorkflow] {
        if !requested.isEmpty { return requested }
        if !fallback.isEmpty { return fallback }
        return AgentWorkflow.defaultTargets
    }

    private static func mapUpdateStatus(_ status: SkillUpdateStatus) -> PromptHubUpdateStatus {
        switch status {
        case .upToDate: return .upToDate
        case .updateAvailable: return .updated
        case .notInstalled: return .notInstalled
        case .noRemoteSource: return .noRemoteSource
        case .remoteUnavailable: return .remoteUnavailable
        }
    }

    private static func matchAgent(
        forPath path: String,
        scope: PromptHubInstallScope,
        agentRoots: [AgentWorkflow: AgentSkillRoots]
    ) -> String? {
        // 1) Direct external agent directory prefix match.
        for (workflow, roots) in agentRoots {
            let candidate = scope == .global ? roots.global : roots.project
            let prefix = candidate.standardizedFileURL.path
            if path.hasPrefix(prefix) || path.hasPrefix("/private" + prefix) {
                return workflow.rawValue
            }
        }
        // 2) Catalog-managed path lives under `<installRoot>/<scope>/<agent>/<package>`.
        // Pick whichever AgentWorkflow rawValue appears as a path segment.
        let segments = path.split(separator: "/")
        for segment in segments {
            if let workflow = AgentWorkflow(rawValue: String(segment)) {
                return workflow.rawValue
            }
        }
        return nil
    }
}


