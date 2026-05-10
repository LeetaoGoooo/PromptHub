import ArgumentParser
import Foundation
import PromptHubCLILib

// MARK: - prompthub prompt

struct PromptCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "prompt",
        abstract: "Read and render prompts from your PromptHub library.",
        subcommands: [ListPrompts.self, GetPrompt.self, RenderPrompt.self, SearchPrompts.self]
    )
}

// MARK: - prompthub prompt list

struct ListPrompts: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all prompts in your PromptHub library."
    )

    @Flag(name: .long, help: "Output as JSON array.")
    var json: Bool = false

    func run() throws {
        let store = AssetStore.shared
        let prompts = store.listPrompts()
        guard !prompts.isEmpty else {
            printStderr("No prompts found. Open PromptHub.app to create prompts.")
            return
        }
        if json {
            let items = prompts.map { ["name": $0.name, "slug": $0.slug, "description": $0.description ?? ""] }
            if let data = try? JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted]),
               let str = String(data: data, encoding: .utf8) { print(str) }
        } else {
            for prompt in prompts {
                let desc = prompt.description.map { " — \($0)" } ?? ""
                print("\(prompt.slug)\(desc)")
            }
        }
    }
}

// MARK: - prompthub prompt get

struct GetPrompt: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Print the raw content of a prompt.",
        discussion: "NAME can be the prompt's display name or its slug."
    )

    @Argument(help: "Prompt name or slug.")
    var name: String

    @Flag(name: .long, help: "Include YAML front-matter in the output.")
    var withFrontMatter: Bool = false

    func run() throws {
        guard let prompt = AssetStore.shared.findPrompt(named: name) else {
            printStderr("Prompt '\(name)' not found. Run 'prompthub prompt list' to see available prompts.")
            throw ExitCode.failure
        }
        if withFrontMatter {
            print("name: \(prompt.name)")
            if let desc = prompt.description { print("description: \(desc)") }
            if let link = prompt.link        { print("link: \(link)") }
            print("---")
            print()
        }
        print(prompt.body)
    }
}

// MARK: - prompthub prompt render

struct RenderPrompt: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "render",
        abstract: "Render a prompt template by substituting {{variable}} placeholders.",
        discussion: """
        Variables in the prompt body that match the pattern {{variable_name}} are replaced
        with the values supplied via --var flags.

        Example:
          prompthub prompt render launch-copy \\
            --var product=PromptHub \\
            --var audience=developers
        """
    )

    @Argument(help: "Prompt name or slug.")
    var name: String

    @Option(name: .customLong("var"), help: "Variable substitution in key=value format. Repeat for multiple variables.")
    var variables: [String] = []

    func run() throws {
        guard let prompt = AssetStore.shared.findPrompt(named: name) else {
            printStderr("Prompt '\(name)' not found. Run 'prompthub prompt list' to see available prompts.")
            throw ExitCode.failure
        }

        var vars: [String: String] = [:]
        for variable in variables {
            let parts = variable.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else {
                printStderr("Invalid --var format '\(variable)'. Expected key=value.")
                throw ExitCode(1)
            }
            vars[String(parts[0])] = String(parts[1])
        }

        let rendered = TemplateRenderer.render(prompt.body, variables: vars)
        print(rendered)

        // Warn about any unresolved placeholders
        let unresolved = TemplateRenderer.findPlaceholders(in: rendered)
        if !unresolved.isEmpty {
            printStderr("Warning: unresolved placeholders: \(unresolved.joined(separator: ", "))")
            printStderr("Pass --var key=value for each placeholder.")
        }
    }
}

// MARK: - prompthub prompt search

struct SearchPrompts: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search prompts by name, slug, description, or body."
    )

    @Argument(help: "Search query.")
    var query: String

    func run() throws {
        let results = AssetStore.shared.searchPrompts(query: query)
        if results.isEmpty {
            printStderr("No prompts match '\(query)'.")
        } else {
            for p in results {
                let desc = p.description.map { " — \($0)" } ?? ""
                print("\(p.slug)\(desc)")
            }
        }
    }
}

// MARK: - Helpers

func printStderr(_ message: String) {
    let standardError = FileHandle.standardError
    standardError.write((message + "\n").data(using: .utf8)!)
}
