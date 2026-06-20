import ArgumentParser
import Foundation
import PromptHubCLILib
import PromptHubSkillKit

@main
struct PromptHubCLICommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ph",
        abstract: "Interact with PromptHub exports and manage CLI agent skills.",
        version: PromptHubCLIVersion,
        subcommands: [
            PromptCommand.self,
            SkillCommand.self,
            DoctorCommand.self
        ]
    )
}

struct CommonOptions: ParsableArguments {
    @Option(name: .long, help: "Override the home directory used to resolve ~/.prompthub and agent folders.")
    var home: String?

    @Option(name: .long, help: "Override PromptHub's managed skills root.")
    var installRoot: String?

    func makeEnvironment(projectRootPath: String? = nil) -> PromptHubCLIEnvironment {
        let live = PromptHubCLIEnvironment.live(fileManager: .default)
        return PromptHubCLIEnvironment(
            homeDirectoryURL: resolvedDirectory(path: home) ?? live.homeDirectoryURL,
            installRootURL: resolvedDirectory(path: installRoot) ?? live.installRootURL,
            projectRootURL: resolvedDirectory(path: projectRootPath) ?? live.projectRootURL,
            githubToken: live.githubToken
        )
    }

    private func resolvedDirectory(path: String?) -> URL? {
        guard let path else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath, isDirectory: true)
    }
}

enum AgentOption: String, ExpressibleByArgument, CaseIterable {
    case codex
    case claudeCode = "claude-code"
    case cursor
    case geminiCLI = "gemini-cli"
    case iflow
    case opencode
    case qwenCode = "qwen-code"
    case qoder

    var workflow: AgentWorkflow {
        switch self {
        case .codex:
            return .codex
        case .claudeCode:
            return .claudeCode
        case .cursor:
            return .cursor
        case .geminiCLI:
            return .geminiCLI
        case .iflow:
            return .iflow
        case .opencode:
            return .opencode
        case .qwenCode:
            return .qwenCode
        case .qoder:
            return .qoder
        }
    }
}

enum SkillInstallScopeOption: String, ExpressibleByArgument, CaseIterable {
    case global
    case project

    var libraryScope: PromptHubInstallScope {
        switch self {
        case .global:
            return .global
        case .project:
            return .project
        }
    }
}

enum SkillListScopeOption: String, ExpressibleByArgument, CaseIterable {
    case all
    case global
    case project

    var filter: InstalledSkillScopeFilter {
        switch self {
        case .all:
            return .all
        case .global:
            return .global
        case .project:
            return .project
        }
    }
}

struct PromptCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "prompt",
        abstract: "Read and write prompts exported by the PromptHub macOS app.",
        discussion: """
        Identifier resolution precedence (exact match first, then prefix):
          1. id   2. slug   3. installation name   4. display name
        Ambiguous matches exit with a non-zero status and list every candidate on stderr.

        Write commands (create/update/delete) operate on ~/.prompthub/prompts; the
        running PromptHub app picks the change up on next launch / reload-from-disk.
        See docs/cli-writable-contract.md for the full v1 contract.
        """,
        subcommands: [
            PromptListCommand.self,
            PromptShowCommand.self,
            PromptSearchCommand.self,
            PromptRenderCommand.self,
            PromptCreateCommand.self,
            PromptUpdateCommand.self,
            PromptDeleteCommand.self
        ]
    )
}

