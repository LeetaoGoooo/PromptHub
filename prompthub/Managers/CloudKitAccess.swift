import Foundation
import Security

enum CloudKitAccess {
    static let publicContainerIdentifier = "iCloud.com.duck.leetao.promptbox"
    private static let entitlementKey = "com.apple.developer.icloud-container-identifiers" as CFString

    static func ensureContainerAccess(identifier: String) throws {
        guard hasContainerEntitlement(identifier: identifier) else {
            throw CloudKitAccessError.missingContainerEntitlement(identifier)
        }
    }

    private static func hasContainerEntitlement(identifier: String) -> Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let entitlementValue = SecTaskCopyValueForEntitlement(task, entitlementKey, nil) else {
            return false
        }

        if let identifiers = entitlementValue as? [String] {
            return identifiers.contains(identifier)
        }

        if let identifiers = entitlementValue as? NSArray as? [String] {
            return identifiers.contains(identifier)
        }

        return false
    }
}

enum CloudKitAccessError: LocalizedError {
    case missingContainerEntitlement(String)

    var errorDescription: String? {
        switch self {
        case .missingContainerEntitlement(let identifier):
            return "CloudKit is unavailable in this build. The app is missing access to \(identifier). Use a signed build with the CloudKit entitlement to access shared prompts."
        }
    }
}
