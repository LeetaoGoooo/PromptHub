import Foundation
import PromptHubSkillKit

struct SkillPackageReference: Hashable, Codable, Sendable {
    struct RemoteInstallDescriptor: Equatable, Sendable {
        let source: String
        let skillName: String
    }

    let rawValue: String
    let source: String?
    let skillName: String

    init(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rawValue = trimmed

        if let at = trimmed.lastIndex(of: "@"), at < trimmed.index(before: trimmed.endIndex) {
            let source = String(trimmed[..<at])
            let skillName = String(trimmed[trimmed.index(after: at)...])
            let parts = source.split(separator: "/", maxSplits: 1).map(String.init)

            if parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty, !skillName.isEmpty {
                self.source = source
                self.skillName = skillName
                return
            }
        }

        self.source = nil
        self.skillName = trimmed
    }

    var normalizedKey: String {
        if let source {
            return "\(source.lowercased())@\(skillName.lowercased())"
        }
        return skillName.lowercased()
    }

    var displayName: String {
        Self.humanize(skillName)
    }

    var displaySource: String? {
        guard let source, !source.isEmpty else {
            return nil
        }
        return source
    }

    var remoteInstallDescriptor: RemoteInstallDescriptor? {
        guard let source, !source.isEmpty, !skillName.isEmpty else {
            return nil
        }
        return RemoteInstallDescriptor(source: source, skillName: skillName)
    }

    private static func humanize(_ raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
            .split(separator: " ")
            .map { token in
                let word = String(token)
                guard let first = word.first else { return word }
                return first.uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}

struct CatalogSkill: Identifiable, Equatable, Sendable {
    let package: SkillPackageReference
    let summary: String
    let url: String?
    let installedHint: Bool
    let hintedScopes: [SkillInstallScope]
    let hintedAgents: [AgentWorkflow]
    let isManagedByPromptHub: Bool

    var id: String { package.normalizedKey }
    var displayName: String { package.displayName }
    var displaySource: String? { package.displaySource }
}

struct InstalledSkillSnapshot: Identifiable, Equatable, Sendable {
    let package: SkillPackageReference
    let packageName: String
    let summary: String
    let scope: SkillInstallScope
    let agents: [AgentWorkflow]
    let url: String?
    let isManagedByPromptHub: Bool
    let installedPaths: [String]
    let projectDisplayNames: [String]

    var id: String { "\(package.normalizedKey)-\(scope.rawValue)" }
    var isGlobal: Bool { scope == .global }
    var displayName: String { package.displayName }
    var displaySource: String? { package.displaySource }
}

enum InstalledSkillsLens: String, CaseIterable, Sendable {
    case activeProject = "Active Project"
    case allSavedProjects = "All Saved Projects"
}

struct CatalogSkillInstallationState: Equatable, Sendable {
    let isInstalled: Bool
    let scopes: [SkillInstallScope]
    let agents: [AgentWorkflow]
    let removableScopes: [SkillInstallScope]
    let agentsByScope: [SkillInstallScope: [AgentWorkflow]]

    static let notInstalled = CatalogSkillInstallationState(
        isInstalled: false,
        scopes: [],
        agents: [],
        removableScopes: [],
        agentsByScope: [:]
    )
}

struct SkillLibrarySummary: Equatable, Sendable {
    let authoredDraftCount: Int
    let catalogCount: Int
    let installedCount: Int
    let projectInstalledCount: Int
    let globalInstalledCount: Int

    static let empty = SkillLibrarySummary(
        authoredDraftCount: 0,
        catalogCount: 0,
        installedCount: 0,
        projectInstalledCount: 0,
        globalInstalledCount: 0
    )
}

struct SkillStoreWorkspaceSnapshot: Equatable, Sendable {
    let catalogSkills: [CatalogSkill]
    let installedSkills: [InstalledSkillSnapshot]
    let installationRegistry: [String: CatalogSkillInstallationState]
    let summary: SkillLibrarySummary

    static let empty = SkillStoreWorkspaceSnapshot(
        catalogSkills: [],
        installedSkills: [],
        installationRegistry: [:],
        summary: .empty
    )
}

struct InstalledSkillsWorkspaceSnapshot: Equatable, Sendable {
    let installedSkills: [InstalledSkillSnapshot]
    let projectSkills: [InstalledSkillSnapshot]
    let globalSkills: [InstalledSkillSnapshot]
    let summary: SkillLibrarySummary

    static let empty = InstalledSkillsWorkspaceSnapshot(
        installedSkills: [],
        projectSkills: [],
        globalSkills: [],
        summary: .empty
    )
}
