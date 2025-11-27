//
//  ContentView.swift
//  ConDict
//
//  Created by Jack Davenport on 11/25/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AVFoundation
import PhotosUI

let speechSynthesizer = AVSpeechSynthesizer()

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    // FETCH LIBRARIES
    @Query(sort: \Library.name) private var libraries: [Library]
    @State private var selectedLibraryID: PersistentIdentifier?
    @State private var showAllWordsGlobal: Bool = false
    
    @Query(sort: \Word.term) private var allWords: [Word]
    @Query(sort: \Folder.name) private var allFolders: [Folder]
    
    // Global Settings
    @AppStorage("selectedVoiceID") var selectedVoiceID: String = ""
    @AppStorage("appTheme") var appTheme: String = "System"
    @AppStorage("selectedFont") var selectedFont: String = "System"
    
    @State private var selectedWord: Word?
    @State private var selectedFolder: Folder?
    @State private var searchText = ""
    @State private var selectedFilter: String = "All"
    
    @State private var isShowingAddSheet = false
    @State private var isShowingFolderSheet = false
    @State private var isShowingLibrarySheet = false
    @State private var isShowingExport = false
    @State private var document: JSONDocument?
    
    @State private var newName = ""
    @State private var newFolderTags = ""
    
    var partsOfSpeech = ["All", "Noun", "Verb", "Adjective", "Adverb", "Pronoun", "Particle", "Conjunction", "Interjection", "Other"]
    
    func getCustomFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if selectedFont == "System" { return .system(size: size, weight: weight, design: .serif) }
        else { return .custom(selectedFont, size: size).weight(weight) }
    }
    
    var colorScheme: ColorScheme? {
        switch appTheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }
    
    // COMPUTED LISTS
    var currentLibrary: Library? {
        if showAllWordsGlobal { return nil }
        if let id = selectedLibraryID {
            return libraries.first(where: { $0.persistentModelID == id })
        }
        return libraries.first
    }
    
    var visibleWords: [Word] {
        if showAllWordsGlobal { return allWords }
        guard let lib = currentLibrary else { return [] }
        return allWords.filter { $0.library == lib }
    }
    
    var visibleFolders: [Folder] {
        guard let lib = currentLibrary else { return [] }
        return allFolders.filter { $0.library == lib }
    }
    
    var filteredWords: [Word] {
        let baseList = selectedFolder == nil ? visibleWords : visibleWords.filter { $0.folder == selectedFolder }
        let searchFiltered: [Word]
        if searchText.isEmpty { searchFiltered = baseList }
        else {
            searchFiltered = baseList.filter { word in
                word.term.localizedCaseInsensitiveContains(searchText) ||
                word.definition.localizedCaseInsensitiveContains(searchText) ||
                word.locationTags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        if selectedFilter == "All" { return searchFiltered }
        else { return searchFiltered.filter { $0.partOfSpeech == selectedFilter } }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedWord) {
                
                // MARK: - LIBRARIES
                Section("Libraries") {
                    Button(action: {
                        showAllWordsGlobal = true
                        selectedLibraryID = nil
                        selectedFolder = nil
                    }) {
                        Label("All Words", systemImage: "tray.2.fill")
                            .foregroundStyle(showAllWordsGlobal ? Color.accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                    
                    ForEach(libraries) { lib in
                        Button(action: {
                            showAllWordsGlobal = false
                            selectedLibraryID = lib.persistentModelID
                            selectedFolder = nil
                        }) {
                            HStack {
                                Image(systemName: "books.vertical.fill")
                                    .foregroundStyle(selectedLibraryID == lib.persistentModelID ? Color.accentColor : .primary)
                                
                                Text(lib.name)
                                    .foregroundStyle(selectedLibraryID == lib.persistentModelID ? Color.accentColor : .primary)
                                    .fontWeight(selectedLibraryID == lib.persistentModelID ? .semibold : .regular)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu { Button("Delete Library", role: .destructive) { modelContext.delete(lib) } }
                    }
                    
                    Button("New Library...") { newName = ""; isShowingLibrarySheet = true }
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                
                // MARK: - FOLDERS
                if currentLibrary != nil {
                    Section("Folders") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 10) {
                            ForEach(visibleFolders) { folder in
                                Button(action: { selectedFolder = folder }) {
                                    VStack {
                                        Image(systemName: folder.icon).font(.title2).foregroundStyle(selectedFolder == folder ? .white : Color.accentColor)
                                        Text(folder.name).font(.caption).lineLimit(1).foregroundStyle(selectedFolder == folder ? .white : .primary)
                                    }
                                    .frame(maxWidth: .infinity).padding(10)
                                    .background(selectedFolder == folder ? Color.accentColor : Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .contextMenu { Button("Delete", role: .destructive) { deleteFolder(folder) } }
                            }
                            Button(action: { newName = ""; newFolderTags = ""; isShowingFolderSheet = true }) {
                                VStack {
                                    Image(systemName: "plus").font(.title2).foregroundStyle(.secondary)
                                    Text("New").font(.caption).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity).padding(10)
                                .background(Color.clear)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundStyle(.secondary.opacity(0.5)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 5)
                    }
                }
                
                // MARK: - WORDS
                Section(selectedFolder?.name ?? (showAllWordsGlobal ? "All Words" : (currentLibrary?.name ?? "Library"))) {
                    ForEach(filteredWords) { word in
                        NavigationLink(value: word) {
                            VStack(alignment: .leading) {
                                Text(word.term).font(getCustomFont(size: 16, weight: .bold))
                                Text(word.definition).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .padding(.vertical, 3)
                        }
                        .contextMenu { Button("Delete", role: .destructive) { deleteWord(word) } }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
            .searchable(text: $searchText, placement: .sidebar)
            
            // MARK: - FOOTER STATS
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Text("\(filteredWords.count) Words")
                    Spacer()
                    if let folder = selectedFolder { Text(folder.name) }
                    else if showAllWordsGlobal { Text("Global") }
                    else { Text(currentLibrary?.name ?? "") }
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding().background(.regularMaterial)
            }
            
        } detail: {
            if let word = selectedWord {
                WordDetailContainer(word: word, selectedVoiceID: selectedVoiceID, selectedFont: selectedFont)
            } else {
                ContentUnavailableView("Select a Word", systemImage: "book", description: Text("Select a word from the sidebar or add a new one."))
            }
        }
        .preferredColorScheme(colorScheme)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(partsOfSpeech, id: \.self) { type in Text(type).tag(type) }
                    }
                } label: { Label("Filter", systemImage: selectedFilter == "All" ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill") }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { newName = ""; newFolderTags = ""; isShowingFolderSheet = true }) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .disabled(showAllWordsGlobal || currentLibrary == nil)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isShowingAddSheet = true }) { Label("Add Word", systemImage: "plus") }
            }
            ToolbarItem(placement: .automatic) {
                Button(action: prepareExport) { Label("Export JSON", systemImage: "square.and.arrow.up") }
            }
        }
        .sheet(isPresented: $isShowingAddSheet) {
            AddWordView(targetFolder: selectedFolder, targetLibrary: currentLibrary).preferredColorScheme(colorScheme)
        }
        .sheet(isPresented: $isShowingFolderSheet) {
            NavigationStack {
                Form {
                    TextField("Folder Name", text: $newName)
                    TextField("Tags (comma separated)", text: $newFolderTags)
                }
                .navigationTitle("New Folder")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isShowingFolderSheet = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            let tags = newFolderTags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                            let newFolder = Folder(name: newName, tags: tags, library: currentLibrary)
                            modelContext.insert(newFolder)
                            isShowingFolderSheet = false
                        }
                        .disabled(newName.isEmpty)
                    }
                }
            }
            .frame(width: 400, height: 200)
        }
        .sheet(isPresented: $isShowingLibrarySheet) {
            NavigationStack {
                Form { TextField("Library Name", text: $newName) }
                .navigationTitle("New Library")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isShowingLibrarySheet = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            let lib = Library(name: newName)
                            modelContext.insert(lib)
                            selectedLibraryID = lib.persistentModelID
                            showAllWordsGlobal = false
                            isShowingLibrarySheet = false
                        }
                        .disabled(newName.isEmpty)
                    }
                }
            }
            .frame(width: 300, height: 150)
        }
        .fileExporter(isPresented: $isShowingExport, document: document, contentType: .json, defaultFilename: "ConDict_Export") { result in
            if case .success(let url) = result { print("Saved to \(url)") }
        }
        .onAppear {
            if libraries.isEmpty {
                let defaultLib = Library(name: "My Dictionary")
                modelContext.insert(defaultLib)
                selectedLibraryID = defaultLib.persistentModelID
            } else if selectedLibraryID == nil {
                selectedLibraryID = libraries.first?.persistentModelID
            }
        }
    }

    private func deleteWord(_ word: Word) {
        withAnimation {
            if selectedWord == word { selectedWord = nil }
            modelContext.delete(word)
        }
    }
    
    private func deleteFolder(_ folder: Folder) {
        withAnimation {
            if selectedFolder == folder { selectedFolder = nil }
            modelContext.delete(folder)
        }
    }
    
    private func prepareExport() {
        let exportData = allWords.map {
            WordExport(
                term: $0.term, pronunciation: $0.pronunciation, definition: $0.definition, partOfSpeech: $0.partOfSpeech,
                example: $0.example, notes: $0.notes, translations: $0.translations, variations: $0.variations,
                tags: $0.tags, locationTags: $0.locationTags, imageData: $0.imageData, folderName: $0.folder?.name, libraryName: $0.library?.name
            )
        }
        if let data = try? JSONEncoder().encode(exportData) {
            self.document = JSONDocument(data: data)
            self.isShowingExport = true
        }
    }
}

// MARK: - Detail Container
struct WordDetailContainer: View {
    @Bindable var word: Word
    var selectedVoiceID: String
    var selectedFont: String
    @State private var isEditing = false
    
    var body: some View {
        Group {
            if isEditing {
                WordEditForm(word: word, selectedFont: selectedFont) // Passed font
            } else {
                WordDisplayView(word: word, voiceID: selectedVoiceID, selectedFont: selectedFont)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(isEditing ? "Done" : "Edit") { withAnimation { isEditing.toggle() } }
            }
        }
    }
}

// MARK: - Display View
struct WordDisplayView: View {
    let word: Word
    let voiceID: String
    let selectedFont: String
    @State private var activePopover: UUID?
    
    func getCustomFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if selectedFont == "System" { return .system(size: size, weight: weight, design: .serif) }
        else { return .custom(selectedFont, size: size).weight(weight) }
    }
    
    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(word.term).font(getCustomFont(size: 48, weight: .bold)).textSelection(.enabled)
                        
                        HStack(spacing: 12) {
                            if !word.pronunciation.isEmpty {
                                HStack(spacing: 4) {
                                    Text("/\(word.pronunciation)/").font(.system(.title3, design: .monospaced)).foregroundStyle(.secondary)
                                    Button(action: { speak(word.pronunciation, isIPA: true) }) {
                                        Image(systemName: "speaker.wave.2.circle.fill").foregroundStyle(.tint)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            Text(word.partOfSpeech).font(.subheadline).fontWeight(.medium).padding(.horizontal, 10).padding(.vertical, 4).background(Color.accentColor.opacity(0.1)).foregroundStyle(Color.accentColor).clipShape(Capsule())
                        }
                        
                        if !word.tags.isEmpty || !word.locationTags.isEmpty {
                            HStack {
                                ForEach(word.tags, id: \.self) { tag in
                                    Text("#\(tag)").font(.caption).padding(4).background(Color.gray.opacity(0.1)).cornerRadius(4)
                                }
                                ForEach(word.locationTags, id: \.self) { loc in
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin").font(.caption2)
                                        Text(loc).font(.caption)
                                    }
                                    .padding(4)
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .cornerRadius(4)
                                }
                            }
                        }
                    }
                    Divider()
                    
                    // Definition
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Definition", systemImage: "book.closed").font(.headline).foregroundStyle(.secondary)
                        Text(.init(word.definition)).font(getCustomFont(size: 22)).lineSpacing(4).textSelection(.enabled)
                    }
                    
                    // Example
                    if !word.example.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Example", systemImage: "quote.opening").font(.headline).foregroundStyle(.secondary)
                            Text(word.example).font(getCustomFont(size: 18)).italic().padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.gray.opacity(0.05)).cornerRadius(8)
                        }
                    }
                    
                    // VARIATIONS
                    if !word.variations.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Variations", systemImage: "map.fill").font(.headline).foregroundStyle(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 10) {
                                ForEach(word.variations) { variant in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(variant.name).font(.headline)
                                            Spacer()
                                            
                                            Button(action: { activePopover = variant.id }) {
                                                Image(systemName: "mappin.circle.fill")
                                                    .foregroundStyle(Color.accentColor)
                                                    .font(.title3)
                                            }
                                            .buttonStyle(.plain)
                                            .popover(isPresented: Binding(get: { activePopover == variant.id }, set: { if !$0 { activePopover = nil } }), arrowEdge: .bottom) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Location").font(.caption).foregroundStyle(.secondary)
                                                    Text(variant.location).font(.headline)
                                                }.padding().frame(minWidth: 150)
                                            }
                                        }
                                        HStack {
                                            Text("/\(variant.pronunciation)/").font(.caption).foregroundStyle(.secondary)
                                            Spacer()
                                            Button(action: { speak(variant.pronunciation, isIPA: true) }) {
                                                Image(systemName: "speaker.wave.1").font(.caption)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // TRANSLATIONS
                    if !word.translations.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Translations", systemImage: "globe").font(.headline).foregroundStyle(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 10) {
                                ForEach(word.translations) { trans in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(trans.text).font(.headline)
                                            Text(trans.language).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button(action: { speak(trans.text) }) {
                                            Image(systemName: "speaker.wave.1").font(.caption).foregroundStyle(Color.accentColor)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(10).background(Color.gray.opacity(0.1)).cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // NOTES
                    if !word.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notes", systemImage: "note.text").font(.headline).foregroundStyle(.secondary)
                            Text(word.notes).font(.body)
                        }
                    }
                }
                
                if let imageData = word.imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fill).frame(width: 250, height: 250).clipShape(RoundedRectangle(cornerRadius: 12)).shadow(radius: 4)
                }
            }
            .padding(40)
        }
    }
    
    func speak(_ text: String, isIPA: Bool = false) {
        let utterance = AVSpeechUtterance(string: text)
        if !isIPA {
            if let scalar = text.unicodeScalars.first, scalar.value >= 0x0400 && scalar.value <= 0x04FF {
                utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
            }
            else if let scalar = text.unicodeScalars.first, scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
                utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            }
            else if !voiceID.isEmpty {
                utterance.voice = AVSpeechSynthesisVoice(identifier: voiceID)
            }
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        speechSynthesizer.speak(utterance)
    }
}

