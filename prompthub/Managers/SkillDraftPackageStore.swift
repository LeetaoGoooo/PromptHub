import AppKit
import Foundation
import UniformTypeIdentifiers

struct SkillDraftPackageItem: Identifiable, Equatable {
    let relativePath: String
    let displayName: String
    let url: URL
    let isDirectory: Bool
    let children: [SkillDraftPackageItem]

    var id: String { relativePath }
}

@MainActor
final class SkillDraftPackageStore {
    enum PackageError: LocalizedError {
        case applicationSupportUnavailable
        case invalidRelativePath
        case itemAlreadyExists
        case notATextFile
        case cannotDeletePrimarySkillFile

        var errorDescription: String? {
            switch self {
            case .applicationSupportUnavailable:
                return "Application Support directory is unavailable."
            case .invalidRelativePath:
                return "The selected package path is invalid."
            case .itemAlreadyExists:
                return "A file or folder with that name already exists."
            case .notATextFile:
                return "Only text files can be edited inline."
            case .cannotDeletePrimarySkillFile:
                return "SKILL.md is required and cannot be deleted."
            }
        }
    }

    enum NewItemKind: String, CaseIterable, Identifiable {
        case file
        case folder

        var id: String { rawValue }

        var title: String {
            switch self {
            case .file:
                return "Text File"
            case .folder:
                return "Folder"
            }
        }
    }

    static let shared = SkillDraftPackageStore()

    private let fileManager: FileManager
    private let baseURLOverride: URL?

    init(fileManager: FileManager = .default, baseURL: URL? = nil) {
        self.fileManager = fileManager
        self.baseURLOverride = baseURL
    }

    func ensurePackage(for skill: Skill, canonicalSkillMarkdown: String) throws -> URL {
        let rootURL = try packageRootURL(for: skill)
        if !fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        }

        let skillFileURL = rootURL.appendingPathComponent("SKILL.md")
        if !fileManager.fileExists(atPath: skillFileURL.path) {
            try canonicalSkillMarkdown.write(to: skillFileURL, atomically: true, encoding: .utf8)
        }

