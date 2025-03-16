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
        let schema = Schema([
            Prompt.self,
            PromptHistory.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    @StateObject private var appSettings = AppSettings()
    

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
                .frame(width: 16, height: 16)
        }
        .modelContainer(sharedModelContainer)
        
        Settings {
            SettingsView(isPresented: .constant(false))
                .environmentObject(appSettings)
        }
    }
}
