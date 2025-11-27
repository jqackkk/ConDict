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
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        return try! ModelContainer(for: schema, configurations: [modelConfiguration])
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
