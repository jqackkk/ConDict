//
//  Utilities.swift
//  ConDict
//
//  Created by Jack Davenport on 11/30/25.
//

import SwiftUI
import AppKit
import SwiftData
import Charts

// MARK: - STATISTICS DASHBOARD
struct StatisticsDashboard: View {
    var library: Library?
    @Query private var words: [Word]
    
    var libraryWords: [Word] {
        if let lib = library {
            return words.filter { $0.library == lib }
        }
        return words
    }
    
    // ERROR FIX: Explicit types for closure parameters
    var posData: [(type: String, count: Int)] {
        let grouped = Dictionary(grouping: libraryWords, by: { $0.partOfSpeech })
        return grouped.map { (key: String, value: [Word]) -> (String, Int) in
            (key, value.count)
        }.sorted { (lhs, rhs) -> Bool in
            lhs.1 > rhs.1
        }
    }
    
    var originData: [(loc: String, count: Int)] {
        var counts: [String: Int] = [:]
        for word in libraryWords {
            for tag in word.locationTags {
                counts[tag, default: 0] += 1
            }
        }
        return counts.map { (key: String, value: Int) -> (String, Int) in
            (key, value)
        }.sorted { (lhs, rhs) -> Bool in
            lhs.1 > rhs.1
        }.prefix(8).map { $0 }
    }
    
    var charFreqData: [(char: String, count: Int)] {
        var counts: [Character: Int] = [:]
        for word in libraryWords {
            for char in word.term.lowercased() {
                if !char.isWhitespace && !char.isPunctuation {
                    counts[char, default: 0] += 1
                }
            }
        }
        return counts.map { (key: Character, value: Int) -> (String, Int) in
            (String(key), value)
        }.sorted { (lhs, rhs) -> Bool in
            lhs.1 > rhs.1
        }.prefix(15).map { $0 }
    }
    
    var averageLength: Double {
        guard !libraryWords.isEmpty else { return 0 }
        let total = libraryWords.reduce(0) { $0 + $1.term.count }
        return Double(total) / Double(libraryWords.count)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Language Statistics").font(.system(size: 32, weight: .bold, design: .serif))
                
                // Overview Cards
                HStack(spacing: 20) {
                    StatCard(title: "Total Words", value: "\(libraryWords.count)", icon: "book", color: .blue)
                    StatCard(title: "Word Types", value: "\(posData.count)", icon: "tag", color: .orange)
                    StatCard(title: "Avg Length", value: String(format: "%.1f", averageLength), icon: "ruler", color: .green)
                }
                
                Divider()
                
                // Charts
                HStack(alignment: .top, spacing: 30) {
                    VStack(alignment: .leading) {
                        Text("Part of Speech Distribution").font(.headline)
                        Chart(posData, id: \.type) { item in
                            SectorMark(
                                angle: .value("Count", item.count),
                                innerRadius: .ratio(0.5),
                                angularInset: 1.5
                            )
                            .cornerRadius(5)
                            .foregroundStyle(by: .value("Type", item.type))
                        }
                        .frame(height: 250)
                    }
                    .padding().background(Color.gray.opacity(0.05)).cornerRadius(12)
                    
                    VStack(alignment: .leading) {
                        Text("Top Origins").font(.headline)
                        if originData.isEmpty {
                            ContentUnavailableView("No location tags", systemImage: "mappin.slash")
                        } else {
                            Chart(originData, id: \.loc) { item in
                                BarMark(
                                    x: .value("Count", item.count),
                                    y: .value("Location", item.loc)
                                )
                                .foregroundStyle(Color.accentColor)
                            }
                            .frame(height: 250)
                        }
                    }
                    .padding().background(Color.gray.opacity(0.05)).cornerRadius(12)
                }
                
                Divider()
                
                // Letter Freq
                VStack(alignment: .leading) {
                    Text("Phoneme/Character Frequency").font(.headline)
                    Text("Most common characters used in your dictionary.").font(.caption).foregroundStyle(.secondary)
                    
                    Chart(charFreqData, id: \.char) { item in
                        BarMark(
                            x: .value("Character", item.char),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(Color.purple.gradient)
                    }
                    .frame(height: 200)
                }
                .padding().background(Color.gray.opacity(0.05)).cornerRadius(12)
            }
            .padding(40)
        }
    }
}

struct StatCard: View {
    let title: String, value: String, icon: String, color: Color
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.system(size: 28, weight: .bold))
            }
            Spacer()
            Image(systemName: icon).font(.largeTitle).foregroundStyle(color.opacity(0.8))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Sound Change Applier
// FIXED: Removed invalid redeclaration of SCARule struct (It is now in Item.swift)

