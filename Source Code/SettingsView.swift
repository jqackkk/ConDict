//
//  SettingsView.swift
//  ConDict
//
//  Created by Jack Davenport on 11/26/25.
//

import SwiftUI
import SwiftData
import AVFoundation
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("appTheme") private var appTheme: String = "System"
    @AppStorage("selectedVoiceID") private var selectedVoiceID: String = ""
    @AppStorage("selectedFont") private var selectedFont: String = "System"
    
    var body: some View {
        TabView {
            GeneralSettingsView(appTheme: $appTheme, selectedVoiceID: $selectedVoiceID, selectedFont: $selectedFont)
                .tabItem { Label("General", systemImage: "gear") }
            
            DataSettingsView()
                .tabItem { Label("Data", systemImage: "externaldrive") }
            
            HelpSettingsView()
                .tabItem { Label("Help", systemImage: "questionmark.circle") }
            
            DeveloperSettingsView()
                .tabItem { Label("Developer", systemImage: "hammer") }
            
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 700, height: 550)
    }
}

// MARK: - DATA TAB
struct DataSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allWords: [Word]
    
    @State private var showExport = false
    @State private var showImport = false
    @State private var document: JSONDocument?
    @State private var importMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("Data Management")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 10)
                
                VStack(alignment: .center, spacing: 10) {
                    Label("Backup & Restore", systemImage: "arrow.triangle.2.circlepath").font(.headline)
                    Text("Export your dictionary to JSON or import an existing backup.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 20) {
                        Button(action: prepareExport) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export JSON")
                            }.frame(width: 120)
                        }
                        
                        Button(action: { showImport = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Import JSON")
                            }.frame(width: 120)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding().background(Color.gray.opacity(0.1)).cornerRadius(12)
                
                if !importMessage.isEmpty {
                    Text(importMessage)
                        .foregroundStyle(importMessage.starts(with: "Error") ? .red : .green)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(40)
        }
        .fileExporter(isPresented: $showExport, document: document, contentType: .json, defaultFilename: "ConDict_Backup") { _ in }
        .fileImporter(isPresented: $showImport, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                importJSON(from: url)
            case .failure(let error):
                importMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func prepareExport() {
        let exportData = allWords.map {
            WordExport(
                term: $0.term, pronunciation: $0.pronunciation, definition: $0.definition, partOfSpeech: $0.partOfSpeech,
                example: $0.example, notes: $0.notes, translations: $0.translations, variations: $0.variations,
                tags: $0.tags, locationTags: $0.locationTags, isPinned: $0.isPinned, folderName: $0.folder?.name, libraryName: $0.library?.name,
                parentWordTerm: $0.parentWord?.term,
                inflectionData: $0.inflectionData
            )
        }
        if let data = try? JSONEncoder().encode(exportData) {
            self.document = JSONDocument(data: data)
            self.showExport = true
        }
    }
    
    private func importJSON(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            let importedWords = try JSONDecoder().decode([WordExport].self, from: data)
            
            let lib = Library(name: "Imported Data")
            modelContext.insert(lib)
            
            for item in importedWords {
                let newWord = Word(
                    term: item.term,
                    pronunciation: item.pronunciation,
                    definition: item.definition,
                    partOfSpeech: item.partOfSpeech,
                    example: item.example,
                    notes: item.notes,
                    translations: item.translations,
                    variations: item.variations,
                    tags: item.tags,
                    locationTags: item.locationTags,
                    isPinned: item.isPinned,
                    library: lib
                )
                // Note: inflectionData is imported but parentWord linking would require a second pass
                if let infData = item.inflectionData { newWord.inflectionData = infData }
                modelContext.insert(newWord)
            }
            importMessage = "Successfully imported \(importedWords.count) words."
        } catch {
            importMessage = "Failed to import: \(error.localizedDescription)"
        }
    }
}

