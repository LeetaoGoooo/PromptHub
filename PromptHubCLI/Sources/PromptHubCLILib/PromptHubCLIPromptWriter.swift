import Foundation
import PromptHubSkillKit

/// Result emitted by `ph prompt create/update/delete`.
///
/// Carries the resulting prompt asset (nil for delete) and a `hint` string the
/// CLI prints to **stderr** as a one-line app-resync nudge. The hint is part
/// of the v1 contract (`docs/cli-writable-contract.md` §8 test 8) so scripts
/// can grep for it.
public struct PromptHubPromptWriteResult: Codable, Equatable, Sendable {
    public enum Action: String, Codable, Sendable {
        case created
        case updated
        case deleted
    }

    public let action: Action
    public let path: String
    public let asset: PromptHubExportedAsset?
    public let hint: String?

    public init(action: Action, path: String, asset: PromptHubExportedAsset?, hint: String?) {
        self.action = action
        self.path = path
        self.asset = asset
        self.hint = hint
    }
}

extension PromptHubCLIService {
    /// Single-line stderr hint emitted after every write. Matches the test
    /// requirement in `docs/cli-writable-contract.md` §8 #8.
    public static let promptWriteAppResyncHint =
        "hint: the running PromptHub app will pick this change up on next launch (or reload-from-disk in the dashboard)."

    /// Create a new prompt under `~/.prompthub/prompts/<uuid>.md`.
    ///
    /// - Parameters:
    ///   - name: Display name. Slug is derived from this.
    ///   - description: Optional summary line. Empty/nil values skip the field.
    ///   - body: Markdown body. Empty allowed.
    ///   - link: Optional reference link (preserved if present, never surfaced via CLI flags in v1).
    ///   - id: Optional caller-supplied UUID (test fixtures / deterministic imports). Must be unique.
    /// - Throws:
    ///   - `invalidVariableAssignment(name)` style errors are NOT used here; use the typed cases below.
    ///   - `PromptHubCLIError.invalidMarkdown` on disk write failure (rewrapped with the target path).
    ///   - `PromptHubCLIError.promptIDCollision` if `id` is supplied and already exists.
    ///   - `PromptHubCLIError.promptSlugCollision` if the derived slug collides with another prompt.
    @discardableResult
    public func createPrompt(
        name: String,
        description: String? = nil,
        body: String = "",
        link: String? = nil,
        id: String? = nil
    ) throws -> PromptHubExportedAsset {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw PromptHubCLIError.invalidPromptName(name)
        }

        let resolvedID = try Self.normalizeUUID(id) ?? UUID().uuidString
        let slug = Self.slug(for: trimmedName)

        // Collision checks.
        let existing = (try? listPrompts()) ?? []
        if let collide = existing.first(where: { $0.id.lowercased() == resolvedID.lowercased() }) {
            throw PromptHubCLIError.promptIDCollision(id: resolvedID, existingName: collide.name)
        }
        if let collide = existing.first(where: { $0.slug?.lowercased() == slug.lowercased() }) {
            throw PromptHubCLIError.promptSlugCollision(slug: slug, existingID: collide.id)
        }

        let promptsURL = environment.promptsURL
        let targetURL = promptsURL.appendingPathComponent("\(resolvedID).md")
        let markdown = Self.renderPromptMarkdown(
            id: resolvedID,
            name: trimmedName,
            slug: slug,
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
            link: link?.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body,
            exportedAt: ISO8601DateFormatter().string(from: Date())
        )

        try ensureDirectory(promptsURL)
        do {
            try markdown.write(to: targetURL, atomically: true, encoding: .utf8)
        } catch {
            throw PromptHubCLIError.promptWriteFailed(path: targetURL.path, underlying: error.localizedDescription)
        }

