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
            // One-time cleanup: Skill/SkillVersion were previously in the CloudKit-enabled
            // PrivateStore. Any pending CloudKit export rows for those entities must be
            // deleted before the container opens, otherwise CoreData+CloudKit will loop
            // trying to push CD_SkillVersion to the immutable production schema.
            prompthubApp.removeSkillsFromPrivateStoreCloudKit()

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

// MARK: - One-time CloudKit migration cleanup

import SQLite3

extension prompthubApp {
    /// Removes stale CoreData+CloudKit pending-export rows for Skill and SkillVersion
    /// from PrivateStore. These entities were previously in a CloudKit-enabled config;
    /// any queued exports must be cleared so the mirroring delegate can initialize.
    /// Safe to run before the ModelContainer opens (file is not yet locked).
    /// Runs exactly once, guarded by a UserDefaults flag.
    static func removeSkillsFromPrivateStoreCloudKit() {
        let key = "com.prompthub.cloudkit.skill.cleanup.v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        defer { UserDefaults.standard.set(true, forKey: key) }

        guard let appSupportURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        // SwiftData names the store file after the ModelConfiguration name.
        let storeURL = appSupportURL.appendingPathComponent("PrivateStore.store")
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }

        var db: OpaquePointer?
        guard sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let db else { return }
        defer { sqlite3_close(db) }

        // ANSCKRECORDMETADATA tracks which local records need to be pushed to CloudKit.
        // ZNEEDSUPLOAD=1 rows for Skill/SkillVersion cause the "Cannot create new type
        // CD_SkillVersion in production schema" loop. Delete them entirely — these
        // entities now live in SkillsStore (cloudKitDatabase: .none) and should never
        // be exported.
        let sql = """
            BEGIN IMMEDIATE;
            DELETE FROM ANSCKRECORDMETADATA
            WHERE ZENTITYID IN (
                SELECT Z_ENT FROM Z_PRIMARYKEY
                WHERE Z_NAME IN ('Skill', 'SkillVersion')
            );
            COMMIT;
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }
}