struct SoundChangeApplierView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Word.term) private var allWords: [Word]
    @Query(sort: \SCAPreset.name) private var presets: [SCAPreset]
    
    @State private var inputWord: String = ""
    @State private var rules: [SCARule] = [SCARule(find: "", replace: "")]
    @State private var outputWord: String = ""
    
    @State private var selectedWordToEvolve: Word?
    @State private var showApplyConfirmation = false
    @State private var showSavePreset = false
    @State private var newPresetName = ""
    
    var onImport: ((String) -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Cancel
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Sound Change Applier").font(.headline)
                Spacer()
                // Invisible button to balance layout
                Button("Cancel") { }.opacity(0).disabled(true)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            HStack(spacing: 0) {
                // Left: Controls
                VStack(alignment: .leading, spacing: 15) {
                    
                    // Presets & Selection
                    HStack {
                        Menu("Load Preset") {
                            ForEach(presets) { preset in
                                Button(preset.name) {
                                    // Item.swift's SCARule is Codable, so it works directly
                                    self.rules = preset.rules
                                }
                            }
                            if presets.isEmpty { Text("No saved presets") }
                        }
                        
                        Spacer()
                        
                        Button("Save Preset") { showSavePreset = true }
                            .disabled(rules.isEmpty || rules.first?.find == "")
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Source").font(.caption).bold().foregroundStyle(.secondary)
                        HStack {
                            Menu {
                                Button("Clear Selection") {
                                    selectedWordToEvolve = nil
                                    inputWord = ""
                                }
                                Divider()
                                if allWords.isEmpty {
                                    Text("No words in dictionary")
                                } else {
                                    ForEach(allWords) { word in
                                        Button(word.term) {
                                            selectedWordToEvolve = word
                                            inputWord = word.term
                                        }
                                    }
                                }
                            } label: {
                                Text(selectedWordToEvolve?.term ?? "Select Existing Word...")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .menuStyle(.borderedButton)
                            .frame(maxWidth: 180)
                            
                            TextField("Proto-Word", text: $inputWord)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    Divider()
                    
                    Text("Rules (Regex)").font(.caption).bold().foregroundStyle(.secondary)
                    
                    List {
                        ForEach($rules) { $rule in
                            HStack {
                                TextField("Find", text: $rule.find)
                                    .font(.system(.caption, design: .monospaced))
                                Image(systemName: "arrow.right").font(.caption)
                                TextField("Replace", text: $rule.replace)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                        .onDelete { idx in rules.remove(atOffsets: idx) }
                    }
                    .frame(minHeight: 200)
                    
                    HStack {
                        Button("Add Rule") { rules.append(SCARule(find: "", replace: "")) }
                        Spacer()
                        Button("Clear Rules") { rules = [SCARule(find: "", replace: "")] }
                    }
                    
                    Button(action: applyRules) {
                        HStack {
                            Text("Preview Evolution")
                            Image(systemName: "eye")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .frame(width: 350)
                
                Divider()
                
                // Right: Output
                VStack(spacing: 30) {
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Text("Result")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text(outputWord.isEmpty ? "..." : outputWord)
                            .font(.system(size: 40, weight: .bold, design: .serif))
                            .textSelection(.enabled)
                            .multilineTextAlignment(.center)
                    }
                    
                    if !outputWord.isEmpty {
                        Button(action: { showApplyConfirmation = true }) {
                            HStack {
                                Text("Use This Evolution")
                                Image(systemName: "checkmark.circle")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog("Apply Changes", isPresented: $showApplyConfirmation) {
                            Button("Update '\(inputWord)' Only") {
                                applyToSingle()
                            }
                            
                            Button("Update ALL Words (\(allWords.count))", role: .destructive) {
                                applyToAll()
                            }
                            
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Do you want to update just the selected word, or apply these sound changes to every word in your dictionary?")
                        }
                    }
                    
                    Spacer()
                }
                .padding(40)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.05))
            }
        }
        .frame(width: 750, height: 550)
        .alert("Save Preset", isPresented: $showSavePreset) {
            TextField("Preset Name", text: $newPresetName)
            Button("Save") {
                let preset = SCAPreset(name: newPresetName, rules: rules)
                modelContext.insert(preset)
                newPresetName = ""
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    func applyRules() {
        outputWord = process(word: inputWord)
    }
    
    func process(word: String) -> String {
        var current = word
        for rule in rules {
            if !rule.find.isEmpty {
                do {
                    let regex = try NSRegularExpression(pattern: rule.find)
                    let range = NSRange(current.startIndex..<current.endIndex, in: current)
                    current = regex.stringByReplacingMatches(in: current, options: [], range: range, withTemplate: rule.replace)
                } catch {
                    print("Regex error: \(error)")
                }
            }
        }
        return current
    }
    
    func applyToSingle() {
        if let word = selectedWordToEvolve {
            word.term = outputWord
        } else {
            onImport?(outputWord)
        }
        dismiss()
    }
    
    func applyToAll() {
        for word in allWords {
            let newTerm = process(word: word.term)
            word.term = newTerm
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Etymology Tree View
struct EtymologyTreeView: View {
    let word: Word
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 20) {
                if let parent = word.parentWord {
                    Text("Derived from:")
                        .font(.caption).foregroundStyle(.secondary)
                    NodeView(word: parent, isCurrent: false)
                    Image(systemName: "arrow.down")
                }
                
                NodeView(word: word, isCurrent: true)
                
                if let children = word.derivedWords, !children.isEmpty {
                    Image(systemName: "arrow.down")
                    HStack(alignment: .top, spacing: 30) {
                        ForEach(children) { child in
                            NodeView(word: child, isCurrent: false)
                        }
                    }
                }
            }
            .padding(40)
        }
        .background(Color.gray.opacity(0.05))
    }
}

struct NodeView: View {
    let word: Word
    let isCurrent: Bool
    
    var body: some View {
        VStack {
            Text(word.term)
                .font(.headline)
                .foregroundStyle(isCurrent ? .white : .primary)
            Text(word.definition)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(isCurrent ? .white.opacity(0.8) : .secondary)
        }
        .padding(10)
        .background(isCurrent ? Color.accentColor : Color.white)
        .cornerRadius(8)
        .shadow(radius: 2)
        .frame(maxWidth: 150)
    }
}

// MARK: - IPA Palette Window
struct IPAPaletteView: View {
    let pulmonicconsonants = ["p", "b", "t", "d", "ʈ", "ɖ", "c", "ɟ", "k", "g", "q", "ɢ", "ʔ", "m", "ɱ", "n", "ɳ", "ɲ", "ŋ", "ɴ", "ʙ", "r", "ʀ", "ⱱ", "ɾ", "ɽ", "ɸ", "β", "f", "v", "θ", "ð", "s", "z", "ʃ", "ʒ", "ʂ", "ʐ", "ç", "ʝ", "x", "ɣ", "χ", "ʁ", "ħ", "ʕ", "h", "ɦ", "ɬ", "ɮ", "ʋ", "ɹ", "ɻ", "j", "ɰ", "l", "ɭ", "ʎ", "ʟ"]
    let vowels = ["i", "y", "u", "e", "o", "ə", "ɛ", "ɔ", "æ", "a", "ɑ", "ɨ", "ʉ", "ɪ", "ʏ", "ʊ", "ɵ", "ø", "ɘ", "ɤ", "ɐ", "œ", "ɜ", "ɞ", "ʌ", "ɶ", "ɒ", "ɯ"]
    let nonpulmonicconsonants = ["ʘ", "ǀ", "ǃ", "ǂ", "ǁ", "ɓ", "ɗ", "ʄ", "ɠ", "ʛ", "pʼ", "tʼ", "sʼ", "kʼ"]
    let affricates = ["t͡s", "t͡ʃ", "t͡ɕ", "ʈ͡ʂ", "d͡z", "d͡ʒ", "d͡ʑ", "ɖ͡ʐ"]
    let othersymbols = ["ʍ", "w", "ɥ", "ʜ", "ʢ", "ʡ", "ɕ", "ʑ", "ɺ", "ɧ"]
    let diacritics = ["ʼ", "ʰ", "ⁿ", "ᶿ", "ᵊ", "ʷ", "ˠ", "ˤ", "ː", "‿", "↗︎", "↘︎", "ꜛ", "ꜜ", ".", "ˌ", "ˈ", " ̀", " ́", " ̂", " ̃", " ̄", " ̅", " ̑", " ̆", " ̇", " ̈", " ̉", " ̊", " ̏", " ̋", " ̌", " ̎", " ̌", " ̐", " ̖", " ̗", " ̭", " ̰", " ̱", " ̲", " ̯", " ̮", " ̣", " ̤", " ̨", " ̥", " ̬", " ̩", " ̒", " ̓", " ̔", " ̕", " ̧", " ̦", " ͝", " ͡", " ͞", " ͜", " ͟"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("IPA Palette").font(.headline).padding(.bottom, 5)
                
                Group {
                    Text("Pulmonic Consonants").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 35))], spacing: 8) {
                        ForEach(pulmonicconsonants, id: \.self) { char in
                            PaletteButton(char: char)
                        }
                    }
                    Divider()
                    Text("Vowels").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 35))], spacing: 8) {
                        ForEach(vowels, id: \.self) { char in
                            PaletteButton(char: char)
                        }
                    }
                    Divider()
                    Text("Diacritics").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 35))], spacing: 8) {
                        ForEach(diacritics, id: \.self) { char in
                            PaletteButton(char: char)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 300, minHeight: 400)
        .background(.regularMaterial)
    }
}

struct PaletteButton: View {
    let char: String
    @State private var justCopied = false
    
    var body: some View {
        Button(action: {
            copyToClipboard(char)
        }) {
            Text(char)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .frame(width: 35, height: 35)
                .background(justCopied ? Color.green.opacity(0.8) : Color.gray.opacity(0.1))
                .cornerRadius(6)
                .foregroundStyle(justCopied ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
    
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Provide visual feedback
        withAnimation(.easeIn(duration: 0.1)) { justCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation { justCopied = false }
        }
    }
}

// MARK: - True Rich Text Editor
struct RichTextEditor: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesInspectorBar = true // Adds the rich text toolbar!
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        
        // Initial setup
        textView.string = text
        textView.font = .systemFont(ofSize: 14)
        
        // Auto-resize
        textView.minSize = NSSize(width: 0, height: 100)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
    
    // FIXED: This cleans up the formatting bar when editing stops
    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        if let textView = nsView.documentView as? NSTextView {
            textView.usesInspectorBar = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }
    }
}