// MARK: - Edit Form
struct WordEditForm: View {
    @Bindable var word: Word
    var selectedFont: String // Receive Font Name
    @Query private var folders: [Folder]
    @State private var selectedItem: PhotosPickerItem?
    
    let partsOfSpeech = ["Noun", "Verb", "Adjective", "Adverb", "Pronoun", "Particle", "Conjunction", "Interjection", "Other"]
    
    func getCustomFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if selectedFont == "System" { return .system(size: size, weight: weight, design: .serif) }
        else { return .custom(selectedFont, size: size).weight(weight) }
    }

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        // FIXED: Uses custom font & bold
                        TextField("Term", text: $word.term)
                            .font(getCustomFont(size: 48, weight: .bold))
                            .textFieldStyle(.plain)
                        
                        HStack {
                            TextField("IPA", text: $word.pronunciation).font(.system(.title3, design: .monospaced)).textFieldStyle(.plain)
                            Picker("", selection: $word.partOfSpeech) {
                                ForEach(partsOfSpeech, id: \.self) { type in Text(type).tag(type) }
                            }.labelsHidden().frame(width: 120)
                        }
                        Picker("Folder", selection: $word.folder) {
                            Text("None").tag(nil as Folder?)
                            ForEach(folders) { folder in Text(folder.name).tag(folder as Folder?) }
                        }.pickerStyle(.menu).frame(maxWidth: 200)
                        
                        TextField("Location Tags (comma separated)", text: Binding(
                            get: { word.locationTags.joined(separator: ", ") },
                            set: { word.locationTags = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
                        ))
                    }
                    Divider()
                    
                    // Definition + Underline
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Definition", systemImage: "book.closed").font(.headline).foregroundStyle(.secondary)
                            Spacer()
                            HStack(spacing: 2) {
                                Button(action: { word.definition += "**bold**" }) { Image(systemName: "bold") }
                                Button(action: { word.definition += "*italic*" }) { Image(systemName: "italic") }
                                Button(action: { word.definition += "<u>underline</u>" }) { Image(systemName: "underline") }
                                Button(action: { word.definition += "~strike~" }) { Image(systemName: "strikethrough") }
                            }.buttonStyle(.borderless).controlSize(.small)
                        }
                        TextField("Definition (Markdown)", text: $word.definition, axis: .vertical).font(.title3).lineSpacing(4).textFieldStyle(.plain).padding(10).background(Color.gray.opacity(0.1)).cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Example", systemImage: "quote.opening").font(.headline).foregroundStyle(.secondary)
                        TextField("Example Sentence", text: $word.example, axis: .vertical).font(.system(.body, design: .serif)).italic().textFieldStyle(.plain).padding(10).background(Color.gray.opacity(0.1)).cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Variations", systemImage: "map.fill").font(.headline).foregroundStyle(.secondary)
                            Spacer()
                            Button("Add") { word.variations.append(Variation()) }
                        }
                        VStack(spacing: 10) {
                            ForEach($word.variations) { $varItem in
                                HStack(spacing: 8) {
                                    TextField("Name", text: $varItem.name)
                                    Divider()
                                    TextField("IPA", text: $varItem.pronunciation)
                                    Divider()
                                    TextField("Loc", text: $varItem.location)
                                    
                                    Button(role: .destructive) {
                                        if let idx = word.variations.firstIndex(where: { $0.id == varItem.id }) { word.variations.remove(at: idx) }
                                    } label: { Image(systemName: "trash") }.buttonStyle(.plain)
                                }
                                .padding(10).background(Color.gray.opacity(0.1)).cornerRadius(8)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Translations", systemImage: "globe").font(.headline).foregroundStyle(.secondary)
                            Spacer()
                            Button("Add") { word.translations.append(Translation()) }
                        }
                        ForEach($word.translations) { $trans in
                            HStack {
                                TextField("Lang", text: $trans.language).frame(width: 80)
                                Divider()
                                TextField("Text", text: $trans.text)
                                Button(role: .destructive) {
                                    if let idx = word.translations.firstIndex(where: { $0.id == trans.id }) { word.translations.remove(at: idx) }
                                } label: { Image(systemName: "trash") }.buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // FIXED: Restored Notes Section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notes", systemImage: "note.text")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        TextField("Etymology / Usage Notes", text: $word.notes, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                VStack {
                    if let imageData = word.imageData, let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fill).frame(width: 200, height: 200).clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(Button(action: { word.imageData = nil }) { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }.buttonStyle(.plain).padding(4), alignment: .topTrailing)
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.1)).frame(width: 200, height: 200).cornerRadius(8).overlay(Label("Add Image", systemImage: "photo").foregroundStyle(.secondary))
                    }
                    PhotosPicker(selection: $selectedItem, matching: .images) { Text(word.imageData == nil ? "Select Image" : "Change Image") }
                        .onChange(of: selectedItem) { _, newItem in Task { if let data = try? await newItem?.loadTransferable(type: Data.self) { word.imageData = data } } }
                }.frame(width: 220)
            }.padding(40)
        }
    }
}

