//
//  ContentView.swift
//  ConDict
//
//  Created by Jack Davenport on 12/19/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AVFoundation

let speechSynthesizer = AVSpeechSynthesizer()

enum SortOption: String, CaseIterable, Identifiable {
    case nameAsc = "A-Z"
    case nameDesc = "Z-A"
    case newest = "Newest"
    case oldest = "Oldest"
    var id: Self { self }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.undoManager) var undoManager
    
    // FETCH LIBRARIES
    @Query(sort: \Library.name) private var libraries: [Library]
    @State private var selectedLibraryID: PersistentIdentifier?
    @State private var showAllWordsGlobal: Bool = false
    @State private var showStatistics = false // Toggle for Dashboard
    
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
    @State private var sortOption: SortOption = .nameAsc
    
    @State private var isShowingAddSheet = false
    @State private var isShowingFolderSheet = false
    
    // Tools
    @State private var showSCA = false
    @State private var showGrammarManager = false
    
    @State private var newName = ""
    @State private var newFolderTags = ""
    
    @State private var activeInfoPopover: PersistentIdentifier?
    @State private var isShowingExport = false
    @State private var document: JSONDocument?
    
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
        
        let final = selectedFilter == "All" ? searchFiltered : searchFiltered.filter { $0.partOfSpeech == selectedFilter }
        
        return final.sorted {
            if $0.isPinned && !$1.isPinned { return true }
            if !$0.isPinned && $1.isPinned { return false }
            
            switch sortOption {
            case .nameAsc: return $0.term.localizedStandardCompare($1.term) == .orderedAscending
            case .nameDesc: return $0.term.localizedStandardCompare($1.term) == .orderedDescending
            case .newest: return $0.createdAt > $1.createdAt
            case .oldest: return $0.createdAt < $1.createdAt
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedWord) {
                // Extracted Sections to reduce compiler load
                librarySection
                folderSection
                wordSection
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
            .searchable(text: $searchText, placement: .sidebar)
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
            if showStatistics {
                StatisticsDashboard(library: currentLibrary)
            } else if let word = selectedWord {
                WordDetailContainer(word: word, selectedVoiceID: selectedVoiceID, selectedFont: selectedFont) { dest in selectedWord = dest }
            } else {
                ContentUnavailableView("Select a Word", systemImage: "book", description: Text("Select a word or view Statistics."))
            }
        }
        .preferredColorScheme(colorScheme)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(SortOption.allCases) { opt in Text(opt.rawValue).tag(opt) }
                    }
                    Divider()
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(partsOfSpeech, id: \.self) { type in Text(type).tag(type) }
                    }
                } label: { Label("View Options", systemImage: "line.3.horizontal.decrease.circle") }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isShowingAddSheet = true }) { Label("Add Word", systemImage: "plus") }
            }
            ToolbarItem(placement: .automatic) {
                Button(action: prepareExport) { Label("Export JSON", systemImage: "square.and.arrow.up") }
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button(action: { showSCA = true }) { Label("Sound Change Applier", systemImage: "wand.and.stars") }
                    Button(action: { showGrammarManager = true }) { Label("Grammar Tables", systemImage: "tablecells") }
                } label: { Label("Tools", systemImage: "hammer") }
            }
        }
        .sheet(isPresented: $isShowingAddSheet) {
            AddWordView(targetFolder: selectedFolder, targetLibrary: currentLibrary, selectedFont: selectedFont).preferredColorScheme(colorScheme)
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
        .sheet(isPresented: $showSCA) {
            SoundChangeApplierView(onImport: { _ in })
        }
        .sheet(isPresented: $showGrammarManager) {
            GrammarManagerView(library: currentLibrary)
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
    
    // MARK: - Extracted Views to fix Compiler Timeout
    
    @ViewBuilder
    private var librarySection: some View {
        Section("Libraries") {
            // Dashboard Button
            if currentLibrary != nil {
                Button(action: { showStatistics = true }) {
                    HStack {
                        Image(systemName: "chart.bar.xaxis")
                        Text("Statistics")
                        Spacer()
                    }
                    .padding(8)
                    .background(showStatistics ? Color.accentColor : Color.clear)
                    .foregroundStyle(showStatistics ? .white : .primary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .tag(nil as Folder?)
            }
            
            Button(action: {
                showAllWordsGlobal = true; selectedLibraryID = nil; selectedFolder = nil; showStatistics = false
            }) {
                HStack {
                    Image(systemName: "tray.2")
                    Text("All Words")
                    Spacer()
                }
                .padding(8)
                .background(showAllWordsGlobal ? Color.accentColor : Color.gray.opacity(0.1))
                .foregroundStyle(showAllWordsGlobal ? .white : .primary)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .tag(nil as Folder?)
            
            if !libraries.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 10) {
                    ForEach(libraries) { lib in
                        Button(action: {
                            showAllWordsGlobal = false
                            selectedLibraryID = lib.persistentModelID
                            selectedFolder = nil
                            showStatistics = false
                        }) {
                            VStack {
                                Image(systemName: "books.vertical")
                                    .font(.title2)
                                    .foregroundStyle(selectedLibraryID == lib.persistentModelID ? .white : Color.accentColor)
                                Text(lib.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(selectedLibraryID == lib.persistentModelID ? .white : .primary)
                            }
                            .frame(maxWidth: .infinity).padding(10)
                            .background(selectedLibraryID == lib.persistentModelID ? Color.accentColor : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }
    
    @ViewBuilder
    private var folderSection: some View {
        if currentLibrary != nil {
            Section("Folders") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 10) {
                    ForEach(visibleFolders) { folder in
                        Button(action: { selectedFolder = folder; showStatistics = false }) {
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
    }
    
    @ViewBuilder
    private var wordSection: some View {
        Section(selectedFolder?.name ?? (showAllWordsGlobal ? "All Words" : (currentLibrary?.name ?? "Library"))) {
            ForEach(filteredWords) { word in
                NavigationLink(value: word) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(word.term).font(getCustomFont(size: 16, weight: .bold))
                            Text(word.definition).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        VStack(spacing: 4) {
                            Button(action: { activeInfoPopover = word.persistentModelID }) {
                                Image(systemName: "info.circle").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: Binding(get: { activeInfoPopover == word.persistentModelID }, set: { if !$0 { activeInfoPopover = nil } }), arrowEdge: .trailing) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Part of Speech: \(word.partOfSpeech)").font(.caption).bold()
                                    if !word.locationTags.isEmpty { Text("Origin: \(word.locationTags.joined(separator: ", "))").font(.caption) }
                                }.padding()
                            }
                            if word.isPinned {
                                Image(systemName: "pin.fill").font(.caption).foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.vertical, 3)
                }
                .contextMenu {
                    Button(word.isPinned ? "Unpin" : "Pin") { word.isPinned.toggle() }
                    Button("Delete", role: .destructive) { deleteWord(word) }
                    if !libraries.isEmpty {
                        Menu("Move to Library") {
                            ForEach(libraries) { lib in
                                if lib != word.library {
                                    Button(lib.name) { moveWord(word, to: lib) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func deleteWord(_ word: Word) {
        withAnimation {
            if selectedWord == word { selectedWord = nil }
            modelContext.delete(word)
            undoManager?.registerUndo(withTarget: modelContext) { context in }
        }
    }
    
    private func deleteFolder(_ folder: Folder) {
        withAnimation {
            if selectedFolder == folder { selectedFolder = nil }
            modelContext.delete(folder)
        }
    }
    
    private func moveWord(_ word: Word, to library: Library) {
        withAnimation {
            word.library = library
            word.folder = nil
            selectedWord = nil
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
            self.isShowingExport = true
        }
    }
}

// MARK: - Detail Container
struct WordDetailContainer: View {
    @Bindable var word: Word
    var selectedVoiceID: String
    var selectedFont: String
    var onJump: (Word) -> Void
    @State private var isEditing = false
    
    var body: some View {
        Group {
            if isEditing {
                WordEditForm(word: word, selectedFont: selectedFont)
            } else {
                WordDisplayView(word: word, voiceID: selectedVoiceID, selectedFont: selectedFont, onJump: onJump)
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
    let onJump: (Word) -> Void
    @State private var showEtymologyTree = false
    @State private var activePopover: UUID?
    
    var inflectionData: [String: String] {
        if let data = word.inflectionData.data(using: .utf8) {
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        return [:]
    }
    
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
                                        Image(systemName: "speaker.wave.2.circle").foregroundStyle(.tint)
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
                                    .padding(4).background(Color.accentColor).foregroundStyle(.white).cornerRadius(4)
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
                    
                    // Relationships
                    if let related = word.relatedWords, !related.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Related Words", systemImage: "link").font(.headline).foregroundStyle(.secondary)
                            FlowLayout(spacing: 8) {
                                ForEach(related) { relWord in
                                    Button(action: { onJump(relWord) }) {
                                        Text(relWord.term)
                                            .padding(6)
                                            .background(Color.accentColor.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    // --- BETA 1.0 SECTIONS ---
                    if word.parentWord != nil || !(word.derivedWords?.isEmpty ?? true) {
                        VStack(alignment: .leading) {
                            Label("Etymology", systemImage: "tree").font(.headline).foregroundStyle(.secondary)
                            if let parent = word.parentWord {
                                HStack {
                                    Text("From")
                                    Button(parent.term) { onJump(parent) }.buttonStyle(.link)
                                }
                            }
                            if let children = word.derivedWords, !children.isEmpty {
                                Text("Derivations: " + children.map { $0.term }.joined(separator: ", "))
                                    .font(.caption)
                            }
                            Button("View Family Tree") { showEtymologyTree = true }.padding(.top, 5)
                        }
                        .padding().background(Color.gray.opacity(0.1)).cornerRadius(8)
                    }
                    
                    if let schema = word.inflectionSchema {
                        VStack(alignment: .leading) {
                            Label(schema.name, systemImage: "tablecells").font(.headline)
                            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                                GridRow {
                                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                                    ForEach(schema.colHeaders, id: \.self) { col in Text(col).bold() }
                                }
                                ForEach(schema.rowHeaders, id: \.self) { row in
                                    GridRow {
                                        Text(row).bold()
                                        ForEach(schema.colHeaders, id: \.self) { col in
                                            let key = "\(row)_\(col)"
                                            Text(inflectionData[key] ?? "-").padding(5).background(Color.white).cornerRadius(4)
                                        }
                                    }
                                }
                            }
                            .padding().background(Color.gray.opacity(0.1)).cornerRadius(8)
                        }
                    }
                    
                    // Example
                    if !word.example.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Example", systemImage: "quote.opening").font(.headline).foregroundStyle(.secondary)
                            Text(word.example).font(getCustomFont(size: 18)).italic().padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.gray.opacity(0.05)).cornerRadius(8)
                        }
                    }
                    
                    // Variations
                    if !word.variations.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Variations", systemImage: "map").font(.headline).foregroundStyle(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 10) {
                                ForEach(word.variations) { variant in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(variant.name).font(.headline)
                                            Spacer()
                                            
                                            Button(action: { activePopover = variant.id }) {
                                                Image(systemName: "mappin.circle").foregroundStyle(Color.accentColor).font(.title3)
                                            }
                                            .buttonStyle(.plain)
                                            .popover(isPresented: Binding(get: { activePopover == variant.id }, set: { if !$0 { activePopover = nil } }), arrowEdge: .bottom) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Location").font(.caption).foregroundStyle(.secondary)
                                                    Text(variant.location).font(.headline)
                                                    if !variant.gender.isEmpty {
                                                        Divider()
                                                        Text("Gender: \(variant.gender)").font(.caption).foregroundStyle(.secondary)
                                                    }
                                                }.padding().frame(minWidth: 150)
                                            }
                                        }
                                        if !variant.gender.isEmpty {
                                            Text(variant.gender).font(.caption).padding(2).background(Color.orange.opacity(0.2)).cornerRadius(4)
                                        }
                                        HStack {
                                            Text("/\(variant.pronunciation)/").font(.caption).foregroundStyle(.secondary)
                                            Spacer()
                                            Button(action: { speak(variant.pronunciation, isIPA: true) }) { Image(systemName: "speaker.wave.1").font(.caption) }.buttonStyle(.plain)
                                        }
                                    }
                                    .padding(10).background(Color.gray.opacity(0.1)).cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Translations
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
                                        Button(action: { speak(trans.text) }) { Image(systemName: "speaker.wave.1").font(.caption).foregroundStyle(Color.accentColor) }.buttonStyle(.plain)
                                    }
                                    .padding(10).background(Color.gray.opacity(0.1)).cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Notes
                    if !word.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notes", systemImage: "note.text").font(.headline).foregroundStyle(.secondary)
                            Text(word.notes).font(.body)
                        }
                    }
                }
            }
            .padding(40)
        }
        .sheet(isPresented: $showEtymologyTree) {
            EtymologyTreeView(word: word)
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

// Helper for Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        return CGSize(width: proposal.width ?? 300, height: 50)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        let height = 30.0
        for view in subviews {
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: nil, height: height))
            x += view.sizeThatFits(.unspecified).width + spacing
        }
    }
}

// MARK: - Edit Form
struct WordEditForm: View {
    @Bindable var word: Word
    var selectedFont: String
    
    @Query private var folders: [Folder]
    @Query private var allWords: [Word]
    @Query private var allSchemas: [InflectionSchema]
    
    @Environment(\.openWindow) private var openWindow
    @State private var showingRelWordSheet = false
    
    @State private var gridValues: [String: String] = [:]
    
    let partsOfSpeech = ["Noun", "Verb", "Adjective", "Adverb", "Pronoun", "Particle", "Conjunction", "Interjection", "Other"]
    
    func getCustomFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if selectedFont == "System" { return .system(size: size, weight: weight, design: .serif) }
        else { return .custom(selectedFont, size: size).weight(weight) }
    }

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Term", text: $word.term)
                            .font(getCustomFont(size: 48, weight: .bold))
                            .textFieldStyle(.plain)
                            .onChange(of: word.term) { _, val in word.term = val.trimmingCharacters(in: .whitespacesAndNewlines) }
                        
                        HStack {
                            TextField("IPA", text: $word.pronunciation)
                                .font(.system(.title3, design: .monospaced))
                                .textFieldStyle(.plain)
                                .onChange(of: word.pronunciation) { _, val in word.pronunciation = val.trimmingCharacters(in: .whitespacesAndNewlines) }
                            
                            Button(action: { openWindow(id: "ipa-palette") }) {
                                Image(systemName: "waveform.circle").font(.title2)
                            }.buttonStyle(.plain)
                            
                            Picker("", selection: $word.partOfSpeech) {
                                ForEach(partsOfSpeech, id: \.self) { type in Text(type).tag(type) }
                            }.labelsHidden().frame(width: 120)
                        }
                        
                        Picker("Folder", selection: $word.folder) {
                            Text("None").tag(nil as Folder?)
                            ForEach(folders) { folder in Text(folder.name).tag(folder as Folder?) }
                        }.pickerStyle(.menu).frame(maxWidth: 200)
                        
                        TextField("Location Tags", text: Binding(
                            get: { word.locationTags.joined(separator: ", ") },
                            set: { word.locationTags = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
                        ))
                    }
                    Divider()
                    
                    RichTextEditor(text: $word.definition).frame(height: 150).border(Color.gray.opacity(0.2), width: 1)
                    
                    // --- BETA 1.0 EDITS ---
                    VStack(alignment: .leading) {
                        Text("Etymology (Parent Word)").font(.caption).bold()
                        Menu {
                            Button("None") { word.parentWord = nil }
                            ForEach(allWords) { w in if w.id != word.id { Button(w.term) { word.parentWord = w } } }
                        } label: {
                            Text(word.parentWord?.term ?? "Select Parent...").frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Conjugation Table").font(.caption).bold()
                        Picker("Schema", selection: $word.inflectionSchema) {
                            Text("None").tag(nil as InflectionSchema?)
                            ForEach(allSchemas) { schema in Text(schema.name).tag(schema as InflectionSchema?) }
                        }
                        if let schema = word.inflectionSchema {
                            VStack {
                                ForEach(schema.rowHeaders, id: \.self) { row in
                                    HStack {
                                        Text(row).frame(width: 80, alignment: .leading)
                                        ForEach(schema.colHeaders, id: \.self) { col in
                                            let key = "\(row)_\(col)"
                                            TextField(col, text: Binding(get: { gridValues[key] ?? "" }, set: { gridValues[key] = $0; saveGrid() })).textFieldStyle(.roundedBorder)
                                        }
                                    }
                                }
                            }
                            .padding().background(Color.gray.opacity(0.1)).cornerRadius(8)
                        }
                    }
                    // ---------------------
                    
                    // Relationships
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Lexical Relationships", systemImage: "link").font(.headline).foregroundStyle(.secondary)
                            Spacer()
                            Button("Add Link") { showingRelWordSheet = true }
                        }
                        if let related = word.relatedWords, !related.isEmpty {
                            ForEach(related) { relWord in
                                HStack {
                                    Text(relWord.term)
                                    Spacer()
                                    Button(role: .destructive) {
                                        if let idx = word.relatedWords?.firstIndex(where: { $0.id == relWord.id }) { word.relatedWords?.remove(at: idx) }
                                    } label: { Image(systemName: "xmark.circle").foregroundStyle(.secondary) }.buttonStyle(.plain)
                                }.padding(6).background(Color.gray.opacity(0.1)).cornerRadius(6)
                            }
                        }
                    }
                    
                    // Example
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Example", systemImage: "quote.opening").font(.headline).foregroundStyle(.secondary)
                        TextField("Example Sentence", text: $word.example, axis: .vertical).font(.system(.body, design: .serif)).italic().textFieldStyle(.plain).padding(10).background(Color.gray.opacity(0.1)).cornerRadius(8)
                    }
                    
                    // Variations
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Variations", systemImage: "map").font(.headline).foregroundStyle(.secondary)
                            Spacer()
                            Button("Add") { word.variations.append(Variation()) }
                        }
                        VStack(spacing: 10) {
                            ForEach($word.variations) { $varItem in
                                VStack(spacing: 5) {
                                    HStack(spacing: 8) {
                                        TextField("Name", text: $varItem.name); Divider()
                                        TextField("IPA", text: $varItem.pronunciation); Divider()
                                        TextField("Loc", text: $varItem.location)
                                    }
                                    HStack {
                                        Text("Gender:").font(.caption).foregroundStyle(.secondary)
                                        TextField("Masculine, Feminine...", text: $varItem.gender).textFieldStyle(.roundedBorder)
                                        Spacer()
                                        Button(role: .destructive) {
                                            if let idx = word.variations.firstIndex(where: { $0.id == varItem.id }) { word.variations.remove(at: idx) }
                                        } label: { Image(systemName: "trash") }.buttonStyle(.plain)
                                    }
                                }
                                .padding(10).background(Color.gray.opacity(0.1)).cornerRadius(8)
                            }
                        }
                    }
                    
                    // Translations
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Translations", systemImage: "globe").font(.headline).foregroundStyle(.secondary)
                            Spacer()
                            Button("Add") { word.translations.append(Translation()) }
                        }
                        VStack(spacing: 10) {
                            ForEach($word.translations) { $trans in
                                HStack {
                                    TextField("Lang", text: $trans.language).frame(width: 80); Divider()
                                    TextField("Text", text: $trans.text)
                                    Button(role: .destructive) {
                                        if let idx = word.translations.firstIndex(where: { $0.id == trans.id }) { word.translations.remove(at: idx) }
                                    } label: { Image(systemName: "trash") }.buttonStyle(.plain)
                                }.padding(10).background(Color.gray.opacity(0.1)).cornerRadius(8)
                            }
                        }
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notes", systemImage: "note.text").font(.headline).foregroundStyle(.secondary)
                        TextField("Etymology / Usage Notes", text: $word.notes, axis: .vertical).textFieldStyle(.plain).padding(10).background(Color.gray.opacity(0.1)).cornerRadius(8)
                    }
                }
            }.padding(40)
        }
        .onAppear {
            if let data = word.inflectionData.data(using: .utf8) {
                gridValues = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
            }
        }
        .sheet(isPresented: $showingRelWordSheet) {
            VStack {
                Text("Link a Word").font(.headline)
                List(allWords.filter { $0.id != word.id }) { cand in
                    Button(cand.term) {
                        if word.relatedWords == nil { word.relatedWords = [] }
                        if !(word.relatedWords?.contains(cand) ?? false) { word.relatedWords?.append(cand) }
                        showingRelWordSheet = false
                    }.buttonStyle(.plain)
                }
                Button("Cancel") { showingRelWordSheet = false }.padding()
            }.frame(width: 300, height: 400)
        }
    }
    
    func saveGrid() {
        if let data = try? JSONEncoder().encode(gridValues) {
            word.inflectionData = String(data: data, encoding: .utf8) ?? "{}"
        }
    }
}

// MARK: - AADD WORD SHEET
struct AddWordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    var targetFolder: Folder?
    var targetLibrary: Library?
    var selectedFont: String
    
    @State private var term = ""; @State private var pronunciation = ""; @State private var definition = ""
    @State private var partOfSpeech = "Noun"; @State private var example = ""; @State private var notes = ""
    @State private var locationTags = ""
    @State private var translations: [Translation] = []
    @State private var variations: [Variation] = []
    @State private var showDuplicateAlert = false
    
    let partsOfSpeech = ["Noun", "Verb", "Adjective", "Adverb", "Pronoun", "Particle", "Conjunction", "Interjection", "Other"]
    
    func getCustomFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if selectedFont == "System" { return .system(size: size, weight: weight, design: .serif) }
        else { return .custom(selectedFont, size: size).weight(weight) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("New Word").font(.system(size: 32, weight: .bold, design: .serif)).padding(.bottom, 5)
                
                HStack(alignment: .top, spacing: 25) {
                    VStack(alignment: .leading, spacing: 15) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("TERM").font(.caption).bold().foregroundStyle(.secondary)
                            TextField("Enter word", text: $term).font(getCustomFont(size: 24, weight: .bold)).textFieldStyle(.plain).padding(8).background(Color.gray.opacity(0.1)).cornerRadius(6)
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("PRONUNCIATION").font(.caption).bold().foregroundStyle(.secondary)
                                HStack {
                                    TextField("IPA", text: $pronunciation).textFieldStyle(.roundedBorder)
                                    Button(action: { openWindow(id: "ipa-palette") }) { Image(systemName: "waveform.circle") }.buttonStyle(.plain)
                                }
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text("TYPE").font(.caption).bold().foregroundStyle(.secondary)
                                Picker("", selection: $partOfSpeech) { ForEach(partsOfSpeech, id: \.self) { type in Text(type).tag(type) } }.labelsHidden()
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("LOCATION TAGS").font(.caption).bold().foregroundStyle(.secondary)
                            TextField("Locations", text: $locationTags).textFieldStyle(.roundedBorder)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("DEFINITION").font(.caption).bold().foregroundStyle(.secondary)
                            RichTextEditor(text: $definition).frame(height: 100).border(Color.gray.opacity(0.2), width: 1)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("EXAMPLE").font(.caption).bold().foregroundStyle(.secondary)
                            TextField("Example sentence", text: $example).textFieldStyle(.roundedBorder)
                        }
                        
                        // Variations
                        VStack(alignment: .leading, spacing: 5) {
                            Text("VARIATIONS").font(.caption).bold().foregroundStyle(.secondary)
                            ForEach($variations) { $v in
                                VStack(spacing: 5) {
                                    HStack { TextField("Name", text: $v.name); TextField("Loc", text: $v.location) }
                                    HStack { Text("Gender:"); TextField("M/F/N", text: $v.gender) }
                                }.padding(5).background(Color.gray.opacity(0.1)).cornerRadius(5)
                            }
                            Button("Add Variation") { variations.append(Variation()) }
                        }
                        
                        // Translations
                        VStack(alignment: .leading, spacing: 5) {
                            Text("TRANSLATIONS").font(.caption).bold().foregroundStyle(.secondary)
                            ForEach($translations) { $t in HStack { TextField("Lang", text: $t.language).frame(width: 60); TextField("Text", text: $t.text) } }
                            Button("Add Translation") { translations.append(Translation()) }
                        }
                        
                        //  Notes
                        VStack(alignment: .leading, spacing: 5) {
                            Text("NOTES").font(.caption).bold().foregroundStyle(.secondary)
                            TextEditor(text: $notes).frame(height: 60).border(Color.gray.opacity(0.2), width: 1)
                        }
                    }
                }
                
                Spacer()
                HStack {
                    Button("Cancel") { dismiss() }
                    Spacer()
                    Button("Add Word") { validateAndSave() }.buttonStyle(.borderedProminent).disabled(term.isEmpty)
                }
            }
            .padding(30)
        }
        .frame(width: 700, height: 700)
        .alert("Duplicate Word", isPresented: $showDuplicateAlert) {
            Button("Add Anyway") { performSave() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("A word with the term '\(term)' already exists in this library. Do you want to add it anyway?")
        }
    }
    
    private func validateAndSave() {
        let sanitizedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<Word>(predicate: #Predicate { $0.term == sanitizedTerm })
        if let count = try? modelContext.fetchCount(descriptor), count > 0 {
            showDuplicateAlert = true
        } else {
            performSave()
        }
    }
    
    private func performSave() {
        let sanitizedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedPron = pronunciation.trimmingCharacters(in: .whitespacesAndNewlines)
        let locs = locationTags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        
        let newWord = Word(term: sanitizedTerm, pronunciation: sanitizedPron, definition: definition, partOfSpeech: partOfSpeech, example: example, notes: notes, translations: translations, variations: variations, tags: targetFolder?.tags ?? [], locationTags: locs, folder: targetFolder, library: targetLibrary)
        modelContext.insert(newWord)
        dismiss()
    }
}