// MARK: - GENERAL TAB
struct GeneralSettingsView: View {
    @Binding var appTheme: String
    @Binding var selectedVoiceID: String
    @Binding var selectedFont: String
    
    // Library Management
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Library.name) private var libraries: [Library]
    @State private var showNewLibSheet = false
    @State private var newLibName = ""
    
    @State private var fontScriptFilter = "All"
    @State private var selectedLanguageFilter = "en"
    
    var availableLanguages: [String] {
        let codes = Set(AVSpeechSynthesisVoice.speechVoices().map { String($0.language.prefix(2)) })
        return codes.sorted()
    }
    
    var filteredVoices: [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.starts(with: selectedLanguageFilter) }
        if selectedLanguageFilter == "en" {
            var results: [AVSpeechSynthesisVoice] = []
            if let us = allVoices.first(where: { $0.language == "en-US" }) { results.append(us) }
            if let gb = allVoices.first(where: { $0.language == "en-GB" }) { results.append(gb) }
            if let au = allVoices.first(where: { $0.language == "en-AU" }) { results.append(au) }
            return results.isEmpty ? Array(allVoices.prefix(3)) : results
        }
        return Array(allVoices.prefix(3))
    }
    
    let scripts = ["All", "Latin", "Arabic", "Armenian", "Balinese", "Bengali", "Cyrillic", "Devanagari", "Ethiopic", "Georgian", "Glagolitic", "Greek", "Hebrew", "Hiragana", "Korean"]
    
    var fontOptions: [String] {
        switch fontScriptFilter {
        case "All": return ["System"]
        case "Latin": return ["Bodoni Moda"]
        case "Arabic": return ["Ruwudu"]
        case "Armenian": return ["Noto Serif Armenian"]
        case "Balinese": return ["Noto Serif Balinese"]
        case "Bengali": return ["Tiro Bangla"]
        case "Cyrillic": return ["Ledger"]
        case "Devanagari": return ["Rozha One"]
        case "Ethiopic": return ["Abyssinica SL"]
        case "Georgian": return ["Noto Serif Georgian"]
        case "Glagolitic": return ["Shafarik"]
        case "Greek": return ["Noto Serif Display"]
        case "Hebrew": return ["Frank Ruhl Libre"]
        case "Hiragana": return ["Zen Old Mincho"]
        case "Korean": return ["Song Myung"]
        default: return ["System"]
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                
                Text("General Settings")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 10)
                
                // Libraries Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Libraries", systemImage: "books.vertical").font(.headline)
                        Spacer()
                        Button(action: { showNewLibSheet = true }) {
                            Image(systemName: "plus.circle").font(.title2)
                        }.buttonStyle(.plain)
                    }
                    
                    if libraries.isEmpty {
                        Text("No libraries found.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(libraries) { lib in
                            HStack {
                                Text(lib.name)
                                Spacer()
                                Text("\(lib.words?.count ?? 0) words").font(.caption).foregroundStyle(.secondary)
                                Button(action: { modelContext.delete(lib) }) {
                                    Image(systemName: "trash").foregroundStyle(.red)
                                }.buttonStyle(.plain)
                            }
                            .padding(8).background(Color.gray.opacity(0.1)).cornerRadius(6)
                        }
                    }
                }
                .sheet(isPresented: $showNewLibSheet) {
                    VStack(spacing: 20) {
                        Text("New Library").font(.headline)
                        TextField("Name", text: $newLibName).textFieldStyle(.roundedBorder)
                        HStack {
                            Button("Cancel") { showNewLibSheet = false }
                            Button("Create") {
                                let lib = Library(name: newLibName)
                                modelContext.insert(lib)
                                showNewLibSheet = false
                                newLibName = ""
                            }.buttonStyle(.borderedProminent).disabled(newLibName.isEmpty)
                        }
                    }.padding().frame(width: 300)
                }
                
                Divider()
                
                VStack(alignment: .leading) {
                    Label("Appearance", systemImage: "paintbrush").font(.headline)
                    Picker("", selection: $appTheme) {
                        Text("System").tag("System"); Text("Light").tag("Light"); Text("Dark").tag("Dark")
                    }.pickerStyle(.segmented)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    Label("Typography", systemImage: "textformat").font(.headline)
                    HStack {
                        Picker("Script", selection: $fontScriptFilter) { ForEach(scripts, id: \.self) { Text($0).tag($0) } }.frame(width: 120)
                            .onChange(of: fontScriptFilter) { _, val in
                                if val == "All" { selectedFont = "System" }
                                else if let f = fontOptions.first { selectedFont = f }
                            }
                        Picker("Font", selection: $selectedFont) {
                            if fontScriptFilter == "All" { Text("System").tag("System") }
                            else { ForEach(fontOptions, id: \.self) { Text($0).tag($0) } }
                        }
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    Label("Pronunciation Voice", systemImage: "waveform").font(.headline)
                    HStack {
                        Picker("Language", selection: $selectedLanguageFilter) {
                            ForEach(availableLanguages, id: \.self) { code in Text(Locale.current.localizedString(forLanguageCode: code) ?? code).tag(code) }
                        }.frame(width: 150)
                        Picker("Voice", selection: $selectedVoiceID) {
                            Text("System Default").tag(""); Divider()
                            ForEach(filteredVoices, id: \.identifier) { voice in Text("\(voice.name) (\(voice.language))").tag(voice.identifier) }
                        }
                    }
                }
            }
            .padding(40)
        }
    }
}