        return rootURL
    }

    func syncSkillMarkdown(_ markdown: String, for skill: Skill) throws {
        let rootURL = try ensurePackage(for: skill, canonicalSkillMarkdown: markdown)
        let skillFileURL = rootURL.appendingPathComponent("SKILL.md")
        try markdown.write(to: skillFileURL, atomically: true, encoding: .utf8)
    }

    func removePackage(for skill: Skill) {
        guard let rootURL = try? packageRootURL(for: skill) else { return }
        try? fileManager.removeItem(at: rootURL)
    }

    func packageItems(for skill: Skill, canonicalSkillMarkdown: String) throws -> [SkillDraftPackageItem] {
        let rootURL = try ensurePackage(for: skill, canonicalSkillMarkdown: canonicalSkillMarkdown)
        return try loadItems(at: rootURL, rootURL: rootURL)
    }

    func readTextFile(relativePath: String, for skill: Skill, canonicalSkillMarkdown: String) throws -> String {
        let fileURL = try resolvedURL(relativePath: relativePath, for: skill, canonicalSkillMarkdown: canonicalSkillMarkdown)
        guard try isTextFile(at: fileURL) else {
            throw PackageError.notATextFile
        }
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    func writeTextFile(relativePath: String, content: String, for skill: Skill, canonicalSkillMarkdown: String) throws {
        let fileURL = try resolvedURL(relativePath: relativePath, for: skill, canonicalSkillMarkdown: canonicalSkillMarkdown)
        guard try isTextFile(at: fileURL) else {
            throw PackageError.notATextFile
        }
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func createItem(
        named rawName: String,
        kind: NewItemKind,
        parentRelativePath: String?,
        for skill: Skill,
        canonicalSkillMarkdown: String
    ) throws -> String {
        let sanitizedName = sanitizeItemName(rawName)
        guard !sanitizedName.isEmpty else {
            throw PackageError.invalidRelativePath
        }

        let rootURL = try ensurePackage(for: skill, canonicalSkillMarkdown: canonicalSkillMarkdown)
        let parentURL: URL
        let parentPath: String

        if let parentRelativePath, !parentRelativePath.isEmpty {
            let candidateURL = try resolvedURL(relativePath: parentRelativePath, for: skill, canonicalSkillMarkdown: canonicalSkillMarkdown)
            if candidateURL.hasDirectoryPath {
                parentURL = candidateURL
                parentPath = parentRelativePath
            } else {
                parentURL = candidateURL.deletingLastPathComponent()
                parentPath = normalizedRelativePath(from: rootURL, to: parentURL)
            }
        } else {
            parentURL = rootURL
            parentPath = ""
        }

        let newItemURL = parentURL.appendingPathComponent(sanitizedName, isDirectory: kind == .folder)
        guard !fileManager.fileExists(atPath: newItemURL.path) else {
            throw PackageError.itemAlreadyExists
        }

        if kind == .folder {
            try fileManager.createDirectory(at: newItemURL, withIntermediateDirectories: true)
        } else {
            try "".write(to: newItemURL, atomically: true, encoding: .utf8)
        }

        let createdPath = [parentPath, sanitizedName].filter { !$0.isEmpty }.joined(separator: "/")
        return createdPath
    }

    func deleteItem(relativePath: String, for skill: Skill, canonicalSkillMarkdown: String) throws {
        let cleanRelativePath = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanRelativePath.isEmpty else {
            throw PackageError.invalidRelativePath
        }
        if cleanRelativePath.caseInsensitiveCompare("SKILL.md") == .orderedSame {
            throw PackageError.cannotDeletePrimarySkillFile
        }

        let targetURL = try resolvedURL(relativePath: cleanRelativePath, for: skill, canonicalSkillMarkdown: canonicalSkillMarkdown)
        guard fileManager.fileExists(atPath: targetURL.path) else {
            throw PackageError.invalidRelativePath
        }
        try fileManager.removeItem(at: targetURL)
    }

    func reveal(relativePath: String?, for skill: Skill, canonicalSkillMarkdown: String) throws {
        let targetURL: URL
        if let relativePath, !relativePath.isEmpty {
            targetURL = try resolvedURL(relativePath: relativePath, for: skill, canonicalSkillMarkdown: canonicalSkillMarkdown)
        } else {
            targetURL = try ensurePackage(for: skill, canonicalSkillMarkdown: canonicalSkillMarkdown)
        }
        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
    }

    func openInDefaultApp(relativePath: String, for skill: Skill, canonicalSkillMarkdown: String) throws {
        let targetURL = try resolvedURL(relativePath: relativePath, for: skill, canonicalSkillMarkdown: canonicalSkillMarkdown)
        NSWorkspace.shared.open(targetURL)
    }

    func isEditableTextFile(relativePath: String, for skill: Skill, canonicalSkillMarkdown: String) throws -> Bool {
        let targetURL = try resolvedURL(relativePath: relativePath, for: skill, canonicalSkillMarkdown: canonicalSkillMarkdown)
        return try isTextFile(at: targetURL)
    }

    func packageRootURL(for skill: Skill) throws -> URL {
        try baseURL().appendingPathComponent(skill.id.uuidString, isDirectory: true)
    }

    private func baseURL() throws -> URL {
        if let baseURLOverride {
            return baseURLOverride
        }

        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw PackageError.applicationSupportUnavailable
        }
        return appSupportURL
            .appendingPathComponent("PromptHub", isDirectory: true)
            .appendingPathComponent("SkillDraftPackages", isDirectory: true)
    }

    private func resolvedURL(relativePath: String, for skill: Skill, canonicalSkillMarkdown: String) throws -> URL {
        let rootURL = try ensurePackage(for: skill, canonicalSkillMarkdown: canonicalSkillMarkdown)
        let cleanRelativePath = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanRelativePath.isEmpty, !cleanRelativePath.contains("..") else {
            throw PackageError.invalidRelativePath
        }

        let targetURL = rootURL.appendingPathComponent(cleanRelativePath)
        let standardizedRoot = rootURL.standardizedFileURL.path
        let standardizedTarget = targetURL.standardizedFileURL.path
        guard standardizedTarget == standardizedRoot || standardizedTarget.hasPrefix(standardizedRoot + "/") else {
            throw PackageError.invalidRelativePath
        }
        return targetURL
    }

    private func loadItems(at directoryURL: URL, rootURL: URL) throws -> [SkillDraftPackageItem] {
        let childURLs = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentTypeKey],
            options: [.skipsHiddenFiles]
        )

        return try childURLs
            .sorted(by: itemSort)
            .map { childURL in
                let isDirectory = (try? childURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let children = isDirectory ? (try loadItems(at: childURL, rootURL: rootURL)) : []
                return SkillDraftPackageItem(
                    relativePath: normalizedRelativePath(from: rootURL, to: childURL),
                    displayName: childURL.lastPathComponent,
                    url: childURL,
                    isDirectory: isDirectory,
                    children: children
                )
            }
    }

    private func itemSort(lhs: URL, rhs: URL) -> Bool {
        let lhsIsDirectory = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let rhsIsDirectory = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if lhsIsDirectory != rhsIsDirectory {
            return lhsIsDirectory && !rhsIsDirectory
        }
        return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
    }

    private func isTextFile(at fileURL: URL) throws -> Bool {
        let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey])
        if resourceValues.isDirectory == true {
            return false
        }

        let textExtensions: Set<String> = [
            "md", "markdown", "txt", "json", "xml", "yml", "yaml", "toml",
            "sh", "bash", "zsh", "command", "js", "ts", "py", "rb", "swift"
        ]
        if textExtensions.contains(fileURL.pathExtension.lowercased()) {
            return true
        }

        if let contentType = resourceValues.contentType {
            if contentType.conforms(to: .text) || contentType.conforms(to: .sourceCode) || contentType.conforms(to: .json) || contentType.conforms(to: .xml) {
                return true
            }
        }

        let data = try Data(contentsOf: fileURL)
        if data.contains(0) {
            return false
        }
        return String(data: data, encoding: .utf8) != nil
    }

    private func sanitizeItemName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }

    private func normalizedRelativePath(from rootURL: URL, to childURL: URL) -> String {
        let rootPath = rootURL.standardizedFileURL.path
        let childPath = childURL.standardizedFileURL.path
        if childPath == rootPath {
            return ""
        }
        return childPath
            .replacingOccurrences(of: rootPath + "/", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
