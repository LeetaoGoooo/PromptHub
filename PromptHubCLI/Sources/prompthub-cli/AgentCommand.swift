import ArgumentParser
import PromptHubCLILib
import Foundation

// MARK: - prompthub agent

struct AgentCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "Utilities for agent/CI environments.",
        subcommands: [AgentDoctor.self]
    )
}

// MARK: - prompthub agent doctor

struct AgentDoctor: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check the PromptHub CLI environment and asset store health.",
        discussion: """
        Verifies that the asset directories exist, are readable, and contain at least
        one prompt and skill. Exits 0 when all checks pass, 1 if any check fails.
        """
    )

    @Flag(name: .long, help: "Output as JSON.")
    var json: Bool = false

    func run() throws {
        let store = AssetStore.shared
        var checks: [(name: String, ok: Bool, detail: String)] = []

        // 1. ~/.prompthub/ exists
        let baseExists = FileManager.default.fileExists(atPath: store.baseURL.path)
        checks.append((
            name: "~/.prompthub/ directory",
            ok: baseExists,
            detail: baseExists
                ? store.baseURL.path
                : "Missing. Open PromptHub.app and create at least one prompt."
        ))

        // 2. prompts/ directory
        let promptsPath = store.baseURL.appendingPathComponent("prompts").path
        let promptsDirOk = FileManager.default.fileExists(atPath: promptsPath)
        checks.append((
            name: "prompts/ directory",
            ok: promptsDirOk,
            detail: promptsDirOk ? promptsPath : "Missing. No prompts exported yet."
        ))

        // 3. skills/ directory
        let skillsPath = store.baseURL.appendingPathComponent("skills").path
        let skillsDirOk = FileManager.default.fileExists(atPath: skillsPath)
        checks.append((
            name: "skills/ directory",
            ok: skillsDirOk,
            detail: skillsDirOk ? skillsPath : "Missing. No skills exported yet."
        ))

        // 4. At least one prompt
        let prompts = store.listPrompts()
        checks.append((
            name: "at least one prompt",
            ok: !prompts.isEmpty,
            detail: prompts.isEmpty ? "0 prompts found." : "\(prompts.count) prompt(s)"
        ))

        // 5. At least one skill
        let skills = store.listSkills()
        checks.append((
            name: "at least one skill",
            ok: !skills.isEmpty,
            detail: skills.isEmpty ? "0 skills found." : "\(skills.count) skill(s)"
        ))

        // 6. CLI binary location
        let cliBinaryPath = findCLIBinary()
        let cliOk = cliBinaryPath != nil
        checks.append((
            name: "prompthub binary on PATH",
            ok: cliOk,
            detail: cliBinaryPath ?? "Not found. Install via: brew install LeetaoGoooo/tap/prompthub"
        ))

        let allPassed = checks.allSatisfy { $0.ok }

        if json {
            let obj: [String: Any] = [
                "passed": allPassed,
                "checks": checks.map { ["name": $0.name, "ok": $0.ok, "detail": $0.detail] },
            ]
            if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
               let str = String(data: data, encoding: .utf8) { print(str) }
        } else {
            print("PromptHub CLI — agent doctor\n")
            for check in checks {
                let icon = check.ok ? "✓" : "✗"
                print("  \(icon)  \(check.name)")
                if !check.ok { print("     → \(check.detail)") }
            }
            print()
            if allPassed {
                print("All checks passed.")
            } else {
                printStderr("Some checks failed. Open PromptHub.app and verify your library.")
            }
        }

        if !allPassed { throw ExitCode(1) }
    }

    private func findCLIBinary() -> String? {
        let candidates = [
            "/opt/homebrew/bin/prompthub",
            "/usr/local/bin/prompthub",
            "\(NSHomeDirectory())/.local/bin/prompthub",
        ]
        return candidates.first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }
}
