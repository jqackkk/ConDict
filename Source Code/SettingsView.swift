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

enum SettingsTab: Hashable {
    case general
    case data
    case developer
    case about
    case helpTopic(String, String) // name, icon
}

struct SettingsView: View {
    @AppStorage("appTheme") private var appTheme: String = "System"
    @AppStorage("selectedVoiceID") private var selectedVoiceID: String = ""
    @AppStorage("selectedFont") private var selectedFont: String = "System"
    
    @State private var selectedTab: SettingsTab? = .general
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section {
                    Label("General", systemImage: "gear").tag(SettingsTab.general)
                    Label("Developer Profile", systemImage: "person.crop.circle").tag(SettingsTab.developer)
                    Label("Data Management", systemImage: "externaldrive").tag(SettingsTab.data)
                    Label("About", systemImage: "info.circle").tag(SettingsTab.about)
                }
                
                Section("Help Topics") {
                    Label("IPA", systemImage: "waveform").tag(SettingsTab.helpTopic("Help_IPA", "waveform"))
                    Label("Libraries", systemImage: "books.vertical").tag(SettingsTab.helpTopic("Help_Libraries", "books.vertical"))
                    Label("Locations", systemImage: "map").tag(SettingsTab.helpTopic("Help_Locations", "map"))
                    Label("Import & Export", systemImage: "square.and.arrow.up").tag(SettingsTab.helpTopic("Help_ImportExport", "square.and.arrow.up"))
                    Label("Etymology", systemImage: "tree").tag(SettingsTab.helpTopic("Help_Etymology", "tree"))
                    Label("Folders", systemImage: "folder").tag(SettingsTab.helpTopic("Help_Folders", "folder"))
                    Label("Typography", systemImage: "textformat.alt").tag(SettingsTab.helpTopic("Help_Typography", "textformat.alt"))
                }
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            switch selectedTab {
            case .general:
                GeneralSettingsView(appTheme: $appTheme, selectedVoiceID: $selectedVoiceID, selectedFont: $selectedFont)
            case .data:
                DataSettingsView()
            case .about:
                AboutSettingsView()
            case .developer:
                DeveloperSettingsView()
            case .helpTopic(let assetName, let icon):
                HelpTopicDetailView(assetName: assetName, iconName: icon)
            case .none:
                Text("Select an item")
            }
        }
        .frame(width: 800, height: 600)
    }
}

