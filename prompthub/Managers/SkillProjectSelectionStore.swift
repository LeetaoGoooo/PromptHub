import Foundation

/// Persists saved project roots and the currently active selection using
/// security-scoped bookmarks so the sandboxed app can access those folders
/// across launches.
final class SkillProjectSelectionStore {
    static let shared = SkillProjectSelectionStore()

    private struct StoredProjectBookmark: Codable, Equatable {
        let path: String
        let data: Data
    }

    private let defaults: UserDefaults
    private let bookmarksKey = "skills.savedProjectRootBookmarks"
    private let selectedProjectPathKey = "skills.selectedProjectRootPath"
    private let legacySingleBookmarkKey = "skills.selectedProjectRootBookmark"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateLegacySelectionIfNeeded()
    }

    // MARK: - Public API

    var savedProjectRootURLs: [URL] {
        loadStoredBookmarks().compactMap(resolveURL(for:))
    }

    var selectedProjectRootURL: URL? {
        guard let selectedPath = defaults.string(forKey: selectedProjectPathKey) else { return nil }
        let normalizedSelectedPath = Self.normalizedPath(for: URL(fileURLWithPath: selectedPath, isDirectory: true))
        return savedProjectRootURLs.first { Self.normalizedPath(for: $0) == normalizedSelectedPath }
    }

    func setSelectedProjectRootURL(_ url: URL?) {
        guard let url else {
            defaults.removeObject(forKey: selectedProjectPathKey)
            return
        }

        upsertBookmark(for: url)
        defaults.set(Self.normalizedPath(for: url), forKey: selectedProjectPathKey)
    }

    func addProjectRootURLs(_ urls: [URL], selecting selectedURL: URL? = nil) {
        guard !urls.isEmpty else { return }

        for url in urls {
            upsertBookmark(for: url)
        }

        if let selectedURL {
            defaults.set(Self.normalizedPath(for: selectedURL), forKey: selectedProjectPathKey)
        } else if defaults.string(forKey: selectedProjectPathKey) == nil,
                  let firstURL = urls.last ?? urls.first {
            defaults.set(Self.normalizedPath(for: firstURL), forKey: selectedProjectPathKey)
        }
    }

    func removeProjectRootURL(_ url: URL) {
        let normalizedPath = Self.normalizedPath(for: url)
        var bookmarks = loadStoredBookmarks()
        bookmarks.removeAll { $0.path == normalizedPath }
        saveStoredBookmarks(bookmarks)

        if defaults.string(forKey: selectedProjectPathKey) == normalizedPath {
            defaults.set(bookmarks.first?.path, forKey: selectedProjectPathKey)
        }
    }

    // MARK: - Private helpers

    private func upsertBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }

        let normalizedPath = Self.normalizedPath(for: url)
        var bookmarks = loadStoredBookmarks()
        bookmarks.removeAll { $0.path == normalizedPath }
        bookmarks.insert(StoredProjectBookmark(path: normalizedPath, data: data), at: 0)
        saveStoredBookmarks(bookmarks)
    }

    private func loadStoredBookmarks() -> [StoredProjectBookmark] {
        guard let data = defaults.data(forKey: bookmarksKey),
              let bookmarks = try? JSONDecoder().decode([StoredProjectBookmark].self, from: data) else {
            return []
        }
        return bookmarks
    }

    private func saveStoredBookmarks(_ bookmarks: [StoredProjectBookmark]) {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        defaults.set(data, forKey: bookmarksKey)
    }

    private func resolveURL(for bookmark: StoredProjectBookmark) -> URL? {
        var isStale = false

        if let resolvedURL = try? URL(
            resolvingBookmarkData: bookmark.data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            return resolvedURL
        }

        return URL(fileURLWithPath: bookmark.path, isDirectory: true)
    }

    private static func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func migrateLegacySelectionIfNeeded() {
        guard loadStoredBookmarks().isEmpty else { return }

        if let legacyBookmarkData = defaults.data(forKey: legacySingleBookmarkKey) {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: legacyBookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                upsertBookmark(for: url)
                defaults.set(Self.normalizedPath(for: url), forKey: selectedProjectPathKey)
            }
            defaults.removeObject(forKey: legacySingleBookmarkKey)
            return
        }

        if defaults.string(forKey: selectedProjectPathKey) != nil {
            defaults.removeObject(forKey: selectedProjectPathKey)
        }
    }
}