// MARK: - HELP TAB
struct HelpSettingsView: View {
    let helpItems = [
        HelpItem(title: "IPA", icon: "waveform", description: "The International Phonetic Alphabet (IPA) is a system of symbols used to represent all sounds in human speech."),
        HelpItem(title: "Libraries", icon: "books.vertical", description: "The Libraries feature allows you to manage separate dictionaries for different languages within the same app."),
        HelpItem(title: "Locations", icon: "map", description: "The Locations feature allows you to tag words with specific regional or dialectal origins."),
        HelpItem(title: "Import & Export", icon: "square.and.arrow.up", description: "The Importing/Exporting feature lets you backup your data to a JSON file or restore from one."),
        HelpItem(title: "Etymology", icon: "tree", description: "The Etymology Tree feature visualizes a word's history, showing its roots and any terms derived from it."),
        HelpItem(title: "Folders", icon: "folder", description: "The Folders feature lets you organize words into custom sub-collections within a library for better categorization."),
        HelpItem(title: "Typography", icon: "textformat.alt", description: "The Typography feature lets you customize the app's font, including support for various scripts like Cyrillic or Arabic.")
    ]
    @State private var selectedHelp: HelpItem?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("Help Center")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 10)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 20) {
                    ForEach(helpItems) { item in
                        Button(action: { selectedHelp = item }) {
                            VStack(spacing: 10) {
                                Image(systemName: item.icon).font(.largeTitle).foregroundStyle(Color.accentColor)
                                Text(item.title).font(.headline)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(40)
        }
        .sheet(item: $selectedHelp) { item in
            VStack(spacing: 20) {
                Image(systemName: item.icon).font(.system(size: 50)).foregroundStyle(Color.accentColor)
                Text(item.title).font(.title).bold()
                Text(item.description).multilineTextAlignment(.center).padding()
                Button("Close") { selectedHelp = nil }
            }
            .padding().frame(width: 300, height: 300)
        }
    }
    
    struct HelpItem: Identifiable {
        let id = UUID(); let title: String; let icon: String; let description: String
    }
}

// MARK: - DEVELOPER TAB
struct DeveloperSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle").font(.system(size: 80)).foregroundStyle(.gray.opacity(0.3))
                    Text("Jack Davenport").font(.title).bold()
                    Text("Student Developer, Conlanger, & Micronation Owner").foregroundStyle(.secondary)
                }
                Divider()
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("Projects", systemImage: "folder").font(.headline)
                        Text("• ConDict (macOS Dictionary Manager)").foregroundStyle(.secondary)
                        Text("• The United Provinces of Sangaia").foregroundStyle(.secondary)
                        Text("• Sangaian (Conlang)").foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Label("Experience", systemImage: "graduationcap").font(.headline)
                        Text("• SwiftUI & SwiftData Development").foregroundStyle(.secondary)
                        Text("• macOS App Architecture").foregroundStyle(.secondary)
                        Text("• High School Student").foregroundStyle(.secondary)
                        Text("• HTML & CSS Coding").foregroundStyle(.secondary)
                        Text("• Linux System Development").foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(40)
        }
    }
}