        return PromptHubExportedAsset(
            id: resolvedID,
            kind: .prompt,
            name: trimmedName,
            slug: slug,
            installationName: nil,
            summary: description?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            exportedAt: nil, // intentionally not surfaced — read path reparses to get the canonical timestamp
            category: nil,
            tags: [],
            path: targetURL.path,
            packageDirectoryPath: nil,
            markdown: markdown,
            body: body
        )
    }

    /// Update a prompt in place. Only fields passed as non-nil are changed.
    /// `link` from the existing file is preserved.
    @discardableResult
    public func updatePrompt(
        identifier: String,
        name: String? = nil,
        description: String?? = nil, // double-optional: nil = leave alone; .some(nil) = clear
        body: String? = nil,
        link: String?? = nil
    ) throws -> PromptHubExportedAsset {
        let prompts = try listPrompts()
        let resolved = try resolveExistingPrompt(identifier: identifier, in: prompts)

        let oldURL = URL(fileURLWithPath: resolved.path)
        let existingMetadata = Self.frontmatterMap(in: resolved.markdown)

        let resolvedName = name?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? resolved.name
        let newSlug: String
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newSlug = Self.slug(for: resolvedName)
            // Slug collision check (ignore the prompt being updated).
            if let collide = prompts.first(where: { $0.id != resolved.id && $0.slug?.lowercased() == newSlug.lowercased() }) {
                throw PromptHubCLIError.promptSlugCollision(slug: newSlug, existingID: collide.id)
            }
        } else {
            newSlug = resolved.slug ?? Self.slug(for: resolvedName)
        }

        // Description: nil → keep, .some(nil) or .some("") → clear, .some(value) → set.
        let resolvedDescription: String?
        switch description {
        case .none:
            resolvedDescription = resolved.summary?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        case .some(let value):
            resolvedDescription = value?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        }

        // Link: nil → preserve existing, .some → overwrite (possibly clear).
        let resolvedLink: String?
        switch link {
        case .none:
            resolvedLink = existingMetadata["link"]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        case .some(let value):
            resolvedLink = value?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        }

        let resolvedBody = body ?? resolved.body

        let markdown = Self.renderPromptMarkdown(
            id: resolved.id,
            name: resolvedName,
            slug: newSlug,
            description: resolvedDescription,
            link: resolvedLink,
            body: resolvedBody,
            exportedAt: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try markdown.write(to: oldURL, atomically: true, encoding: .utf8)
        } catch {
            throw PromptHubCLIError.promptWriteFailed(path: oldURL.path, underlying: error.localizedDescription)
        }

        return PromptHubExportedAsset(
            id: resolved.id,
            kind: .prompt,
            name: resolvedName,
            slug: newSlug,
            installationName: nil,
            summary: resolvedDescription,
            exportedAt: nil,
            category: nil,
            tags: [],
            path: oldURL.path,
            packageDirectoryPath: nil,
            markdown: markdown,
            body: resolvedBody
        )
    }

    /// Delete the file backing the given prompt identifier.
    /// Returns the URL that was removed.
    @discardableResult
    public func deletePrompt(identifier: String) throws -> URL {
        let prompts = try listPrompts()
        let resolved = try resolveExistingPrompt(identifier: identifier, in: prompts)
        let url = URL(fileURLWithPath: resolved.path)
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw PromptHubCLIError.promptWriteFailed(path: url.path, underlying: error.localizedDescription)
        }
        return url
    }

    // MARK: - Helpers

    /// Mirror of `PromptHubBridge.slug(for:)` so CLI-written files round-trip identically.
    public static func slug(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    /// Mirror of `PromptHubBridge.yamlScalar(_:)`. Quoting rules MUST match
    /// or `cliParsesBridgeFixtureFormat` style parity tests will regress.
    public static func yamlScalar(_ value: String) -> String {
        let needsQuoting = value.contains(":") || value.contains("#") ||
                           value.contains("\n") || value.contains("\"") ||
                           value.hasPrefix(" ") || value.hasSuffix(" ") ||
                           value.hasPrefix("---")
        guard needsQuoting else { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
                           .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    /// Render the exact bridge-compatible prompt markdown for `~/.prompthub/prompts/<uuid>.md`.
    public static func renderPromptMarkdown(
        id: String,
        name: String,
        slug: String,
        description: String?,
        link: String?,
        body: String,
        exportedAt: String
    ) -> String {
        var lines: [String] = ["---"]
        lines.append("id: \(id)")
        lines.append("name: \(yamlScalar(name))")
        lines.append("slug: \(slug)")
        if let description, !description.isEmpty { lines.append("description: \(yamlScalar(description))") }
        if let link, !link.isEmpty { lines.append("link: \(yamlScalar(link))") }
        lines.append("exported_at: \(exportedAt)")
        lines.append("---")
        lines.append("")
        lines.append(body)
        return lines.joined(separator: "\n")
    }

    /// Resolve a prompt identifier using the same exact-then-prefix precedence
    /// the read commands use, but constrained to the supplied prompt list so
    /// callers can batch lookups.
    private func resolveExistingPrompt(
        identifier: String,
        in prompts: [PromptHubExportedAsset]
    ) throws -> PromptHubExportedAsset {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()

        let exact = prompts.filter {
            $0.id.lowercased() == lowered
                || $0.slug?.lowercased() == lowered
                || $0.name.lowercased() == lowered
        }
        if exact.count == 1 { return exact[0] }
        if exact.count > 1 {
            throw PromptHubCLIError.ambiguousAsset(
                kind: .prompt,
                identifier: trimmed,
                matches: exact.map { $0.slug ?? $0.name }.sorted()
            )
        }

        let prefix = prompts.filter {
            $0.id.lowercased().hasPrefix(lowered)
                || ($0.slug?.lowercased().hasPrefix(lowered) ?? false)
        }
        if prefix.count == 1 { return prefix[0] }
        if prefix.count > 1 {
            throw PromptHubCLIError.ambiguousAsset(
                kind: .prompt,
                identifier: trimmed,
                matches: prefix.map { $0.slug ?? $0.name }.sorted()
            )
        }

        throw PromptHubCLIError.assetNotFound(kind: .prompt, identifier: trimmed)
    }

    /// Parse YAML key/value lines out of the `---` frontmatter block of a markdown
    /// file. Intentionally minimal — only handles `key: value` lines, which is the
    /// only shape the bridge ever emits for prompts.
    static func frontmatterMap(in markdown: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return result }
        for line in lines.dropFirst() {
            if line.trimmingCharacters(in: .whitespaces) == "---" { break }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = String(value.dropFirst().dropLast())
                value = value.replacingOccurrences(of: "\\n", with: "\n")
                    .replacingOccurrences(of: "\\\"", with: "\"")
            }
            result[key] = value
        }
        return result
    }

    private func ensureDirectory(_ url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private static func normalizeUUID(_ raw: String?) throws -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UUID(uuidString: trimmed) != nil else {
            throw PromptHubCLIError.invalidPromptID(trimmed)
        }
        // Canonicalize to uppercase to match bridge output.
        return trimmed.uppercased()
    }
}

private extension String {
    /// Returns nil for empty strings, otherwise self.
    var nonEmpty: String? { isEmpty ? nil : self }
}
