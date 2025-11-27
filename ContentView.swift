//
//  ContentView.swift
//  ConDict
//
//  Created by Jack Davenport on 11/25/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AVFoundation // <--- IMPORT REQUIRED FOR SPEECH

// Global Synthesizer (Must be outside the struct to persist)
let speechSynthesizer = AVSpeechSynthesizer()

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Word.term) private var words: [Word]
    
    // UI State
    @State private var selectedWord: Word?
    @State private var searchText = ""
    @State private var selectedFilter: String = "All"
    
    // Sheet State
    @State private var isShowingAddSheet = false
    
    // Export State
    @State private var isShowingExport = false
    @State private var document: JSONDocument?
    
    var partsOfSpeech = ["All", "Noun", "Verb", "Adjective", "Adverb", "Pronoun", "Particle", "Conjunction", "Interjection", "Other"]

    var filteredWords: [Word] {
        words.filter { word in
            let matchesSearch = searchText.isEmpty ||
                word.term.localizedCaseInsensitiveContains(searchText) ||
                word.definition.localizedCaseInsensitiveContains(searchText)
            
            let matchesFilter = selectedFilter == "All" || word.partOfSpeech == selectedFilter
            
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        NavigationSplitView {
            // --- SIDEBAR ---
            List(selection: $selectedWord) {
                // Invisible Top Spacer
                Color.clear
                    .frame(height: 10)
                    .listRowInsets(EdgeInsets())
                    .selectionDisabled()
                    .accessibilityHidden(true)
                
                ForEach(filteredWords) { word in
                    NavigationLink(value: word) {
                        VStack(alignment: .leading) {
                            Text(word.term)
                                .font(.headline)
                            Text(word.definition)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 3)
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            deleteWord(word)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
            .searchable(text: $searchText, placement: .sidebar)
            
        } detail: {
            // --- DETAIL VIEW ---
            if let word = selectedWord {
                WordDetailContainer(word: word)
            } else {
                ContentUnavailableView("Select a Word", systemImage: "book", description: Text("Select a word from the sidebar or add a new one."))
            }
        }
        // --- TOOLBAR ---
        .toolbar {
            // 1. FILTER BUTTON
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(partsOfSpeech, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }

            // 2. ADD BUTTON
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isShowingAddSheet = true }) {
                    Label("Add Word", systemImage: "plus")
                }
            }
            
            // 3. EXPORT BUTTON
            ToolbarItem(placement: .automatic) {
                Button(action: prepareExport) {
                    Label("Export JSON", systemImage: "square.and.arrow.up")
                }
            }
        }
        // --- POP-OVER FOR NEW WORDS ---
        .sheet(isPresented: $isShowingAddSheet) {
            AddWordView()
        }
        // --- EXPORT LOGIC ---
        .fileExporter(
            isPresented: $isShowingExport,
            document: document,
            contentType: .json,
            defaultFilename: "MyConDict_Backup"
        ) { result in
            if case .success(let url) = result {
                print("Saved to \(url)")
            } else {
                print("Export failed")
            }
        }
    }

    private func deleteWord(_ word: Word) {
        withAnimation {
            if selectedWord == word {
                selectedWord = nil
            }
            modelContext.delete(word)
        }
    }
    
    private func prepareExport() {
        let exportData = words.map {
            WordExport(
                term: $0.term,
                pronunciation: $0.pronunciation,
                definition: $0.definition,
                partOfSpeech: $0.partOfSpeech,
                example: $0.example,
                notes: $0.notes
            )
        }
        if let data = try? JSONEncoder().encode(exportData) {
            self.document = JSONDocument(data: data)
            self.isShowingExport = true
        }
    }
}

// MARK: - 1. Detail Container (Handles Read vs Edit Mode)
struct WordDetailContainer: View {
    @Bindable var word: Word
    @State private var isEditing = false
    
    var body: some View {
        Group {
            if isEditing {
                WordEditForm(word: word)
            } else {
                WordDisplayView(word: word)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(isEditing ? "Done" : "Edit") {
                    withAnimation {
                        isEditing.toggle()
                    }
                }
            }
        }
    }
}

