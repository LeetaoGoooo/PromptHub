import AppKit
import Foundation
import PromptHubSkillKit

enum CLIDirectory: String, CaseIterable, Identifiable {
    case agents = ".agents"
    case claude = ".claude"
    case codex = ".codex"
    case cursor = ".cursor"
    case gemini = ".gemini"
    case iflow = ".iflow"
    case opencode = ".config/opencode"
    case qwen = ".qwen"
    case qoder = ".qoder"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .agents: return "PromptHub (.agents)"
        case .claude: return "Claude Code (.claude)"
        case .codex: return "Codex (.codex)"
        case .cursor: return "Cursor (.cursor)"
        case .gemini: return "Gemini CLI (.gemini)"
        case .iflow: return "iFlow CLI (.iflow)"
        case .opencode: return "OpenCode (.config/opencode)"
        case .qwen: return "Qwen (.qwen)"
        case .qoder: return "Qoder (.qoder)"
        }
    }
}

final class CLIDirectoryAccessManager: ObservableObject, @unchecked Sendable {
    static let shared = CLIDirectoryAccessManager()
    
    private let defaults: UserDefaults
    
    @Published var grantedDirectories: Set<CLIDirectory> = []
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.grantedDirectories = Set(CLIDirectory.allCases.filter { self.hasAccess(to: $0) })
    }
    
    private func bookmarkKey(for directory: CLIDirectory) -> String {
        return "cliAccessBookmark.\(directory.rawValue)"
    }
    
    var anyAccessGranted: Bool {
        !grantedDirectories.isEmpty
    }
    
    func hasAccess(to directory: CLIDirectory) -> Bool {
        resolvedURL(for: directory) != nil
    }
    
    func resolvedURL(for directory: CLIDirectory) -> URL? {
        guard let data = defaults.data(forKey: bookmarkKey(for: directory)) else { return nil }
        var isStale = false
        let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale, let url {
            refreshBookmark(from: url, for: directory)
        }
        return url
    }
    
    @discardableResult
    @MainActor
    func requestAccess(for directory: CLIDirectory) -> Bool {
        guard let pwDir = getpwuid(getuid())?.pointee.pw_dir else { return false }
        let realHomePath = String(cString: pwDir)
        let realHomeURL = URL(fileURLWithPath: realHomePath, isDirectory: true)
        
        let targetURL: URL
        if directory == .opencode {
            targetURL = realHomeURL.appendingPathComponent(".config", isDirectory: true).appendingPathComponent("opencode", isDirectory: true)
        } else {
            targetURL = realHomeURL.appendingPathComponent(directory.rawValue, isDirectory: true)
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant"
        panel.message = "Please allow PromptBox to access the \(directory.rawValue) folder in your Home directory.\nYou may need to press Cmd + Shift + . to see hidden folders."
        panel.directoryURL = targetURL

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }
        
        let success = saveBookmark(for: url, directory: directory)
        if success {
            grantedDirectories.insert(directory)
        }
        return success
    }
    
    @MainActor
    func revokeAccess(for directory: CLIDirectory) {
        defaults.removeObject(forKey: bookmarkKey(for: directory))
        grantedDirectories.remove(directory)
    }

    func withAccess<T: Sendable>(_ work: @Sendable () async throws -> T) async rethrows -> T {
        let urls = CLIDirectory.allCases.compactMap { resolvedURL(for: $0) }
        let started = urls.map { $0.startAccessingSecurityScopedResource() }
        defer {
            for (url, didStart) in zip(urls, started) where didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try await work()
    }
    
    private func saveBookmark(for url: URL, directory: CLIDirectory) -> Bool {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return false }
        defaults.set(data, forKey: bookmarkKey(for: directory))
        return true
    }
    
    private func refreshBookmark(from url: URL, for directory: CLIDirectory) {
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        saveBookmark(for: url, directory: directory)
    }
    
    // MARK: - SkillCatalogService Integration
    
    func makeCatalog(
        session: URLSession,
        fileManager: FileManager,
        apiBaseURL: URL?,
        installRootURL: URL?,
        projectRootURL: URL?
    ) -> SkillCatalogService {
        
        let sandboxHome = fileManager.homeDirectoryForCurrentUser
        
        func urlFor(_ dir: CLIDirectory) -> URL {
            resolvedURL(for: dir) ?? sandboxHome.appendingPathComponent(dir.rawValue, isDirectory: true)
        }
        
        let agentsURL = urlFor(.agents)
        let claudeURL = urlFor(.claude)
        let codexURL = urlFor(.codex)
        let cursorURL = urlFor(.cursor)
        let geminiURL = urlFor(.gemini)
        let iflowURL = urlFor(.iflow)
        let opencodeURL = urlFor(.opencode)
        let qwenURL = urlFor(.qwen)
        let qoderURL = urlFor(.qoder)
        
        let pRoot = projectRootURL ?? URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        
        let customRoots: [AgentWorkflow: AgentSkillRoots] = [
            .codex: AgentSkillRoots(global: codexURL.appendingPathComponent("skills", isDirectory: true), project: pRoot.appendingPathComponent(".agents/skills", isDirectory: true)),
            .claudeCode: AgentSkillRoots(global: claudeURL.appendingPathComponent("skills", isDirectory: true), project: pRoot.appendingPathComponent(".claude/skills", isDirectory: true)),
            .cursor: AgentSkillRoots(global: cursorURL.appendingPathComponent("skills", isDirectory: true), project: pRoot.appendingPathComponent(".cursor/skills", isDirectory: true)),
            .geminiCLI: AgentSkillRoots(global: geminiURL.appendingPathComponent("skills", isDirectory: true), project: pRoot.appendingPathComponent(".agents/skills", isDirectory: true)),
            .iflow: AgentSkillRoots(global: iflowURL.appendingPathComponent("skills", isDirectory: true), project: pRoot.appendingPathComponent(".iflow/skills", isDirectory: true)),
            .opencode: AgentSkillRoots(global: opencodeURL.appendingPathComponent("skills", isDirectory: true), project: pRoot.appendingPathComponent(".agents/skills", isDirectory: true)),
            .qwenCode: AgentSkillRoots(global: qwenURL.appendingPathComponent("skills", isDirectory: true), project: pRoot.appendingPathComponent(".qwen/skills", isDirectory: true)),
            .qoder: AgentSkillRoots(global: qoderURL.appendingPathComponent("skills", isDirectory: true), project: pRoot.appendingPathComponent(".qoder/skills", isDirectory: true))
        ]
        
        var finalLocalRoots: [URL] = [
            agentsURL.appendingPathComponent("skills", isDirectory: true),
            sandboxHome.appendingPathComponent(".config/agents/skills", isDirectory: true)
        ]
        finalLocalRoots.append(contentsOf: AgentWorkflow.allCases.compactMap { customRoots[$0]?.global })
        finalLocalRoots.append(contentsOf: AgentWorkflow.allCases.compactMap { customRoots[$0]?.project })
        
        let customSharedLocalRoots: [URL] = [
            agentsURL.appendingPathComponent("skills", isDirectory: true),
            sandboxHome.appendingPathComponent(".config/agents/skills", isDirectory: true)
        ]
        
        let customLockFiles: [URL] = [
            agentsURL.appendingPathComponent(".skill-lock.json"),
            sandboxHome.appendingPathComponent(".config/agents/.skill-lock.json"),
            agentsURL.appendingPathComponent("skills/.skill-lock.json"),
            sandboxHome.appendingPathComponent(".config/agents/skills/.skill-lock.json")
        ]
        
        return SkillCatalogService(
            session: session,
            fileManager: fileManager,
            apiBaseURL: apiBaseURL,
            installRootURL: installRootURL,
            projectRootURL: projectRootURL,
            agentSkillRoots: customRoots,
            localSkillRoots: finalLocalRoots,
            sharedLocalRoots: customSharedLocalRoots,
            skillLockFileURLs: customLockFiles
        )
    }
}