// MARK: - Add Word Sheet
struct AddWordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var targetFolder: Folder?
    var targetLibrary: Library?
    
    @State private var term = ""; @State private var pronunciation = ""; @State private var definition = ""
    @State private var partOfSpeech = "Noun"; @State private var example = ""; @State private var notes = ""
    @State private var locationTags = ""
    @State private var translations: [Translation] = []
    @State private var variations: [Variation] = []
    @State private var selectedItem: PhotosPickerItem?; @State private var imageData: Data?
    
    let partsOfSpeech = ["Noun", "Verb", "Adjective", "Adverb", "Pronoun", "Particle", "Conjunction", "Interjection", "Other"]

    var body: some View {
        NavigationStack {
            HStack(alignment: .top) {
                Form {
                    Section("Basic Info") {
                        TextField("Term", text: $term)
                        TextField("Pronunciation", text: $pronunciation)
                        Picker("Type", selection: $partOfSpeech) { ForEach(partsOfSpeech, id: \.self) { type in Text(type).tag(type) } }
                        TextField("Location Tags (comma sep)", text: $locationTags)
                    }
                    Section {
                        HStack {
                            Button("B") { definition += "**" }.fontWeight(.bold)
                            Button("I") { definition += "*" }.italic()
                            Button("U") { definition += "<u>" }.underline()
                            Button("S") { definition += "~" }.strikethrough()
                            Spacer()
                        }.buttonStyle(.borderless)
                        TextField("Definition", text: $definition, axis: .vertical).lineLimit(3...6)
                        TextField("Example", text: $example, axis: .vertical).font(.system(.body, design: .serif)).italic()
                    }
                    Section("Variations") {
                        ForEach($variations) { $v in HStack { TextField("Name", text: $v.name); TextField("Loc", text: $v.location) } }
                        Button("Add Variation") { variations.append(Variation()) }
                    }
                    Section("Translations") {
                        ForEach($translations) { $t in HStack { TextField("Lang", text: $t.language).frame(width: 60); TextField("Text", text: $t.text) } }
                        Button("Add Translation") { translations.append(Translation()) }
                    }
                    
                    // FIXED: Restored Notes Section
                    Section("Notes") {
                        TextField("Etymology / Usage Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }.formStyle(.grouped)
                VStack {
                    if let data = imageData, let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fill).frame(width: 150, height: 150).clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1)).frame(width: 150, height: 150).overlay(Image(systemName: "photo"))
                    }
                    PhotosPicker(selection: $selectedItem, matching: .images) { Label("Select Image", systemImage: "photo") }
                        .onChange(of: selectedItem) { _, newItem in Task { if let data = try? await newItem?.loadTransferable(type: Data.self) { imageData = data } } }
                }.padding().background(Color.gray.opacity(0.05))
            }
            .navigationTitle("New Word")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add Word") { saveWord() }.disabled(term.isEmpty) }
            }
        }.frame(width: 750, height: 600)
    }
    
    private func saveWord() {
        let locs = locationTags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        let newWord = Word(term: term, pronunciation: pronunciation, definition: definition, partOfSpeech: partOfSpeech, example: example, notes: notes, translations: translations, variations: variations, tags: targetFolder?.tags ?? [], locationTags: locs, imageData: imageData, folder: targetFolder, library: targetLibrary)
        modelContext.insert(newWord)
        dismiss()
    }
}

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { self.data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { return FileWrapper(regularFileWithContents: data) }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Word.self, configurations: config)
    return ContentView().modelContainer(container)
}