// MARK: - 2. The "Clean" Read-Only Interface
struct WordDisplayView: View {
    let word: Word
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // HEADER: Term, IPA, and Type
                VStack(alignment: .leading, spacing: 8) {
                    Text(word.term)
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                    
                    HStack(spacing: 12) {
                        if !word.pronunciation.isEmpty {
                            // 👇 IPA SECTION WITH SPEAKER BUTTON
                            HStack(spacing: 6) {
                                Text("/\(word.pronunciation)/")
                                    .font(.system(.title3, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                
                                Button(action: { speakIPA(word.pronunciation) }) {
                                    Image(systemName: "speaker.wave.2.circle.fill")
                                        .foregroundStyle(.tint)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .help("Pronounce IPA")
                            }
                        }
                        
                        Text(word.partOfSpeech)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 10)
                
                Divider()
                
                // DEFINITION
                VStack(alignment: .leading, spacing: 8) {
                    Label("Definition", systemImage: "book.closed")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(word.definition)
                        .font(.title3)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
                
                // EXAMPLE
                if !word.example.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Example", systemImage: "quote.opening")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text(word.example)
                            .font(.system(.body, design: .serif))
                            .italic()
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                            .textSelection(.enabled)
                    }
                }
                
                // NOTES
                if !word.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notes", systemImage: "note.text")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(word.notes)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
                
                Spacer()
            }
            .padding(40)
        }
    }
    
    // 👇 TTS FUNCTION
    func speakIPA(_ ipa: String) {
        let utterance = AVSpeechUtterance(string: ipa)
        // en-US usually handles IPA characters decently, though support varies by system version
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechSynthesizer.speak(utterance)
    }
}

// MARK: - 3. The "Edit" Form
struct WordEditForm: View {
    @Bindable var word: Word
    let partsOfSpeech = ["Noun", "Verb", "Adjective", "Adverb", "Pronoun", "Particle", "Conjunction", "Interjection", "Other"]

    var body: some View {
        Form {
            Section(header: Text("Basic Info")) {
                TextField("Term", text: $word.term)
                    .font(.title2)
                    .bold()
                
                TextField("Pronunciation (IPA)", text: $word.pronunciation)
                    .font(.system(.body, design: .monospaced))
                
                Picker("Part of Speech", selection: $word.partOfSpeech) {
                    ForEach(partsOfSpeech, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
            }
            Section(header: Text("Meaning")) {
                TextField("Definition", text: $word.definition, axis: .vertical)
                    .lineLimit(2...4)
                
                TextField("Example Sentence", text: $word.example, axis: .vertical)
                    .font(.system(.body, design: .serif))
                    .italic()
                    .lineLimit(2...4)
            }
            Section(header: Text("Notes")) {
                TextField("Etymology / Usage Notes", text: $word.notes, axis: .vertical)
                    .lineLimit(4...8)
            }
        }
        .padding()
    }
}

// MARK: - 4. The Pop-over "Add" Sheet
struct AddWordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Local state for the new word
    @State private var term = ""
    @State private var pronunciation = ""
    @State private var definition = ""
    @State private var partOfSpeech = "Noun"
    @State private var example = ""
    @State private var notes = ""
    
    let partsOfSpeech = ["Noun", "Verb", "Adjective", "Adverb", "Pronoun", "Particle", "Conjunction", "Interjection", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Term", text: $term)
                    TextField("Pronunciation", text: $pronunciation)
                    Picker("Part of Speech", selection: $partOfSpeech) {
                        ForEach(partsOfSpeech, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }
                Section {
                    TextField("Definition", text: $definition, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("Example", text: $example, axis: .vertical)
                        .font(.system(.body, design: .serif))
                        .italic()
                }
                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Word")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Word") {
                        saveWord()
                    }
                    .disabled(term.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private func saveWord() {
        let newWord = Word(
            term: term,
            pronunciation: pronunciation,
            definition: definition,
            partOfSpeech: partOfSpeech,
            example: example,
            notes: notes
        )
        modelContext.insert(newWord)
        dismiss()
    }
}

// MARK: - Helper: JSON Document Handling
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
    let sample1 = Word(term: "Qapla'", pronunciation: "qχɑplɑʔ", definition: "Success", partOfSpeech: "Noun")
    container.mainContext.insert(sample1)
    return ContentView().modelContainer(container)
}
