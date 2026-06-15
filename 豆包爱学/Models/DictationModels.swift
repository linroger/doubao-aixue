//
//  DictationModels.swift
//  豆包爱学
//
//  听写 — dictation lists and results.
//

import Foundation
import SwiftData

/// A single dictation entry (word/phrase). Value type stored in a list payload.
public nonisolated struct DictationEntry: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var text: String
    public var reading: String          // pinyin or phonetic
    public var meaning: String
    public init(id: String = UUID().uuidString, text: String, reading: String = "", meaning: String = "") {
        self.id = id; self.text = text; self.reading = reading; self.meaning = meaning
    }
}

@Model
public final class DictationList {
    public var id: UUID = UUID()
    public var name: String = ""
    public var languageRaw: String = Subject.chinese.rawValue   // chinese / english
    public var unit: String = ""
    public var entriesData: Data? = nil    // [DictationEntry]
    public var createdAt: Date = Date()

    public init() {}

    public var language: Subject {
        get { Subject(rawValue: languageRaw) ?? .chinese }
        set { languageRaw = newValue.rawValue }
    }
    public var entries: [DictationEntry] {
        get { DBJSON.decode([DictationEntry].self, from: entriesData) ?? [] }
        set { entriesData = DBJSON.encode(newValue) }
    }
}

@Model
public final class DictationResult {
    public var id: UUID = UUID()
    public var listID: UUID = UUID()
    public var listName: String = ""
    public var total: Int = 0
    public var correct: Int = 0
    public var wrongWords: [String] = []
    public var createdAt: Date = Date()

    public init() {}

    public var accuracy: Double { total == 0 ? 0 : Double(correct) / Double(total) }
}