/// `--body` accepts a literal string, `@path/to/file.md` for a file, or omitted
/// when `--body-stdin` is set. Resolves to the actual body string the writer
/// should use, or `nil` when none was supplied at all.
private func resolveBodySource(
    raw: String?,
    readFromStdin: Bool
) throws -> String? {
    if readFromStdin {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    guard let raw else { return nil }
    if raw.hasPrefix("@") {
        let path = String(raw.dropFirst())
        let expanded = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PromptHubCLIError.promptBodyFileNotFound(expanded)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
    return raw
}

struct PromptCreateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new prompt under ~/.prompthub/prompts.",
        discussion: """
        Body input: pass --body "literal text", --body @path/to/file.md to read a file,
        or --body-stdin to consume the entire standard input.
        Slug is derived from --name and is not editable directly in v1.
        On success, writes a one-line app-resync hint to stderr.
        """
    )

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Display name. Slug is derived from this value.")
    var name: String

    @Option(name: .long, help: "Optional description / summary line.")
    var description: String?

    @Option(name: .long, help: "Body text, or @path/to/file.md to read from a file.")
    var body: String?

    @Flag(name: .long, help: "Read the prompt body from standard input instead of --body.")
    var bodyStdin = false

    @Option(name: .long, help: "Optional caller-supplied UUID. When omitted, a fresh UUIDv4 is generated.")
    var id: String?

    @Flag(name: .long, help: "Emit the created prompt as JSON instead of printing the resulting path.")
    var json = false

    mutating func run() async throws {
        let service = PromptHubCLIService(environment: common.makeEnvironment())
        let bodyValue = (try resolveBodySource(raw: body, readFromStdin: bodyStdin)) ?? ""
        let asset = try service.createPrompt(
            name: name,
            description: description,
            body: bodyValue,
            link: nil,
            id: id
        )

        fputs("\(PromptHubCLIService.promptWriteAppResyncHint)\n", stderr)

        if json {
            printJSON(asset)
            return
        }
        print("Created prompt '\(asset.name)' (slug: \(asset.slug ?? "-"), id: \(asset.id))")
        print("Path: \(asset.path)")
    }
}

struct PromptUpdateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update an existing prompt's metadata and/or body. Only --name --description --body change anything.",
        discussion: """
        Identifier follows the same precedence as `ph prompt show`. Renaming via --name
        regenerates the slug; the existing id is preserved. The `link` frontmatter field
        from the existing file is preserved verbatim.
        """
    )

    @OptionGroup var common: CommonOptions

    @Argument(help: "Prompt identifier (id, slug, or display name).")
    var identifier: String

    @Option(name: .long, help: "New display name. Regenerates slug.")
    var name: String?

    @Option(name: .long, help: "New description. Pass an empty string to clear.")
    var description: String?

    @Option(name: .long, help: "New body text, or @path/to/file.md to read from a file.")
    var body: String?

    @Flag(name: .long, help: "Read the new prompt body from standard input.")
    var bodyStdin = false

    @Flag(name: .long, help: "Emit the updated prompt as JSON instead of a summary.")
    var json = false

    mutating func run() async throws {
        let service = PromptHubCLIService(environment: common.makeEnvironment())
        let bodyValue = try resolveBodySource(raw: body, readFromStdin: bodyStdin)

        // `description` semantics: ArgumentParser passes nil when the flag is absent
        // and a (possibly empty) string when present. Map that into the double-optional
        // the service expects so nil = leave alone and "" = clear.
        let descriptionDoubleOptional: String??
        if let description {
            descriptionDoubleOptional = .some(description.isEmpty ? nil : description)
        } else {
            descriptionDoubleOptional = .none
        }

        let asset = try service.updatePrompt(
            identifier: identifier,
            name: name,
            description: descriptionDoubleOptional,
            body: bodyValue,
            link: nil
        )

        fputs("\(PromptHubCLIService.promptWriteAppResyncHint)\n", stderr)

        if json {
            printJSON(asset)
            return
        }
        print("Updated prompt '\(asset.name)' (slug: \(asset.slug ?? "-"), id: \(asset.id))")
        print("Path: \(asset.path)")
    }
}

struct PromptDeleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete the file backing a prompt from ~/.prompthub/prompts.",
        discussion: """
        Requires --yes when stdout is a TTY so an interactive misuse cannot silently
        drop a prompt. In non-interactive use (pipes / CI) the safety check is skipped
        so scripts do not need to fake a TTY.
        """
    )

    @OptionGroup var common: CommonOptions

    @Argument(help: "Prompt identifier (id, slug, or display name).")
    var identifier: String

    @Flag(name: .long, help: "Confirm deletion. Required when stdout is a TTY.")
    var yes = false

    @Flag(name: .long, help: "Emit JSON with the removed path instead of a summary line.")
    var json = false

    mutating func run() async throws {
        // TTY safety. isatty returns 1 for an interactive terminal.
        let isInteractive = isatty(fileno(stdout)) != 0
        if isInteractive && !yes {
            throw PromptHubCLIError.promptDeleteRefused(identifier: identifier)
        }

        let service = PromptHubCLIService(environment: common.makeEnvironment())
        let removed = try service.deletePrompt(identifier: identifier)

        fputs("\(PromptHubCLIService.promptWriteAppResyncHint)\n", stderr)

        if json {
            struct Result: Encodable {
                let action = "deleted"
                let path: String
            }
            printJSON(Result(path: removed.path))
            return
        }
        print("Deleted \(removed.path)")
    }
}

