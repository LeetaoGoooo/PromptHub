import Foundation

// MARK: - CLI Detector

/// Checks whether the PromptHub CLI binary is available and executable.
enum CLIDetector {

    /// Known install locations, checked in order.
    static let knownPaths: [String] = [
        "/opt/homebrew/bin/prompthub",
        "/usr/local/bin/prompthub",
        "\(NSHomeDirectory())/.local/bin/prompthub",
    ]

    /// Returns the path of the installed CLI binary, or nil if not found.
    static func installedPath() -> String? {
        // Check PATH first
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for dir in pathEnv.components(separatedBy: ":") {
            let candidate = (dir as NSString).appendingPathComponent("prompthub")
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        // Fallback to known locations (useful when app is launched without full shell PATH)
        return knownPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Returns true when the CLI is installed and executable.
    static func isInstalled() -> Bool {
        installedPath() != nil
    }
}
