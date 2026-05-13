import Foundation
import PromptHubSkillKit

public enum PromptHubExportedAssetKind: String, Codable, Sendable {
    case prompt
    case skill

    public var displayName: String {
        switch self {
        case .prompt:
            return "prompt"
        case .skill:
            return "skill"
        }
    }
}

public enum PromptHubInstallScope: String, Codable, CaseIterable, Sendable {
    case global
    case project

    public var isGlobal: Bool {
        self == .global
    }
}

public enum InstalledSkillScopeFilter: Sendable {
    case all
    case global
    case project
}

public struct PromptHubExportedAsset: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: PromptHubExportedAssetKind
    public let name: String
    public let slug: String?
    public let installationName: String?
    public let summary: String?
    public let exportedAt: String?
    public let category: String?
    public let tags: [String]
    public let path: String
    public let packageDirectoryPath: String?
    public let markdown: String
    public let body: String
}

public struct PromptHubInstalledSkillSummary: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(package)-\(scope.rawValue)" }

    public let package: String
    public let description: String
    public let scope: PromptHubInstallScope
    public let agents: [String]
    public let isManagedByPromptHub: Bool
    public let url: String?
}

public enum PromptHubCLIError: LocalizedError, Equatable {
    case invalidMarkdown(String)
    case assetNotFound(kind: PromptHubExportedAssetKind, identifier: String)
    case ambiguousAsset(kind: PromptHubExportedAssetKind, identifier: String, matches: [String])
    case invalidRemoteSkillReference(String)

    public var errorDescription: String? {
        switch self {
        case .invalidMarkdown(let path):
            return "Unable to parse exported markdown at \(path)"
        case .assetNotFound(let kind, let identifier):
            return "No exported \(kind.displayName) matched '\(identifier)'"
        case .ambiguousAsset(let kind, let identifier, let matches):
            return "Multiple exported \(kind.displayName)s matched '\(identifier)': \(matches.joined(separator: ", "))"
        case .invalidRemoteSkillReference(let reference):
            return "Invalid skill reference '\(reference)'; expected owner/repo@skill-name"
        }
    }
}

public final class PromptHubCLIService {
    private let environment: PromptHubCLIEnvironment
    private let fileManager: FileManager
    private let session: URLSession

    public init(
        environment: PromptHubCLIEnvironment = .live(),
        fileManager: FileManager = .default,
        session: URLSession = .shared
    ) {
        self.environment = environment
        self.fileManager = fileManager
        self.session = session
    }

    public func listPrompts() throws -> [PromptHubExportedAsset] {
        try loadAssets(from: environment.promptsURL, kind: .prompt)
    }

    public func showPrompt(identifier: String) throws -> PromptHubExportedAsset {
        try resolveAsset(identifier: identifier, within: listPrompts(), kind: .prompt)
    }

    public func listExportedSkills() throws -> [PromptHubExportedAsset] {
        try loadAssets(from: environment.skillsURL, kind: .skill)
    }

    public func showExportedSkill(identifier: String) throws -> PromptHubExportedAsset {
        try resolveAsset(identifier: identifier, within: listExportedSkills(), kind: .skill)
    }

    public func listInstalledSkills(
        scopeFilter: InstalledSkillScopeFilter = .all,
        projectRootURL: URL? = nil
    ) async throws -> [PromptHubInstalledSkillSummary] {
        let catalog = environment.makeCatalog(session: session, fileManager: fileManager, projectRootURL: projectRootURL)
        let installed = try await catalog.listInstalledSkills()

        return installed
            .map { skill in
                PromptHubInstalledSkillSummary(
                    package: skill.name,
                    description: skill.description,
                    scope: skill.isGlobal ? .global : .project,
                    agents: skill.installedAgents.map(\.rawValue).sorted(),
                    isManagedByPromptHub: skill.isManagedByPromptHub,
                    url: skill.url
                )
            }
            .filter { summary in
                switch scopeFilter {
                case .all:
                    return true
                case .global:
                    return summary.scope == .global
                case .project:
                    return summary.scope == .project
                }
            }
            .sorted { lhs, rhs in
                if lhs.scope != rhs.scope {
                    return lhs.scope == .project
                }
                return lhs.package.localizedCaseInsensitiveCompare(rhs.package) == .orderedAscending
            }
    }