struct PromptListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List prompts exported to ~/.prompthub/prompts."
    )

    @OptionGroup var common: CommonOptions
    @Flag(name: .long, help: "Emit JSON instead of a table.")
    var json = false

    mutating func run() async throws {
        let service = PromptHubCLIService(environment: common.makeEnvironment())
        let prompts = try service.listPrompts()
        if json {
            printJSON(prompts)
            return
        }

        if prompts.isEmpty {
            print("No exported prompts found.")
            return
        }

        printTable(
            headers: ["Name", "Slug", "ID"],
            rows: prompts.map { [$0.name, $0.slug ?? "-", $0.id] }
        )
    }
}

struct PromptShowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Print the body of an exported prompt resolved by id, slug, or name."
    )

    @OptionGroup var common: CommonOptions
    @Argument(help: "Prompt identifier, slug, or name.")
    var identifier: String

    @Flag(name: .long, help: "Emit the full prompt asset as JSON.")
    var json = false

    mutating func run() async throws {
        let service = PromptHubCLIService(environment: common.makeEnvironment())
        let prompt = try service.showPrompt(identifier: identifier)
        if json {
            printJSON(prompt)
            return
        }
        print(prompt.body)
    }
}

struct PromptSearchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Find exported prompts whose name, slug, tags, or body match a query."
    )

    @OptionGroup var common: CommonOptions

    @Argument(help: "Substring to search for. Matching is case-insensitive.")
    var query: String

    @Flag(name: .long, help: "Emit JSON instead of a table.")
    var json = false

    mutating func run() async throws {
        let service = PromptHubCLIService(environment: common.makeEnvironment())
        let matches = try service.searchPrompts(query: query)
        if json {
            printJSON(matches)
            return
        }

        if matches.isEmpty {
            print("No exported prompts matched '\(query)'.")
            return
        }

        printTable(
            headers: ["Name", "Slug", "ID"],
            rows: matches.map { [$0.name, $0.slug ?? "-", $0.id] }
        )
    }
}

struct PromptRenderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "render",
        abstract: "Resolve an exported prompt and substitute {{variable}} placeholders.",
        discussion: """
        Variables come from repeated --var key=value flags. Use --var-stdin <name> to
        read the entire standard input into a single variable (useful for piping file or
        command output as a placeholder body).
        """
    )

    @OptionGroup var common: CommonOptions

    @Argument(help: "Prompt identifier, slug, installation name, or display name.")
    var identifier: String

    @Option(name: .customLong("var"), parsing: .singleValue, help: "Variable assignment in key=value form. Repeat for additional variables.")
    var vars: [String] = []

    @Option(name: .long, help: "Read the entire standard input into the named variable.")
    var varStdin: String?

    @Flag(name: .long, help: "Emit JSON with rendered text, declared variables, and resolved values.")
    var json = false

    mutating func run() async throws {
        let service = PromptHubCLIService(environment: common.makeEnvironment())

        var variables: [String: String] = [:]
        for raw in vars {
            let (key, value) = try PromptHubCLIService.parseVariableAssignment(raw)
            variables[key] = value
        }

        if let stdinName = varStdin {
            let data = FileHandle.standardInput.readDataToEndOfFile()
            variables[stdinName] = String(data: data, encoding: .utf8) ?? ""
        }

        let result = try service.renderPrompt(identifier: identifier, variables: variables)

        if json {
            printJSON(result)
            return
        }
        print(result.rendered)
    }
}

