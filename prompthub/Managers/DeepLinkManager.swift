//
//  DeepLinkTarget.swift
//  prompthub
//
//  Created by leetao on 2025/5/29.
//


import SwiftUI
import SwiftData
import OSLog


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

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DeepLinkManager")
    
    let urlScheme = "sharedprompt"

    @MainActor
    func handleURL(_ url: URL, modelContainer: ModelContainer) async {
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

        // Check if this link was created by the current user
        let isOwnCreation = SharedCreation.isCreatedByCurrentUser(id: sharedItemID, modelContext: context)
        
        if isOwnCreation {
            logger.info("SharedCreation \(sharedItemID.uuidString) was created by current user - skipping import")
            self.importStatusMessage = "This is your own shared creation - no need to import!"
            return
        }

        do {
  
            let pubCloudKitManager = PublicCloudKitSyncManager(containerIdentifier: "iCloud.com.duck.leetao.promptbox",  modelContext: context)
            let sharedCreation = try await pubCloudKitManager.fetchSharedCreation(bySharedCreationID: sharedItemID)
            
            // Check if a similar prompt already exists locally
            let hasSimilarPrompt = SharedCreation.hasSimilarPromptLocally(
                name: sharedCreation.name,
                prompt: sharedCreation.prompt,
                modelContext: context
            )
            
            if hasSimilarPrompt {
                logger.info("Similar prompt '\(sharedCreation.name)' already exists locally - skipping import")
                self.importStatusMessage = "A similar prompt '\(sharedCreation.name)' already exists in your collection!"
                return
            }
            
            let sourceData = sharedCreation.dataSources?.map { $0.data }
            let newPrompt = Prompt(name: sharedCreation.name, desc: sharedCreation.desc, externalSource: sourceData)
            let newHistory = newPrompt.createHistory(prompt: sharedCreation.prompt, version: 0)
            
            context.insert(newPrompt)
            context.insert(newHistory)
            
            try context.save()
            
            self.importStatusMessage = "'\(newPrompt.name)' imported successfully!"
            self.activeTarget = .showImportedPrompt(promptID: newPrompt.id) // For navigation

        } catch {
            logger.error("Error processing shared item: \(error.localizedDescription)")
            self.activeTarget = .showError(message: "Error importing: \(error.localizedDescription)")
            self.importStatusMessage = "Error importing: \(error.localizedDescription)"
        }
    }
}
