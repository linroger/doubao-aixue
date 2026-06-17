//
//  ActivityRecorder.swift
//  豆包爱学 — Services/Persistence
//
//  The single, app-wide entry point for recording that the learner did something —
//  most importantly, how many QUESTIONS they answered / graded / practiced. Every
//  learning surface (作业批改 / 题库 / 拍题 / 练习 / 考试 / 听写 / 背单词 / 作文) funnels
//  through `ActivityRecorder.log(...)` so the data is consistent and the daily
//  contribution heatmap ("答题足迹") counts everything the same way.
//
//  Keeping this in one place means a new feature only has to add one line to start
//  contributing to the streak, the report charts, and the contribution graph.
//

import Foundation
import SwiftData

/// Canonical activity kinds. Stored as `ActivityLog.kindRaw`; the display name and
/// icon live here so 报告 / 今日 / 贡献图 all label activity identically.
public enum ActivityKind: String, CaseIterable, Sendable {
    case solve          // 拍题 / 搜题
    case workbook       // 作业批改
    case practice       // 题库 / 智能出题 练习
    case drill          // 靶向练习
    case exam           // 测验 / 考试
    case dictation      // 听写
    case vocabulary     // 背单词
    case essay          // 作文批改
    case tutor          // AI 辅导对话
    case focus          // 专注番茄钟
    case course         // 听课

    public var displayName: String {
        switch self {
        case .solve: "拍题搜题"
        case .workbook: "作业批改"
        case .practice: "智能练习"
        case .drill: "靶向练习"
        case .exam: "测验"
        case .dictation: "听写"
        case .vocabulary: "背单词"
        case .essay: "作文批改"
        case .tutor: "AI 辅导"
        case .focus: "专注"
        case .course: "听课"
        }
    }

    public var symbolName: String {
        switch self {
        case .solve: "camera.viewfinder"
        case .workbook: "doc.viewfinder.fill"
        case .practice: "sparkles"
        case .drill: "target"
        case .exam: "checklist"
        case .dictation: "pencil.and.scribble"
        case .vocabulary: "textformat.abc"
        case .essay: "text.badge.checkmark"
        case .tutor: "bubble.left.and.bubble.right.fill"
        case .focus: "timer"
        case .course: "play.rectangle.fill"
        }
    }
}

@MainActor
public enum ActivityRecorder {

    /// Record a learning event. `questions` is the number of questions answered /
    /// graded / practiced (drives the contribution heatmap); `minutes` is elapsed
    /// study time (drives 本周学习时长). Either may be zero. Returns whether the
    /// underlying save succeeded.
    @discardableResult
    public static func log(
        _ context: ModelContext,
        kind: ActivityKind,
        subject: Subject? = nil,
        questions: Int = 0,
        minutes: Double = 0,
        detail: String = ""
    ) -> Bool {
        let entry = ActivityLog()
        entry.kindRaw = kind.rawValue
        entry.subject = subject
        entry.count = max(0, questions)
        entry.minutes = max(0, minutes)
        entry.detail = detail
        entry.date = Date()
        context.insert(entry)
        return context.saveLogging("ActivityRecorder.log(\(kind.rawValue))")
    }
}

// MARK: - Contribution aggregation

/// Pure, testable helpers that turn raw `ActivityLog`s into the day-bucketed data
/// the contribution heatmap renders. Kept free of SwiftUI so it can be reused by
/// 今日 / 个人中心 / 学习报告 and unit-checked independently.
public enum ContributionStats {

    /// One calendar day's rolled-up question count.
    public struct DayCount: Sendable, Identifiable {
        public let date: Date          // start-of-day
        public let questions: Int
        public var id: Date { date }
    }

    /// Sum `ActivityLog.count` per calendar day, keyed by start-of-day.
    public static func questionsByDay(_ logs: [ActivityLog], calendar: Calendar = .current) -> [Date: Int] {
        var result: [Date: Int] = [:]
        for log in logs where log.count > 0 {
            let day = calendar.startOfDay(for: log.date)
            result[day, default: 0] += log.count
        }
        return result
    }

    /// Build a contiguous run of `weeks` * 7 day buckets ending today (oldest → newest),
    /// each carrying that day's question total (0 when nothing was practiced).
    public static func dailySeries(
        _ logs: [ActivityLog],
        weeks: Int,
        calendar: Calendar = .current,
        today: Date = Date()
    ) -> [DayCount] {
        let byDay = questionsByDay(logs, calendar: calendar)
        let end = calendar.startOfDay(for: today)
        // `trailing` = today's row index within its week column (0 == firstWeekday).
        let weekday = calendar.component(.weekday, from: end) // 1 = Sunday
        let trailing = ((weekday - calendar.firstWeekday) % 7 + 7) % 7
        let totalDays = weeks * 7
        // Grid starts on the firstWeekday of the oldest week so that chunking the
        // result by 7 yields clean calendar-week columns and the LAST column is the
        // current week (its days after today render as empty/future).
        let startOffset = -((weeks - 1) * 7 + trailing)
        return (0..<totalDays).map { i in
            let day = calendar.date(byAdding: .day, value: startOffset + i, to: end) ?? end
            return DayCount(date: day, questions: byDay[day] ?? 0)
        }
    }

    /// Total questions across all supplied logs.
    public static func totalQuestions(_ logs: [ActivityLog]) -> Int {
        logs.reduce(0) { $0 + max(0, $1.count) }
    }

    /// Current streak: consecutive days (ending today, or yesterday if today is
    /// still empty) on which at least one question was practiced.
    public static func currentStreak(
        _ logs: [ActivityLog],
        calendar: Calendar = .current,
        today: Date = Date()
    ) -> Int {
        let byDay = questionsByDay(logs, calendar: calendar)
        guard !byDay.isEmpty else { return 0 }
        let start = calendar.startOfDay(for: today)
        var streak = 0
        var cursor = start
        // Allow the streak to "hold" if today hasn't been practiced yet but yesterday was.
        if (byDay[cursor] ?? 0) == 0 {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            guard (byDay[cursor] ?? 0) > 0 else { return 0 }
        }
        while (byDay[cursor] ?? 0) > 0 {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    /// The busiest single day's question count (for legend scaling / "最佳一天").
    public static func bestDay(_ logs: [ActivityLog], calendar: Calendar = .current) -> Int {
        questionsByDay(logs, calendar: calendar).values.max() ?? 0
    }
}
