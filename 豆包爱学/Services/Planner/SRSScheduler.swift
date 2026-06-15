//
//  SRSScheduler.swift
//  豆包爱学
//
//  Spaced-repetition scheduling (SM-2 variant) for 背单词 and 错题本 review.
//

import Foundation

public nonisolated enum ReviewGrade: Int, Sendable, CaseIterable {
    case again = 0   // 不会
    case hard = 3    // 模糊
    case good = 4    // 会
    case easy = 5    // 很简单

    public var displayName: String {
        switch self {
        case .again: "不会"
        case .hard: "模糊"
        case .good: "会"
        case .easy: "简单"
        }
    }
}

public nonisolated struct SRSState: Sendable, Equatable {
    public var easeFactor: Double
    public var intervalDays: Double
    public var repetitions: Int
    public var dueDate: Date
    public init(easeFactor: Double = 2.5, intervalDays: Double = 0, repetitions: Int = 0, dueDate: Date = Date()) {
        self.easeFactor = easeFactor; self.intervalDays = intervalDays
        self.repetitions = repetitions; self.dueDate = dueDate
    }
}

public nonisolated enum SRSScheduler {

    /// Apply an SM-2 update for a review of the given quality.
    public static func update(_ state: SRSState, grade: ReviewGrade, now: Date = Date()) -> SRSState {
        var s = state
        let q = Double(grade.rawValue)

        if grade == .again {
            s.repetitions = 0
            s.intervalDays = 1
        } else {
            s.repetitions += 1
            switch s.repetitions {
            case 1: s.intervalDays = 1
            case 2: s.intervalDays = 6
            default: s.intervalDays = (s.intervalDays * s.easeFactor).rounded()
            }
        }
        // Ease-factor adjustment, floored at 1.3.
        s.easeFactor = max(1.3, s.easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)))
        s.dueDate = Calendar.current.date(byAdding: .day, value: Int(s.intervalDays), to: now) ?? now
        return s
    }

    /// Map an interval to a coarse mastery state for UI.
    public static func mastery(forInterval days: Double) -> MasteryState {
        switch days {
        case ..<1: .new
        case ..<6: .weak
        case ..<21: .developing
        default: .mastered
        }
    }
}
