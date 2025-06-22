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
            schema: Schema([SharedCreation.self]),
            cloudKitDatabase: .automatic
        )

        let privateConfig = ModelConfiguration(
            schema: Schema([ Prompt.self, PromptHistory.self, ExternalSource.self ]),
            cloudKitDatabase: .automatic
        )
        
        do {
            return try ModelContainer(
                for: Schema(versionedSchema: SchemaV3.self),
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
                .frame(minWidth: 550, minHeight: 450)
        }
        #if os(macOS)
        .defaultSize(width: 600, height: 450)
        #endif
        .commands {
            CommandGroup(replacing: .newItem) { }
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
}