struct SkillCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skill",
        abstract: "Inspect exported skills and install them into supported agents.",
        discussion: """
        Read commands ('exports', 'show', 'list', 'inspect') share the same JSON keys
        where concepts overlap, so external tooling can join exported and installed
        records on `name`/`package`, `scope`, and `installedPaths`.
        """,
        subcommands: [
            SkillListCommand.self,
            SkillExportsCommand.self,
            SkillShowCommand.self,
            SkillInspectCommand.self,
            SkillWhereCommand.self,
            SkillSearchCommand.self,
            SkillInstallCommand.self,
            SkillUninstallCommand.self,
            SkillUpdateCommand.self,
            SkillReinstallCommand.self
        ]
    )
}

struct SkillSearchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search the remote skill catalog and print install-ready package references.",
        discussion: """
        Each result row's `package` field can be piped directly into `ph skill install`.
        An empty query lists the catalog's most-installed skills first.

        Remote sources include the PromptHub registry, a curated crawler snapshot,
        and (as a fallback) live GitHub crawl of seed repos. Failures degrade with
        an actionable stderr message — local 'ph skill exports' and 'ph skill list'
        keep working even when the remote catalog is offline.
        """
    )

    @OptionGroup var common: CommonOptions

    @Argument(help: "Substring to search for. Matches against the package reference, description, and source URL. Omit for the default ordered listing.")
    var query: String?

    @Option(name: .long, help: "Project root used for project-scope reconciliation of already-installed flags.")
    var projectRoot: String?

    @Flag(name: .long, help: "Emit JSON instead of a table.")
    var json = false

    mutating func run() async throws {
        let projectRootURL = resolvedDirectory(path: projectRoot)
        let service = PromptHubCLIService(environment: common.makeEnvironment(projectRootPath: projectRoot))
        let results = try await service.searchRemoteSkills(
            query: query ?? "",
            projectRootURL: projectRootURL
        )

        if json {
            printJSON(results)
            return
        }

        if results.isEmpty {
            if let query, !query.isEmpty {
                print("No remote skills matched '\(query)'.")
            } else {
                print("No remote skills available.")
            }
            return
        }

        printTable(
            headers: ["Package", "Installed", "Description"],
            rows: results.map { row in
                [
                    row.package,
                    row.isInstalled ? "yes" : "no",
                    truncate(row.description, max: 70)
                ]
            }
        )
    }

    private func resolvedDirectory(path: String?) -> URL? {
        guard let path else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath, isDirectory: true)
    }

    private func truncate(_ text: String, max: Int) -> String {
        guard text.count > max else { return text }
        return String(text.prefix(max - 1)) + "…"
    }
}

struct SkillUninstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "uninstall",
        abstract: "Remove a PromptHub-managed skill from one or more agent directories.",
        discussion: """
        By default, refuses to delete skill files that were not installed by PromptHub
        to avoid wiping hand-authored content. Pass --force to remove anyway.
        Per-agent results are reported individually so a single failure does not hide
        successful removals.
        """
    )

    @OptionGroup var common: CommonOptions

    @Argument(help: "Installed skill package name (case-sensitive, as it appears in `ph skill list`).")
    var package: String

    @Option(name: .long, help: "Scope to uninstall from. Defaults to global.")
    var scope: SkillInstallScopeOption = .global

    @Option(name: .long, help: "Repeat to limit removal to specific agents. Defaults to every agent the install was discovered in.")
    var agent: [AgentOption] = []

    @Option(name: .long, help: "Project root used for project-scoped removal. Defaults to the current working directory.")
    var projectRoot: String?

    @Flag(name: .long, help: "Delete the files even when PromptHub did not install them. Use with care.")
    var force = false

    @Flag(name: .long, help: "Emit JSON instead of a human-readable summary.")
    var json = false

    mutating func run() async throws {
        let projectRootURL = resolvedDirectory(path: projectRoot)
        let service = PromptHubCLIService(environment: common.makeEnvironment(projectRootPath: projectRoot))
        let result = try await service.uninstallSkill(
            package: package,
            scope: scope.libraryScope,
            agents: agent.map(\.workflow),
            projectRootURL: projectRootURL,
            force: force
        )

        if json {
            printJSON(result)
        } else {
            print("Uninstalled \(result.package) (scope \(result.scope.rawValue))")
            for row in result.agents {
                let badge = row.succeeded ? "✓" : "✗"
                if let err = row.error {
                    print("  \(badge) \(row.agent): \(err)")
                } else {
                    print("  \(badge) \(row.agent)")
                }
            }
            if !result.removedPaths.isEmpty {
                print("Paths that were targeted:")
                for path in result.removedPaths {
                    print("  - \(path)")
                }
            }
        }

        if result.allFailed {
            throw ExitCode.failure
        }
    }

    private func resolvedDirectory(path: String?) -> URL? {
        guard let path else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath, isDirectory: true)
    }
}

