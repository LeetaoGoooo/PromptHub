import Foundation

/// Persists the user-selected project root URL using a Security-Scoped Bookmark
/// so the sandboxed app can access the folder across launches.
final class SkillProjectSelectionStore {
    static let shared = SkillProjectSelectionStore()

    private let defaults: UserDefaults
    private let bookmarkKey = "skills.selectedProjectRootBookmark"
    // Legacy key – migrated on first read.
    private let legacyPathKey = "skills.selectedProjectRootPath"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateLegacyPathIfNeeded()
    }

    // MARK: - Public API

    var selectedProjectRootURL: URL? {
        guard let data = defaults.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale, let url {
            saveBookmark(for: url)
        }
        return url
    }

    func setSelectedProjectRootURL(_ url: URL?) {
        guard let url else {
            defaults.removeObject(forKey: bookmarkKey)
            return
        }
        saveBookmark(for: url)
    }

    // MARK: - Private helpers

    private func saveBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        defaults.set(data, forKey: bookmarkKey)
    }

    /// One-time migration: if the old raw path key exists, drop it
    /// (we can't create a bookmark from a raw path post-hoc without user picker).
    private func migrateLegacyPathIfNeeded() {
        guard defaults.data(forKey: bookmarkKey) == nil,
              defaults.string(forKey: legacyPathKey) != nil else { return }
        // Remove the stale raw-path entry; user will re-select via picker.
        defaults.removeObject(forKey: legacyPathKey)
    }
}
