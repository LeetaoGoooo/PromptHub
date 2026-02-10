import Foundation

protocol CommandLineExecutor: Sendable {
    func execute(args: [String]) async throws -> String
}

class RealCommandLineExecutor: CommandLineExecutor {
    enum ExecutorError: Error {
        case decodingError
        case commandFailed(String)
    }

    func execute(args: [String]) async throws -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["npx", "-y"] + args
        process.standardOutput = pipe
        process.standardError = pipe
        
        var env = ProcessInfo.processInfo.environment
        // Prioritize common binary paths for Homebrew and system-wide Node
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
        
        // Disable ANSI colors at the source
        env["TERM"] = "dumb"
        env["NO_COLOR"] = "1"
        env["FORCE_COLOR"] = "0"
        
        process.environment = env
        
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: ExecutorError.decodingError)
                    return
                }
                
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: ExecutorError.commandFailed(output))
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
