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
            cloudKitDatabase: .automatic,
        )

        let privateConfig = ModelConfiguration(
            "PrivateStore",
            schema: Schema([ Prompt.self, PromptHistory.self]),
            cloudKitDatabase: .none,
        )
        
        let schemas = Schema([
            Prompt.self,
            PromptHistory.self,
            SharedCreation.self,
        ])

        do {
            return try ModelContainer(for: schemas, configurations: [publicConfig, privateConfig])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    @StateObject private var appSettings = AppSettings()
    @State private var showingSettings = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
        }
        .modelContainer(sharedModelContainer)

        MenuBarExtra {
            PromptMenuView()
        }
        label: {
            Image(nsImage: NSImage(named: "whale")!)
                .resizable()
                .scaledToFit()
                .frame(width: 8, height: 8)
        }
        .modelContainer(sharedModelContainer)
        
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