    @discardableResult
    public func installSkill(
        reference: String,
        scope: PromptHubInstallScope = .global,
        agents: [AgentWorkflow] = AgentWorkflow.defaultTargets,
        projectRootURL: URL? = nil
    ) async throws -> PromptHubInstalledSkillSummary {
        let catalog = environment.makeCatalog(session: session, fileManager: fileManager, projectRootURL: projectRootURL)
        let effectiveAgents = agents.isEmpty ? AgentWorkflow.defaultTargets : agents
        let trimmedReference = reference.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedReference.contains("/") || trimmedReference.contains("@") {
            guard let parsed = Self.parseRemoteSkillReference(trimmedReference) else {
                throw PromptHubCLIError.invalidRemoteSkillReference(trimmedReference)
            }

            try await catalog.install(
                request: SkillInstallRequest(
                    source: parsed.source,
                    skillNames: [parsed.skillName],
                    targetAgents: effectiveAgents,
                    isGlobal: scope.isGlobal
                )
            )
            return try await findInstalledSkillSummary(
                package: "\(parsed.source)@\(parsed.skillName)",
                scope: scope,
                projectRootURL: projectRootURL,
                fallbackDescription: ""
            )
        }

        let exportedSkill = try showExportedSkill(identifier: trimmedReference)
        let installName = exportedSkill.installationName ?? Self.sanitizeIdentifier(exportedSkill.name)
        try await catalog.installLocal(
            name: installName,
            markdown: exportedSkill.markdown,
            packageDirectoryURL: exportedSkill.packageDirectoryPath.map {
                URL(fileURLWithPath: $0, isDirectory: true)
            },
            isGlobal: scope.isGlobal,
            targetAgents: effectiveAgents
        )

        return try await findInstalledSkillSummary(
            package: installName,
            scope: scope,
            projectRootURL: projectRootURL,
            fallbackDescription: exportedSkill.summary ?? ""
        )
    }

    private func loadAssets(
        from directoryURL: URL,
        kind: PromptHubExportedAssetKind
    ) throws -> [PromptHubExportedAsset] {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return []
        }