struct SkillUpdateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Pull the latest remote content for an installed skill and apply it across every agent that has it."
    )

    @OptionGroup var common: CommonOptions

    @Argument(help: "Installed skill package name.")
    var package: String

    @Option(name: .long, help: "Scope to update. Defaults to global.")
    var scope: SkillInstallScopeOption = .global

    @Option(name: .long, help: "Project root used for project-scoped update.")
    var projectRoot: String?

    @Flag(name: .long, help: "Emit JSON instead of a human-readable summary.")
    var json = false

    mutating func run() async throws {
        let projectRootURL = resolvedDirectory(path: projectRoot)
        let service = PromptHubCLIService(environment: common.makeEnvironment(projectRootPath: projectRoot))
        let result = try await service.updateSkill(
            package: package,
            scope: scope.libraryScope,
            projectRootURL: projectRootURL
        )

        if json {
            printJSON(result)
            return
        }

        switch result.status {
        case .updated:
            print("Updated \(result.package) (scope \(result.scope.rawValue))")
            for path in result.appliedPaths {
                print("  • \(path)")
            }
        case .upToDate:
            print("\(result.package): already up to date.")
        case .noRemoteSource:
            print("\(result.package): no remote source recorded — nothing to pull.")
        case .remoteUnavailable:
            print("\(result.package): remote source could not be reached. Try again later.")
        case .notInstalled:
            print("\(result.package): not installed in scope \(result.scope.rawValue).")
        }
    }

    private func resolvedDirectory(path: String?) -> URL? {
        guard let path else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath, isDirectory: true)
    }
}

struct SkillReinstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reinstall",
        abstract: "Re-run the original install for a skill. Routes by package shape: owner/repo@skill -> remote, anything else -> exported PromptHub asset."
    )

    @OptionGroup var common: CommonOptions

    @Argument(help: "Installed skill package name or remote owner/repo@skill reference.")
    var package: String

    @Option(name: .long, help: "Repeat to target one or more agents. Defaults to every supported agent.")
    var agent: [AgentOption] = []

    @Option(name: .long, help: "Scope to reinstall into. Defaults to global.")
    var scope: SkillInstallScopeOption = .global

    @Option(name: .long, help: "Project root used for project-scoped reinstall.")
    var projectRoot: String?

    @Flag(name: .long, help: "Emit JSON instead of human-readable output.")
    var json = false

    mutating func run() async throws {
        let projectRootURL = resolvedDirectory(path: projectRoot)
        let service = PromptHubCLIService(environment: common.makeEnvironment(projectRootPath: projectRoot))
        let summary = try await service.reinstallSkill(
            package: package,
            scope: scope.libraryScope,
            agents: agent.map(\.workflow),
            projectRootURL: projectRootURL
        )

        if json {
            printJSON(summary)
            return
        }

        print("Reinstalled \(summary.package) (scope \(summary.scope.rawValue))")
        if summary.agents.isEmpty {
            print("  Agents: pending discovery")
        } else {
            print("  Agents: \(summary.agents.joined(separator: ", "))")
        }
    }

    private func resolvedDirectory(path: String?) -> URL? {
        guard let path else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath, isDirectory: true)
    }
}

