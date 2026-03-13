import Foundation

final class SkillProjectSelectionStore {
    static let shared = SkillProjectSelectionStore()

    private let defaults: UserDefaults
    private let key = "skills.selectedProjectRootPath"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedProjectRootURL: URL? {
        guard let path = defaults.string(forKey: key), !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    func setSelectedProjectRootURL(_ url: URL?) {
        if let url {
            defaults.set(url.standardizedFileURL.path, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
