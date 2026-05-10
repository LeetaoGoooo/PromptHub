import ArgumentParser
import PromptHubCLILib

// Entry point — must stay in main.swift (top-level code)
PromptHubCLI.main()

struct PromptHubCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "prompthub",
        abstract: "PromptHub CLI — agent access to your local prompt and skill assets.",
        discussion: """
        PromptHub CLI lets agents, scripts, and CI pipelines read prompts and skills
        managed by the PromptHub macOS app. Assets are read from ~/.prompthub/.

        Install the macOS app from https://github.com/LeetaoGoooo/PromptHub to populate
        your asset library.

        QUICK START
          prompthub prompt list
          prompthub prompt get code-review
          prompthub prompt render launch-copy --var product=MyApp
          prompthub skill list
          prompthub skill read product-manager
          prompthub skill audit product-manager
          prompthub agent doctor
        """,
        version: "1.0.0",
        subcommands: [
            PromptCommand.self,
            SkillCommand.self,
            AgentCommand.self,
        ]
    )
}

