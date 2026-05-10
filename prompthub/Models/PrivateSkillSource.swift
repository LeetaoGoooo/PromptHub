import Foundation
import Security

// MARK: - Model

/// A user-configured private skill source — either a private GitHub repo or a
/// team-shared local directory (e.g. an NFS share).
struct PrivateSkillSource: Codable, Identifiable, Equatable {
    enum SourceType: String, Codable, CaseIterable {
        case githubPrivate = "github-private"
        case localShared   = "local-shared"

        var displayName: String {
            switch self {
            case .githubPrivate: return "Private GitHub Repo"
            case .localShared:   return "Team Shared Path"
            }
        }

        var systemImage: String {
            switch self {
            case .githubPrivate: return "lock.shield"
            case .localShared:   return "externaldrive.connected.to.line.below"
            }
        }
    }

    /// Stable identifier, auto-generated on creation.
    let id: String
    /// Human-readable label shown in the UI.
    var label: String
    var type: SourceType
    /// For `githubPrivate`: `owner/repo`; for `localShared`: absolute path string.
    var location: String
    /// Optional description shown in the list.
    var notes: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        label: String,
        type: SourceType,
        location: String,
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.location = location
        self.notes = notes
        self.createdAt = createdAt
    }

    /// Returns the `owner/repo` value for GitHub sources, nil for local.
    var githubOwnerRepo: (owner: String, repo: String)? {
        guard type == .githubPrivate else { return nil }
        let parts = location.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return (parts[0], parts[1])
    }
}

// MARK: - Store

/// Persists `PrivateSkillSource` metadata in UserDefaults and GitHub tokens in the
/// macOS Keychain.  All token access is done directly through the Security framework —
/// no external dependencies required.
final class PrivateSkillSourceStore: ObservableObject {
    static let shared = PrivateSkillSourceStore()

    @Published private(set) var sources: [PrivateSkillSource] = []

    private let defaults: UserDefaults
    private static let storageKey = "privateSkillSources.v1"
    private static let keychainService = "com.prompthub.private-skill-token"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.sources = Self.load(from: defaults)
    }

    // MARK: CRUD

    func add(_ source: PrivateSkillSource) {
        sources.removeAll { $0.id == source.id }
        sources.append(source)
        save()
    }

    func remove(id: String) {
        deleteToken(for: id)
        sources.removeAll { $0.id == id }
        save()
    }

    func update(_ source: PrivateSkillSource) {
        guard let idx = sources.firstIndex(where: { $0.id == source.id }) else { return }
        sources[idx] = source
        save()
    }

    // MARK: Token (Keychain)

    func saveToken(_ token: String, for sourceID: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { deleteToken(for: sourceID); return }
        let data = Data(trimmed.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: sourceID,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        // Try update first, then add.
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query as CFDictionary, nil)
        }
        // Ignore errors — if Keychain fails the token won't persist but the source will.
    }

    func loadToken(for sourceID: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: sourceID,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else { return nil }
        return token
    }

    func deleteToken(for sourceID: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: sourceID
        ]
        SecItemDelete(query as CFDictionary)
    }

    func hasToken(for sourceID: String) -> Bool {
        loadToken(for: sourceID) != nil
    }

    // MARK: Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(sources) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [PrivateSkillSource] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PrivateSkillSource].self, from: data) else {
            return []
        }
        return decoded
    }
}
