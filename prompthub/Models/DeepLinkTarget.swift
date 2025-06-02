//
//  DeepLinkTarget.swift
//  prompthub
//
//  Created by leetao on 2025/5/29.
//


import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DeepLinkManager")

enum DeepLinkTarget: Identifiable {
    case showImportedPrompt(promptID: UUID)
    case showError(message: String)

    var id: String {
        switch self {
        case .showImportedPrompt(let id): return "imported-\(id.uuidString)"
        case .showError(let msg): return "error-\(msg.hashValue)"
        }
    }
}

class DeepLinkManager: ObservableObject {
    @Published var activeTarget: DeepLinkTarget? = nil
    @Published var importStatusMessage: String? = nil

    let urlScheme = "sharedprompt"

    @MainActor
    func handleURL(_ url: URL, modelContainer: ModelContainer) {
        logger.info("Handling URL: \(url.absoluteString)")

        guard url.scheme == urlScheme else {
            logger.error("URL scheme mismatch. Expected '\(self.urlScheme)', got '\(url.scheme ?? "nil")'")
            self.activeTarget = .showError(message: "Invalid URL scheme.")
            self.importStatusMessage = "Error: Invalid URL."
            return
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            logger.error("Could not create URLComponents from URL: \(url.absoluteString)")
            self.activeTarget = .showError(message: "Malformed URL.")
            self.importStatusMessage = "Error: Malformed URL."
            return
        }

        
        logger.debug("URL Components: host=\(components.host ?? "nil"), path=\(components.path)")

        guard components.host == "creation" else {
            logger.error("Invalid host. Expected 'creation', got '\(components.host ?? "nil")'")
            self.activeTarget = .showError(message: "Invalid link format (host).")
            self.importStatusMessage = "Error: Invalid link format."
            return
        }

 
        let path = components.path
        guard path.hasPrefix("/") && path.count > 1 else {
            logger.error("Invalid path format: \(path)")
            self.activeTarget = .showError(message: "Invalid link format (path).")
            self.importStatusMessage = "Error: Invalid link format."
            return
        }
        
        let uuidString = String(path.dropFirst())

        guard let sharedItemID = UUID(uuidString: uuidString) else {
            logger.error("Invalid UUID string in path: \(uuidString)")
            self.activeTarget = .showError(message: "Invalid shared item ID.")
            self.importStatusMessage = "Error: Invalid shared item ID."
            return
        }

        logger.info("Extracted SharedCreation ID: \(sharedItemID.uuidString)")

        let context = ModelContext(modelContainer)

        do {
  
            let predicate = #Predicate<SharedCreation> { $0.id == sharedItemID }
            let descriptor = FetchDescriptor(predicate: predicate)
            
            logger.debug("Fetching SharedCreation with ID: \(sharedItemID.uuidString)")
            guard let sharedItem = try context.fetch(descriptor).first else {
                logger.warning("SharedCreation with ID \(sharedItemID.uuidString) not found in public store.")
                self.activeTarget = .showError(message: "Shared item not found.")
                self.importStatusMessage = "Shared item not found."
                return
            }
            logger.info("Found SharedCreation: \(sharedItem.name)")

            let (newPrompt, newPromptHistory) = sharedItem.makeLocalCopy()
 

            logger.debug("Created local Prompt: \(newPrompt.name) (ID: \(newPrompt.id)), History for prompt: \(newPromptHistory.prompt)")

            context.insert(newPrompt)
            context.insert(newPromptHistory)
            try context.save()
            logger.info("Successfully imported and saved '\(newPrompt.name)' locally. Prompt ID: \(newPrompt.id)")

            self.importStatusMessage = "'\(newPrompt.name)' imported successfully!"
            self.activeTarget = .showImportedPrompt(promptID: newPrompt.id) // For navigation

        } catch {
            logger.error("Error processing shared item: \(error.localizedDescription)")
            self.activeTarget = .showError(message: "Error importing: \(error.localizedDescription)")
            self.importStatusMessage = "Error importing: \(error.localizedDescription)"
        }
    }
}