// MARK: - GRAMMAR MANAGER
struct GrammarManagerView: View {
    var library: Library?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var schemas: [InflectionSchema]
    
    @State private var newName = ""
    @State private var rows: [String] = []
    @State private var cols: [String] = []
    @State private var newCol = ""
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // List of existing
                List {
                    ForEach(schemas) { schema in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(schema.name).font(.headline)
                                Text("\(schema.rowHeaders.count) rows x \(schema.colHeaders.count) cols")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                modelContext.delete(schema)
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onDelete { idx in
                        idx.forEach { modelContext.delete(schemas[$0]) }
                    }
                }
                .frame(width: 250)
                
                Divider()
                
                // Add New
                VStack(alignment: .leading, spacing: 20) {
                    Text("Create New Table Schema").font(.headline)
                    
                    TextField("Name (e.g. Regular Verbs)", text: $newName)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack(alignment: .top, spacing: 20) {
                        // Row Builder
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Rows").font(.caption).bold()
                                Spacer()
                                Menu {
                                    Button("1st Sg (First Person Singular)") { rows.append("1st Sg") }
                                    Button("2nd Sg (Second Person Singular)") { rows.append("2nd Sg") }
                                    Button("3rd Sg (Third Person Singular)") { rows.append("3rd Sg") }
                                    Divider()
                                    Button("1st Pl (First Person Plural)") { rows.append("1st Pl") }
                                    Button("2nd Pl (Second Person Plural)") { rows.append("2nd Pl") }
                                    Button("3rd Pl (Third Person Plural)") { rows.append("3rd Pl") }
                                    Divider()
                                    Button("Add Custom...") { rows.append("New Row") }
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                                .menuStyle(.borderlessButton)
                            }
                            
                            List {
                                ForEach(rows.indices, id: \.self) { i in
                                    TextField("Row", text: $rows[i])
                                }
                                .onDelete { rows.remove(atOffsets: $0) }
                            }
                            .frame(height: 150)
                            .border(Color.gray.opacity(0.2))
                        }
                        
                        // COLS BUILDER
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Columns").font(.caption).bold()
                                Spacer()
                                Button(action: {
                                    if !newCol.isEmpty {
                                        cols.append(newCol)
                                        newCol = ""
                                    }
                                }) {
                                    Image(systemName: "plus.circle")
                                }
                                .buttonStyle(.plain)
                                .disabled(newCol.isEmpty)
                            }
                            
                            HStack {
                                TextField("New Col", text: $newCol)
                                    .onSubmit {
                                        if !newCol.isEmpty { cols.append(newCol); newCol = "" }
                                    }
                            }
                            
                            List {
                                ForEach(cols.indices, id: \.self) { i in
                                    TextField("Col", text: $cols[i])
                                }
                                .onDelete { cols.remove(atOffsets: $0) }
                            }
                            .frame(height: 120)
                            .border(Color.gray.opacity(0.2))
                        }
                    }
                    
                    Button("Create Schema") {
                        let newSchema = InflectionSchema(name: newName, rowHeaders: rows, colHeaders: cols, library: library)
                        modelContext.insert(newSchema)
                        newName = ""
                        rows = []
                        cols = []
                    }
                    .disabled(newName.isEmpty || rows.isEmpty || cols.isEmpty)
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 700, height: 500)
    }
}
