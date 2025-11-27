//
//  ConDictApp.swift
//  ConDict
//
//  Created by Jack Davenport on 11/25/25.
//
import SwiftUI
import SwiftData

@main
struct ConDictApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Word.self,
            Folder.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ConDict") {
                    NSApp.orderFrontStandardAboutPanel()
                }
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}