// MARK: - DATA TAB
struct DataSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allWords: [Word]
    
    @State private var showExport = false
    @State private var showImport = false
    @State private var document = JSONDocument()
    @State private var importMessage = ""
    
    var body: some View {
        Form {
            Section("Backup & Restore") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Export your dictionary to JSON or import an existing backup.")
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 20) {
                        Button(action: prepareExport) { Label("Export JSON", systemImage: "square.and.arrow.up") }
                        Button(action: { showImport = true }) { Label("Import JSON", systemImage: "square.and.arrow.down") }
                    }
                    .padding(.top, 5)
                }
            }
            
            if !importMessage.isEmpty {
                Section {
                    Text(importMessage).foregroundStyle(importMessage.starts(with: "Error") ? .red : .green)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Data Management")
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
        self.document = JSONDocument(words: exportData)
        self.showExport = true
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
                    term: item.term, pronunciation: item.pronunciation, definition: item.definition,
                    partOfSpeech: item.partOfSpeech, example: item.example, notes: item.notes,
                    translations: item.translations, variations: item.variations, tags: item.tags,
                    locationTags: item.locationTags, isPinned: item.isPinned, library: lib
                )
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
        Form {
            Section("Libraries") {
                if libraries.isEmpty {
                    Text("No libraries found.").foregroundStyle(.secondary)
                } else {
                    ForEach(libraries) { lib in
                        HStack {
                            Text(lib.name)
                            Spacer()
                            Text("\(lib.words?.count ?? 0) words").foregroundStyle(.secondary)
                            Button(action: { modelContext.delete(lib) }) { Image(systemName: "trash").foregroundStyle(.red) }.buttonStyle(.plain)
                        }
                    }
                }
                Button("New Library...") { showNewLibSheet = true }
            }
            
            Section("Appearance") {
                Picker("Theme", selection: $appTheme) {
                    Text("System").tag("System"); Text("Light").tag("Light"); Text("Dark").tag("Dark")
                }
            }
            
            Section("Typography") {
                Picker("Script", selection: $fontScriptFilter) { ForEach(scripts, id: \.self) { Text($0).tag($0) } }
                    .onChange(of: fontScriptFilter) { _, val in
                        if val == "All" { selectedFont = "System" }
                        else if let f = fontOptions.first { selectedFont = f }
                    }
                Picker("Font", selection: $selectedFont) {
                    if fontScriptFilter == "All" { Text("System").tag("System") }
                    else { ForEach(fontOptions, id: \.self) { Text($0).tag($0) } }
                }
            }
            
            Section("Pronunciation Voice") {
                Picker("Language", selection: $selectedLanguageFilter) {
                    ForEach(availableLanguages, id: \.self) { code in Text(Locale.current.localizedString(forLanguageCode: code) ?? code).tag(code) }
                }
                Picker("Voice", selection: $selectedVoiceID) {
                    Text("System Default").tag(""); Divider()
                    ForEach(filteredVoices, id: \.identifier) { voice in Text("\(voice.name) (\(voice.language))").tag(voice.identifier) }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
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
    }
}

// MARK: - HELP TAB
struct HelpTopicDetailView: View {
    let assetName: String
    let iconName: String
    
    var markdownContent: String {
        if let asset = NSDataAsset(name: assetName),
           let string = String(data: asset.data, encoding: .utf8) {
            return string
        }
        return "Failed to load help topic."
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: iconName).font(.system(size: 50)).foregroundStyle(Color.accentColor).padding(.bottom, 10)
                if let attrStr = try? AttributedString(markdown: markdownContent) {
                    Text(attrStr)
                } else {
                    Text(markdownContent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(40)
        }
        .navigationTitle("Help Topic")
    }
}

// MARK: - DEVELOPER TAB
struct DeveloperSettingsView: View {
    var body: some View {
        Form {
            Section {
                VStack(spacing: 15) {
                    Image("ProfilePic").resizable().scaledToFill().frame(width: 100, height: 100).clipShape(Circle())
                    Text("Jack Davenport").font(.title).bold()
                    Text("Student Developer, Conlanger, & Micronation Owner").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            
            Section("Projects") {
                Label("ConDict (macOS Dictionary Manager)", systemImage: "book.pages")
                Label("The United Provinces of Sangaia", systemImage: "map")
                Label("Sangaian (Conlang)", systemImage: "quote.bubble")
                HStack {
                    Label("ravynOS", systemImage: "desktopcomputer")
                    Spacer()
                    Link(destination: URL(string: "https://ravynos.com")!) {
                        Image(systemName: "safari")
                    }.buttonStyle(.plain).foregroundStyle(.blue)
                }
            }
            
            Section("Experience") {
                Label("SwiftUI & SwiftData Development", systemImage: "swift")
                Label("macOS App Architecture", systemImage: "macwindow")
                Label("College Student", systemImage: "graduationcap")
                Label("HTML & CSS Coding", systemImage: "chevron.left.forwardslash.chevron.right")
                Label("C#, C++, and Objective-C", systemImage: "curlybraces")
                Label("Linux System Development", systemImage: "terminal")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Developer Profile")
    }
}

// MARK: - ABOUT TAB
struct AboutSettingsView: View {
    @State private var showHistory = false
    var body: some View {
        Form {
            Section {
                VStack(spacing: 15) {
                    Image("AppIconImage").resizable().scaledToFit().frame(width: 80, height: 80).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(radius: 3)
                    Text("ConDict").font(.title).bold().fontDesign(.serif)
                    Text("Release 2.0").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            
            Section("What's New in Release 2.0") {
                FeatureRow(icon: "macwindow", text: "macOS System Settings", subtext: "A completely redesigned, native settings experience.")
                FeatureRow(icon: "textformat.alt", text: "Rich Text Editor", subtext: "Format definitions using standard keyboard shortcuts.")
                FeatureRow(icon: "sidebar.left", text: "UI Polish", subtext: "New sidebar navigation, modern pickers, and dynamic app icons.")
                FeatureRow(icon: "wand.and.stars", text: "Bug Fixes", subtext: "Fixed a critical crash when exporting dictionary data.")
                FeatureRow(icon: "xmark.bin", text: "Deprecations", subtext: "The titlebar Export button has been removed. All data management is now handled exclusively in Settings.")
            }
            
            Section {
                Button("View Version History") { showHistory = true }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("About")
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
                Section("Release 2.0") {
                    Text("• Redesigned Settings App")
                    Text("• Added Native Rich Text Editor")
                    Text("• Moved Statistics to Menubar")
                    Text("• Native macOS Pickers & UI Polish")
                    Text("• Added Dynamic App Icons")
                    Text("• Fixed JSON Export Crash")
                }
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