// MARK: - ABOUT TAB
struct AboutSettingsView: View {
    @State private var showHistory = false
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image("AppIconSettings").resizable().scaledToFit().frame(width: 100, height: 100).clipShape(RoundedRectangle(cornerRadius: 22)).shadow(radius: 5).padding(.top, 20)
                Text("ConDict").font(.largeTitle).bold().fontDesign(.serif)
                Text("Beta 1.1").foregroundStyle(.secondary)
                Divider()
                VStack(alignment: .center, spacing: 15) {
                    Text("What's New in Beta 1.1").font(.headline)
                    VStack(alignment: .leading, spacing: 15) {
                        FeatureRow(icon: "wand.and.stars", text: "Bug Fixes", subtext: "Squashed some hidden bugs and critters.")
                    }
                    }.padding(.horizontal, 20)
                Spacer()
                Button("View Version History") { showHistory = true }.buttonStyle(.bordered).padding()
            }.padding()
        }
        .sheet(isPresented: $showHistory) {
            VersionHistoryView()
        }
    }
}

struct VersionHistoryView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack {
            Text("Version History").font(.title2).bold().padding()
            List {
                Section("Beta 1.0") {
                    Text("• Added Sound Change Applier")
                    Text("• Added Etymology Trees")
                    Text("• Added Grammar/Conjugation Tables")
                    Text("• Added Duplicate Validation")
                    Text("• Improved Help Center")
                    Text("• Icons Now Consistent")
                    Text("• Improved Import/Export")
                }
                Section("Alpha 1.5") {
                    Text("• Added Undo/Redo")
                    Text("• True Rich Text Editor")
                    Text("• IPA Utility Window")
                    Text("• Lexical Relationships")
                    Text("• Data Import/Export")
                }
                Section("Alpha 1.4") {
                    Text("• Removed Image-Adding")
                    Text("• Libraries Are In Settings")
                    Text("• Pin Words")
                    Text("• Redesigned Add Word Menu")
                    Text("• Added Help Center")
                    Text("• Added Word Status Icons")
                }
                Section("Alpha 1.3") {
                    Text("• Create Multiple Dictionaries")
                    Text("• More Script Support")
                    Text("• Font Filtering")
                    Text("• Better Location Tags")
                }
                Section("Alpha 1.2") {
                    Text("• Added Font Changing")
                    Text("• New Developer Page in Settings")
                    Text("• Added Location Tags")
                    Text("• Added Dialect Variations")
                    Text("• Added Cyrillic Support")
                }
                Section("Alpha 1.1") {
                    Text("• Added Translation Grid")
                    Text("• Added Settings Menu")
                    Text("• Added Libraries")
                    Text("• Added Folders")
                    Text("• Added Markdown Editing")
                    Text("• Added Image Attachments")
                    Text("• Refined Edit Menu")
                    Text("• Added 'What's New' Section")
                }
                Section("Alpha 1.0") {
                    Text("• Initial Release")
                }
               
            }
            Button("Close") { dismiss() }.padding()
        }.frame(width: 400, height: 600)
    }
}

struct FeatureRow: View {
    let icon: String, text: String, subtext: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(Color.accentColor).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(text).fontWeight(.semibold)
                Text(subtext).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
