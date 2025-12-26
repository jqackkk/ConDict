//
//  Item.swift
//  ConDict
//
//  Created by Jack Davenport on 11/25/25.
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - SUB-MODELS

struct Translation: Codable, Identifiable, Hashable {
    var id = UUID()
    var language: String
    var text: String
    
    init(language: String = "English", text: String = "") {
        self.language = language
        self.text = text
    }
}

struct Variation: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var pronunciation: String
    var location: String
    var gender: String = "" // Added for Beta 1.1
    
    init(name: String = "", pronunciation: String = "", location: String = "", gender: String = "") {
        self.name = name
        self.pronunciation = pronunciation
        self.location = location
        self.gender = gender
    }
}

// Moved from Utilities to allow persistence
struct SCARule: Identifiable, Codable {
    var id = UUID()
    var find: String
    var replace: String
}

// MARK: - DATABASE MODELS

@Model
final class SCAPreset {
    var name: String
    var rulesData: Data // Stores [SCARule] as JSON
    var createdAt: Date
    
    init(name: String, rules: [SCARule]) {
        self.name = name
        self.createdAt = Date()
        self.rulesData = (try? JSONEncoder().encode(rules)) ?? Data()
    }
    
    var rules: [SCARule] {
        if let decoded = try? JSONDecoder().decode([SCARule].self, from: rulesData) {
            return decoded
        }
        return []
    }
}

@Model
final class InflectionSchema {
    var name: String
    var rowHeaders: [String]
    var colHeaders: [String]
    
    var library: Library?
    
    @Relationship(deleteRule: .nullify, inverse: \Word.inflectionSchema)
    var words: [Word]? = []
    
    init(name: String, rowHeaders: [String], colHeaders: [String], library: Library? = nil) {
        self.name = name
        self.rowHeaders = rowHeaders
        self.colHeaders = colHeaders
        self.library = library
    }
}

@Model
final class Library {
    var name: String
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Word.library)
    var words: [Word]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \Folder.library)
    var folders: [Folder]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \InflectionSchema.library)
    var inflectionSchemas: [InflectionSchema]? = []
    
    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
}

@Model
final class Folder {
    var name: String
    var icon: String
    var tags: [String] = []
    var createdAt: Date
    
    var library: Library?
    
    @Relationship(deleteRule: .nullify, inverse: \Word.folder)
    var words: [Word]? = []
    
    init(name: String, icon: String = "folder", tags: [String] = [], library: Library? = nil) {
        self.name = name
        self.icon = icon
        self.tags = tags
        self.library = library
        self.createdAt = Date()
    }
}

@Model
final class Word {
    var term: String
    var pronunciation: String
    var definition: String
    var partOfSpeech: String
    var example: String
    var notes: String
    
    var translations: [Translation] = []
    var variations: [Variation] = []
    var tags: [String] = []
    var locationTags: [String] = []
    
    // Self-referential relationship for lexical links
    @Relationship(deleteRule: .nullify)
    var relatedWords: [Word]? = []
    
    var isPinned: Bool = false
    
    // -- ETYMOLOGY --
    @Relationship(deleteRule: .nullify, inverse: \Word.derivedWords)
    var parentWord: Word?
    
    var derivedWords: [Word]? = []
    
    // -- GRAMMAR --
    var inflectionSchema: InflectionSchema?
    var inflectionData: String = "{}" // JSON string: "row_col" : "value"
    
    var createdAt: Date
    var folder: Folder?
    var library: Library?
    
    init(term: String = "",
         pronunciation: String = "",
         definition: String = "",
         partOfSpeech: String = "Noun",
         example: String = "",
         notes: String = "",
         translations: [Translation] = [],
         variations: [Variation] = [],
         tags: [String] = [],
         locationTags: [String] = [],
         isPinned: Bool = false,
         folder: Folder? = nil,
         library: Library? = nil,
         parentWord: Word? = nil) {
        self.term = term
        self.pronunciation = pronunciation
        self.definition = definition
        self.partOfSpeech = partOfSpeech
        self.example = example
        self.notes = notes
        self.translations = translations
        self.variations = variations
        self.tags = tags
        self.locationTags = locationTags
        self.isPinned = isPinned
        self.folder = folder
        self.library = library
        self.parentWord = parentWord
        self.createdAt = Date()
    }
}

// MARK: - SHARED DATA TYPES

// Data Transfer Object for Export/Import
struct WordExport: Codable {
    let term: String
    let pronunciation: String
    let definition: String
    let partOfSpeech: String
    let example: String
    let notes: String
    let translations: [Translation]
    let variations: [Variation]
    let tags: [String]
    let locationTags: [String]
    let isPinned: Bool
    let folderName: String?
    let libraryName: String?
    let parentWordTerm: String?
    let inflectionData: String?
}

// Shared Document Type for Exporting
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { self.data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { return FileWrapper(regularFileWithContents: data) }
}