struct SkillWhereCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "where",
        abstract: "Print one (agent, scope, path) row per installed copy of a skill.",
        discussion: """
        Designed for piping. Default output is `<agent>\\t<scope>\\t<path>` per line so
        wrappers can `cut`/`awk` straight into `cd` or `open`. Use --json for the full
        record (includes managed-by-PromptHub flag and package name).
        """
    )

    @OptionGroup var common: CommonOptions

    @Argument(help: "Installed skill package name.")
    var package: String

    @Option(name: .long, help: "Optional scope filter (global or project). Defaults to both.")
    var scope: SkillInstallScopeOption?

    @Option(name: .long, help: "Project root used for project-scoped discovery.")
    var projectRoot: String?

    @Flag(name: .long, help: "Emit JSON with the full record per location.")
    var json = false

    mutating func run() async throws {
        let projectRootURL = resolvedDirectory(path: projectRoot)
        let service = PromptHubCLIService(environment: common.makeEnvironment(projectRootPath: projectRoot))
        let rows = try await service.whereSkill(
            package: package,
            scope: scope?.libraryScope,
            projectRootURL: projectRootURL
        )

        if json {
            printJSON(rows)
            return
        }

        for row in rows {
            print("\(row.agent)\t\(row.scope.rawValue)\t\(row.path)")
        }
    }

    private func resolvedDirectory(path: String?) -> URL? {
        guard let path else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath, isDirectory: true)
    }
}

struct SkillShowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Print the body and metadata of an exported skill package."
    )

    @OptionGroup var common: CommonOptions

    @Argument(help: "Exported skill identifier, slug, installation name, or display name.")
    var identifier: String

    @Flag(name: .long, help: "Emit the full exported asset as JSON (metadata, package path, markdown).")
    var json = false

    mutating func run() async throws {
        let service = PromptHubCLIService(environment: common.makeEnvironment())
        let skill = try service.showExportedSkill(identifier: identifier)
        if json {
            printJSON(skill)
            return
        }

        print("Name:       \(skill.name)")
        if let slug = skill.slug { print("Slug:       \(slug)") }
        if let install = skill.installationName { print("Install as: \(install)") }
        print("ID:         \(skill.id)")
        if let category = skill.category { print("Category:   \(category)") }
        if !skill.tags.isEmpty { print("Tags:       \(skill.tags.joined(separator: ", "))") }
        if let summary = skill.summary, !summary.isEmpty { print("Summary:    \(summary)") }
        print("Path:       \(skill.path)")
        if let pkg = skill.packageDirectoryPath { print("Package:    \(pkg)") }
        print("")
        print(skill.body)
    }
}

struct SkillInspectCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inspect",
        abstract: "Report installed skill detail: scope, agents, managed/unmanaged state, URL, and resolved paths.",
        discussion: """
        Looks up the skill across global and project scope. Use --scope to disambiguate
        when the same package is installed in multiple places. Use --project-root when
        the project scope should resolve against a directory other than the current one.
        """
    )

    @OptionGroup var common: CommonOptions

    @Argument(help: "Installed skill package name (case-insensitive).")
    var package: String

    @Option(name: .long, help: "Optional scope filter (global or project). Defaults to both.")
    var scope: SkillInstallScopeOption?

    @Option(name: .long, help: "Project root used for project-scoped discovery. Defaults to the current working directory.")
    var projectRoot: String?

    @Flag(name: .long, help: "Emit JSON instead of a human-readable summary.")
    var json = false

    mutating func run() async throws {
        let projectRootURL = resolvedDirectory(path: projectRoot)
        let service = PromptHubCLIService(environment: common.makeEnvironment(projectRootPath: projectRoot))
        let matches = try await service.inspectInstalledSkill(
            package: package,
            scope: scope?.libraryScope,
            projectRootURL: projectRootURL
        )

        if json {
            printJSON(matches)
            return
        }

        for (index, match) in matches.enumerated() {
            if index > 0 { print("") }
            print("Package:    \(match.package)")
            print("Scope:      \(match.scope.rawValue)")
            print("Managed:    \(match.isManagedByPromptHub ? "PromptHub-managed" : "Unmanaged (pre-existing file)")")
            if !match.description.isEmpty { print("Description:\(match.description)") }
            print("Agents:     \(match.agents.isEmpty ? "(none discovered)" : match.agents.joined(separator: ", "))")
            if let url = match.url, !url.isEmpty { print("Source URL: \(url)") }
            if match.installedPaths.isEmpty {
                print("Paths:      (none reported)")
            } else {
                print("Paths:")
                for path in match.installedPaths {
                    print("  - \(path)")
                }
            }
        }
    }

    private func resolvedDirectory(path: String?) -> URL? {
        guard let path else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath, isDirectory: true)
    }
}