        let files = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return files
            .filter { assetURL in
                switch kind {
                case .prompt:
                    return assetURL.pathExtension.lowercased() == "md"
                case .skill:
                    return isExportedSkillFile(assetURL) || isExportedSkillPackageDirectory(assetURL)
                }
            }
            .compactMap { assetURL in
                do {
                    return try parseAsset(from: assetURL, kind: kind)
                } catch PromptHubCLIError.invalidMarkdown {
                    fputs("warning: skipping malformed exported \(kind.displayName) at \(assetURL.path)\n", stderr)
                    return nil
                } catch {
                    fputs("warning: skipping unreadable exported \(kind.displayName) at \(assetURL.path): \(error.localizedDescription)\n", stderr)
                    return nil
                }
            }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private func parseAsset(
        from assetURL: URL,
        kind: PromptHubExportedAssetKind
    ) throws -> PromptHubExportedAsset {
        let isDirectory = (try? assetURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let markdownURL = isDirectory ? assetURL.appendingPathComponent("SKILL.md") : assetURL
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        guard let parsed = SkillMarkdownDocument.parse(markdown: markdown) else {
            throw PromptHubCLIError.invalidMarkdown(markdownURL.path)
        }

        let metadata = parsed.metadata
        let fileStem = isDirectory ? assetURL.lastPathComponent : assetURL.deletingPathExtension().lastPathComponent
        let name = SkillMarkdownDocument.stringValue(for: "name", in: metadata) ?? fileStem
        let slug = SkillMarkdownDocument.stringValue(for: "slug", in: metadata)
        let id = SkillMarkdownDocument.stringValue(for: "id", in: metadata) ?? fileStem
        let installationName = kind == .skill ? (slug ?? Self.sanitizeIdentifier(name)) : nil

        return PromptHubExportedAsset(
            id: id,
            kind: kind,
            name: name,
            slug: slug,
            installationName: installationName,
            summary: SkillMarkdownDocument.stringValue(for: "description", in: metadata),
            exportedAt: SkillMarkdownDocument.stringValue(for: "exported_at", in: metadata),
            category: SkillMarkdownDocument.stringValue(for: "category", in: metadata),
            tags: SkillMarkdownDocument.stringArrayValue(for: "tags", in: metadata),
            path: assetURL.path,
            packageDirectoryPath: isDirectory ? assetURL.path : nil,
            markdown: markdown,
            body: parsed.instructions
        )
    }

    private func isExportedSkillFile(_ assetURL: URL) -> Bool {
        assetURL.pathExtension.lowercased() == "md"
    }

    private func isExportedSkillPackageDirectory(_ assetURL: URL) -> Bool {
        let isDirectory = (try? assetURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        guard isDirectory else {
            return false
        }
        return fileManager.fileExists(atPath: assetURL.appendingPathComponent("SKILL.md").path)
    }

    private func resolveAsset(
        identifier: String,
        within assets: [PromptHubExportedAsset],
        kind: PromptHubExportedAssetKind
    ) throws -> PromptHubExportedAsset {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        let exactMatches = assets.filter { asset in
            asset.id.lowercased() == lowercased
                || asset.slug?.lowercased() == lowercased
                || asset.installationName?.lowercased() == lowercased
                || asset.name.lowercased() == lowercased
        }

        if !exactMatches.isEmpty {
            return try Self.uniqueMatch(from: exactMatches, kind: kind, identifier: trimmed)
        }

        let prefixMatches = assets.filter { asset in
            asset.id.lowercased().hasPrefix(lowercased)
                || (asset.slug?.lowercased().hasPrefix(lowercased) ?? false)
                || (asset.installationName?.lowercased().hasPrefix(lowercased) ?? false)
        }

        if !prefixMatches.isEmpty {
            return try Self.uniqueMatch(from: prefixMatches, kind: kind, identifier: trimmed)
        }

        throw PromptHubCLIError.assetNotFound(kind: kind, identifier: trimmed)
    }

    private func findInstalledSkillSummary(
        package: String,
        scope: PromptHubInstallScope,
        projectRootURL: URL?,
        fallbackDescription: String
    ) async throws -> PromptHubInstalledSkillSummary {
        let installed = try await listInstalledSkills(scopeFilter: scope == .global ? .global : .project, projectRootURL: projectRootURL)
        if let match = installed.first(where: { $0.package == package && $0.scope == scope }) {
            return match
        }

        return PromptHubInstalledSkillSummary(
            package: package,
            description: fallbackDescription,
            scope: scope,
            agents: [],
            isManagedByPromptHub: true,
            url: nil
        )
    }

    private static func uniqueMatch(
        from matches: [PromptHubExportedAsset],
        kind: PromptHubExportedAssetKind,
        identifier: String
    ) throws -> PromptHubExportedAsset {
        if matches.count == 1 {
            return matches[0]
        }

        let names = matches.map { $0.installationName ?? $0.slug ?? $0.name }.sorted()
        throw PromptHubCLIError.ambiguousAsset(kind: kind, identifier: identifier, matches: names)
    }

    private static func parseRemoteSkillReference(_ reference: String) -> (source: String, skillName: String)? {
        let trimmed = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let atIndex = trimmed.lastIndex(of: "@") else {
            return nil
        }

        let source = String(trimmed[..<atIndex])
        let skillName = String(trimmed[trimmed.index(after: atIndex)...])
        let sourceParts = source.split(separator: "/")

        guard sourceParts.count == 2, !skillName.isEmpty else {
            return nil
        }

        return (source: source, skillName: skillName)
    }

    private static func sanitizeIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}