import ArgumentParser
import Foundation
import PromptHubCLILib

// MARK: - prompthub skill

struct SkillCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skill",
        abstract: "Read and audit skill assets from your PromptHub library.",
        subcommands: [ListSkills.self, ReadSkill.self, AuditSkill.self, SkillVisible.self, SearchSkills.self]
    )
}

// MARK: - prompthub skill list

struct ListSkills: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all skill drafts in your PromptHub library."
    )

    @Flag(name: .long, help: "Output as JSON array.")
    var json: Bool = false

    func run() throws {
        let skills = AssetStore.shared.listSkills()
        guard !skills.isEmpty else {
            printStderr("No skills found. Open PromptHub.app to create or import skills.")
            return
        }
        if json {
            let items: [[String: Any]] = skills.map {
                var obj: [String: Any] = [
                    "name": $0.name,
                    "slug": $0.slug,
                    "tags": $0.tags,
                ]
                if let desc = $0.description { obj["description"] = desc }
                if let cat = $0.category     { obj["category"] = cat }
                return obj
            }
            if let data = try? JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted]),
               let str = String(data: data, encoding: .utf8) { print(str) }
        } else {
            for skill in skills {
                let desc = skill.description.map { " — \($0)" } ?? ""
                print("\(skill.slug)\(desc)")
            }
        }
    }
}

// MARK: - prompthub skill read

struct ReadSkill: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "read",
        abstract: "Print the raw instructions body of a skill.",
        discussion: "NAME can be the skill's display name or its slug."
    )

    @Argument(help: "Skill name or slug.")
    var name: String

    func run() throws {
        guard let skill = AssetStore.shared.findSkill(named: name) else {
            printStderr("Skill '\(name)' not found. Run 'prompthub skill list' to see available skills.")
            throw ExitCode.failure
        }
        print(skill.body)
    }
}

// MARK: - prompthub skill visible

struct SkillVisible: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "visible",
        abstract: "Check whether a skill is visible / accessible to agents.",
        discussion: """
        Prints a one-line status and exits 0 if accessible, 1 if not found.
        Useful in CI or agent pre-flight checks.
        """
    )

    @Argument(help: "Skill name or slug.")
    var name: String

    func run() throws {
        if let skill = AssetStore.shared.findSkill(named: name) {
            print("visible  \(skill.slug)  (\(skill.name))")
        } else {
            printStderr("not-found  \(name)")
            throw ExitCode.failure
        }
    }
}

// MARK: - prompthub skill audit

struct AuditSkill: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "audit",
        abstract: "Run static quality checks on a skill's SKILL.md body.",
        discussion: """
        Checks that the skill document contains required sections and
        meets basic quality thresholds. Exit code 0 = pass, 1 = warnings.
        """
    )

    @Argument(help: "Skill name or slug.")
    var name: String

    @Flag(name: .long, help: "Output as JSON.")
    var json: Bool = false

    func run() throws {
        guard let skill = AssetStore.shared.findSkill(named: name) else {
            printStderr("Skill '\(name)' not found. Run 'prompthub skill list' to see available skills.")
            throw ExitCode.failure
        }
        let report = SkillAuditor.audit(skill)
        if json {
            let obj: [String: Any] = [
                "skill": skill.slug,
                "passed": report.passed,
                "warnings": report.warnings,
            ]
            if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
               let str = String(data: data, encoding: .utf8) { print(str) }
        } else {
            print("Audit: \(skill.name)")
            print(report.passed ? "PASS" : "WARN")
            for warning in report.warnings {
                print("  • \(warning)")
            }
            if report.passed { print("  ✓ No issues found.") }
        }
        if !report.passed { throw ExitCode(1) }
    }
}

// MARK: - prompthub skill search

struct SearchSkills: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search skills by name, slug, description, or body."
    )

    @Argument(help: "Search query.")
    var query: String

    func run() throws {
        let results = AssetStore.shared.searchSkills(query: query)
        if results.isEmpty {
            printStderr("No skills match '\(query)'.")
        } else {
            for s in results {
                let desc = s.description.map { " — \($0)" } ?? ""
                print("\(s.slug)\(desc)")
            }
        }
    }
}
