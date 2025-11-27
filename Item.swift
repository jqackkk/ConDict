//
//  Item.swift
//  ConDict
//
//  Created by Jack Davenport on 11/25/25.
//

import Foundation
import SwiftData

// MARK: - Sub-Models
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
    var name: String      // e.g. "Bavarian Dialect"
    var pronunciation: String // IPA
    var location: String  // e.g. "Munich"
    
    init(name: String = "", pronunciation: String = "", location: String = "") {
        self.name = name
        self.pronunciation = pronunciation
        self.location = location
    }
}

// MARK: - Folder Model
@Model
final class Folder {
    var name: String
    var icon: String
    var tags: [String] = []
    var createdAt: Date
    
    @Relationship(deleteRule: .nullify, inverse: \Word.folder)
    var words: [Word]? = []
    
    init(name: String, icon: String = "folder", tags: [String] = []) {
        self.name = name
        self.icon = icon
        self.tags = tags
        self.createdAt = Date()
    }
}

// MARK: - Word Model
@Model
final class Word {
    var term: String
    var pronunciation: String
    var definition: String
    var partOfSpeech: String
    var example: String
    var notes: String
    
    // Complex Data
    var translations: [Translation] = []
    var variations: [Variation] = []    // NEW: Regional variations
    var tags: [String] = []             // Folder tags
    var locationTags: [String] = []     // NEW: Location sorting tags
    
    @Attribute(.externalStorage)
    var imageData: Data?
    
    var createdAt: Date
    var folder: Folder?
    
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
         imageData: Data? = nil,
         folder: Folder? = nil) {
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
        self.imageData = imageData
        self.folder = folder
        self.createdAt = Date()
    }
}

// Export Helper
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
    let imageData: Data?
    let folderName: String?
}
