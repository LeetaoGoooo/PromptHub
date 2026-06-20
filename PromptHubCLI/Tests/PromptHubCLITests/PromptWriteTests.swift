import Foundation
import PromptHubCLILib
import PromptHubSkillKit
import Testing

private func makeTempBase() -> (FileManager, URL) {
    let fileManager = FileManager.default
    let base = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let promptsRoot = base.appendingPathComponent(".prompthub/prompts", isDirectory: true)
    try? fileManager.createDirectory(at: promptsRoot, withIntermediateDirectories: true)
    return (fileManager, base)
}

// MARK: - 1. Round-trip read/write

@Test func createRoundtripsThroughShow() throws {
    let (fileManager, base) = makeTempBase()
    defer { try? fileManager.removeItem(at: base) }

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))
    let created = try service.createPrompt(
        name: "Foo Lookup",
        description: "Demo",
        body: "Hello there.",
        link: nil,
        id: nil
    )

    let fetched = try service.showPrompt(identifier: "foo-lookup")
    #expect(fetched.id == created.id)
    #expect(fetched.name == "Foo Lookup")
    #expect(fetched.body == "Hello there.")
    #expect(fetched.summary == "Demo")
}

// MARK: - 2. Update only the requested fields

@Test func updateChangesOnlyRequestedFields() throws {
    let (fileManager, base) = makeTempBase()
    defer { try? fileManager.removeItem(at: base) }

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))
    let created = try service.createPrompt(name: "Untouched", description: "first", body: "BODY", link: nil, id: nil)

    let updated = try service.updatePrompt(
        identifier: "untouched",
        name: nil,
        description: .some("second"),
        body: nil,
        link: nil
    )

    #expect(updated.id == created.id)
    #expect(updated.slug == "untouched")
    #expect(updated.name == "Untouched")
    #expect(updated.body == "BODY")
    #expect(updated.summary == "second")
}

// MARK: - 3. Slug regeneration on rename

@Test func updateRenameRegeneratesSlugAndPreservesID() throws {
    let (fileManager, base) = makeTempBase()
    defer { try? fileManager.removeItem(at: base) }

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))
    let created = try service.createPrompt(name: "Old Name", description: nil, body: "x", link: nil, id: nil)
    let original = created.id

    let updated = try service.updatePrompt(
        identifier: "old-name",
        name: "Bar Bar",
        description: nil,
        body: nil,
        link: nil
    )
    #expect(updated.id == original)
    #expect(updated.slug == "bar-bar")
    #expect(updated.name == "Bar Bar")

    // The file path is keyed by id, so it does NOT move when the name changes.
    // Resolve symlinks because macOS may surface /var vs /private/var.
    #expect(
        URL(fileURLWithPath: updated.path).resolvingSymlinksInPath().path
            == URL(fileURLWithPath: created.path).resolvingSymlinksInPath().path
    )
}

// MARK: - 4. Atomic write under failure — preserve previous file on write error

@Test func atomicWriteKeepsPreviousFileWhenTargetUnwritable() throws {
    let (fileManager, base) = makeTempBase()
    defer { try? fileManager.removeItem(at: base) }

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))
    let created = try service.createPrompt(name: "Stable", description: "kept", body: "keep me", link: nil, id: nil)

    // Make the file read-only AND the containing directory read-only so atomic
    // rewrite cannot succeed.
    let promptsDir = base.appendingPathComponent(".prompthub/prompts", isDirectory: true)
    try fileManager.setAttributes([.posixPermissions: 0o500], ofItemAtPath: promptsDir.path)
    defer {
        // Restore so cleanup works.
        try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: promptsDir.path)
    }

    do {
        _ = try service.updatePrompt(
            identifier: "stable",
            name: nil,
            description: .some("changed"),
            body: .some("changed body"),
            link: nil
        )
        Issue.record("expected promptWriteFailed under read-only directory")
    } catch let error as PromptHubCLIError {
        if case .promptWriteFailed = error {} else { Issue.record("unexpected error \(error)") }
    }

    // Restore perms so we can read it back.
    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: promptsDir.path)

    // Old content must still be intact.
    let still = try service.showPrompt(identifier: "stable")
    #expect(still.id == created.id)
    #expect(still.body == "keep me")
    #expect(still.summary == "kept")
}