struct SkillExportsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "exports",
        abstract: "List skills exported by PromptHub to ~/.prompthub/skills."
    )

    @OptionGroup var common: CommonOptions
    @Flag(name: .long, help: "Emit JSON instead of a table.")
    var json = false

    mutating func run() async throws {
        let service = PromptHubCLIService(environment: common.makeEnvironment())
        let skills = try service.listExportedSkills()
        if json {
            printJSON(skills)
            return
        }

        if skills.isEmpty {
            print("No exported skills found.")
            return
        }

        printTable(
            headers: ["Name", "Install Name", "ID"],
            rows: skills.map { [$0.name, $0.installationName ?? $0.slug ?? "-", $0.id] }
        )
    }
}

struct SkillListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List installed skills discovered from PromptHub's managed registry and agent folders."
    )

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Filter installed skills by scope.")
    var scope: SkillListScopeOption = .all

    @Option(name: .long, help: "Project root used for project-scoped discovery. Defaults to the current working directory.")
    var projectRoot: String?

    @Flag(name: .long, help: "Emit JSON instead of a table.")
    var json = false

    mutating func run() async throws {
        let service = PromptHubCLIService(environment: common.makeEnvironment(projectRootPath: projectRoot))
        let installed = try await service.listInstalledSkills(
            scopeFilter: scope.filter,
            projectRootURL: resolvedDirectory(path: projectRoot)
        )

        if json {
            printJSON(installed)
            return
        }

        if installed.isEmpty {
            print("No installed skills found.")
            return
        }

        printTable(
            headers: ["Package", "Scope", "Agents"],
            rows: installed.map { [$0.package, $0.scope.rawValue, $0.agents.joined(separator: ",")] }
        )
    }

    private func resolvedDirectory(path: String?) -> URL? {
        guard let path else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath, isDirectory: true)
    }
}

