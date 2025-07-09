//
//  prompthubApp.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import SwiftData
import SwiftUI

@main
struct prompthubApp: App {
    var sharedModelContainer: ModelContainer = {
            
            let publicConfig = ModelConfiguration(
                "PublicStore",
                schema: Schema([SharedCreation.self, DataSource.self]),
                cloudKitDatabase: .automatic
            )

            let privateConfig = ModelConfiguration(
                schema: Schema([ Prompt.self, PromptHistory.self, ExternalSource.self ]),
                cloudKitDatabase: .automatic
            )
            
            do {
                return try ModelContainer(
                    for: Schema([SharedCreation.self, DataSource.self, Prompt.self, PromptHistory.self, ExternalSource.self]),
                    migrationPlan: PromptHubMigrationPlan.self,
                    configurations: [publicConfig, privateConfig]
                )
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()
    
    @StateObject private var appSettings = AppSettings()
    @StateObject private var deepLinkManager = DeepLinkManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
                .environmentObject(deepLinkManager)
                .environment(ServicesManager())
            
                .onAppear {
                    // Perform one-time cleanup when the app starts
                    performOneTimeCleanup()
                }
                .onOpenURL { url in
                    Task {
                        await deepLinkManager.handleURL(url, modelContainer: sharedModelContainer)
                    }
                }
                .alert("Import Status", isPresented: .init(
                    get: { deepLinkManager.importStatusMessage != nil },
                    set: { _ in deepLinkManager.importStatusMessage = nil }
                ), actions: {
                    Button("OK") { }
                }, message: {
                    Text(deepLinkManager.importStatusMessage ?? "Unknown status.")
                })
        }
        .modelContainer(sharedModelContainer)

        MenuBarExtra {
            PromptMenuView()

            Divider()
            
            Button("Quit PromptBox") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
            .padding(.bottom, 6)
        }
        label: {
            Image(nsImage: NSImage(named: "whale")!)
                .resizable()
                .scaledToFit()
                .frame(width: 8, height: 8)
        }
        .modelContainer(sharedModelContainer)
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings-window") {
            SettingsView()
                .environmentObject(appSettings)
                .environment(ServicesManager())
                .frame(minWidth: 550, minHeight: 450)
        }
        #if os(macOS)
        .defaultSize(width: 600, height: 450)
        #endif
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        #if os(macOS)
        WindowGroup("Image Viewer", for: Data.self) { $data in
            if let imageData = data {
                ImageViewerView(imageData: imageData)
                    .frame(minWidth: 200, minHeight: 200)
            } else {
                Text("No image data provided to window.")
                    .frame(width: 300, height: 200)
            }
        }
        .windowResizability(.contentSize)
        #endif
    }
    
    // MARK: - Cleanup Functions
    
    /// Performs one-time cleanup of orphaned SharedCreations when the app starts
    /// Uses UserDefaults to track if cleanup has already been performed
    private func performOneTimeCleanup() {
        let cleanupKey = "SharedCreationCleanupPerformed_v1"
        
        // Check if cleanup has already been performed
        guard !UserDefaults.standard.bool(forKey: cleanupKey) else {
            return
        }
        
        Task {
            do {
                // Create a ModelContext for the cleanup operation
                let context = ModelContext(sharedModelContainer)
                
                // Initialize the sync manager with the CloudKit container identifier
                let syncManager = PublicCloudKitSyncManager(
                    containerIdentifier: "iCloud.com.duck.leetao.promptbox",
                    modelContext: context
                )
                
                // Perform the cleanup
                try await syncManager.cleanupOrphanedLocalSharedCreations()
                
                // Mark cleanup as completed
                UserDefaults.standard.set(true, forKey: cleanupKey)
                
                print("One-time SharedCreation cleanup completed successfully")
            } catch {
                print("Failed to perform one-time SharedCreation cleanup: \(error.localizedDescription)")
                // Don't mark as completed if it failed, so it will retry next time
            }
        }
    }
}
