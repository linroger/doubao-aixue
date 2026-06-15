//
//  VocabularyModels.swift
//  豆包爱学
//
//  背单词 — SwiftData-backed spaced-repetition decks and cards.
//

import Foundation
import SwiftData

@Model
public final class WordDeck {
    public var id: UUID = UUID()
    public var name: String = ""
    public var subjectRaw: String = Subject.english.rawValue
    public var editionRaw: String = TextbookEdition.waiyan.rawValue
    public var gradeRaw: Int = GradeLevel.g7.rawValue
    public var unit: String = ""
    public var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \WordCard.deck)
    public var cards: [WordCard]? = []

    public init() {}

    public var subject: Subject {
        get { Subject(rawValue: subjectRaw) ?? .english }
        set { subjectRaw = newValue.rawValue }
    }
    public var grade: GradeLevel {
        get { GradeLevel(rawValue: gradeRaw) ?? .g7 }
        set { gradeRaw = newValue.rawValue }
    }
    public var dueCount: Int {
        let now = Date()
        return (cards ?? []).filter { $0.dueDate <= now }.count
    }
}

@Model
public final class WordCard {
    public var id: UUID = UUID()
    public var headword: String = ""
    public var phonetic: String = ""
    public var definition: String = ""
    public var examples: [String] = []
    // SM-2 spaced repetition state.
    public var easeFactor: Double = 2.5
    public var intervalDays: Double = 0
    public var repetitions: Int = 0
    public var dueDate: Date = Date()
    public var masteryRaw: String = MasteryState.new.rawValue
    public var deck: WordDeck? = nil

    public init() {}

    public var mastery: MasteryState {
        get { MasteryState(rawValue: masteryRaw) ?? .new }
        set { masteryRaw = newValue.rawValue }
    }
}
