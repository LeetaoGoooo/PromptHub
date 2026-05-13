import CryptoKit
import Foundation

public enum SkillKitError: LocalizedError, Equatable, Sendable {
    case invalidResponse
    case invalidSkillPackage
    case networkError(String)
    case fileIOError(String)
    case requestFailed(code: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unexpected response from skills API"
        case .invalidSkillPackage:
            return "Invalid skill package, expected owner/repo@skill-name"
        case .networkError(let message):
            return message.isEmpty ? "Network request failed" : message
        case .fileIOError(let message):
            return message.isEmpty ? "Failed to read or write skill files" : message
        case .requestFailed(let code, let message):
            return "skills-api \(code): \(message)"
        }
    }
}

public enum AgentWorkflow: String, Codable, CaseIterable, Sendable {
    case codex
    case claudeCode = "claude-code"
    case cursor
    case geminiCLI = "gemini-cli"
    case iflow
    case opencode
    case qwenCode = "qwen-code"
    case qoder

    public var displayName: String {
        switch self {
        case .codex:
            return "Codex"
        case .claudeCode:
            return "Claude Code"
        case .cursor:
            return "Cursor"
        case .geminiCLI:
            return "Gemini CLI"
        case .iflow:
            return "iFlow CLI"
        case .opencode:
            return "OpenCode"
        case .qwenCode:
            return "Qwen Code"
        case .qoder:
            return "Qoder"
        }
    }

    public static let defaultTargets: [AgentWorkflow] = [
        .codex,
        .claudeCode,
        .cursor,
        .geminiCLI,
        .iflow,
        .opencode,
        .qwenCode,
        .qoder
    ]
}

public enum SkillInstallScope: String, Codable, CaseIterable, Sendable {
    case project
    case global

    public var displayName: String {
        switch self {
        case .project:
            return "Project"
        case .global:
            return "Global"
        }
    }
}

public struct SkillInfo: Codable, Identifiable, Equatable, Sendable {
    public var id: String { "\(name)-\(isGlobal)" }
    public let name: String
    public let description: String
    public var isInstalled: Bool
    public var isGlobal: Bool
    public var url: String?
    public var installedAgents: [AgentWorkflow]
    public var installedScopes: [SkillInstallScope]
    public var isManagedByPromptHub: Bool
    public var installedPaths: [String]

    public init(
        name: String,
        description: String,
        isInstalled: Bool = false,
        isGlobal: Bool = false,
        url: String? = nil,
        installedAgents: [AgentWorkflow] = [],
        installedScopes: [SkillInstallScope] = [],
        isManagedByPromptHub: Bool = true,
        installedPaths: [String] = []
    ) {
        self.name = name
        self.description = description
        self.isInstalled = isInstalled
        self.isGlobal = isGlobal
        self.url = url
        self.installedAgents = installedAgents
        self.installedScopes = installedScopes
        self.isManagedByPromptHub = isManagedByPromptHub
        self.installedPaths = installedPaths
    }
}

public struct SkillInstallRequest: Sendable {
    public let source: String
    public let skillNames: [String]
    public let targetAgents: [AgentWorkflow]
    public let isGlobal: Bool

    public init(
        source: String,
        skillNames: [String],
        targetAgents: [AgentWorkflow] = AgentWorkflow.defaultTargets,
        isGlobal: Bool = true
    ) {
        self.source = source
        self.skillNames = skillNames
        self.targetAgents = targetAgents
        self.isGlobal = isGlobal
    }
}

/// The visibility status of a skill for a specific agent, determined by filesystem scan.
public enum AgentVisibilityStatus: String, Codable, Sendable, Equatable, CaseIterable {
    /// SKILL.md file was found in the agent's expected read directory.
    case visible
    /// The agent directory exists but SKILL.md is not present (e.g. missing symlink).
    case missing
    /// The agent's root directory is not configured or does not exist on disk.
    case unknownPath
}

/// A single agent's filesystem visibility result for a skill.
public struct SkillAgentVisibility: Codable, Sendable, Equatable {
    public let agent: AgentWorkflow
    public let status: AgentVisibilityStatus
    /// The absolute path that was checked (nil when status is unknownPath).
    public let checkedPath: String?
    public let isGlobal: Bool

    public init(
        agent: AgentWorkflow,
        status: AgentVisibilityStatus,
        checkedPath: String?,
        isGlobal: Bool
    ) {
        self.agent = agent
        self.status = status
        self.checkedPath = checkedPath
        self.isGlobal = isGlobal
    }
}

/// The result of comparing a locally installed SKILL.md against its remote source.
public enum SkillSourceIntegrityStatus: String, Codable, Sendable, Equatable {
    /// Local content matches the remote source exactly.
    case verified
    /// Local content differs from the current remote version.
    case modified
    /// Remote content could not be fetched (offline or network error).
    case remoteUnavailable
    /// Skill has no resolvable remote source (e.g. authored locally).
    case noRemoteSource
    /// Local SKILL.md could not be found on disk.
    case notInstalled
}

/// The result of a source integrity check for a single installed skill.
public struct SkillSourceIntegrity: Codable, Sendable, Equatable {
    /// Hex-encoded SHA-256 of the local SKILL.md, or nil if not installed.
    public let localHash: String?
    /// Hex-encoded SHA-256 of the remote SKILL.md, or nil if unavailable.
    public let remoteHash: String?
    public let status: SkillSourceIntegrityStatus
    /// The raw content URL that was fetched for comparison.
    public let remoteURL: String?
    /// The local file path that was read.
    public let localPath: String?
    public let checkedAt: Date

    public init(
        localHash: String?,
        remoteHash: String?,
        status: SkillSourceIntegrityStatus,
        remoteURL: String?,
        localPath: String?,
        checkedAt: Date = Date()
    ) {
        self.localHash = localHash
        self.remoteHash = remoteHash
        self.status = status
        self.remoteURL = remoteURL
        self.localPath = localPath
        self.checkedAt = checkedAt
    }
}

// MARK: - Skill Structural Quality
//
// These types describe the *structural* health of a SKILL.md file: presence of
// frontmatter, a usage section, examples, and similar textual signals. They
// are part of PromptHub's audit layer and intentionally do NOT measure
// behavioral correctness. Behavioral evaluation lives in a separate layer
// (see plans/skill-eval-final-plan.md).
//
// Backwards compatibility: the legacy `SkillEffectiveness*` and
// `EffectivenessTier` names are kept as deprecated typealiases so existing
// app-side callers still compile while they migrate.

/// A single structural check on a SKILL.md file.
public struct SkillStructuralQualityCheck: Codable, Sendable, Equatable {
    /// Human-readable title, e.g. "Has frontmatter description".
    public let title: String
    /// Short explanation of why this check matters.
    public let rationale: String
    /// Whether the check passed.
    public let passed: Bool
    /// Optional hint shown when the check fails.
    public let hint: String?

    public init(title: String, rationale: String, passed: Bool, hint: String?) {
        self.title = title
        self.rationale = rationale
        self.passed = passed
        self.hint = hint
    }
}

/// Structural quality tier derived from the overall score.
public enum StructuralQualityTier: String, Codable, Sendable, Equatable {
    /// 80–100 % of checks pass.
    case excellent
    /// 60–79 % of checks pass.
    case good
    /// 40–59 % of checks pass.
    case fair
    /// < 40 % of checks pass.
    case poor

    public var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }

    public var systemImage: String {
        switch self {
        case .excellent: return "checkmark.seal.fill"
        case .good: return "star.fill"
        case .fair: return "exclamationmark.circle.fill"
        case .poor: return "xmark.circle.fill"
        }
    }
}

/// Aggregate structural-quality report for an installed SKILL.md.
public struct SkillStructuralQualityReport: Codable, Sendable, Equatable {
    public let checks: [SkillStructuralQualityCheck]
    /// 0.0 … 1.0
    public let score: Double
    public let tier: StructuralQualityTier
    /// Whether the SKILL.md file was found at all.
    public let fileFound: Bool

    public init(checks: [SkillStructuralQualityCheck], score: Double, tier: StructuralQualityTier, fileFound: Bool) {
        self.checks = checks
        self.score = score
        self.tier = tier
        self.fileFound = fileFound
    }

    public static let notFound = SkillStructuralQualityReport(
        checks: [],
        score: 0,
        tier: .poor,
        fileFound: false
    )
}

// MARK: - Deprecated Effectiveness aliases

@available(*, deprecated, renamed: "SkillStructuralQualityCheck")
public typealias SkillEffectivenessCheck = SkillStructuralQualityCheck

@available(*, deprecated, renamed: "StructuralQualityTier")
public typealias EffectivenessTier = StructuralQualityTier

@available(*, deprecated, renamed: "SkillStructuralQualityReport")
public typealias SkillEffectivenessReport = SkillStructuralQualityReport

// MARK: - Skill Update / Rollback

/// A single line in a diff between two SKILL.md versions.
public enum SkillDiffLine: Sendable, Equatable {
    case added(String)
    case removed(String)
    case context(String)

    public var text: String {
        switch self {
        case .added(let t), .removed(let t), .context(let t): return t
        }
    }

    public var prefix: String {
        switch self {
        case .added: return "+"
        case .removed: return "-"
        case .context: return " "
        }
    }

    public var isChange: Bool {
        switch self {
        case .added, .removed: return true
        case .context: return false
        }
    }
}

/// Status describing whether a skill update is available.
public enum SkillUpdateStatus: Sendable, Equatable {
    /// Remote content matches local — skill is up to date.
    case upToDate
    /// Remote content differs — an update is available.
    case updateAvailable
    /// Remote content could not be fetched.
    case remoteUnavailable
    /// Skill has no remote source.
    case noRemoteSource
    /// Local SKILL.md not found.
    case notInstalled
}

/// Preview of a pending skill update including the computed diff.
public struct SkillUpdatePreview: Sendable, Equatable {
    public let skillName: String
    public let isGlobal: Bool
    public let localContent: String?
    public let remoteContent: String?
    public let diffLines: [SkillDiffLine]
    public let status: SkillUpdateStatus
    /// Path(s) that will be written on apply.
    public let localPaths: [String]

    public init(
        skillName: String,
        isGlobal: Bool,
        localContent: String?,
        remoteContent: String?,
        diffLines: [SkillDiffLine],
        status: SkillUpdateStatus,
        localPaths: [String]
    ) {
        self.skillName = skillName
        self.isGlobal = isGlobal
        self.localContent = localContent
        self.remoteContent = remoteContent
        self.diffLines = diffLines
        self.status = status
        self.localPaths = localPaths
    }

    public var hasChanges: Bool { !diffLines.filter(\.isChange).isEmpty }
    public var addedLines: Int { diffLines.filter { if case .added = $0 { return true }; return false }.count }
    public var removedLines: Int { diffLines.filter { if case .removed = $0 { return true }; return false }.count }
}

public struct AgentSkillRoots: Sendable {
    public let global: URL
    public let project: URL

    public init(global: URL, project: URL) {
        self.global = global
        self.project = project
    }
}