// MARK: - 5. Cross-format parity with PromptHubBridge

@Test func createWritesBridgeCompatibleFrontmatter() throws {
    let (fileManager, base) = makeTempBase()
    defer { try? fileManager.removeItem(at: base) }

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))
    let created = try service.createPrompt(
        name: "Bridge Parity: with colon",
        description: "weird # chars",
        body: "Body here.",
        link: nil,
        id: nil
    )

    // Reload from disk through the standard read path; this is the same parser
    // PromptHubBridge round-trips through.
    let fetched = try service.showPrompt(identifier: created.id)
    #expect(fetched.name == "Bridge Parity: with colon")
    #expect(fetched.summary == "weird # chars")
    #expect(fetched.body == "Body here.")
    // Verify the raw file uses YAML quoting for colon-bearing scalars.
    let raw = try String(contentsOfFile: fetched.path, encoding: .utf8)
    #expect(raw.contains("name: \"Bridge Parity: with colon\""))
    #expect(raw.contains("description: \"weird # chars\""))
    #expect(raw.contains("slug: bridge-parity-with-colon"))
}

// MARK: - 6. Identifier precedence and ambiguity safety

@Test func updateAmbiguousIdentifierDoesNotMutate() throws {
    let (fileManager, base) = makeTempBase()
    defer { try? fileManager.removeItem(at: base) }

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))
    let one = try service.createPrompt(name: "Review One", description: nil, body: "one", link: nil, id: nil)
    let two = try service.createPrompt(name: "Review Two", description: nil, body: "two", link: nil, id: nil)

    do {
        _ = try service.updatePrompt(
            identifier: "review",
            name: nil,
            description: .some("touched"),
            body: nil,
            link: nil
        )
        Issue.record("expected ambiguousAsset for prefix collision")
    } catch let error as PromptHubCLIError {
        if case .ambiguousAsset = error {} else { Issue.record("unexpected error \(error)") }
    }

    // Neither prompt was modified.
    let oneAfter = try service.showPrompt(identifier: one.id)
    let twoAfter = try service.showPrompt(identifier: two.id)
    #expect(oneAfter.summary == nil)
    #expect(twoAfter.summary == nil)
}

// MARK: - 7. --id collision

@Test func createWithDuplicateIDFailsCleanly() throws {
    let (fileManager, base) = makeTempBase()
    defer { try? fileManager.removeItem(at: base) }

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))
    let fixedID = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    _ = try service.createPrompt(name: "First", description: nil, body: "x", link: nil, id: fixedID)

    do {
        _ = try service.createPrompt(name: "Second", description: nil, body: "y", link: nil, id: fixedID)
        Issue.record("expected promptIDCollision")
    } catch let error as PromptHubCLIError {
        if case .promptIDCollision = error {} else { Issue.record("unexpected error \(error)") }
    }

    // Original prompt body untouched.
    let first = try service.showPrompt(identifier: fixedID)
    #expect(first.name == "First")
}

// MARK: - 8. --id non-UUID rejected

@Test func createWithMalformedIDFailsBeforeWrite() throws {
    let (fileManager, base) = makeTempBase()
    defer { try? fileManager.removeItem(at: base) }

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))
    do {
        _ = try service.createPrompt(name: "Anything", description: nil, body: "x", link: nil, id: "not-a-uuid")
        Issue.record("expected invalidPromptID")
    } catch let error as PromptHubCLIError {
        if case .invalidPromptID = error {} else { Issue.record("unexpected error \(error)") }
    }
    // No file should be created.
    let promptsDir = base.appendingPathComponent(".prompthub/prompts", isDirectory: true)
    let entries = try fileManager.contentsOfDirectory(at: promptsDir, includingPropertiesForKeys: nil)
    #expect(entries.isEmpty)
}

// MARK: - 9. Slug collision rejected before overwrite

