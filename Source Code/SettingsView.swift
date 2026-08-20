//
//  SettingsView.swift
//  ConDict
//
//  Created by Jack Davenport on 11/26/25.
//

import SwiftUI
import CoreText
import SwiftData
import AVFoundation
import UniformTypeIdentifiers
import AppKit

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
                    Label("Import Structure", systemImage: "chevron.left.forwardslash.chevron.right").tag(SettingsTab.helpTopic("Help_ImportStructure", "chevron.left.forwardslash.chevron.right"))
                    Label("Etymology", systemImage: "tree").tag(SettingsTab.helpTopic("Help_Etymology", "tree"))
                    Label("Folders", systemImage: "folder").tag(SettingsTab.helpTopic("Help_Folders", "folder"))
                }
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            switch selectedTab {
            case .general:
                GeneralSettingsView(appTheme: $appTheme, selectedVoiceID: $selectedVoiceID)
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
    @Query private var libraries: [Library]
    @Query private var folders: [Folder]
    
    @State private var showExport = false
    @State private var showImport = false
    @State private var document = JSONDocument()
    @State private var importMessage = ""
    
    @State private var selectedImportLibrary: Library?
    @State private var selectedImportFolder: Folder?
    
    @State private var showEraseConfirm = false
    @State private var eraseAction: () -> Void = {}
    
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
            
            Section("Import Destination") {
                Picker("Target Library", selection: $selectedImportLibrary) {
                    Text("New Library").tag(Library?.none)
                    ForEach(libraries) { lib in
                        Text(lib.name).tag(Optional(lib))
                    }
                }
                Picker("Target Folder", selection: $selectedImportFolder) {
                    Text("None").tag(Folder?.none)
                    ForEach(folders) { folder in
                        Text(folder.name).tag(Optional(folder))
                    }
                }
            }
            
            Section("Danger Zone") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Erase data to start fresh. This action cannot be undone.").foregroundStyle(.red)
                    HStack(spacing: 20) {
                        Button("Erase App Data", role: .destructive) {
                            eraseAction = {
                                try? modelContext.delete(model: Word.self)
                                try? modelContext.delete(model: Folder.self)
                                try? modelContext.delete(model: Library.self)
                            }
                            showEraseConfirm = true
                        }
                        
                        Menu("Erase Library...") {
                            ForEach(libraries) { lib in
                                Button(lib.name) {
                                    eraseAction = { modelContext.delete(lib) }
                                    showEraseConfirm = true
                                }
                            }
                        }
                        
                        Menu("Erase Folder...") {
                            ForEach(folders) { folder in
                                Button(folder.name) {
                                    eraseAction = { modelContext.delete(folder) }
                                    showEraseConfirm = true
                                }
                            }
                        }
                    }
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
        .alert("Are you sure?", isPresented: $showEraseConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Erase", role: .destructive) { eraseAction() }
        } message: {
            Text("This action cannot be undone. All selected data will be permanently deleted.")
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
            
            let lib = selectedImportLibrary ?? Library(name: "Imported Data")
            if selectedImportLibrary == nil {
                modelContext.insert(lib)
            }
            
            for item in importedWords {
                let newWord = Word(
                    term: item.term, pronunciation: item.pronunciation, definition: item.definition,
                    partOfSpeech: item.partOfSpeech, example: item.example, notes: item.notes,
                    translations: item.translations, variations: item.variations, tags: item.tags,
                    locationTags: item.locationTags, isPinned: item.isPinned, folder: selectedImportFolder, library: lib
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
    
    // Library Management
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Library.name) private var libraries: [Library]
    @State private var showNewLibSheet = false
    @State private var newLibName = ""
    @State private var libraryToEditFont: Library?
    
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
                            Button(action: { libraryToEditFont = lib }) { Image(systemName: "gear") }.buttonStyle(.plain)
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
        .sheet(item: $libraryToEditFont) { lib in
            LibraryFontPickerView(library: lib)
        }
    }
}

// MARK: - HELP TAB
enum MarkdownBlock: Hashable {
    case text(String)
    case table([String], [[String]])
}

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
    
    func parseMarkdownBlocks(from text: String) -> [MarkdownBlock] {
        let lines = text.components(separatedBy: .newlines)
        var blocks = [MarkdownBlock]()
        var currentText = ""
        var currentTableLines = [String]()
        
        func flushText() {
            if !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.text(currentText))
            }
            currentText = ""
        }
        
        func flushTable() {
            if currentTableLines.isEmpty { return }
            var headers = [String]()
            var rows = [[String]]()
            for (i, tableLine) in currentTableLines.enumerated() {
                let cells = tableLine.split(separator: "|", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
                let actualCells = Array(cells.dropFirst().dropLast())
                if i == 0 { headers = actualCells }
                else if i == 1 && actualCells.first?.contains("-") == true { continue }
                else { rows.append(actualCells) }
            }
            blocks.append(.table(headers, rows))
            currentTableLines.removeAll()
        }
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                flushText()
                currentTableLines.append(trimmed)
            } else {
                flushTable()
                currentText += line + "\n"
            }
        }
        flushText()
        flushTable()
        
        return blocks
    }
    
    func formattedMarkdown(for text: String) -> AttributedString {
        guard let attr = try? AttributedString(markdown: text) else { return AttributedString(text) }
        var result = AttributedString()
        var lastIntentId: Int? = nil
        
        for run in attr.runs {
            if let intent = run.presentationIntent {
                let currentId = intent.components.first?.identity
                let isListItem = intent.components.contains { String(describing: $0).contains("listItem") }
                
                if lastIntentId != nil && currentId != lastIntentId {
                    if !String(result.characters).hasSuffix("\n") {
                        result.append(AttributedString("\n\n"))
                    }
                    if isListItem { result.append(AttributedString("• ")) }
                } else if lastIntentId == nil && isListItem {
                    result.append(AttributedString("• "))
                }
                
                lastIntentId = currentId
            }
            result.append(attr[run.range])
        }
        return result
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: iconName).font(.system(size: 50)).foregroundStyle(Color.accentColor).padding(.bottom, 10)
                let blocks = parseMarkdownBlocks(from: markdownContent)
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .text(let txt):
                        Text(formattedMarkdown(for: txt))
                    case .table(let headers, let rows):
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                                    Text(header).bold().padding(8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                        .background(Color.gray.opacity(0.2))
                                        .border(Color.gray.opacity(0.3))
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            ForEach(Array(rows.enumerated()), id: \.offset) { r, row in
                                HStack(spacing: 0) {
                                    ForEach(Array(row.enumerated()), id: \.offset) { c, cell in
                                        Text(cell).padding(8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                            .background(r % 2 == 0 ? Color.clear : Color.gray.opacity(0.05))
                                            .border(Color.gray.opacity(0.3))
                                    }
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 5)
                    }
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
                    Text("Release 2.1").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            
            Section("What's New in Release 2.1") {
                FeatureRow(icon: "textformat", text: "Custom Library Fonts", subtext: "Assign specific fonts for different libraries.")
                FeatureRow(icon: "square.and.arrow.down", text: "Targeted Import", subtext: "Import JSON data directly to specific libraries and folders.")
                FeatureRow(icon: "exclamationmark.triangle", text: "Danger Zone", subtext: "Erase specific data components easily.")
                FeatureRow(icon: "pencil", text: "UI Changes", subtext: "Edit text has been replaced with a pencil icon.")
                FeatureRow(icon: "doc.text", text: "Import Structure Guide", subtext: "New help topic explaining JSON import format.")
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
                Section("Release 2.1") {
                    Text("• Added Custom Library Fonts")
                    Text("• Targeted Data Import by Library and Folder")
                    Text("• Erase App Data Options (Danger Zone)")
                    Text("• Added Import Structure Help Topic")
                    Text("• Changed Edit Button to Icon")
                }
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

// MARK: - Library Font Picker
struct LibraryFontPickerView: View {
    @Environment(\.dismiss) private var dismiss
    var library: Library
    
    @State private var searchText = ""
    @State private var selectedScript = "All Scripts"
    @State private var previewFontName: String
    
    init(library: Library) {
        self.library = library
        _previewFontName = State(initialValue: library.fontName)
        registerCustomFonts()
    }
    
    // Mock data for Part 1
        let fontDatabase: [(displayName: String, postScriptName: String, script: String)] = [
        ("System", "System", "Roman"),
        ("4#kolek", "4#kolek", "Conlang Scripts"),
        ("Abc", "AbcRNormal", "Conlang Scripts"),
        ("Aceh Original", "AcehOriginal", "Conlang Scripts"),
        ("adaptative script", "adaptativescript", "Conlang Scripts"),
        ("Adunaroth Classic", "AdunarothClassic", "Conlang Scripts"),
        ("Aleo", "Aleo-Regular", "Roman"),
        ("Amadz3", "Amadz3", "Conlang Scripts"),
        ("Anquietas", "Anquietas", "Conlang Scripts"),
        ("AppleBeech", "AppleBeech", "Conlang Scripts"),
        ("Arsenal", "Arsenal-Regular", "Cyrillic"),
        ("Asset", "Asset-Regular", "Roman"),
        ("Avern", "Avern", "Conlang Scripts"),
        ("Aziana", "Zooki-Regular", "Conlang Scripts"),
        ("Bad Script", "BadScript-Regular", "Roman"),
        ("Bel Arian", "BelArian", "Conlang Scripts"),
        ("Blokscript", "Blokscript", "Conlang Scripts"),
        ("Cascadia Mono", "CascadiaMono-Regular", "Greek"),
        ("Cause", "Cause-Regular", "Roman"),
        ("CKA3b", "CKA3b", "Conlang Scripts"),
        ("Cookie", "Cookie-Regular", "Roman"),
        ("Crymeddau", "Crymeddau", "Conlang Scripts"),
        ("Curvetic", "Curveticnormal", "Conlang Scripts"),
        ("Cylenian Font", "CylenianFont", "Conlang Scripts"),
        ("Dardanian 3", "Dardanian3", "Conlang Scripts"),
        ("Datatype", "Datatype-Regular", "Roman"),
        ("Datatype UltraCondensed", "DatatypeUltraCondensed-Regular", "Roman"),
        ("Doto", "Doto-Regular", "Roman"),
        ("Doto Rounded", "DotoRounded-Regular", "Roman"),
        ("Dushan Musa Alphabet", "DushanMusaAlphabet-Regular", "Conlang Scripts"),
        ("Edu SA Beginner", "EduSABeginner-Regular", "Roman"),
        ("Efkolia", "Efkolia", "Conlang Scripts"),
        ("Enganagri", "Enganagri", "Conlang Scripts"),
        ("Eufnix", "Eufnix", "Conlang Scripts"),
        ("Faer", "Faer", "Conlang Scripts"),
        ("FBB_4_336994", "FBB_4_336994", "Conlang Scripts"),
        ("Fehti Martonersi", "FehtiMartonersiRegular", "Conlang Scripts"),
        ("Franaderoan Modern", "FranaderoanModern", "Conlang Scripts"),
        ("Gammadel", "Gammadel", "Conlang Scripts"),
        ("Ge Yin Zi", "GeYinZi", "Conlang Scripts"),
        ("GFS Artemisia", "GFSArtemisia-Regular", "Greek"),
        ("GFS Didot", "GFSDidot-Regular", "Greek"),
        ("GFS Gazis", "GFSGazis-Regular", "Greek"),
        ("GFS Neohellenic", "GFSNeohellenic-Regular", "Greek"),
        ("GFS Olga", "GFSOlga-Regular", "Greek"),
        ("GFS Orpheus Sans", "GFSOrpheusSans", "Greek"),
        ("GFS Porson", "GFSPorson-Regular", "Greek"),
        ("Gluten", "Gluten-Regular", "Roman"),
        ("Google Sans Flex", "GoogleSansFlex72pt-Regular", "Roman"),
        ("Gorwelion", "Gorwelion", "Conlang Scripts"),
        ("Hanawan Syllabary", "Hanawan-Syllabary", "Conlang Scripts"),
        ("Herami", "Herami", "Conlang Scripts"),
        ("High ˆarian", "High-ˆarian", "Conlang Scripts"),
        ("Imperial Script", "ImperialScript-Regular", "Roman"),
        ("Inconsolata", "InconsolataExtraExpanded-Regular", "Roman"),
        ("Inconsolata UltraCondensed", "InconsolataUltraCondensed-Regular", "Roman"),
        ("Inconsolata UltraExpanded", "InconsolataUltraExpanded-Regular", "Roman"),
        ("Indie Flower", "IndieFlower", "Roman"),
        ("Inspired", "Inspired", "Conlang Scripts"),
        ("Instrument Serif", "InstrumentSerif-Regular", "Roman"),
        ("Inter", "Inter24pt-Regular", "Roman"),
        ("INTERBET", "INTERBET", "Conlang Scripts"),
        ("Italianno", "Italianno-Regular", "Roman"),
        ("Jeernervaniaan Sribnaki", "JeernervaniaanSribnakiNormal", "Conlang Scripts"),
        ("JetBrains Mono", "JetBrainsMono-Regular", "Roman"),
        ("Katona III", "KatonaIII-UltraLight", "Cyrillic"),
        ("keburi", "keburi", "Conlang Scripts"),
        ("Keltic", "Keltic", "Conlang Scripts"),
        ("Kerigal", "Kerigal", "Conlang Scripts"),
        ("KRISHNA _ONAL_NARMAL", "KRISHNA_ONAL_NARMAL", "Conlang Scripts"),
        ("KÎble Ruin alphabet", "KÎble-Ruin-alphabet", "Conlang Scripts"),
        ("Laala", "Laalanormal", "Conlang Scripts"),
        ("Lancelot", "Lancelot", "Roman"),
        ("Lato", "Lato-Regular", "Roman"),
        ("Lekton", "Lekton-Regular", "Roman"),
        ("Library", "Library", "Conlang Scripts"),
        ("Lierean Script", "LiereanScript", "Conlang Scripts"),
        ("LinguisticsMod", "LinguisticsMod", "Conlang Scripts"),
        ("Lortho-2", "Lortho-2", "Conlang Scripts"),
        ("LT Superior Mono", "LTSuperiorMono-Regular", "Greek"),
        ("LT Superior Mono Med", "LTSuperiorMono-Medium", "Greek"),
        ("LT Superior Mono Med Semi-", "LTSuperiorMono-Semibold", "Greek"),
        ("Lucrecia Serif", "LucreciaSerif", "Conlang Scripts"),
        ("MesaAnalog", "MesaAnalogMedium", "Conlang Scripts"),
        ("Montaga", "Montaga-Regular", "Roman"),
        ("My Font", "MyFontRegular", "Conlang Scripts"),
        ("NeoRunic", "NeoRunic", "Conlang Scripts"),
        ("NewAkhaT", "NewAkhaT", "Conlang Scripts"),
        ("NewMaori", "NewMaori", "Conlang Scripts"),
        ("Newmong", "NewmongT", "Conlang Scripts"),
        ("Nirichaen (Ninety)", "NirichaenNinety", "Conlang Scripts"),
        ("Nkoma", "Nkoma", "Conlang Scripts"),
        ("Noto Serif", "NotoSerif-Regular", "Roman"),
        ("Nyght Serif", "NyghtSerif-Regular", "Cyrillic"),
        ("Nyght Serif Dark", "NyghtSerif-Dark", "Cyrillic"),
        ("Oranienbaum", "Oranienbaum-Regular", "Roman"),
        ("Patrick Hand", "PatrickHand-Regular", "Roman"),
        ("Pattern", "Pattern", "Conlang Scripts"),
        ("Permanent Marker", "PermanentMarker-Regular", "Roman"),
        ("Phono Braille", "PhonoBraille", "Conlang Scripts"),
        ("Playfair Display", "PlayfairDisplay-Regular", "Roman"),
        ("Ren", "Ren", "Conlang Scripts"),
        ("ReneMP", "ReneMP", "Conlang Scripts"),
        ("Road UI", "RoadUI-Regular", "Cyrillic"),
        ("Road UI ExtBd", "RoadUI-ExtraBold", "Cyrillic"),
        ("Road UI ExtLt", "RoadUI-ExtraLight", "Cyrillic"),
        ("Road UI Med", "RoadUI-Medium", "Cyrillic"),
        ("Road UI SemBd", "RoadUI-SemiBold", "Cyrillic"),
        ("Roboto", "Roboto-Regular", "Roman"),
        ("Rock Salt", "RockSalt-Regular", "Roman"),
        ("Roenskrif", "Roenskrif-Regular", "Conlang Scripts"),
        ("SArchipelago", "SArchipelago", "Conlang Scripts"),
        ("Shirn Brádulë", "ShirnBrdul", "Conlang Scripts"),
        ("Shiwi", "Shiwi", "Conlang Scripts"),
        ("Sidaan", "Sidaan", "Conlang Scripts"),
        ("Sofia", "Sofia-Regular", "Roman"),
        ("Soyombo", "Soyombo", "Conlang Scripts"),
        ("Space Mono", "SpaceMono-Regular", "Roman"),
        ("SpaceInKees", "SpaceInKees-Caligrafic", "Conlang Scripts"),
        ("Tanar", "Tanar", "Conlang Scripts"),
        ("Tenctonese", "Tenctonese", "Conlang Scripts"),
        ("The Hermit Runes", "The-Hermit-Runes", "Conlang Scripts"),
        ("Trevor's Super Longhand", "Trevor's-Super-Longhand", "Conlang Scripts"),
        ("Ultra", "Ultra-Regular", "Roman"),
        ("Universal Alphabet", "Universal-Alphabet", "Conlang Scripts"),
        ("Utrusken", "Utrusken", "Conlang Scripts"),
        ("Vavileqel", "Vavileqel", "Conlang Scripts"),
        ("Vremisian 2.0", "Vremisian-2.0", "Conlang Scripts"),
        ("VT323", "VT323-Regular", "Roman"),
        ("Weem", "Weem", "Cyrillic"),
        ("Workbench", "Workbench-Regular", "Roman"),
        ("Wyrm", "Wyrm", "Conlang Scripts"),
        ("Zalando Sans", "ZalandoSansSemiExpanded-Regular", "Roman"),
        ("Zvin Serif", "ZvinSerif-Regular", "Cyrillic")
    ]
    
    var scripts: [String] {
        let s = Set(fontDatabase.map { $0.script })
        return ["All Scripts"] + s.sorted()
    }
    
    var filteredFonts: [(displayName: String, postScriptName: String, script: String)] {
        fontDatabase.filter { font in
            let matchesScript = selectedScript == "All Scripts" || font.script == selectedScript
            let matchesSearch = searchText.isEmpty || font.displayName.localizedCaseInsensitiveContains(searchText)
            return matchesScript && matchesSearch
        }
    }
    
    

    
    
    func isRTL(fontName: String) -> Bool {
        let name = fontName.lowercased()
        return name.contains("phoenician") || name.contains("canaanite") || name.contains("khatt-i") || name.contains("utruscan") || name.contains("avestan")
    }

    func greetingFor(fontName: String, script: String) -> String {
        let name = fontName.lowercased()
        
        // Fictional / A Priori specific
        if name.contains("aliaric") || name.contains("avern") || name.contains("bel'arian") || name.contains("belarian") { return "suilad" }
        if name.contains("ancients") { return "sgnal" }
        if name.contains("caralhûnan") || name.contains("caralhunan") { return "aiya" }
        if name.contains("chelyesta") || name.contains("daikan") || name.contains("dardanian") { return "kava" }
        if name.contains("faer") || name.contains("falandril") { return "mae govannen" }
        if name.contains("harta") || name.contains("hermit runes") { return "HAILAZ" }
        if name.contains("hylian") { return "konnichiwa" }
        if name.contains("mártölammë") || name.contains("martolamme") { return "elen sila" }
        if name.contains("nirichaen") || name.contains("oxidilogi") { return "sal" }
        if name.contains("troitròskíng") || name.contains("utruscan") { return "avil" }
        if name.contains("wedges") { return "shulmu" }
        if name.contains("efkolia") || name.contains("lovecraftian") { return "ph'nglui" }
        if name.contains("tinta") || name.contains("ataic") || name.contains("lirean") || name.contains("lierean") { return "nai" }
        if name.contains("wyrmish") || name.contains("ckaz") || name.contains("cka3b") || name.contains("skaz") { return "zdrastvuyte" }
        
        // Phonetic / Featural
        if name.contains("uarizibu") || name.contains("gammadel") || name.contains("géyīnzì") || name.contains("franaderoan") || name.contains("franader") { return "ni hao" }
        if name.contains("qosta") || name.contains("rirasu") || name.contains("shiwi") { return "ola" }
        if name.contains("persian-avestan") || name.contains("avestan") { return "dorood" }
        
        // Specific natural/historical implementations mentioned
        if name.contains("phoenician") || name.contains("canaanite") { return "slm" }
        if name.contains("lanna") { return "sawatdee" }
        if name.contains("soyombo") { return "sain baina uu" }
        if name.contains("afaka") { return "odi" }
        if name.contains("kayah") { return "ne di hwa" }
        if name.contains("ol onal") || name.contains("ol chiki") { return "johar" }
        if name.contains("vellara") { return "tungjatjeta" }
        if name.contains("a-chik") || name.contains("tokbirim") { return "nambama" }
        if name.contains("khatt-i") { return "salam" }
        if name.contains("naguaké") || name.contains("taino") { return "tau" }
        if name.contains("vinča") || name.contains("vinca") { return "hello" }
        if name.contains("harah acèh") || name.contains("aceh") { return "peu haba" }
        if name.contains("new akha") || name.contains("akha") { return "uq duq" }
        if name.contains("new mong") || name.contains("mong") { return "nyob zoo" }
        if name.contains("new maori") || name.contains("maori") { return "kia ora" }
        
        // Fallbacks by script category
        if script == "Cyrillic" { return "Привет" }
        if script == "Greek" { return "Γειά σου" }
        if script == "Roman" { return "Hello" }
        
        // Universal fallback for direct ciphers and unnamed fonts
        return "Hello"
    }

    
    private func registerCustomFonts() {
        let exts = ["ttf", "otf", "TTF", "OTF"]
        var urls = [URL]()
        for ext in exts {
            if let fontURLs = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: "Fonts") {
                urls.append(contentsOf: fontURLs)
            }
            if let fontURLs = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                urls.append(contentsOf: fontURLs)
            }
        }
        CTFontManagerRegisterFontsForURLs(urls as CFArray, .process, nil)
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Filters
                VStack(spacing: 10) {
                    TextField("Search Fonts...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Picker("Script", selection: $selectedScript) {
                        ForEach(scripts, id: \.self) { Text($0).tag($0) }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                
                List(selection: $previewFontName) {
                    ForEach(filteredFonts, id: \.postScriptName) { font in
                        Text(font.displayName)
                            .font(font.postScriptName == "System" ? .system(size: 14) : .custom(font.postScriptName, size: 14))
                            .tag(font.postScriptName)
                    }
                }
            }
            .navigationTitle("Typography")
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        } detail: {
            VStack(spacing: 30) {
                Spacer()
                
                let scriptForPreview = fontDatabase.first(where: { $0.postScriptName == previewFontName })?.script ?? "Roman"
                Text(greetingFor(fontName: previewFontName, script: scriptForPreview))
                    .font(previewFontName == "System" ? .system(size: 80) : .custom(previewFontName, size: 80))
                    .environment(\.layoutDirection, isRTL(fontName: previewFontName) ? LayoutDirection.rightToLeft : LayoutDirection.leftToRight)
                    .tracking(isRTL(fontName: previewFontName) ? 0 : 0) // force layout update
                    .multilineTextAlignment(.center)
                    .padding()
                
                let previewDisplayName = fontDatabase.first(where: { $0.postScriptName == previewFontName })?.displayName ?? previewFontName
                Text(previewDisplayName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: {
                    library.fontName = previewFontName
                    dismiss()
                }) {
                    HStack {
                        Text("Apply to Library")
                        Image(systemName: "checkmark.circle")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.05))
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}
