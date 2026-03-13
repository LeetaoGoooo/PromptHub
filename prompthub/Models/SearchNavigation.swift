import Foundation

enum SearchNavigationTarget: Equatable {
    case prompt(UUID)
    case skill(UUID)
}

extension Notification.Name {
    static let searchNavigationRequested = Notification.Name("SearchNavigationRequested")
}

enum SearchNavigationRequest {
    static let targetKey = "target"

    static func post(_ target: SearchNavigationTarget) {
        NotificationCenter.default.post(
            name: .searchNavigationRequested,
            object: nil,
            userInfo: [targetKey: target]
        )
    }

    static func from(_ notification: Notification) -> SearchNavigationTarget? {
        notification.userInfo?[targetKey] as? SearchNavigationTarget
    }
}
