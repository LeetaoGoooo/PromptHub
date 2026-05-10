//
//  prompthubApp.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import SwiftData
import SwiftUI
import KeyboardShortcuts


@MainActor
final class AppState: ObservableObject {
    private var searchWindowController: SearchWindowController
    
    init(modelContainer: ModelContainer) {
        self.searchWindowController = SearchWindowController(modelContainer: modelContainer)
        
        // Set default shortcut for search
        KeyboardShortcuts.setShortcut(.init(.k, modifiers: [.command]), for: .toggleSearch)
        
        // Listen for search shortcut
        KeyboardShortcuts.onKeyDown(for: .toggleSearch) { [weak self] in
            self?.showSearchWindow()
        }
    }
    
    private func showSearchWindow() {
        searchWindowController.showWindow()
    }
}

@main
struct prompthubApp: App {
    var sharedModelContainer: ModelContainer = {

            let publicConfig = ModelConfiguration(
                "PublicStore",
                schema: Schema([SharedCreation.self, DataSource.self]),
                cloudKitDatabase: .automatic
            )

            let privateConfig = ModelConfiguration(
                "PrivateStore",
                schema: Schema([Prompt.self, PromptHistory.self, ExternalSource.self]),
                cloudKitDatabase: .automatic
            )

            // Skills are local-only drafts — never synced to CloudKit.
            // Putting them in a CloudKit-enabled config would require deploying
            // CD_Skill / CD_SkillVersion to the production schema first, which
            // would break sync with "Cannot create new type in production schema".
            let skillsConfig = ModelConfiguration(
                "SkillsStore",
                schema: Schema([Skill.self, SkillVersion.self]),
                cloudKitDatabase: .none
            )

            do {
                return try ModelContainer(
                    for: Schema([SharedCreation.self, DataSource.self, Prompt.self, PromptHistory.self, ExternalSource.self, Skill.self, SkillVersion.self]),
                    migrationPlan: PromptHubMigrationPlan.self,
                    configurations: [publicConfig, privateConfig, skillsConfig]
                )
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()
    
    @StateObject private var appSettings = AppSettings()
    @StateObject private var deepLinkManager = DeepLinkManager()
    @StateObject private var appState: AppState

    init() {
        let modelContainer = sharedModelContainer
        _appState = StateObject(wrappedValue: AppState(modelContainer: modelContainer))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
                .environmentObject(deepLinkManager)
                .environment(ServicesManager())
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
#if os(macOS)
        .defaultSize(width: 1120, height: 760)
#endif
        
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
}
