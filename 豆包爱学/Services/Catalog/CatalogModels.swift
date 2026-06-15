//
//  CatalogModels.swift
//  豆包爱学
//
//  Lightweight Sendable value types for bundled sample content (seeded into
//  SwiftData on first run and used by browse surfaces).
//

import Foundation

public nonisolated struct CatalogCourse: Sendable, Hashable, Identifiable {
    public var id = UUID()
    public var title: String
    public var author: String
    public var dynasty: String
    public var subject: Subject
    public var grade: GradeLevel
    public var summary: String
    public var durationSec: Int
    public var isUGC: Bool
    public init(title: String, author: String, dynasty: String, subject: Subject,
                grade: GradeLevel, summary: String, durationSec: Int, isUGC: Bool = false) {
        self.title = title; self.author = author; self.dynasty = dynasty; self.subject = subject
        self.grade = grade; self.summary = summary; self.durationSec = durationSec; self.isUGC = isUGC
    }
}

public nonisolated struct CatalogPoem: Sendable, Hashable, Identifiable {
    public var id = UUID()
    public var title: String
    public var dynasty: String
    public var author: String
    public var original: String
    public var translation: String
    public var appreciation: String
    public var grade: GradeLevel
    public init(title: String, dynasty: String, author: String, original: String,
                translation: String, appreciation: String, grade: GradeLevel) {
        self.title = title; self.dynasty = dynasty; self.author = author; self.original = original
        self.translation = translation; self.appreciation = appreciation; self.grade = grade
    }
}

public nonisolated struct CatalogWord: Sendable, Hashable, Identifiable {
    public var id = UUID()
    public var headword: String
    public var phonetic: String
    public var definition: String
    public var examples: [String]
    public init(headword: String, phonetic: String, definition: String, examples: [String]) {
        self.headword = headword; self.phonetic = phonetic; self.definition = definition; self.examples = examples
    }
}

public nonisolated struct CatalogKnowledgePoint: Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var subject: Subject
    public var grade: GradeLevel
    public var summary: String
    public var chapter: String
    public var parentIDs: [String]
    public init(id: String, name: String, subject: Subject, grade: GradeLevel,
                summary: String, chapter: String, parentIDs: [String] = []) {
        self.id = id; self.name = name; self.subject = subject; self.grade = grade
        self.summary = summary; self.chapter = chapter; self.parentIDs = parentIDs
    }
}

public nonisolated struct CatalogProblem: Sendable, Hashable, Identifiable {
    public var id = UUID()
    public var subject: Subject
    public var text: String
    public var answer: String
    public init(subject: Subject, text: String, answer: String) {
        self.subject = subject; self.text = text; self.answer = answer
    }
}