public actor SkillCatalogService {
    private struct InstalledSkillRecord: Codable, Equatable {
        let package: String
        var description: String
        let isGlobal: Bool
        var url: String?
        var agents: [AgentWorkflow]
        var installDirectories: [String]
        var updatedAt: Date
    }

    private struct ParsedPackage {
        let owner: String
        let repo: String
        let skill: String
    }

    private struct ScrapedRegistrySnapshot: Codable {
        let scrapedAt: String?
        let totalSkills: Int?
        let totalSources: Int?
        let totalOwners: Int?
        let skills: [ScrapedRegistrySkill]
    }

    private struct ScrapedRegistrySkill: Codable {
        let source: String
        let skillId: String
        let name: String
        let installs: Int
        let owner: String
        let repo: String
        let githubURL: String?
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case source
            case skillId
            case name
            case installs
            case owner
            case repo
            case githubURL = "githubUrl"
            case displayName
        }
    }

    private struct GitHubRepoMetadata {
        let htmlURL: String?
        let defaultBranch: String?
        let stars: Int
    }

    private struct RemoteSkillPackageFile {
        let relativePath: String
        let data: Data
    }

    private struct RemoteSkillPackage {
        let markdown: String
        let files: [RemoteSkillPackageFile]
    }

    private struct SkillLockSnapshot: Codable {
        let lastSelectedAgents: [String]?
        let skills: [String: SkillLockEntry]?
    }

    private struct SkillLockEntry: Codable {
        let source: String?
    }

    private let session: URLSession
    private let fileManager: FileManager
    private let apiBaseURLs: [URL]
    private let crawlerSnapshotURLs: [URL]
    private let crawlerSeedRepos: [String]
    private let githubToken: String?
    private let installRootURL: URL
    private let registryURL: URL
    private let crawlerCacheURL: URL
    private let agentSkillRoots: [AgentWorkflow: AgentSkillRoots]
    private let localSkillRoots: [URL]
    private let sharedLocalRoots: [URL]
    private let skillLockFileURLs: [URL]

    public init(
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        apiBaseURL: URL? = nil,
        apiBaseURLs: [URL]? = nil,
        crawlerSnapshotURLs: [URL]? = nil,
        crawlerSeedRepos: [String]? = nil,
        githubToken: String? = nil,
        installRootURL: URL? = nil,
        projectRootURL: URL? = nil,
        agentSkillRoots: [AgentWorkflow: AgentSkillRoots]? = nil,
        localSkillRoots: [URL]? = nil,
        sharedLocalRoots: [URL]? = nil,
        skillLockFileURLs: [URL]? = nil
    ) {
        self.session = session
        self.fileManager = fileManager
        self.apiBaseURLs = Self.resolveAPIBaseURLs(custom: apiBaseURL, additional: apiBaseURLs)
        self.crawlerSnapshotURLs = Self.resolveCrawlerSnapshotURLs(custom: crawlerSnapshotURLs)
        self.crawlerSeedRepos = Self.resolveCrawlerSeedRepos(custom: crawlerSeedRepos)
        if let githubToken {
            let trimmedToken = githubToken.trimmingCharacters(in: .whitespacesAndNewlines)
            self.githubToken = trimmedToken.isEmpty ? nil : trimmedToken
        } else {
            self.githubToken = nil
        }

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let root = installRootURL
            ?? appSupport
            .appendingPathComponent("PromptHub", isDirectory: true)
            .appendingPathComponent("Skills", isDirectory: true)

        self.installRootURL = root
        self.registryURL = root.appendingPathComponent("installed-skills.json")
        self.crawlerCacheURL = root.appendingPathComponent("skills-registry-cache.json")
        self.agentSkillRoots = agentSkillRoots ?? Self.defaultAgentSkillRoots(
            fileManager: fileManager,
            projectRootURL: projectRootURL
        )
        self.localSkillRoots = localSkillRoots
            ?? Self.defaultLocalSkillRoots(fileManager: fileManager, agentSkillRoots: self.agentSkillRoots)
        self.sharedLocalRoots = sharedLocalRoots ?? Self.defaultSharedLocalRoots(fileManager: fileManager)
        self.skillLockFileURLs = skillLockFileURLs ?? Self.defaultSkillLockFileURLs(fileManager: fileManager)
    }

    public func findSkills(query: String = "") async throws -> [SkillInfo] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let pageSize = 100
        let maxPages = trimmedQuery.isEmpty ? 5 : 3

        var skills: [SkillInfo] = []
        var lastError: Error?

        do {
            for page in 1...maxPages {
                var queryItems: [URLQueryItem] = [
                    URLQueryItem(name: "sortBy", value: "installs"),
                    URLQueryItem(name: "sortOrder", value: "desc"),
                    URLQueryItem(name: "page", value: "\(page)"),
                    URLQueryItem(name: "pageSize", value: "\(pageSize)")
                ]
                if !trimmedQuery.isEmpty {
                    queryItems.insert(URLQueryItem(name: "query", value: trimmedQuery), at: 0)
                }

                let json = try await requestJSON(
                    paths: ["/api/skills", "/skills"],
                    queryItems: queryItems
                )
                let pageSkills = parseFindAPIResponse(json)
                mergeUniqueSkills(from: pageSkills, into: &skills)

                if pageSkills.count < pageSize {
                    break
                }
            }
        } catch {
            lastError = error
        }

        if skills.isEmpty {
            do {
                skills = try await findSkillsFromCrawlerSnapshot(query: trimmedQuery)
            } catch {
                if lastError == nil {
                    lastError = error
                }
            }
        }

        if skills.isEmpty, let lastError {
            throw lastError
        }

        let installed = (try? listInstalledSkills()) ?? []
        var installedByQualifiedPackage: [String: [SkillInfo]] = [:]
        for item in installed {
            guard let key = normalizedQualifiedPackage(item.name) else {
                continue
            }
            installedByQualifiedPackage[key, default: []].append(item)
        }

        for index in skills.indices {
            guard let key = normalizedQualifiedPackage(skills[index].name),
                  let matches = installedByQualifiedPackage[key],
                  !matches.isEmpty else {
                continue
            }

            skills[index].isInstalled = true
            skills[index].installedAgents = Array(
                Set(matches.flatMap(\.installedAgents))
            ).sorted { $0.rawValue < $1.rawValue }
            skills[index].installedScopes = Array(
                Set(matches.flatMap(\.installedScopes))
            ).sorted { lhs, rhs in
                switch (lhs, rhs) {
                case (.project, .global):
                    return true
                case (.global, .project):
                    return false
                default:
                    return lhs.rawValue < rhs.rawValue
                }
            }
        }

        return skills
    }

    private func mergeUniqueSkills(from incoming: [SkillInfo], into existing: inout [SkillInfo]) {
        guard !incoming.isEmpty else {
            return
        }

        var seen = Set(existing.map(\.name))
        for item in incoming where !seen.contains(item.name) {
            existing.append(item)
            seen.insert(item.name)
        }
    }

    public func listInstalledSkills() throws -> [SkillInfo] {
        let records = loadInstalledRecordsLenient()
        var output = records.map { record in
            let discoveredAgents = discoverExternalInstalledAgents(
                package: record.package,
                isGlobal: record.isGlobal
            )
            let agents = Array(Set(record.agents + discoveredAgents)).sorted { $0.rawValue < $1.rawValue }
            return SkillInfo(
                name: record.package,
                description: record.description,
                isInstalled: true,
                isGlobal: record.isGlobal,
                url: record.url,
                installedAgents: agents,
                installedScopes: [record.isGlobal ? .global : .project],
                isManagedByPromptHub: true,
                installedPaths: record.installDirectories.map {
                    installRootURL.appendingPathComponent($0, isDirectory: true).path
                }
            )
        }

        let localSkills = discoverLocalInstalledSkills()
        let managedSkills = discoverManagedInstalledSkills()
        if !localSkills.isEmpty {
            output.append(contentsOf: localSkills)
        }
        if !managedSkills.isEmpty {
            output.append(contentsOf: managedSkills)
        }

        output = mergeInstalledEntries(output)

        return output.sorted {
            if $0.isGlobal != $1.isGlobal {
                return !$0.isGlobal && $1.isGlobal
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    public func install(package: String, isGlobal: Bool = true) async throws {
        let parsed = try parsePackage(package)
        try await install(
            request: SkillInstallRequest(
                source: "\(parsed.owner)/\(parsed.repo)",
                skillNames: [parsed.skill],
                targetAgents: AgentWorkflow.defaultTargets,
                isGlobal: isGlobal
            )
        )
    }

    public func install(request: SkillInstallRequest) async throws {
        let sourceParts = request.source.split(separator: "/", maxSplits: 1).map(String.init)
        guard sourceParts.count == 2, !request.skillNames.isEmpty else {
            throw SkillKitError.invalidSkillPackage
        }

        let owner = sourceParts[0]
        let repo = sourceParts[1]
        let agents = request.targetAgents.isEmpty ? AgentWorkflow.defaultTargets : request.targetAgents

        var records = loadInstalledRecordsLenient()

        for skillName in request.skillNames {
            let package = "\(owner)/\(repo)@\(skillName)"
            let remotePackage = try? await fetchSkillPackageFromGitHub(owner: owner, repo: repo, skillName: skillName)
            let markdown: String
            if let remotePackage {
                markdown = remotePackage.markdown
            } else {
                markdown = try await fetchSkillMarkdown(owner: owner, repo: repo, skillName: skillName)
            }
            let description = extractDescription(fromMarkdown: markdown)

            var installDirectories: [String] = []
            for agent in agents {
                let relativeDir = try writeManagedSkillMarkdown(
                    markdown,
                    package: package,
                    packageFiles: remotePackage?.files,
                    agent: agent,
                    isGlobal: request.isGlobal
                )
                installDirectories.append(relativeDir)

                try writeExternalSkillMarkdown(
                    markdown,
                    package: package,
                    packageFiles: remotePackage?.files,
                    agent: agent,
                    isGlobal: request.isGlobal
                )
            }

            if let index = records.firstIndex(where: { $0.package == package && $0.isGlobal == request.isGlobal }) {
                var record = records[index]
                if !description.isEmpty {
                    record.description = description
                }
                if record.url == nil {
                    record.url = buildSkillURL(owner: owner, repo: repo, skillName: skillName)
                }
                record.agents = Array(Set(record.agents + agents)).sorted { $0.rawValue < $1.rawValue }
                record.installDirectories = Array(Set(record.installDirectories + installDirectories)).sorted()
                record.updatedAt = Date()
                records[index] = record
            } else {
                records.append(
                    InstalledSkillRecord(
                        package: package,
                        description: description,
                        isGlobal: request.isGlobal,
                        url: buildSkillURL(owner: owner, repo: repo, skillName: skillName),
                        agents: agents.sorted { $0.rawValue < $1.rawValue },
                        installDirectories: Array(Set(installDirectories)).sorted(),
                        updatedAt: Date()
                    )
                )
            }
        }

        try saveInstalledRecords(records)
        try? upsertSkillLockEntries(
            skillNames: request.skillNames,
            source: request.source,
            targetAgents: agents
        )
    }

    public func installLocal(
        name: String,
        markdown: String,
        packageDirectoryURL: URL? = nil,
        isGlobal: Bool = true,
        targetAgents: [AgentWorkflow] = AgentWorkflow.defaultTargets
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMarkdown = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedMarkdown.isEmpty else {
            throw SkillKitError.invalidSkillPackage
        }

        let package = sanitizeSkillIdentifier(trimmedName)
        guard !package.isEmpty else {
            throw SkillKitError.invalidSkillPackage
        }

        let agents = targetAgents.isEmpty ? AgentWorkflow.defaultTargets : targetAgents
        let description = extractDescription(fromMarkdown: markdown)
        var records = loadInstalledRecordsLenient()

        var installDirectories: [String] = []
        for agent in agents {
            let relativeDir = try writeManagedSkillPackage(
                markdown,
                package: package,
                packageDirectoryURL: packageDirectoryURL,
                agent: agent,
                isGlobal: isGlobal
            )
            installDirectories.append(relativeDir)

            try writeExternalSkillPackage(
                markdown,
                package: package,
                packageDirectoryURL: packageDirectoryURL,
                agent: agent,
                isGlobal: isGlobal
            )
        }

        if let index = records.firstIndex(where: { $0.package == package && $0.isGlobal == isGlobal }) {
            var record = records[index]
            if !description.isEmpty {
                record.description = description
            }
            record.agents = Array(Set(record.agents + agents)).sorted { $0.rawValue < $1.rawValue }
            record.installDirectories = Array(Set(record.installDirectories + installDirectories)).sorted()
            record.updatedAt = Date()
            records[index] = record
        } else {
            records.append(
                InstalledSkillRecord(
                    package: package,
                    description: description,
                    isGlobal: isGlobal,
                    url: nil,
                    agents: agents.sorted { $0.rawValue < $1.rawValue },
                    installDirectories: Array(Set(installDirectories)).sorted(),
                    updatedAt: Date()
                )
            )
        }

        try saveInstalledRecords(records)
        try? upsertSkillLockEntries(
            skillNames: [package],
            source: nil,
            targetAgents: agents
        )
    }

    public func installExisting(
        name: String,
        isGlobal: Bool = true,
        targetAgents: [AgentWorkflow] = AgentWorkflow.defaultTargets
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw SkillKitError.invalidSkillPackage
        }

        guard let markdown = try existingInstalledMarkdown(
            for: trimmedName,
            isGlobal: isGlobal
        ) else {
            throw SkillKitError.fileIOError("Unable to locate an installed SKILL.md for \(trimmedName)")
        }

        try installLocal(
            name: shortSkillName(fromPackage: trimmedName),
            markdown: markdown,
            isGlobal: isGlobal,
            targetAgents: targetAgents
        )
    }

    public func loadInstalledMarkdown(
        name: String,
        isGlobal: Bool = true
    ) throws -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw SkillKitError.invalidSkillPackage
        }

        return try existingInstalledMarkdown(for: trimmedName, isGlobal: isGlobal)
    }

    /// Performs a real-time filesystem scan for each agent's expected skill directory.
    ///
    /// For every `AgentWorkflow`, this checks whether `SKILL.md` is present inside the
    /// agent's configured global or project skill root.  The result is intentionally
    /// synchronous (no network) and is safe to call on any thread because `SkillCatalogService`
    /// is an actor and all reads use the immutable `agentSkillRoots` map.
    ///
    /// - Parameters:
    ///   - skillName: The full package name (e.g. `"owner/repo@skill"`) or just the short name.
    ///   - isGlobal: Whether to check the global or project-scoped path for each agent.
    /// - Returns: One `SkillAgentVisibility` entry per known agent.
    public func checkAgentVisibility(
        skillName: String,
        isGlobal: Bool = true
    ) -> [SkillAgentVisibility] {
        let short = sanitizePathComponent(shortSkillName(fromPackage: skillName))
        return AgentWorkflow.allCases.map { workflow in
            guard let roots = agentSkillRoots[workflow] else {
                return SkillAgentVisibility(
                    agent: workflow,
                    status: .unknownPath,
                    checkedPath: nil,
                    isGlobal: isGlobal
                )
            }
            let base = isGlobal ? roots.global : roots.project
            // If the agent's root directory itself doesn't exist, we can't distinguish
            // "never configured" from "installed but file missing". Treat as unknownPath.
            guard fileManager.fileExists(atPath: base.path) else {
                return SkillAgentVisibility(
                    agent: workflow,
                    status: .unknownPath,
                    checkedPath: base.path,
                    isGlobal: isGlobal
                )
            }
            let skillDir = base.appendingPathComponent(short, isDirectory: true)
            let skillFile = skillDir.appendingPathComponent("SKILL.md")
            let status: AgentVisibilityStatus = fileManager.fileExists(atPath: skillFile.path) ? .visible : .missing
            return SkillAgentVisibility(
                agent: workflow,
                status: status,
                checkedPath: skillFile.path,
                isGlobal: isGlobal
            )
        }
    }

    /// Computes a SHA-256 hash of the locally installed SKILL.md and optionally fetches the
    /// remote version from GitHub to compare.  Falls back to offline-only mode when network
    /// access is unavailable.
    ///
    /// - Parameters:
    ///   - skillName: Full package name (e.g. `"owner/repo@skill"`) used to locate the file and derive the remote URL.
    ///   - isGlobal: Whether to look in the global or project skill root.
    /// - Returns: A `SkillSourceIntegrity` describing local hash, remote hash, and status.
    public func checkSourceIntegrity(
        skillName: String,
        isGlobal: Bool = true
    ) async -> SkillSourceIntegrity {
        let now = Date()

        // Locate local SKILL.md via the first agent that has a configured root.
        let short = sanitizePathComponent(shortSkillName(fromPackage: skillName))
        var localContent: String?
        var localFilePath: String?
        for workflow in AgentWorkflow.allCases {
            guard let roots = agentSkillRoots[workflow] else { continue }
            let base = isGlobal ? roots.global : roots.project
            let skillFile = base.appendingPathComponent(short, isDirectory: true)
                .appendingPathComponent("SKILL.md")
            if let text = try? String(contentsOf: skillFile, encoding: .utf8), !text.isEmpty {
                localContent = text
                localFilePath = skillFile.path
                break
            }
        }

        guard let localText = localContent else {
            return SkillSourceIntegrity(
                localHash: nil,
                remoteHash: nil,
                status: .notInstalled,
                remoteURL: nil,
                localPath: localFilePath,
                checkedAt: now
            )
        }

        let localHash = sha256Hex(localText)

        // Parse package to get owner/repo/skillName for GitHub fetching.
        guard let parsed = try? parsePackage(skillName) else {
            return SkillSourceIntegrity(
                localHash: localHash,
                remoteHash: nil,
                status: .noRemoteSource,
                remoteURL: nil,
                localPath: localFilePath,
                checkedAt: now
            )
        }

        // Attempt to fetch remote content.
        let remoteMarkdown: String?
        var remoteRawURL: String?

        do {
            let markdown = try await fetchSkillMarkdownFromGitHub(
                owner: parsed.owner,
                repo: parsed.repo,
                skillName: parsed.skill
            )
            remoteMarkdown = markdown
            // Best-effort URL for display purposes.
            remoteRawURL = "https://raw.githubusercontent.com/\(parsed.owner)/\(parsed.repo)/HEAD/skills/\(parsed.skill)/SKILL.md"
        } catch {
            return SkillSourceIntegrity(
                localHash: localHash,
                remoteHash: nil,
                status: .remoteUnavailable,
                remoteURL: nil,
                localPath: localFilePath,
                checkedAt: now
            )
        }

        guard let remoteText = remoteMarkdown else {
            return SkillSourceIntegrity(
                localHash: localHash,
                remoteHash: nil,
                status: .remoteUnavailable,
                remoteURL: remoteRawURL,
                localPath: localFilePath,
                checkedAt: now
            )
        }

        let remoteHash = sha256Hex(remoteText)
        let status: SkillSourceIntegrityStatus = localHash == remoteHash ? .verified : .modified

        return SkillSourceIntegrity(
            localHash: localHash,
            remoteHash: remoteHash,
            status: status,
            remoteURL: remoteRawURL,
            localPath: localFilePath,
            checkedAt: now
        )
    }

    /// Analyzes the locally installed SKILL.md for structural quality signals.
    ///
    /// The checks are purely structural/textual — no network access is required.
    /// This is the audit-layer signal: it answers "is this skill well-formed",
    /// not "does this skill behave correctly". Behavioral proof belongs to the
    /// evaluation layer.
    ///
    /// - Parameters:
    ///   - skillName: Full package name or short skill name.
    ///   - isGlobal: Whether to look in the global or project skill root.
    /// - Returns: A `SkillStructuralQualityReport` with individual check results and an overall score.
    public func checkStructuralQuality(
        skillName: String,
        isGlobal: Bool = true
    ) -> SkillStructuralQualityReport {
        let short = sanitizePathComponent(shortSkillName(fromPackage: skillName))

        // Locate the SKILL.md from the first agent that has a configured root.
        var markdown: String?
        for workflow in AgentWorkflow.allCases {
            guard let roots = agentSkillRoots[workflow] else { continue }
            let base = isGlobal ? roots.global : roots.project
            let skillFile = base
                .appendingPathComponent(short, isDirectory: true)
                .appendingPathComponent("SKILL.md")
            if let content = try? String(contentsOf: skillFile, encoding: .utf8) {
                markdown = content
                break
            }
        }

        guard let content = markdown else {
            return .notFound
        }

        let checks = Self.runStructuralQualityChecks(on: content)
        let passedCount = checks.filter(\.passed).count
        let score = checks.isEmpty ? 0.0 : Double(passedCount) / Double(checks.count)
        let tier: StructuralQualityTier = {
            switch score {
            case 0.8...: return .excellent
            case 0.6..<0.8: return .good
            case 0.4..<0.6: return .fair
            default: return .poor
            }
        }()

        return SkillStructuralQualityReport(checks: checks, score: score, tier: tier, fileFound: true)
    }

    /// Deprecated alias for `checkStructuralQuality(skillName:isGlobal:)`.
    @available(*, deprecated, renamed: "checkStructuralQuality(skillName:isGlobal:)")
    public func checkEffectiveness(
        skillName: String,
        isGlobal: Bool = true
    ) -> SkillStructuralQualityReport {
        checkStructuralQuality(skillName: skillName, isGlobal: isGlobal)
    }

    /// Pure function: run all structural checks on raw SKILL.md content.
    private static func runStructuralQualityChecks(on content: String) -> [SkillStructuralQualityCheck] {
        let lines = content.components(separatedBy: .newlines)
        let lower = content.lowercased()
        let headings = lines.filter { $0.hasPrefix("#") }.map { $0.lowercased() }

        // 1. Has YAML frontmatter
        let hasFrontmatter: Bool = {
            guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return false }
            let closeIdx = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" })
            return closeIdx != nil
        }()

        // 2. Has non-empty description in frontmatter
        let hasDescription: Bool = {
            guard hasFrontmatter else { return false }
            let descLine = lines.first(where: { $0.lowercased().hasPrefix("description:") })
            guard let raw = descLine else { return false }
            let value = raw.dropFirst("description:".count).trimmingCharacters(in: .whitespacesAndNewlines)
            return !value.isEmpty && value.count > 10
        }()

        // 3. Has a ## Usage section (or similar trigger-word heading)
        let hasUsageSection = headings.contains(where: {
            $0.contains("usage") || $0.contains("when to use") || $0.contains("trigger")
        })

        // 4. Has a code block (example of usage)
        let hasCodeBlock = content.contains("```")

        // 5. Length is substantial (> 150 chars of non-frontmatter content)
        let contentWithoutFrontmatter: String = {
            guard hasFrontmatter,
                  let closeRange = content.range(of: "\n---", range: content.range(of: "---")!.upperBound..<content.endIndex) else {
                return content
            }
            return String(content[closeRange.upperBound...])
        }()
        let isSubstantial = contentWithoutFrontmatter
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .count > 150

        // 6. Has a primary heading (# Title)
        let hasTitle = lines.contains(where: { $0.hasPrefix("# ") })

        // 7. Has tool/file references (indicates practical grounding)
        let hasToolRefs = lower.contains("file") || lower.contains("command") || lower.contains("tool") || lower.contains("function")

        return [
            SkillStructuralQualityCheck(
                title: "YAML frontmatter",
                rationale: "Frontmatter lets agents extract structured metadata.",
                passed: hasFrontmatter,
                hint: hasFrontmatter ? nil : "Add `---` frontmatter with at least a `description:` field."
            ),
            SkillStructuralQualityCheck(
                title: "Non-empty description",
                rationale: "A clear description helps agents decide when to invoke this skill.",
                passed: hasDescription,
                hint: hasDescription ? nil : "Add a `description:` field with at least a sentence."
            ),
            SkillStructuralQualityCheck(
                title: "Title heading",
                rationale: "A `# Title` heading makes the skill scannable.",
                passed: hasTitle,
                hint: hasTitle ? nil : "Add a top-level `# SkillName` heading."
            ),
            SkillStructuralQualityCheck(
                title: "Usage section",
                rationale: "An explicit usage or 'when to use' section sets invocation expectations.",
                passed: hasUsageSection,
                hint: hasUsageSection ? nil : "Add a `## Usage` or `## When to use` section."
            ),
            SkillStructuralQualityCheck(
                title: "Code or command examples",
                rationale: "Concrete examples improve agent reliability.",
                passed: hasCodeBlock,
                hint: hasCodeBlock ? nil : "Add at least one fenced code block with an example."
            ),
            SkillStructuralQualityCheck(
                title: "Substantial content",
                rationale: "Thin skill files often lack enough context for reliable agent behavior.",
                passed: isSubstantial,
                hint: isSubstantial ? nil : "Expand the skill file with more detail (aim for > 150 characters of body content)."
            ),
            SkillStructuralQualityCheck(
                title: "Tool or file references",
                rationale: "Referencing tools or files grounds the skill in practical usage.",
                passed: hasToolRefs,
                hint: hasToolRefs ? nil : "Mention specific tools, files, or commands this skill relies on."
            ),
        ]
    }

    // MARK: - Update Preview / Apply / Rollback

    /// Fetches the remote SKILL.md and computes the diff against the local installation.
    /// This is a read-only operation — nothing is written to disk.
    ///
    /// - Parameters:
    ///   - skillName: Full package name (e.g. `"owner/repo@skill"`).
    ///   - isGlobal: Whether to check global or project scope.
    /// - Returns: A `SkillUpdatePreview` with diff lines and status.
    public func previewUpdate(
        skillName: String,
        isGlobal: Bool = true
    ) async -> SkillUpdatePreview {
        let short = sanitizePathComponent(shortSkillName(fromPackage: skillName))

        // Collect all local paths for this skill (one per agent).
        var localContent: String?
        var localPaths: [String] = []
        for workflow in AgentWorkflow.allCases {
            guard let roots = agentSkillRoots[workflow] else { continue }
            let base = isGlobal ? roots.global : roots.project
            let skillFile = base
                .appendingPathComponent(short, isDirectory: true)
                .appendingPathComponent("SKILL.md")
            if fileManager.fileExists(atPath: skillFile.path) {
                localPaths.append(skillFile.path)
                if localContent == nil {
                    localContent = try? String(contentsOf: skillFile, encoding: .utf8)
                }
            }
        }

        guard let local = localContent else {
            return SkillUpdatePreview(
                skillName: skillName,
                isGlobal: isGlobal,
                localContent: nil,
                remoteContent: nil,
                diffLines: [],
                status: .notInstalled,
                localPaths: localPaths
            )
        }

        // Need owner/repo/skill to fetch from GitHub.
        guard let parsed = try? parsePackage(skillName) else {
            return SkillUpdatePreview(
                skillName: skillName,
                isGlobal: isGlobal,
                localContent: local,
                remoteContent: nil,
                diffLines: [],
                status: .noRemoteSource,
                localPaths: localPaths
            )
        }

        let remoteText: String
        do {
            remoteText = try await fetchSkillMarkdownFromGitHub(
                owner: parsed.owner,
                repo: parsed.repo,
                skillName: parsed.skill
            )
        } catch {
            return SkillUpdatePreview(
                skillName: skillName,
                isGlobal: isGlobal,
                localContent: local,
                remoteContent: nil,
                diffLines: [],
                status: .remoteUnavailable,
                localPaths: localPaths
            )
        }

        let normalLocal = local.replacingOccurrences(of: "\r\n", with: "\n")
        let normalRemote = remoteText.replacingOccurrences(of: "\r\n", with: "\n")

        if normalLocal == normalRemote {
            return SkillUpdatePreview(
                skillName: skillName,
                isGlobal: isGlobal,
                localContent: local,
                remoteContent: remoteText,
                diffLines: [],
                status: .upToDate,
                localPaths: localPaths
            )
        }

        let diffLines = computeDiff(old: normalLocal, new: normalRemote)
        return SkillUpdatePreview(
            skillName: skillName,
            isGlobal: isGlobal,
            localContent: local,
            remoteContent: remoteText,
            diffLines: diffLines,
            status: .updateAvailable,
            localPaths: localPaths
        )
    }

    /// Writes the remote content from `preview` to all agent skill directories.
    ///
    /// Before overwriting, a `.bak` backup of the existing file is written alongside it
    /// so the user can roll back with `rollbackUpdate(preview:)`.
    ///
    /// - Parameter preview: A preview that was returned by `previewUpdate` and has status `.updateAvailable`.
    /// - Throws: `SkillKitError.fileIOError` if writing fails.
    public func applyUpdate(preview: SkillUpdatePreview) throws {
        guard let remoteContent = preview.remoteContent else {
            throw SkillKitError.fileIOError("No remote content to apply for \(preview.skillName)")
        }
        for path in preview.localPaths {
            let url = URL(fileURLWithPath: path)
            let backupURL = url.deletingLastPathComponent()
                .appendingPathComponent("SKILL.md.bak")
            // Back up existing content before overwriting.
            if let existing = try? Data(contentsOf: url) {
                try existing.write(to: backupURL)
            }
            try remoteContent.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Restores the `.bak` backup written by `applyUpdate(preview:)`.
    ///
    /// - Parameter preview: The same preview that was passed to `applyUpdate`.
    /// - Returns: Number of paths successfully restored.
    @discardableResult
    public func rollbackUpdate(preview: SkillUpdatePreview) throws -> Int {
        var restored = 0
        for path in preview.localPaths {
            let url = URL(fileURLWithPath: path)
            let backupURL = url.deletingLastPathComponent()
                .appendingPathComponent("SKILL.md.bak")
            guard fileManager.fileExists(atPath: backupURL.path) else { continue }
            let backupData = try Data(contentsOf: backupURL)
            try backupData.write(to: url)
            try? fileManager.removeItem(at: backupURL)
            restored += 1
        }
        return restored
    }

    /// Checks whether a backup file exists for the given skill/scope.
    public func hasRollbackBackup(skillName: String, isGlobal: Bool) -> Bool {
        let short = sanitizePathComponent(shortSkillName(fromPackage: skillName))
        for workflow in AgentWorkflow.allCases {
            guard let roots = agentSkillRoots[workflow] else { continue }
            let base = isGlobal ? roots.global : roots.project
            let backupFile = base
                .appendingPathComponent(short, isDirectory: true)
                .appendingPathComponent("SKILL.md.bak")
            if fileManager.fileExists(atPath: backupFile.path) { return true }
        }
        return false
    }

    /// Simple LCS-based line diff producing `SkillDiffLine` output.
    private func computeDiff(old: String, new: String) -> [SkillDiffLine] {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")

        // Build LCS table.
        let m = oldLines.count
        let n = newLines.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                if oldLines[i - 1] == newLines[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        // Backtrack.
        var result: [SkillDiffLine] = []
        var i = m, j = n
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && oldLines[i - 1] == newLines[j - 1] {
                result.append(.context(oldLines[i - 1]))
                i -= 1; j -= 1
            } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
                result.append(.added(newLines[j - 1]))
                j -= 1
            } else {
                result.append(.removed(oldLines[i - 1]))
                i -= 1
            }
        }
        return result.reversed()
    }

    private func sha256Hex(_ text: String) -> String {
        // Normalize line endings to LF before hashing so CRLF vs LF differences
        // (common between Windows-authored remotes and local macOS copies) do not
        // produce false "modified" results.
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let data = Data(normalized.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public func remove(
        name: String,
        isGlobal: Bool = true,
        targetAgents: [AgentWorkflow]? = nil
    ) throws {
        var records = loadInstalledRecordsLenient()
        guard let index = records.firstIndex(where: { $0.package == name && $0.isGlobal == isGlobal }) else {
            _ = try removeExternalSkillDirectories(
                name: name,
                isGlobal: isGlobal,
                targetAgents: targetAgents
            )
            if !hasInstalledSkillDirectory(name: name, isGlobal: isGlobal) {
                try? removeSkillLockEntries(skillNames: [shortSkillName(fromPackage: name)])
            }
            return
        }

        var record = records[index]
        let requestedAgents = (targetAgents ?? record.agents)
        let normalizedAgents = requestedAgents.isEmpty ? record.agents : requestedAgents
        let targetAgentSet = Set(normalizedAgents)

        let targetDirectories = record.installDirectories.filter { relativePath in
            let segments = relativePath.split(separator: "/").map(String.init)
            guard segments.count >= 2 else { return false }
            guard let agent = AgentWorkflow(rawValue: segments[1]) else { return false }
            return targetAgentSet.contains(agent)
        }

        for relativePath in targetDirectories {
            let path = installRootURL.appendingPathComponent(relativePath, isDirectory: true)
            try removeDirectoryIfExists(path)
        }

        let retainedAgents = Set(record.agents.filter { !targetAgentSet.contains($0) })
        let retainedExternalPathSet = Set(
            retainedAgents.map {
                externalSkillDirectory(package: name, agent: $0, isGlobal: isGlobal)
                    .standardizedFileURL.path
            }
        )
        let targetExternalPathSet = Set(
            targetAgentSet.map {
                externalSkillDirectory(package: name, agent: $0, isGlobal: isGlobal)
                    .standardizedFileURL.path
            }
        )
        for externalPath in targetExternalPathSet where !retainedExternalPathSet.contains(externalPath) {
            try removeDirectoryIfExists(URL(fileURLWithPath: externalPath, isDirectory: true))
        }
        _ = try removeExternalSkillDirectories(
            name: name,
            isGlobal: isGlobal,
            targetAgents: Array(targetAgentSet)
        )

        record.installDirectories.removeAll { targetDirectories.contains($0) }
        record.agents.removeAll { targetAgentSet.contains($0) }
        record.agents = Array(Set(record.agents)).sorted { $0.rawValue < $1.rawValue }
        record.updatedAt = Date()

        if record.installDirectories.isEmpty || record.agents.isEmpty {
            records.remove(at: index)
        } else {
            records[index] = record
        }

        try saveInstalledRecords(records)
        if !hasInstalledSkillDirectory(name: name, isGlobal: isGlobal) {
            try? removeSkillLockEntries(skillNames: [shortSkillName(fromPackage: name)])
        }
    }

    private func removeExternalSkillDirectories(
        name: String,
        isGlobal: Bool,
        targetAgents: [AgentWorkflow]?
    ) throws -> Bool {
        let roots = candidateRemovalRoots(isGlobal: isGlobal, targetAgents: targetAgents)
        guard !roots.isEmpty else {
            return false
        }

        var removed = false
        for root in roots {
            let directories = matchingSkillDirectories(in: root, packageOrSkillName: name)
            for directory in directories {
                try removeDirectoryIfExists(directory)
                removed = true
            }
        }
        return removed
    }

    private func existingInstalledMarkdown(
        for name: String,
        isGlobal: Bool
    ) throws -> String? {
        for root in candidateRemovalRoots(isGlobal: isGlobal, targetAgents: nil) {
            for directory in matchingSkillDirectories(in: root, packageOrSkillName: name) {
                let skillFile = directory.appendingPathComponent("SKILL.md")
                guard fileManager.fileExists(atPath: skillFile.path) else {
                    continue
                }
                return try String(contentsOf: skillFile, encoding: .utf8)
            }
        }
        return nil
    }

    private func candidateRemovalRoots(
        isGlobal: Bool,
        targetAgents: [AgentWorkflow]?
    ) -> [URL] {
        var roots: [URL] = []

        if let targetAgents, !targetAgents.isEmpty {
            for workflow in targetAgents {
                guard let configuredRoots = agentSkillRoots[workflow] else {
                    continue
                }
                roots.append(isGlobal ? configuredRoots.global : configuredRoots.project)
            }
        } else {
            roots.append(
                contentsOf: AgentWorkflow.allCases.compactMap { workflow in
                    guard let configuredRoots = agentSkillRoots[workflow] else {
                        return nil
                    }
                    return isGlobal ? configuredRoots.global : configuredRoots.project
                }
            )
            roots.append(
                contentsOf: localSkillRoots.filter { root in
                    inferScope(fromLocalRoot: root) == (isGlobal ? .global : .project)
                }
            )
        }

        var deduped: [URL] = []
        var seen = Set<String>()
        for root in roots {
            let normalized = root.resolvingSymlinksInPath().standardizedFileURL.path.lowercased()
            if seen.insert(normalized).inserted {
                deduped.append(root)
            }
        }
        return deduped
    }

    private func matchingSkillDirectories(in root: URL, packageOrSkillName: String) -> [URL] {
        guard fileManager.fileExists(atPath: root.path) else {
            return []
        }

        let shortName = shortSkillName(fromPackage: packageOrSkillName).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !shortName.isEmpty else {
            return []
        }
        let normalizedTarget = sanitizeSkillIdentifier(shortName)

        var candidates: [URL] = []
        let exact = root.appendingPathComponent(shortName, isDirectory: true)
        candidates.append(exact)

        if let children = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for child in children {
                let isDirectory = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDirectory else { continue }

                let childName = child.lastPathComponent
                let matchesExact = childName.compare(shortName, options: [.caseInsensitive]) == .orderedSame
                let matchesNormalized = sanitizeSkillIdentifier(childName) == normalizedTarget
                guard matchesExact || matchesNormalized else { continue }

                candidates.append(child)
            }
        }

        var output: [URL] = []
        var seen = Set<String>()
        for candidate in candidates {
            let skillFile = candidate.appendingPathComponent("SKILL.md")
            guard fileManager.fileExists(atPath: skillFile.path) else {
                continue
            }
            let normalized = candidate.resolvingSymlinksInPath().standardizedFileURL.path.lowercased()
            if seen.insert(normalized).inserted {
                output.append(candidate)
            }
        }

        return output
    }

    private func hasInstalledSkillDirectory(name: String, isGlobal: Bool) -> Bool {
        let roots = candidateRemovalRoots(isGlobal: isGlobal, targetAgents: nil)
        for root in roots {
            if !matchingSkillDirectories(in: root, packageOrSkillName: name).isEmpty {
                return true
            }
        }
        return false
    }

    private func upsertSkillLockEntries(
        skillNames: [String],
        source: String?,
        targetAgents: [AgentWorkflow]
    ) throws {
        let normalizedSkills = Array(
            Set(
                skillNames.map { sanitizeSkillIdentifier(shortSkillName(fromPackage: $0)) }
                    .filter { !$0.isEmpty }
            )
        )
        guard !normalizedSkills.isEmpty || !targetAgents.isEmpty else {
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let lockFiles = writableSkillLockFiles()
        for lockFile in lockFiles {
            var root = loadSkillLockJSON(lockFile) ?? [:]
            if root["version"] == nil {
                root["version"] = 3
            }

            var skills = root["skills"] as? [String: Any] ?? [:]
            for skill in normalizedSkills {
                var entry = skills[skill] as? [String: Any] ?? [:]
                if entry["installedAt"] == nil {
                    entry["installedAt"] = now
                }
                entry["updatedAt"] = now

                if let source, source.contains("/") {
                    let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
                    entry["source"] = trimmedSource
                    entry["sourceType"] = "github"
                    if entry["sourceUrl"] == nil {
                        entry["sourceUrl"] = "https://github.com/\(trimmedSource).git"
                    }
                }

                skills[skill] = entry
            }
            root["skills"] = skills

            if !targetAgents.isEmpty {
                root["lastSelectedAgents"] = targetAgents.map(\.rawValue)
            }

            try saveSkillLockJSON(root, to: lockFile)
        }
    }

    private func removeSkillLockEntries(skillNames: [String]) throws {
        let normalizedSkills = Set(
            skillNames.map { sanitizeSkillIdentifier(shortSkillName(fromPackage: $0)) }
                .filter { !$0.isEmpty }
        )
        guard !normalizedSkills.isEmpty else {
            return
        }

        for lockFile in skillLockFileURLs where fileManager.fileExists(atPath: lockFile.path) {
            guard var root = loadSkillLockJSON(lockFile) else {
                continue
            }
            guard var skills = root["skills"] as? [String: Any] else {
                continue
            }

            let beforeCount = skills.count
            for skill in normalizedSkills {
                skills.removeValue(forKey: skill)
            }
            guard skills.count != beforeCount else {
                continue
            }

            root["skills"] = skills
            try saveSkillLockJSON(root, to: lockFile)
        }
    }

    private func writableSkillLockFiles() -> [URL] {
        let existing = skillLockFileURLs.filter { fileManager.fileExists(atPath: $0.path) }
        if !existing.isEmpty {
            return existing
        }
        if let first = skillLockFileURLs.first {
            return [first]
        }
        return []
    }

    private func loadSkillLockJSON(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = object as? [String: Any] else {
            return nil
        }
        return dict
    }

    private func saveSkillLockJSON(_ json: [String: Any], to url: URL) throws {
        let folder = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: folder.path) {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private static func resolveAPIBaseURLs(custom: URL?, additional: [URL]? = nil) -> [URL] {
        var candidates: [URL] = []

        if let custom {
            candidates.append(custom)
        }
        if let additional {
            candidates.append(contentsOf: additional)
        }

        var seen = Set<String>()
        return candidates.filter { url in
            let key = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, !seen.contains(key) else {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    private static func resolveCrawlerSnapshotURLs(custom: [URL]? = nil) -> [URL] {
        var candidates: [URL] = []
        if let custom {
            candidates.append(contentsOf: custom)
        }

        if let rawSnapshot = URL(
            string: "https://raw.githubusercontent.com/mastra-ai/skills-api/main/src/registry/scraped-skills.json"
        ) {
            candidates.append(rawSnapshot)
        }

        var seen = Set<String>()
        return candidates.filter { url in
            let key = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, !seen.contains(key) else {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    private static func resolveCrawlerSeedRepos(custom: [String]? = nil) -> [String] {
        var candidates: [String] = []
        if let custom {
            candidates.append(contentsOf: custom)
        }

        if candidates.isEmpty {
            candidates = [
                "vercel-labs/agent-skills",
                "vercel-labs/skills"
            ]
        }

        var seen = Set<String>()
        return candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { repo in
                guard repo.contains("/"), !repo.hasPrefix("/"), !repo.hasSuffix("/"), !seen.contains(repo) else {
                    return false
                }
                seen.insert(repo)
                return true
            }
    }

    private static func defaultAgentSkillRoots(
        fileManager: FileManager = .default,
        projectRootURL: URL? = nil
    ) -> [AgentWorkflow: AgentSkillRoots] {
        let home = fileManager.homeDirectoryForCurrentUser
        let projectRoot = projectRootURL
            ?? URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)

        return [
            .codex: AgentSkillRoots(
                global: home.appendingPathComponent(".codex/skills", isDirectory: true),
                project: projectRoot.appendingPathComponent(".agents/skills", isDirectory: true)
            ),
            .claudeCode: AgentSkillRoots(
                global: home.appendingPathComponent(".claude/skills", isDirectory: true),
                project: projectRoot.appendingPathComponent(".claude/skills", isDirectory: true)
            ),
            .cursor: AgentSkillRoots(
                global: home.appendingPathComponent(".cursor/skills", isDirectory: true),
                project: projectRoot.appendingPathComponent(".cursor/skills", isDirectory: true)
            ),
            .geminiCLI: AgentSkillRoots(
                global: home.appendingPathComponent(".gemini/skills", isDirectory: true),
                project: projectRoot.appendingPathComponent(".agents/skills", isDirectory: true)
            ),
            .iflow: AgentSkillRoots(
                global: home.appendingPathComponent(".iflow/skills", isDirectory: true),
                project: projectRoot.appendingPathComponent(".iflow/skills", isDirectory: true)
            ),
            .opencode: AgentSkillRoots(
                global: home.appendingPathComponent(".config/opencode/skills", isDirectory: true),
                project: projectRoot.appendingPathComponent(".agents/skills", isDirectory: true)
            ),
            .qwenCode: AgentSkillRoots(
                global: home.appendingPathComponent(".qwen/skills", isDirectory: true),
                project: projectRoot.appendingPathComponent(".qwen/skills", isDirectory: true)
            ),
            .qoder: AgentSkillRoots(
                global: home.appendingPathComponent(".qoder/skills", isDirectory: true),
                project: projectRoot.appendingPathComponent(".qoder/skills", isDirectory: true)
            )
        ]
    }

    private static func defaultLocalSkillRoots(
        fileManager: FileManager = .default,
        agentSkillRoots: [AgentWorkflow: AgentSkillRoots]
    ) -> [URL] {
        let home = fileManager.homeDirectoryForCurrentUser
        var roots: [URL] = [
            home.appendingPathComponent(".agents/skills", isDirectory: true),
            home.appendingPathComponent(".config/agents/skills", isDirectory: true)
        ]
        roots.append(
            contentsOf: AgentWorkflow.allCases.compactMap { workflow in
                agentSkillRoots[workflow]?.global
            }
        )
        roots.append(
            contentsOf: AgentWorkflow.allCases.compactMap { workflow in
                agentSkillRoots[workflow]?.project
            }
        )

        var deduped: [URL] = []
        var seen = Set<String>()
        for root in roots {
            let normalized = root.standardizedFileURL.path
            if seen.insert(normalized).inserted {
                deduped.append(root)
            }
        }

        return deduped
    }

    private static func defaultSharedLocalRoots(
        fileManager: FileManager = .default
    ) -> [URL] {
        let home = fileManager.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".agents/skills", isDirectory: true),
            home.appendingPathComponent(".config/agents/skills", isDirectory: true)
        ]
    }

    private static func defaultSkillLockFileURLs(
        fileManager: FileManager = .default
    ) -> [URL] {
        let home = fileManager.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".agents/.skill-lock.json"),
            home.appendingPathComponent(".config/agents/.skill-lock.json"),
            home.appendingPathComponent(".agents/skills/.skill-lock.json"),
            home.appendingPathComponent(".config/agents/skills/.skill-lock.json")
        ]
    }

    private func requestJSON(paths: [String], queryItems: [URLQueryItem] = []) async throws -> Any {
        var lastError: SkillKitError = .invalidResponse

        for path in paths {
            do {
                return try await requestJSON(path: path, queryItems: queryItems)
            } catch let error as SkillKitError {
                lastError = error
            } catch {
                lastError = .networkError(error.localizedDescription)
            }
        }

        throw lastError
    }

    private func requestJSON(path: String, queryItems: [URLQueryItem] = []) async throws -> Any {
        var lastError: SkillKitError = .invalidResponse

        for baseURL in apiBaseURLs {
            do {
                return try await requestJSON(path: path, queryItems: queryItems, baseURL: baseURL)
            } catch let error as SkillKitError {
                lastError = error
            } catch {
                lastError = .networkError(error.localizedDescription)
            }
        }

        throw lastError
    }

    private func requestJSON(path: String, queryItems: [URLQueryItem], baseURL: URL) async throws -> Any {
        guard let url = buildURL(baseURL: baseURL, path: path, queryItems: queryItems) else {
            throw SkillKitError.invalidResponse
        }

        var request = URLRequest(url: url)
        applyCommonHeaders(to: &request, accept: "application/json")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SkillKitError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SkillKitError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw SkillKitError.requestFailed(
                code: http.statusCode,
                message: normalizedErrorMessage(from: data, response: http)
            )
        }

        if looksLikeHTMLDocument(data: data, response: http) {
            throw SkillKitError.requestFailed(
                code: http.statusCode,
                message: "Received HTML instead of JSON from skills API (\(baseURL.host ?? baseURL.absoluteString))"
            )
        }

        do {
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw SkillKitError.invalidResponse
        }
    }

    private func requestString(path: String) async throws -> String {
        var lastError: SkillKitError = .invalidResponse

        for baseURL in apiBaseURLs {
            do {
                return try await requestString(path: path, baseURL: baseURL)
            } catch let error as SkillKitError {
                lastError = error
            } catch {
                lastError = .networkError(error.localizedDescription)
            }
        }

        throw lastError
    }

    private func requestString(path: String, baseURL: URL) async throws -> String {
        guard let url = buildURL(baseURL: baseURL, path: path, queryItems: []) else {
            throw SkillKitError.invalidResponse
        }

        var request = URLRequest(url: url)
        applyCommonHeaders(to: &request, accept: "text/plain")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SkillKitError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SkillKitError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw SkillKitError.requestFailed(
                code: http.statusCode,
                message: normalizedErrorMessage(from: data, response: http)
            )
        }

        if looksLikeHTMLDocument(data: data, response: http) {
            throw SkillKitError.requestFailed(
                code: http.statusCode,
                message: "Received HTML instead of markdown from skills API (\(baseURL.host ?? baseURL.absoluteString))"
            )
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw SkillKitError.invalidResponse
        }
        return text
    }

    private func requestJSONAbsolute(url: URL) async throws -> Any {
        var request = URLRequest(url: url)
        applyCommonHeaders(to: &request, accept: "application/json")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SkillKitError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SkillKitError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw SkillKitError.requestFailed(
                code: http.statusCode,
                message: normalizedErrorMessage(from: data, response: http)
            )
        }
        if looksLikeHTMLDocument(data: data, response: http) {
            throw SkillKitError.invalidResponse
        }

        do {
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw SkillKitError.invalidResponse
        }
    }

    private func requestStringAbsolute(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        applyCommonHeaders(to: &request, accept: "text/plain")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SkillKitError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SkillKitError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw SkillKitError.requestFailed(
                code: http.statusCode,
                message: normalizedErrorMessage(from: data, response: http)
            )
        }
        if looksLikeHTMLDocument(data: data, response: http) {
            throw SkillKitError.invalidResponse
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw SkillKitError.invalidResponse
        }
        return text
    }

    private func requestDataAbsolute(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        applyCommonHeaders(to: &request, accept: "application/octet-stream")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SkillKitError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SkillKitError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw SkillKitError.requestFailed(
                code: http.statusCode,
                message: normalizedErrorMessage(from: data, response: http)
            )
        }
        if looksLikeHTMLDocument(data: data, response: http) {
            throw SkillKitError.invalidResponse
        }

        return data
    }

    private func applyCommonHeaders(to request: inout URLRequest, accept: String) {
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("PromptHubSkillKit/1.0", forHTTPHeaderField: "User-Agent")
        if let host = request.url?.host?.lowercased(),
           host.contains("github.com"),
           let githubToken {
            request.setValue("Bearer \(githubToken)", forHTTPHeaderField: "Authorization")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            if host == "api.github.com" {
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            }
        }
    }

    private func buildURL(baseURL: URL, path: String, queryItems: [URLQueryItem]) -> URL? {
        let route = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let fullPath: String
        if basePath.isEmpty {
            fullPath = "/\(route)"
        } else {
            fullPath = "/\(basePath)/\(route)"
        }
        components.path = fullPath.replacingOccurrences(of: "//", with: "/")

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        return components.url
    }

    private func fetchSkillMarkdown(owner: String, repo: String, skillName: String) async throws -> String {
        var lastError: SkillKitError = .invalidResponse
        for candidateSkillName in candidateSkillNames(
            owner: owner,
            repo: repo,
            requestedSkillName: skillName
        ) {
            let attempts = [
                "/api/skills/\(owner)/\(repo)/\(candidateSkillName)/content",
                "/api/skills/\(owner)/\(repo)/\(candidateSkillName)",
                "/skills/\(owner)/\(repo)/\(candidateSkillName)/content",
                "/skills/\(owner)/\(repo)/\(candidateSkillName)"
            ]

            for path in attempts {
                do {
                    let text = try await requestString(path: path)
                    if isLikelyMarkdown(text) {
                        return text
                    }
                } catch let error as SkillKitError {
                    lastError = error
                } catch {
                    lastError = .networkError(error.localizedDescription)
                }

                do {
                    let json = try await requestJSON(path: path)
                    if let markdown = extractSkillMarkdown(from: json), isLikelyMarkdown(markdown) {
                        return markdown
                    }
                } catch let error as SkillKitError {
                    lastError = error
                } catch {
                    lastError = .networkError(error.localizedDescription)
                }
            }

            if let markdown = try? await fetchSkillMarkdownFromGitHub(
                owner: owner,
                repo: repo,
                skillName: candidateSkillName
            ) {
                return markdown
            }
        }

        throw lastError
    }

    private func candidateSkillNames(
        owner: String,
        repo: String,
        requestedSkillName: String
    ) -> [String] {
        let requested = requestedSkillName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requested.isEmpty else {
            return []
        }

        let ownerTokens = normalizedPrefixTokens(from: owner)
        let repoTokens = normalizedPrefixTokens(from: repo)
        let prefixes = Array(Set(ownerTokens + repoTokens)).sorted { lhs, rhs in
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }
            return lhs < rhs
        }

        var ordered: [String] = []
        var queue = [requested]
        var seen = Set<String>()

        while let current = queue.first {
            queue.removeFirst()
            let lowered = current.lowercased()
            guard seen.insert(lowered).inserted else {
                continue
            }
            ordered.append(current)

            for prefix in prefixes {
                let loweredPrefix = prefix.lowercased()
                guard lowered.hasPrefix(loweredPrefix + "-") else {
                    continue
                }
                let stripped = String(current.dropFirst(prefix.count + 1))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
                if !stripped.isEmpty {
                    queue.append(stripped)
                }
            }
        }

        return ordered
    }

    private func normalizedPrefixTokens(from raw: String) -> [String] {
        let cleaned = raw
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return []
        }

        let segments = cleaned
            .split(separator: "-", omittingEmptySubsequences: true)
            .map(String.init)

        var tokens = [cleaned]
        tokens.append(contentsOf: segments)
        return tokens.filter { !$0.isEmpty }
    }

    private func looksLikeHTMLDocument(data: Data, response: HTTPURLResponse) -> Bool {
        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        if contentType.contains("text/html") {
            return true
        }
        guard let text = String(data: data.prefix(256), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return false
        }
        return text.hasPrefix("<!doctype html") || text.hasPrefix("<html")
    }

    private func normalizedErrorMessage(from data: Data, response: HTTPURLResponse) -> String {
        if looksLikeHTMLDocument(data: data, response: response) {
            return "Received HTML from skills API endpoint; please verify the API base URL"
        }

        if let json = try? JSONSerialization.jsonObject(with: data, options: []),
           let dictionary = json as? [String: Any] {
            if let text = firstString(in: dictionary, keys: ["error", "message", "detail"]) {
                return text
            }
        }

        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
        }

        if text.count > 240 {
            return String(text.prefix(240)) + "..."
        }
        return text
    }

    private func fetchSkillMarkdownFromGitHub(owner: String, repo: String, skillName: String) async throws -> String {
        let candidatePaths = [
            "skills/\(skillName)/SKILL.md",
            "\(skillName)/SKILL.md"
        ]
        let metadata = try? await fetchGitHubRepoMetadata(owner: owner, repo: repo)
        let branches = resolveCandidateBranches(preferred: metadata?.defaultBranch)
        var lastError: SkillKitError = .invalidResponse

        for branch in branches {
            for path in candidatePaths {
                guard let rawURL = buildRawGitHubURL(owner: owner, repo: repo, branch: branch, path: path) else {
                    continue
                }
                do {
                    let markdown = try await requestStringAbsolute(url: rawURL)
                    if isLikelyMarkdown(markdown) {
                        return markdown
                    }
                } catch let error as SkillKitError {
                    lastError = error
                } catch {
                    lastError = .networkError(error.localizedDescription)
                }
            }
        }

        for branch in branches {
            guard let path = try? await discoverSkillMarkdownPathViaGitHubTree(
                owner: owner,
                repo: repo,
                skillName: skillName,
                branch: branch
            ), let rawURL = buildRawGitHubURL(owner: owner, repo: repo, branch: branch, path: path) else {
                continue
            }

            do {
                let markdown = try await requestStringAbsolute(url: rawURL)
                guard isLikelyMarkdown(markdown) else {
                    continue
                }
                if path == "SKILL.md",
                   !matchesRequestedRepositoryRootSkill(markdown, requestedSkillName: skillName, repoName: repo) {
                    continue
                }
                return markdown
            } catch let error as SkillKitError {
                lastError = error
            } catch {
                lastError = .networkError(error.localizedDescription)
            }
        }

        throw lastError
    }

    private func fetchSkillPackageFromGitHub(owner: String, repo: String, skillName: String) async throws -> RemoteSkillPackage {
        let metadata = try? await fetchGitHubRepoMetadata(owner: owner, repo: repo)
        let branches = resolveCandidateBranches(preferred: metadata?.defaultBranch)
        var lastError: SkillKitError = .invalidResponse

        for branch in branches {
            do {
                let tree = try await loadGitHubTreeEntries(owner: owner, repo: repo, branch: branch)
                guard let skillMarkdownPath = discoverSkillMarkdownPath(in: tree, skillName: skillName) else {
                    continue
                }

                let packageRootPath = (skillMarkdownPath as NSString).deletingLastPathComponent
                let packagePrefix = packageRootPath.isEmpty ? "" : packageRootPath + "/"
                let packageBlobPaths = tree.compactMap { item -> String? in
                    guard let type = item["type"] as? String, type == "blob",
                          let path = item["path"] as? String else {
                        return nil
                    }

                    if path == skillMarkdownPath {
                        return path
                    }

                    guard !packagePrefix.isEmpty, path.hasPrefix(packagePrefix) else {
                        return nil
                    }
                    return path
                }
                .sorted()

                var files: [RemoteSkillPackageFile] = []
                var markdown: String?

                for path in packageBlobPaths {
                    guard let rawURL = buildRawGitHubURL(owner: owner, repo: repo, branch: branch, path: path) else {
                        continue
                    }

                    let data = try await requestDataAbsolute(url: rawURL)
                    let relativePath: String
                    if packageRootPath.isEmpty {
                        relativePath = path
                    } else {
                        relativePath = String(path.dropFirst(packagePrefix.count))
                    }
                    files.append(RemoteSkillPackageFile(relativePath: relativePath, data: data))

                    if relativePath.caseInsensitiveCompare("SKILL.md") == .orderedSame,
                       let decodedMarkdown = String(data: data, encoding: .utf8) {
                        markdown = decodedMarkdown
                    }
                }

                guard let markdown, isLikelyMarkdown(markdown) else {
                    continue
                }
                if skillMarkdownPath == "SKILL.md",
                   !matchesRequestedRepositoryRootSkill(markdown, requestedSkillName: skillName, repoName: repo) {
                    continue
                }
                return RemoteSkillPackage(markdown: markdown, files: files)
            } catch let error as SkillKitError {
                lastError = error
            } catch {
                lastError = .networkError(error.localizedDescription)
            }
        }

        throw lastError
    }

    private func discoverSkillMarkdownPathViaGitHubTree(
        owner: String,
        repo: String,
        skillName: String,
        branch: String
    ) async throws -> String? {
        let tree = try await loadGitHubTreeEntries(owner: owner, repo: repo, branch: branch)
        return discoverSkillMarkdownPath(in: tree, skillName: skillName)
    }

    private func loadGitHubTreeEntries(owner: String, repo: String, branch: String) async throws -> [[String: Any]] {
        guard var components = URLComponents(
            string: "https://api.github.com/repos/\(owner)/\(repo)/git/trees/\(branch)"
        ) else {
            throw SkillKitError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "recursive", value: "1")]
        guard let url = components.url else {
            throw SkillKitError.invalidResponse
        }

        let json = try await requestJSONAbsolute(url: url)
        guard let dictionary = json as? [String: Any],
              let tree = dictionary["tree"] as? [[String: Any]] else {
            throw SkillKitError.invalidResponse
        }

        return tree
    }

    private func discoverSkillMarkdownPath(in tree: [[String: Any]], skillName: String) -> String? {
        let lowerSkill = sanitizeSkillIdentifier(skillName)
        var fallbackPath: String?
        var repositoryRootPath: String?

        for item in tree {
            guard let type = item["type"] as? String, type == "blob",
                  let path = item["path"] as? String else {
                continue
            }

            let lowerPath = path.lowercased()
            guard lowerPath.hasSuffix("/skill.md") || lowerPath == "skill.md" else {
                continue
            }

            if lowerPath.hasSuffix("/\(lowerSkill)/skill.md") || lowerPath == "\(lowerSkill)/skill.md" {
                return path
            }

            if lowerPath == "skill.md" {
                repositoryRootPath = path
                continue
            }

            if fallbackPath == nil && (lowerPath.contains("/skills/") || lowerPath.contains(lowerSkill)) {
                fallbackPath = path
            }
        }

        return fallbackPath ?? repositoryRootPath
    }

    private func matchesRequestedRepositoryRootSkill(
        _ markdown: String,
        requestedSkillName: String,
        repoName: String
    ) -> Bool {
        let normalizedRequested = sanitizeSkillIdentifier(requestedSkillName)

        if let extractedName = extractSkillName(fromMarkdown: markdown) {
            return sanitizeSkillIdentifier(extractedName) == normalizedRequested
        }

        return sanitizeSkillIdentifier(repoName) == normalizedRequested
    }

    private func buildRawGitHubURL(owner: String, repo: String, branch: String, path: String) -> URL? {
        guard var components = URLComponents(string: "https://raw.githubusercontent.com") else {
            return nil
        }

        var finalPath = "/\(owner)/\(repo)/\(branch)"
        for segment in path.split(separator: "/") {
            finalPath += "/\(segment)"
        }
        components.path = finalPath
        return components.url
    }

    private func isLikelyMarkdown(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && (trimmed.contains("#") || trimmed.contains("---") || trimmed.contains("\n"))
    }

    private func parseFindAPIResponse(_ json: Any) -> [SkillInfo] {
        let items = extractSkillItemArray(from: json)
        var seen = Set<String>()
        var output: [SkillInfo] = []

        for item in items {
            guard let package = normalizeSkillPackage(from: item), !seen.contains(package) else {
                continue
            }
            seen.insert(package)

            let description = firstString(
                in: item,
                keys: [
                    "description",
                    "summary",
                    "excerpt",
                    "content.description",
                    "metadata.description"
                ]
            ) ?? "No description available"

        let owner = firstString(in: item, keys: ["owner", "repoOwner", "githubOwner", "source.owner"])
        var repo = firstString(in: item, keys: ["repo", "repository", "repoName", "source.repo"])
        let skill = firstString(in: item, keys: ["skill", "skillName", "slug", "skillId", "name"])
        if repo == nil,
           let source = firstString(in: item, keys: ["source"]),
           source.contains("/") {
            repo = source.split(separator: "/", maxSplits: 1).last.map(String.init)
        }
        let url = firstString(in: item, keys: ["url", "skillUrl", "webUrl"])
                ?? buildSkillURL(owner: owner, repo: repo, skillName: skill)

            output.append(
                SkillInfo(
                    name: package,
                    description: description,
                    isInstalled: false,
                    isGlobal: false,
                    url: url
                )
            )
        }

        return output
    }

    private func extractSkillItemArray(from json: Any) -> [[String: Any]] {
        if let array = json as? [[String: Any]] {
            return array
        }

        guard let dictionary = json as? [String: Any] else {
            return []
        }

        for key in ["skills", "items", "results", "data"] {
            if let array = dictionary[key] as? [[String: Any]] {
                return array
            }
            if let nested = dictionary[key] as? [String: Any] {
                for nestedKey in ["skills", "items", "results", "data"] {
                    if let array = nested[nestedKey] as? [[String: Any]] {
                        return array
                    }
                }
            }
        }

        return []
    }

    private func findSkillsFromCrawlerSnapshot(query: String) async throws -> [SkillInfo] {
        let snapshot = try await loadCrawlerSnapshot()
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let maxResults = needle.isEmpty ? 200 : 100

        let filtered = snapshot.skills.filter { skill in
            guard !needle.isEmpty else { return true }
            return skill.name.lowercased().contains(needle)
                || skill.skillId.lowercased().contains(needle)
                || skill.source.lowercased().contains(needle)
                || skill.owner.lowercased().contains(needle)
                || skill.repo.lowercased().contains(needle)
                || (skill.displayName?.lowercased().contains(needle) ?? false)
        }

        return filtered
            .sorted { $0.installs > $1.installs }
            .prefix(maxResults)
            .map { item in
                let package = "\(item.owner)/\(item.repo)@\(item.skillId)"
                let description = (item.displayName ?? item.name)
                    + (item.installs > 0 ? " • \(item.installs) installs" : "")
                let url = item.githubURL ?? buildSkillURL(owner: item.owner, repo: item.repo, skillName: item.skillId)

                return SkillInfo(
                    name: package,
                    description: description,
                    isInstalled: false,
                    isGlobal: false,
                    url: url
                )
            }
    }

    private func loadCrawlerSnapshot() async throws -> ScrapedRegistrySnapshot {
        var lastError: SkillKitError = .invalidResponse

        if let cached = try? loadCrawlerSnapshotCache() {
            if !isCrawlerCacheExpired(cached), isCrawlerSnapshotSufficient(cached) {
                return cached
            }

            if !isCrawlerSnapshotSufficient(cached) {
                try? fileManager.removeItem(at: crawlerCacheURL)
            }
        }

        for sourceURL in crawlerSnapshotURLs {
            do {
                let json = try await requestJSONAbsolute(url: sourceURL)
                let snapshot = try parseCrawlerSnapshot(json)
                try? saveCrawlerSnapshotCache(snapshot)
                return snapshot
            } catch let error as SkillKitError {
                lastError = error
            } catch {
                lastError = .networkError(error.localizedDescription)
            }
        }

        do {
            let crawled = try await crawlSkillsFromGitHub()
            try? saveCrawlerSnapshotCache(crawled)
            return crawled
        } catch let error as SkillKitError {
            lastError = error
        } catch {
            lastError = .networkError(error.localizedDescription)
        }

        if let cached = try? loadCrawlerSnapshotCache() {
            return cached
        }

        throw lastError
    }

    private func isCrawlerCacheExpired(_ snapshot: ScrapedRegistrySnapshot) -> Bool {
        guard let scrapedAt = snapshot.scrapedAt,
              let date = ISO8601DateFormatter().date(from: scrapedAt) else {
            return false
        }
        let maxAge: TimeInterval = 60 * 60 * 12
        return abs(date.timeIntervalSinceNow) > maxAge
    }

    private func isCrawlerSnapshotSufficient(_ snapshot: ScrapedRegistrySnapshot) -> Bool {
        let count = snapshot.totalSkills ?? snapshot.skills.count
        return count >= 100
    }

    private func crawlSkillsFromGitHub() async throws -> ScrapedRegistrySnapshot {
        var skills: [ScrapedRegistrySkill] = []
        var seen = Set<String>()
        var discoveredSources = Set<String>()

        for source in crawlerSeedRepos {
            let parts = source.split(separator: "/", maxSplits: 1).map(String.init)
            guard parts.count == 2 else {
                continue
            }

            let owner = parts[0]
            let repo = parts[1]
            let metadata = try? await fetchGitHubRepoMetadata(owner: owner, repo: repo)
            let fallbackURL = "https://github.com/\(owner)/\(repo)"
            let branches = resolveCandidateBranches(preferred: metadata?.defaultBranch)
            var treeEntries: [String] = []

            for branch in branches where treeEntries.isEmpty {
                if let entries = try? await fetchGitHubTreeSkillMarkdownPaths(owner: owner, repo: repo, branch: branch) {
                    treeEntries = entries
                }
            }

            guard !treeEntries.isEmpty else {
                continue
            }
            discoveredSources.insert("\(owner)/\(repo)")

            for path in treeEntries {
                let skillID = deriveSkillIDFromPath(path, repoName: repo)
                let package = "\(owner)/\(repo)@\(skillID)"
                guard !seen.contains(package.lowercased()) else {
                    continue
                }
                seen.insert(package.lowercased())

                skills.append(
                    ScrapedRegistrySkill(
                        source: "\(owner)/\(repo)",
                        skillId: skillID,
                        name: skillID,
                        installs: max(0, metadata?.stars ?? 0),
                        owner: owner,
                        repo: repo,
                        githubURL: metadata?.htmlURL ?? fallbackURL,
                        displayName: makeDisplayName(from: skillID)
                    )
                )
            }
        }

        if skills.isEmpty {
            throw SkillKitError.requestFailed(
                code: 503,
                message: "Crawler could not discover any skills from configured repositories"
            )
        }

        return ScrapedRegistrySnapshot(
            scrapedAt: ISO8601DateFormatter().string(from: Date()),
            totalSkills: skills.count,
            totalSources: discoveredSources.count,
            totalOwners: Set(skills.map(\.owner)).count,
            skills: skills.sorted { lhs, rhs in
                if lhs.installs != rhs.installs {
                    return lhs.installs > rhs.installs
                }
                return lhs.skillId.localizedCaseInsensitiveCompare(rhs.skillId) == .orderedAscending
            }
        )
    }

    private func fetchGitHubRepoMetadata(owner: String, repo: String) async throws -> GitHubRepoMetadata {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)") else {
            throw SkillKitError.invalidResponse
        }
        let json = try await requestJSONAbsolute(url: url)
        guard let dictionary = json as? [String: Any] else {
            throw SkillKitError.invalidResponse
        }
        let htmlURL = firstString(in: dictionary, keys: ["html_url"])
        let defaultBranch = firstString(in: dictionary, keys: ["default_branch"])
        let stars = (dictionary["stargazers_count"] as? Int)
            ?? (dictionary["stargazers_count"] as? NSNumber)?.intValue
            ?? 0
        return GitHubRepoMetadata(
            htmlURL: htmlURL,
            defaultBranch: defaultBranch,
            stars: stars
        )
    }

    private func fetchGitHubTreeSkillMarkdownPaths(owner: String, repo: String, branch: String) async throws -> [String] {
        guard var components = URLComponents(
            string: "https://api.github.com/repos/\(owner)/\(repo)/git/trees/\(branch)"
        ) else {
            throw SkillKitError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "recursive", value: "1")]
        guard let url = components.url else {
            throw SkillKitError.invalidResponse
        }

        let json = try await requestJSONAbsolute(url: url)
        guard let dictionary = json as? [String: Any],
              let tree = dictionary["tree"] as? [[String: Any]] else {
            throw SkillKitError.invalidResponse
        }

        return tree.compactMap { item in
            guard (item["type"] as? String) == "blob",
                  let path = item["path"] as? String else {
                return nil
            }
            let lower = path.lowercased()
            guard lower.hasSuffix("/skill.md") || lower == "skill.md" else {
                return nil
            }
            return path
        }
    }

    private func resolveCandidateBranches(preferred: String?) -> [String] {
        var branches: [String] = []
        if let preferred, !preferred.isEmpty {
            branches.append(preferred)
        }
        branches.append(contentsOf: ["main", "master"])
        var seen = Set<String>()
        return branches.filter { seen.insert($0.lowercased()).inserted }
    }

    private func deriveSkillIDFromPath(_ path: String, repoName: String) -> String {
        let segments = path.split(separator: "/").map(String.init)
        guard segments.count >= 2 else {
            return repoName
        }

        if let skillsIndex = segments.firstIndex(where: { $0.lowercased() == "skills" }),
           skillsIndex + 1 < segments.count {
            return sanitizeSkillIdentifier(segments[skillsIndex + 1])
        }

        let parent = segments[segments.count - 2]
        return sanitizeSkillIdentifier(parent)
    }

    private func sanitizeSkillIdentifier(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "skill"
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = trimmed.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "-"
        }.joined()
        return cleaned
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .lowercased()
    }

    private func makeDisplayName(from skillID: String) -> String {
        skillID
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { part in
                let text = String(part)
                return text.prefix(1).uppercased() + text.dropFirst()
            }
            .joined(separator: " ")
    }

    private func parseCrawlerSnapshot(_ json: Any) throws -> ScrapedRegistrySnapshot {
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            return try JSONDecoder().decode(ScrapedRegistrySnapshot.self, from: data)
        } catch {
            throw SkillKitError.invalidResponse
        }
    }

    private func saveCrawlerSnapshotCache(_ snapshot: ScrapedRegistrySnapshot) throws {
        do {
            let folder = crawlerCacheURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: folder.path) {
                try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: crawlerCacheURL, options: .atomic)
        } catch {
            throw SkillKitError.fileIOError(error.localizedDescription)
        }
    }

    private func loadCrawlerSnapshotCache() throws -> ScrapedRegistrySnapshot {
        do {
            let data = try Data(contentsOf: crawlerCacheURL)
            return try JSONDecoder().decode(ScrapedRegistrySnapshot.self, from: data)
        } catch {
            throw SkillKitError.fileIOError(error.localizedDescription)
        }
    }

    private func discoverLocalInstalledSkills() -> [SkillInfo] {
        var output: [SkillInfo] = []
        let sourceMap = skillSourcesFromSkillLockFiles()

        for root in localSkillRoots {
            let resolvedRoot = root.resolvingSymlinksInPath()
            guard fileManager.fileExists(atPath: resolvedRoot.path) else {
                continue
            }
            let inferredScope = inferScope(fromLocalRoot: root)
            let rootAgents = inferAgents(fromLocalRoot: root)

            guard let enumerator = fileManager.enumerator(
                at: resolvedRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                guard fileURL.lastPathComponent.lowercased() == "skill.md" else {
                    continue
                }

                let skillName = fileURL.deletingLastPathComponent().lastPathComponent
                guard !skillName.isEmpty, !skillName.hasPrefix(".") else {
                    continue
                }

                let resolvedPackageName: String = {
                    let lookupKeys = [skillName.lowercased(), sanitizeSkillIdentifier(skillName).lowercased()]
                    for key in lookupKeys {
                        if let source = sourceMap[key], source.contains("/") {
                            return "\(source)@\(skillName)"
                        }
                    }
                    return skillName
                }()

                let markdown = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
                var description = extractDescription(fromMarkdown: markdown)
                if description.isEmpty {
                    let sourceLabel = resolvedRoot.deletingLastPathComponent().lastPathComponent
                    description = sourceLabel.isEmpty ? "Local skill" : "Local skill (\(sourceLabel))"
                }
                let inferredAgents = inferAgentsForSkill(
                    folderName: skillName,
                    isGlobal: inferredScope == .global
                )
                let agents = Array(Set(inferredAgents + rootAgents))
                    .sorted { $0.rawValue < $1.rawValue }

                output.append(
                    SkillInfo(
                        name: resolvedPackageName,
                        description: description,
                        isInstalled: true,
                        isGlobal: inferredScope == .global,
                        url: nil,
                        installedAgents: agents,
                        installedScopes: [inferredScope],
                        isManagedByPromptHub: false,
                        installedPaths: [fileURL.deletingLastPathComponent().path]
                    )
                )
            }
        }

        return mergeInstalledEntries(output).sorted { lhs, rhs in
            if lhs.isGlobal != rhs.isGlobal {
                return !lhs.isGlobal && rhs.isGlobal
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func discoverManagedInstalledSkills() -> [SkillInfo] {
        guard fileManager.fileExists(atPath: installRootURL.path) else {
            return []
        }

        var output: [SkillInfo] = []
        var seen = Set<String>()

        guard let enumerator = fileManager.enumerator(
            at: installRootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent.lowercased() == "skill.md" else {
                continue
            }
            guard let relativePath = relativePath(from: installRootURL, to: fileURL) else {
                continue
            }

            let components = relativePath.split(separator: "/").map(String.init)
            guard components.count >= 4 else {
                continue
            }
            let scope = components[0].lowercased()
            let agent = components[1]
            let folderName = components[2]
            let isGlobal = scope == "global"

            let markdown = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            var skillName = extractSkillName(fromMarkdown: markdown)
            if skillName == nil || skillName?.isEmpty == true {
                skillName = folderName
            }
            let resolvedName = (skillName ?? folderName).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !resolvedName.isEmpty else {
                continue
            }

            let dedupeKey = "\(canonicalPackageName(resolvedName))|\(isGlobal)|\(agent)"
            guard !seen.contains(dedupeKey) else {
                continue
            }
            seen.insert(dedupeKey)

            var description = extractDescription(fromMarkdown: markdown)
            if description.isEmpty {
                description = "Installed by PromptHub (\(agent))"
            } else {
                description += " (\(agent))"
            }

            output.append(
                SkillInfo(
                    name: resolvedName,
                    description: description,
                    isInstalled: true,
                    isGlobal: isGlobal,
                    url: nil,
                    installedAgents: AgentWorkflow(rawValue: agent).map { [$0] } ?? [],
                    installedScopes: [isGlobal ? .global : .project],
                    isManagedByPromptHub: true,
                    installedPaths: [fileURL.deletingLastPathComponent().path]
                )
            )
        }

        return output.sorted { lhs, rhs in
            if lhs.isGlobal != rhs.isGlobal {
                return !lhs.isGlobal && rhs.isGlobal
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func relativePath(from root: URL, to file: URL) -> String? {
        let rootPath = root.standardizedFileURL.path
        let filePath = file.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else {
            return nil
        }
        let suffix = filePath.dropFirst(rootPath.count)
        return String(suffix).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func inferAgents(fromLocalRoot root: URL) -> [AgentWorkflow] {
        let normalizedRoot = root.resolvingSymlinksInPath().standardizedFileURL.path.lowercased()
        var agents: [AgentWorkflow] = []
        for workflow in AgentWorkflow.allCases {
            guard let roots = agentSkillRoots[workflow] else {
                continue
            }
            let globalPath = roots.global.resolvingSymlinksInPath().standardizedFileURL.path.lowercased()
            let projectPath = roots.project.resolvingSymlinksInPath().standardizedFileURL.path.lowercased()
            if normalizedRoot == globalPath || normalizedRoot == projectPath {
                agents.append(workflow)
            }
        }
        if agents.isEmpty {
            agents.append(contentsOf: inferAgentsFromSharedLocalRoot(root))
        }
        return Array(Set(agents)).sorted { $0.rawValue < $1.rawValue }
    }

    private func inferAgentsForSkill(folderName: String, isGlobal: Bool) -> [AgentWorkflow] {
        var agents: [AgentWorkflow] = []
        for workflow in AgentWorkflow.allCases {
            guard let roots = agentSkillRoots[workflow] else {
                continue
            }
            let base = isGlobal ? roots.global : roots.project
            let fileURL = base
                .appendingPathComponent(folderName, isDirectory: true)
                .appendingPathComponent("SKILL.md")
            if fileManager.fileExists(atPath: fileURL.path) {
                agents.append(workflow)
            }
        }
        return Array(Set(agents)).sorted { $0.rawValue < $1.rawValue }
    }

    private func inferScope(fromLocalRoot root: URL) -> SkillInstallScope {
        let originalPath = root.standardizedFileURL.path
        let resolvedPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        for workflow in AgentWorkflow.allCases {
            guard let roots = agentSkillRoots[workflow] else {
                continue
            }
            let projectPath = roots.project.standardizedFileURL.path
            let resolvedProjectPath = roots.project.resolvingSymlinksInPath().standardizedFileURL.path
            if originalPath == projectPath || resolvedPath == resolvedProjectPath {
                return .project
            }
        }
        return .global
    }

    private func inferAgentsFromSharedLocalRoot(_ root: URL) -> [AgentWorkflow] {
        guard isSharedLocalRoot(root) else {
            return []
        }

        let lockFileAgents = selectedAgentsFromSkillLockFile()
        let activeAgents = activeAgentsFromConfiguredRoots()
        if !lockFileAgents.isEmpty || !activeAgents.isEmpty {
            return Array(Set(lockFileAgents + activeAgents))
                .sorted { $0.rawValue < $1.rawValue }
        }

        return [.codex, .geminiCLI, .opencode]
    }

    private func activeAgentsFromConfiguredRoots() -> [AgentWorkflow] {
        var agents: [AgentWorkflow] = []
        for workflow in AgentWorkflow.allCases {
            guard let roots = agentSkillRoots[workflow] else {
                continue
            }
            let globalRoot = roots.global
            guard fileManager.fileExists(atPath: globalRoot.path) else {
                continue
            }

            guard let children = try? fileManager.contentsOfDirectory(
                at: globalRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            let hasSkill = children.contains { child in
                let isDirectory = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDirectory else { return false }
                let skillFile = child.appendingPathComponent("SKILL.md")
                return fileManager.fileExists(atPath: skillFile.path)
            }

            if hasSkill {
                agents.append(workflow)
            }
        }

        return Array(Set(agents)).sorted { $0.rawValue < $1.rawValue }
    }

    private func isSharedLocalRoot(_ root: URL) -> Bool {
        let normalizedRoot = root.resolvingSymlinksInPath().standardizedFileURL.path.lowercased()
        return sharedLocalRoots.contains {
            $0.resolvingSymlinksInPath().standardizedFileURL.path.lowercased() == normalizedRoot
        }
    }

    private func selectedAgentsFromSkillLockFile() -> [AgentWorkflow] {
        for lockFile in skillLockFileURLs {
            guard let data = try? Data(contentsOf: lockFile) else {
                continue
            }

            if let snapshot = try? JSONDecoder().decode(SkillLockSnapshot.self, from: data),
               let selected = snapshot.lastSelectedAgents {
                let mapped = mapWorkflows(from: selected)
                if !mapped.isEmpty {
                    return mapped
                }
            }

            if let object = try? JSONSerialization.jsonObject(with: data, options: []),
               let dict = object as? [String: Any],
               let selected = dict["lastSelectedAgents"] as? [String] {
                let mapped = mapWorkflows(from: selected)
                if !mapped.isEmpty {
                    return mapped
                }
            }
        }

        return []
    }

    private func skillSourcesFromSkillLockFiles() -> [String: String] {
        var sources: [String: String] = [:]

        for lockFile in skillLockFileURLs {
            guard let data = try? Data(contentsOf: lockFile) else {
                continue
            }

            if let snapshot = try? JSONDecoder().decode(SkillLockSnapshot.self, from: data),
               let entries = snapshot.skills {
                for (skill, entry) in entries {
                    guard let source = entry.source?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !source.isEmpty,
                          source.contains("/") else {
                        continue
                    }
                    sources[skill.lowercased()] = source
                }
            }

            if let object = try? JSONSerialization.jsonObject(with: data, options: []),
               let dict = object as? [String: Any],
               let skills = dict["skills"] as? [String: Any] {
                for (skill, rawEntry) in skills {
                    guard let entry = rawEntry as? [String: Any],
                          let source = (entry["source"] as? String)?
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                          !source.isEmpty,
                          source.contains("/") else {
                        continue
                    }
                    sources[skill.lowercased()] = source
                }
            }
        }

        return sources
    }

    private func mapWorkflows(from rawAgents: [String]) -> [AgentWorkflow] {
        let mapped = rawAgents.compactMap(mapWorkflow)
        return Array(Set(mapped)).sorted { $0.rawValue < $1.rawValue }
    }

    private func mapWorkflow(_ rawAgent: String) -> AgentWorkflow? {
        let normalized = rawAgent
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        switch normalized {
        case "codex":
            return .codex
        case "codex-cli":
            return .codex
        case "claude", "claude-code", "claudecode":
            return .claudeCode
        case "cursor":
            return .cursor
        case "gemini", "gemini-cli":
            return .geminiCLI
        case "iflow", "iflow-cli":
            return .iflow
        case "opencode", "open-code", "opencode-cli":
            return .opencode
        case "qwen", "qwen-code", "qwen-cli":
            return .qwenCode
        case "qoder":
            return .qoder
        default:
            return nil
        }
    }

    private func mergeInstalledEntries(_ entries: [SkillInfo]) -> [SkillInfo] {
        guard !entries.isEmpty else { return [] }

        var mergedByKey: [String: SkillInfo] = [:]
        for entry in entries {
            let key = "\(canonicalPackageName(entry.name))|\(entry.isGlobal)"
            if var existing = mergedByKey[key] {
                existing.isInstalled = existing.isInstalled || entry.isInstalled

                let incomingDescription = entry.description.trimmingCharacters(in: .whitespacesAndNewlines)
                let existingDescription = existing.description.trimmingCharacters(in: .whitespacesAndNewlines)
                if existingDescription.isEmpty, !incomingDescription.isEmpty {
                    existing = SkillInfo(
                        name: existing.name,
                        description: incomingDescription,
                        isInstalled: existing.isInstalled,
                        isGlobal: existing.isGlobal,
                        url: existing.url ?? entry.url,
                        installedAgents: Array(Set(existing.installedAgents + entry.installedAgents)).sorted { $0.rawValue < $1.rawValue },
                        installedScopes: sortedScopes(Array(Set(existing.installedScopes + entry.installedScopes))),
                        isManagedByPromptHub: existing.isManagedByPromptHub || entry.isManagedByPromptHub,
                        installedPaths: Array(Set(existing.installedPaths + entry.installedPaths)).sorted()
                    )
                } else {
                    existing.url = existing.url ?? entry.url
                    existing.installedAgents = Array(Set(existing.installedAgents + entry.installedAgents)).sorted { $0.rawValue < $1.rawValue }
                    existing.installedScopes = sortedScopes(Array(Set(existing.installedScopes + entry.installedScopes)))
                    existing.isManagedByPromptHub = existing.isManagedByPromptHub || entry.isManagedByPromptHub
                    existing.installedPaths = Array(Set(existing.installedPaths + entry.installedPaths)).sorted()
                }
                mergedByKey[key] = existing
            } else {
                var normalized = entry
                if normalized.installedScopes.isEmpty {
                    normalized.installedScopes = [normalized.isGlobal ? .global : .project]
                }
                mergedByKey[key] = normalized
            }
        }

        return Array(mergedByKey.values)
    }

    private func sortedScopes(_ scopes: [SkillInstallScope]) -> [SkillInstallScope] {
        scopes.sorted { lhs, rhs in
            switch (lhs, rhs) {
            case (.project, .global):
                return true
            case (.global, .project):
                return false
            default:
                return lhs.rawValue < rhs.rawValue
            }
        }
    }

    private func canonicalPackageName(_ package: String) -> String {
        if let qualified = normalizedQualifiedPackage(package) {
            return qualified
        }
        let shortName = shortSkillName(fromPackage: package)
        let sanitized = sanitizeSkillIdentifier(shortName)
        if !sanitized.isEmpty {
            return sanitized.lowercased()
        }
        return shortName.lowercased()
    }

    private func normalizedQualifiedPackage(_ package: String) -> String? {
        let trimmed = package.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let at = trimmed.lastIndex(of: "@"),
              at < trimmed.index(before: trimmed.endIndex) else {
            return nil
        }

        let source = String(trimmed[..<at])
        let skill = String(trimmed[trimmed.index(after: at)...])
        let sourceParts = source.split(separator: "/", maxSplits: 1).map(String.init)
        guard sourceParts.count == 2,
              !sourceParts[0].isEmpty,
              !sourceParts[1].isEmpty,
              !skill.isEmpty else {
            return nil
        }

        return "\(sourceParts[0].lowercased())/\(sourceParts[1].lowercased())@\(skill.lowercased())"
    }

    private func shortSkillName(fromPackage package: String) -> String {
        let trimmed = package.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = trimmed.lastIndex(of: "@"), at < trimmed.index(before: trimmed.endIndex) else {
            return trimmed
        }
        return String(trimmed[trimmed.index(after: at)...])
    }

    private func normalizeSkillPackage(from item: [String: Any]) -> String? {
        if let package = firstString(in: item, keys: ["package", "identifier", "fullName"]),
           package.contains("/") && package.contains("@") {
            return package
        }

        if let name = firstString(in: item, keys: ["name"]), name.contains("/") && name.contains("@") {
            return name
        }

        let owner = firstString(in: item, keys: ["owner", "repoOwner", "githubOwner", "source.owner"])
        var repo = firstString(in: item, keys: ["repo", "repository", "repoName", "source.repo"])
        let skill = firstString(in: item, keys: ["skill", "skillName", "slug", "skillId", "name"])

        if repo == nil,
           let source = firstString(in: item, keys: ["source"]),
           source.contains("/") {
            repo = source.split(separator: "/", maxSplits: 1).last.map(String.init)
        }

        if let owner, let repo, let skill {
            return "\(owner)/\(repo)@\(skill)"
        }

        return nil
    }

    private func extractSkillMarkdown(from json: Any) -> String? {
        if let text = json as? String {
            return text
        }

        guard let dictionary = json as? [String: Any] else {
            return nil
        }

        if let direct = firstString(in: dictionary, keys: ["markdown", "raw", "content"]) {
            return direct
        }

        if let content = dictionary["content"] as? [String: Any] {
            if let direct = firstString(in: content, keys: ["markdown", "raw", "content", "body", "instructions"]) {
                return direct
            }
            if let instructions = firstString(in: content, keys: ["instructions", "body"]) {
                let frontmatter = content["frontmatter"] as? [String: Any] ?? [:]
                return makeSkillMarkdown(frontmatter: frontmatter, instructions: instructions)
            }
        }

        if let data = dictionary["data"] {
            return extractSkillMarkdown(from: data)
        }

        return nil
    }

    private func extractSkillName(fromMarkdown markdown: String) -> String? {
        if let name = SkillMarkdownDocument.stringValue(for: "name", in: markdown) {
            return name
        }

        let lines = markdown.components(separatedBy: .newlines)

        if let heading = lines.first(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#") }) {
            let value = heading.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "# "))
            return value.isEmpty ? nil : value
        }

        return nil
    }

    private func makeSkillMarkdown(frontmatter: [String: Any], instructions: String) -> String {
        guard !frontmatter.isEmpty else {
            return instructions
        }

        return SkillMarkdownDocument.generate(metadata: frontmatter, instructions: instructions)
    }

    private func extractDescription(fromMarkdown markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return ""
        }

        var index = 1
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if line == "---" {
                break
            }
            if line.lowercased().hasPrefix("description:") {
                return line
                    .dropFirst("description:".count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            index += 1
        }

        return ""
    }

    private func parsePackage(_ package: String) throws -> ParsedPackage {
        let trimmed = package.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            throw SkillKitError.invalidSkillPackage
        }

        let source = parts[0]
        let skill = parts[1]
        let sourceParts = source.split(separator: "/", maxSplits: 1).map(String.init)
        guard sourceParts.count == 2 else {
            throw SkillKitError.invalidSkillPackage
        }

        return ParsedPackage(owner: sourceParts[0], repo: sourceParts[1], skill: skill)
    }

    private func firstString(in dictionary: [String: Any], keys: [String]) -> String? {
        for keyPath in keys {
            let segments = keyPath.split(separator: ".").map(String.init)
            if let value = value(in: dictionary, keyPath: segments) as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private func value(in dictionary: [String: Any], keyPath: [String]) -> Any? {
        guard let first = keyPath.first else {
            return nil
        }

        if keyPath.count == 1 {
            return dictionary[first]
        }

        guard let nested = dictionary[first] as? [String: Any] else {
            return nil
        }

        return value(in: nested, keyPath: Array(keyPath.dropFirst()))
    }

    private func buildSkillURL(owner: String?, repo: String?, skillName: String?) -> String? {
        guard let owner, let repo, let skillName else {
            return nil
        }
        return "https://skills.sh/\(owner)/\(repo)/\(skillName)"
    }

    private func loadInstalledRecords() throws -> [InstalledSkillRecord] {
        do {
            guard fileManager.fileExists(atPath: registryURL.path) else {
                return []
            }
            let data = try Data(contentsOf: registryURL)
            return try JSONDecoder().decode([InstalledSkillRecord].self, from: data)
        } catch {
            throw SkillKitError.fileIOError(error.localizedDescription)
        }
    }

    private func loadInstalledRecordsLenient() -> [InstalledSkillRecord] {
        (try? loadInstalledRecords()) ?? []
    }

    private func saveInstalledRecords(_ records: [InstalledSkillRecord]) throws {
        do {
            let folder = registryURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: folder.path) {
                try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            }

            let data = try JSONEncoder().encode(records)
            try data.write(to: registryURL, options: .atomic)
        } catch {
            throw SkillKitError.fileIOError(error.localizedDescription)
        }
    }

    private func writeManagedSkillMarkdown(
        _ markdown: String,
        package: String,
        packageFiles: [RemoteSkillPackageFile]? = nil,
        agent: AgentWorkflow,
        isGlobal: Bool
    ) throws -> String {
        try writeManagedSkillPackage(
            markdown,
            package: package,
            packageDirectoryURL: nil,
            packageFiles: packageFiles,
            agent: agent,
            isGlobal: isGlobal
        )
    }

    private func writeManagedSkillPackage(
        _ markdown: String,
        package: String,
        packageDirectoryURL: URL?,
        packageFiles: [RemoteSkillPackageFile]? = nil,
        agent: AgentWorkflow,
        isGlobal: Bool
    ) throws -> String {
        let scope = isGlobal ? "global" : "project"
        let packageFolder = sanitizePathComponent(package)
        let relativeDir = "\(scope)/\(agent.rawValue)/\(packageFolder)"
        let targetDir = installRootURL.appendingPathComponent(relativeDir, isDirectory: true)

        try writeSkillPackageContents(
            markdown: markdown,
            packageDirectoryURL: packageDirectoryURL,
            packageFiles: packageFiles,
            to: targetDir
        )

        return relativeDir
    }

    private func writeSkillPackageContents(
        markdown: String,
        packageDirectoryURL: URL?,
        packageFiles: [RemoteSkillPackageFile]? = nil,
        to targetDir: URL
    ) throws {
        let parentDirectory = targetDir.deletingLastPathComponent()

        do {
            if !fileManager.fileExists(atPath: parentDirectory.path) {
                try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
            }

            if fileManager.fileExists(atPath: targetDir.path) {
                try fileManager.removeItem(at: targetDir)
            }

            if let packageDirectoryURL {
                try fileManager.copyItem(at: packageDirectoryURL, to: targetDir)
            } else if let packageFiles, !packageFiles.isEmpty {
                try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
                for packageFile in packageFiles {
                    let relativePath = packageFile.relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !relativePath.isEmpty, !relativePath.contains("..") else {
                        continue
                    }

                    let fileURL = targetDir.appendingPathComponent(relativePath)
                    let fileParent = fileURL.deletingLastPathComponent()
                    if !fileManager.fileExists(atPath: fileParent.path) {
                        try fileManager.createDirectory(at: fileParent, withIntermediateDirectories: true)
                    }
                    try packageFile.data.write(to: fileURL, options: .atomic)
                }

                let skillFileURL = targetDir.appendingPathComponent("SKILL.md")
                if !fileManager.fileExists(atPath: skillFileURL.path) {
                    try markdown.write(to: skillFileURL, atomically: true, encoding: .utf8)
                }
            } else {
                try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
                let fileURL = targetDir.appendingPathComponent("SKILL.md")
                try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            throw SkillKitError.fileIOError(error.localizedDescription)
        }
    }

    private func writeExternalSkillMarkdown(
        _ markdown: String,
        package: String,
        packageFiles: [RemoteSkillPackageFile]? = nil,
        agent: AgentWorkflow,
        isGlobal: Bool
    ) throws {
        try writeExternalSkillPackage(
            markdown,
            package: package,
            packageDirectoryURL: nil,
            packageFiles: packageFiles,
            agent: agent,
            isGlobal: isGlobal
        )
    }

    private func writeExternalSkillPackage(
        _ markdown: String,
        package: String,
        packageDirectoryURL: URL?,
        packageFiles: [RemoteSkillPackageFile]? = nil,
        agent: AgentWorkflow,
        isGlobal: Bool
    ) throws {
        let targetDir = externalSkillDirectory(package: package, agent: agent, isGlobal: isGlobal)
        try writeSkillPackageContents(
            markdown: markdown,
            packageDirectoryURL: packageDirectoryURL,
            packageFiles: packageFiles,
            to: targetDir
        )
    }

    private func externalSkillDirectory(package: String, agent: AgentWorkflow, isGlobal: Bool) -> URL {
        let roots = agentSkillRoots[agent]
        let base = isGlobal ? roots?.global : roots?.project
        let fallback = (isGlobal ? installRootURL.appendingPathComponent("external-global", isDirectory: true)
            : installRootURL.appendingPathComponent("external-project", isDirectory: true))
        let packageFolder = sanitizePathComponent(shortSkillName(fromPackage: package))
        return (base ?? fallback).appendingPathComponent(packageFolder, isDirectory: true)
    }

    private func discoverExternalInstalledAgents(
        package: String,
        isGlobal: Bool
    ) -> [AgentWorkflow] {
        var agents: [AgentWorkflow] = []
        for workflow in AgentWorkflow.allCases {
            let path = externalSkillDirectory(package: package, agent: workflow, isGlobal: isGlobal)
            let skillFile = path.appendingPathComponent("SKILL.md")
            if fileManager.fileExists(atPath: skillFile.path) {
                agents.append(workflow)
            }
        }
        return agents
    }

    private func removeDirectoryIfExists(_ path: URL) throws {
        guard fileManager.fileExists(atPath: path.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: path)
        } catch {
            throw SkillKitError.fileIOError(error.localizedDescription)
        }
    }

    private func sanitizePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "_"
        }.joined()
    }
}
