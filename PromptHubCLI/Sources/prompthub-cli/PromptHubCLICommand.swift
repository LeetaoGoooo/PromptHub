import ArgumentParser
import Foundation
import PromptHubCLILib
import PromptHubSkillKit

@main
struct PromptHubCLICommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ph",
        abstract: "Interact with PromptHub exports and manage CLI agent skills.",
        subcommands: [
            PromptCommand.self,
            SkillCommand.self
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
        abstract: "Read prompts exported by the PromptHub macOS app.",
        subcommands: [PromptListCommand.self, PromptShowCommand.self]
    )
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

struct SkillCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skill",
        abstract: "Inspect exported skills and install them into supported agents.",
        subcommands: [SkillListCommand.self, SkillExportsCommand.self, SkillInstallCommand.self]
    )
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