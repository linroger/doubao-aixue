//
//  VocabularySupport.swift
//  豆包爱学 — Features/Practice/Vocabulary
//
//  背单词 (RESEARCH F35). Presentation-only helpers shared by the deck list and the
//  flashcard review surface: how a mastery state maps to a tint/symbol, the
//  forgetting-curve "下次复习" framing copy, and the pure quiz-question generator
//  used by the spelling/choice quiz mode. Kept tiny and side-effect-free so the
//  views stay focused and these helpers are trivially testable.
//

import SwiftUI

// MARK: - Mastery presentation

/// Pure mapping helpers (no state) shared across the 背单词 surfaces.
enum VocabPresentation {

    static func masteryTint(_ mastery: MasteryState) -> Color {
        switch mastery {
        case .new: .dbTextTertiary
        case .weak: .dbError
        case .developing: .dbWarning
        case .mastered: .dbSuccess
        }
    }

    static func masterySymbol(_ mastery: MasteryState) -> String {
        switch mastery {
        case .new: "circle.dashed"
        case .weak: "exclamationmark.triangle.fill"
        case .developing: "arrow.up.right.circle.fill"
        case .mastered: "checkmark.seal.fill"
        }
    }

    /// Tint for a self-rating button so honesty is encouraged (not punished).
    static func gradeTint(_ grade: ReviewGrade) -> Color {
        switch grade {
        case .again: .dbError
        case .hard: .dbWarning
        case .good: .dbPrimary
        case .easy: .dbSuccess
        }
    }

    static func gradeSymbol(_ grade: ReviewGrade) -> String {
        switch grade {
        case .again: "arrow.counterclockwise"
        case .hard: "cloud.fill"
        case .good: "hand.thumbsup.fill"
        case .easy: "bolt.fill"
        }
    }

    /// Human relative-time framing for a card's next due date (forgetting curve).
    static func dueDescription(for date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: now)
        let startDue = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: startToday, to: startDue).day ?? 0
        switch days {
        case ..<0: return "已逾期 \(-days) 天"
        case 0: return "今天复习"
        case 1: return "明天复习"
        default: return "\(days) 天后复习"
        }
    }

    /// Friendly preview of when the card will return after a given grade — shown
    /// on the rating buttons so the spaced-repetition payoff is visible.
    static func intervalPreview(for card: WordCard, grade: ReviewGrade) -> String {
        let state = SRSState(easeFactor: card.easeFactor,
                             intervalDays: card.intervalDays,
                             repetitions: card.repetitions,
                             dueDate: card.dueDate)
        let next = SRSScheduler.update(state, grade: grade)
        let days = Int(next.intervalDays)
        switch days {
        case ..<1: return "稍后"
        case 1: return "1 天"
        default: return "\(days) 天"
        }
    }

    /// The headword spoken slowly enough for a learner to follow.
    static let speakRate: Float = 0.42
}

// MARK: - Quiz question

/// One generated multiple-choice question for the quiz mode: show the definition,
/// pick the matching headword from four English options.
nonisolated struct VocabQuizQuestion: Identifiable, Sendable {
    let id: UUID
    /// The card being tested (its headword is the correct answer).
    let cardID: UUID
    let prompt: String          // the Chinese/English definition to match
    let phonetic: String
    let answer: String          // correct headword
    let options: [String]       // 4 shuffled options including the answer

    func isCorrect(_ choice: String) -> Bool { choice == answer }
}

/// Pure builder for a small quiz from a set of cards. Deterministic given a seed
/// so previews and tests are stable; distractors are drawn from the same deck so
/// they're plausible (real headwords), padded with a fallback pool if the deck is
/// tiny. Never throws and never returns malformed questions.
enum VocabQuizBuilder {

    /// Fallback distractors used only when a deck has fewer than 4 distinct words,
    /// so a choice question always has four options.
    private static let fallbackPool = [
        "improve", "achieve", "memory", "knowledge", "challenge",
        "confident", "practice", "develop", "explore", "succeed",
    ]

    /// Build up to `limit` choice questions from `cards`.
    /// - Parameter seed: makes shuffling deterministic for previews/tests.
    static func makeQuestions(from cards: [WordCard], limit: Int = 8, seed: UInt64 = 0x9E3779B9) -> [VocabQuizQuestion] {
        let usable = cards.filter { !$0.headword.isEmpty && !$0.definition.isEmpty }
        guard !usable.isEmpty else { return [] }

        var rng = SeededGenerator(seed: seed)
        let pool = orderedUnique(usable.map(\.headword) + fallbackPool)
        let chosen = usable.shuffled(using: &rng).prefix(limit)

        return chosen.map { card in
            var distractors = pool.filter { $0.caseInsensitiveCompare(card.headword) != .orderedSame }
            distractors.shuffle(using: &rng)
            let picks = Array(distractors.prefix(3))
            var options = (picks + [card.headword])
            options.shuffle(using: &rng)
            return VocabQuizQuestion(
                id: UUID(),
                cardID: card.id,
                prompt: card.definition,
                phonetic: card.phonetic,
                answer: card.headword,
                options: options)
        }
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for v in values where seen.insert(v.lowercased()).inserted {
            result.append(v)
        }
        return result
    }
}

/// A tiny deterministic PRNG (SplitMix64) so shuffles are reproducible — keeps
/// previews/tests stable without pulling in any dependency.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