@Test func renameToCollidingSlugFails() throws {
    let (fileManager, base) = makeTempBase()
    defer { try? fileManager.removeItem(at: base) }

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))
    _ = try service.createPrompt(name: "Alpha", description: nil, body: "a", link: nil, id: nil)
    _ = try service.createPrompt(name: "Bravo", description: nil, body: "b", link: nil, id: nil)

    do {
        _ = try service.updatePrompt(
            identifier: "bravo",
            name: "Alpha",
            description: nil,
            body: nil,
            link: nil
        )
        Issue.record("expected promptSlugCollision")
    } catch let error as PromptHubCLIError {
        if case .promptSlugCollision = error {} else { Issue.record("unexpected error \(error)") }
    }
}

// MARK: - 10. Delete removes the file

@Test func deleteRemovesFileAndIsObservable() throws {
    let (fileManager, base) = makeTempBase()
    defer { try? fileManager.removeItem(at: base) }

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))
    let created = try service.createPrompt(name: "Doomed", description: nil, body: "x", link: nil, id: nil)
    #expect(fileManager.fileExists(atPath: created.path))

    let removed = try service.deletePrompt(identifier: "doomed")
    // Compare basenames — full paths can differ in /var vs /private/var form on macOS.
    #expect(removed.lastPathComponent == URL(fileURLWithPath: created.path).lastPathComponent)
    #expect(!fileManager.fileExists(atPath: created.path))

    // Subsequent show fails with assetNotFound.
    do {
        _ = try service.showPrompt(identifier: "doomed")
        Issue.record("expected assetNotFound after delete")
    } catch let error as PromptHubCLIError {
        if case .assetNotFound = error {} else { Issue.record("unexpected error \(error)") }
    }
}

// MARK: - 11. End-to-end lifecycle scenario

@Test func endToEndLifecycleScenario() throws {
    let (fileManager, base) = makeTempBase()
    defer { try? fileManager.removeItem(at: base) }

    let service = PromptHubCLIService(environment: PromptHubCLIEnvironment(homeDirectoryURL: base))

    // create
    let created = try service.createPrompt(
        name: "Lifecycle Demo",
        description: "v1",
        body: "Hello {{name}}.",
        link: nil,
        id: nil
    )
    #expect(created.slug == "lifecycle-demo")

    // list — must show exactly one prompt and find by slug.
    let listed = try service.listPrompts()
    #expect(listed.map(\.slug) == ["lifecycle-demo"])

    // search by body substring
    let found = try service.searchPrompts(query: "hello")
    #expect(found.first?.id == created.id)

    // render — declared variable substitution works against CLI-written body.
    let rendered = try service.renderPrompt(identifier: "lifecycle-demo", variables: ["name": "Ada"])
    #expect(rendered.rendered == "Hello Ada.")

    // update body only
    let updated = try service.updatePrompt(
        identifier: created.id,
        name: nil,
        description: nil,
        body: .some("Goodbye {{name}}."),
        link: nil
    )
    let rendered2 = try service.renderPrompt(identifier: "lifecycle-demo", variables: ["name": "Ada"])
    #expect(rendered2.rendered == "Goodbye Ada.")
    #expect(updated.id == created.id)

    // delete
    _ = try service.deletePrompt(identifier: "lifecycle-demo")
    #expect(try service.listPrompts().isEmpty)
}

// MARK: - Slug derivation helper parity

@Test func slugHelperMatchesBridgeRule() {
    #expect(PromptHubCLIService.slug(for: "Foo Bar BAZ") == "foo-bar-baz")
    #expect(PromptHubCLIService.slug(for: "  spaces  ") == "spaces")
    #expect(PromptHubCLIService.slug(for: "punct: yes!") == "punct-yes")
    #expect(PromptHubCLIService.slug(for: "中文 mixed") == "mixed" || PromptHubCLIService.slug(for: "中文 mixed") == "中文-mixed")
}

// MARK: - YAML scalar quoting parity

@Test func yamlScalarMatchesBridgeQuotingRules() {
    #expect(PromptHubCLIService.yamlScalar("plain") == "plain")
    #expect(PromptHubCLIService.yamlScalar("has: colon") == "\"has: colon\"")
    #expect(PromptHubCLIService.yamlScalar("has # hash") == "\"has # hash\"")
    #expect(PromptHubCLIService.yamlScalar("ends with quote\"") == "\"ends with quote\\\"\"")
    #expect(PromptHubCLIService.yamlScalar(" leading space") == "\" leading space\"")
}