struct SkillInstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install either a remote owner/repo@skill package or an exported PromptHub skill by id, slug, or name."
    )

    @OptionGroup var common: CommonOptions

    @Argument(help: "Remote skill reference (owner/repo@skill) or exported skill identifier.")
    var reference: String

    @Option(name: .long, help: "Repeat to target one or more agents. Defaults to all supported agents.")
    var agent: [AgentOption] = []

    @Option(name: .long, help: "Install scope. Project scope defaults to the current working directory when --project-root is omitted.")
    var scope: SkillInstallScopeOption = .global

    @Option(name: .long, help: "Project root used for project-scoped installs.")
    var projectRoot: String?

    @Flag(name: .long, help: "Emit JSON instead of human-readable output.")
    var json = false

    mutating func run() async throws {
        let projectRootURL = resolvedDirectory(path: projectRoot)
        let service = PromptHubCLIService(environment: common.makeEnvironment(projectRootPath: projectRoot))
        let summary = try await service.installSkill(
            reference: reference,
            scope: scope.libraryScope,
            agents: agent.map(\.workflow),
            projectRootURL: projectRootURL
        )

        if json {
            printJSON(summary)
            return
        }

        print("Installed \(summary.package)")
        print("Scope: \(summary.scope.rawValue)")
        if summary.agents.isEmpty {
            print("Agents: pending discovery")
        } else {
            print("Agents: \(summary.agents.joined(separator: ", "))")
        }
    }

    private func resolvedDirectory(path: String?) -> URL? {
        guard let path else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath, isDirectory: true)
    }
}

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Diagnose the PromptHub CLI environment: export roots, install paths, project root, and per-agent visibility.",
        discussion: """
        Doctor runs filesystem checks only and never mutates state. It is safe to run
        in any directory. Exits non-zero when any finding has 'error' severity so the
        command works as a precondition in scripts; 'warning' findings exit zero so
        users on a partial setup (e.g. one agent installed) are not blocked.
        """
    )

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Project root used for project-scoped checks. Defaults to the current working directory.")
    var projectRoot: String?

    @Flag(name: .long, help: "Emit a stable JSON report instead of human-readable output.")
    var json = false

    mutating func run() async throws {
        let projectRootURL = resolvedDirectory(path: projectRoot)
        let service = PromptHubCLIService(environment: common.makeEnvironment(projectRootPath: projectRoot))
        let report = service.runDoctor(projectRootURL: projectRootURL)

        if json {
            printJSON(report)
        } else {
            printDoctorReport(report)
        }

        if report.findings.contains(where: { $0.severity == .error }) {
            throw ExitCode.failure
        }
    }

    private func resolvedDirectory(path: String?) -> URL? {
        guard let path else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath, isDirectory: true)
    }

    private func printDoctorReport(_ report: DoctorReport) {
        print("PromptHub CLI Doctor")
        print("====================")
        print("")
        print(formatPath(label: "Home",          check: report.homeDirectory))
        print(formatPath(label: "Exports",       check: report.exportsRoot))
        print(formatPath(label: "  prompts",     check: report.promptsRoot))
        print(formatPath(label: "  skills",      check: report.skillsRoot))
        if let install = report.installRoot {
            print(formatPath(label: "Install root", check: install))
        } else {
            print("Install root  (using PromptHub app-managed default)")
        }
        print(formatPath(label: "Project root", check: report.projectRoot))
        print("GitHub token  \(report.githubTokenPresent ? "present" : "not set")")
        print("")

        print("Agents")
        print("------")
        for agent in report.agents {
            let globalMark = symbol(for: agent.globalPath)
            let projectMark = symbol(for: agent.projectPath)
            print("\(agent.agent)  global \(globalMark) \(agent.globalPath.path)")
            print("\(String(repeating: " ", count: agent.agent.count))  project \(projectMark) \(agent.projectPath.path)")
            print("\(String(repeating: " ", count: agent.agent.count))  visible skills: \(agent.visibleSkillCount)")
        }
        print("")

        print("Findings")
        print("--------")
        for finding in report.findings {
            let badge = badge(for: finding.severity)
            var line = "\(badge) [\(finding.code)] \(finding.message)"
            if let path = finding.path { line += " (\(path))" }
            print(line)
        }
    }

    private func formatPath(label: String, check: DoctorPathCheck) -> String {
        let mark = symbol(for: check)
        let label = label.padding(toLength: max(label.count, 12), withPad: " ", startingAt: 0)
        return "\(label) \(mark) \(check.path)"
    }

    private func symbol(for check: DoctorPathCheck) -> String {
        if !check.exists { return "✗ missing" }
        if !check.isReadable { return "⚠ unreadable" }
        if !check.isWritable { return "⚠ read-only" }
        return "✓"
    }

    private func badge(for severity: DoctorSeverity) -> String {
        switch severity {
        case .ok:      return "✓"
        case .warning: return "⚠"
        case .error:   return "✗"
        }
    }
}

private func printJSON<T: Encodable>(_ value: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(value), let string = String(data: data, encoding: .utf8) {
        print(string)
    }
}

private func printTable(headers: [String], rows: [[String]]) {
    let normalizedRows = rows.map { row in
        row.enumerated().map { index, value in
            index < headers.count ? value : ""
        }
    }

    let widths = headers.indices.map { column in
        max(
            headers[column].count,
            normalizedRows.map { row in
                column < row.count ? row[column].count : 0
            }.max() ?? 0
        )
    }

    func padded(_ value: String, width: Int) -> String {
        if value.count >= width {
            return value
        }
        return value + String(repeating: " ", count: width - value.count)
    }

    let headerLine = headers.enumerated().map { index, header in
        padded(header, width: widths[index])
    }.joined(separator: "  ")
    print(headerLine)
    print(widths.map { String(repeating: "-", count: $0) }.joined(separator: "  "))

    for row in normalizedRows {
        let line = row.enumerated().map { index, value in
            padded(value, width: widths[index])
        }.joined(separator: "  ")
        print(line)
    }
}