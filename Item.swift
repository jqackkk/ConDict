//
//  Item.swift
//  ConDict
//
//  Created by Jack Davenport on 11/25/25.
//

import Foundation
import SwiftData

@Model
final class Word {
    var term: String
    var pronunciation: String
    var definition: String
    var partOfSpeech: String
    var example: String
    var notes: String
    var createdAt: Date
    
    init(term: String = "",
         pronunciation: String = "",
         definition: String = "",
         partOfSpeech: String = "Noun",
         example: String = "",
         notes: String = "") {
        self.term = term
        self.pronunciation = pronunciation
        self.definition = definition
        self.partOfSpeech = partOfSpeech
        self.example = example
        self.notes = notes
        self.createdAt = Date()
    }
}

// Helper for JSON Export
struct WordExport: Codable {
    let term: String
    let pronunciation: String
    let definition: String
    let partOfSpeech: String
    let example: String
    let notes: String
}
