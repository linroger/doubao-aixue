//
//  AchievementModel.swift
//  豆包爱学 — Features/Achievements
//
//  Pure, deterministic gamification logic that turns the learner's seeded
//  SwiftData history (LearnerProfile / MasteryRecord / MistakeItem / WordCard /
//  ProblemRecord / ActivityLog) into XP, levels and badges — WITHOUT adding any
//  new @Model. The view feeds in already-fetched @Query arrays; this layer does
//  the math so it stays testable and off the main concern of the View body.
//
//  All types here are value types and isolation-free (`nonisolated`) so they can
//  be built from any context. Color/Font helpers live on the View side because
//  the design-system accessors are @MainActor.
//

import Foundation

// MARK: - Tier

/// Visual rarity of a badge — drives its accent color on the View side.
nonisolated enum AchievementTier: Int, Codable, Sendable, CaseIterable {
    case bronze, silver, gold, platinum

    var displayName: String {
        switch self {
        case .bronze: "青铜"
        case .silver: "白银"
        case .gold: "黄金"
        case .platinum: "铂金"
        }
    }
}

// MARK: - Metric

/// The underlying counter a badge tracks. Each maps to a derived stat so a badge
/// can render real progress ("再坚持 3 天解锁") even while locked.
nonisolated enum AchievementMetric: String, Codable, Sendable {
    case streak          // 连续打卡天数
    case problemsSolved  // 累计解题
    case mistakesMastered // 攻克错题
    case knowledgeMastered // 掌握知识点
    case wordsLearned    // 学会的单词
    case level           // 等级里程碑
}

// MARK: - Badge definition (static catalog)

/// A static, ship-time badge spec. Unlock state is computed at runtime by
/// comparing `threshold` against the live metric value.
nonisolated struct AchievementDef: Identifiable, Sendable {
    let id: String
    let title: String
    let blurb: String          // shown when unlocked
    let lockedHint: String     // shown when locked (no spoilers, just direction)
    let systemImage: String
    let metric: AchievementMetric
    let threshold: Int
    let tier: AchievementTier
    let xp: Int                // XP awarded when unlocked
}

// MARK: - Runtime badge (def + live state)

nonisolated struct AchievementBadge: Identifiable, Sendable {
    let def: AchievementDef
    let currentValue: Int
    let isUnlocked: Bool
    let unlockedDate: Date?

    var id: String { def.id }

    /// Progress toward unlock, clamped 0...1. Unlocked badges read as full.
    var progress: Double {
        guard def.threshold > 0 else { return 1 }
        if isUnlocked { return 1 }
        return min(1, max(0, Double(currentValue) / Double(def.threshold)))
    }

    /// How many more units are needed — used for the "再…解锁" nudge.
    var remaining: Int { max(0, def.threshold - currentValue) }
}

// MARK: - Derived learner metrics

/// A snapshot of the counters the achievement system reads. Built once from the
/// live @Query arrays so every badge shares a consistent view of the data.
nonisolated struct AchievementMetrics: Sendable {
    var streakDays: Int = 0
    var problemsSolved: Int = 0
    var mistakesMastered: Int = 0
    var knowledgeMastered: Int = 0
    var wordsLearned: Int = 0

    func value(for metric: AchievementMetric, level: Int) -> Int {
        switch metric {
        case .streak: streakDays
        case .problemsSolved: problemsSolved
        case .mistakesMastered: mistakesMastered
        case .knowledgeMastered: knowledgeMastered
        case .wordsLearned: wordsLearned
        case .level: level
        }
    }
}

// MARK: - XP / level math

/// Computed level standing derived from total XP. The curve is gentle early
/// (fast wins) and steeper later (long-term goals) — Duolingo-style.
nonisolated struct LevelProgress: Sendable {
    let totalXP: Int
    let level: Int
    let xpIntoLevel: Int
    let xpForLevel: Int     // span of the current level

    /// 0...1 ring fill toward the next level.
    var fraction: Double {
        guard xpForLevel > 0 else { return 0 }
        return min(1, max(0, Double(xpIntoLevel) / Double(xpForLevel)))
    }

    var xpToNext: Int { max(0, xpForLevel - xpIntoLevel) }
}

// MARK: - Engine

/// Stateless engine: pure functions over metrics. No persistence, no isolation.
nonisolated enum AchievementEngine {

    /// XP contributed by raw activity, independent of badge bonuses. Tuned so a
    /// committed week of study lands a learner around level 3–4.
    static func baseXP(from m: AchievementMetrics) -> Int {
        m.problemsSolved * 12
            + m.mistakesMastered * 20
            + m.knowledgeMastered * 30
            + m.wordsLearned * 8
            + m.streakDays * 15
    }

    /// Total XP = activity XP + the XP of every unlocked badge.
    static func totalXP(metrics: AchievementMetrics, unlockedBadgeXP: Int) -> Int {
        baseXP(from: metrics) + unlockedBadgeXP
    }

    /// XP required to *complete* a given level (i.e. go from `level` to `level+1`).
    /// Level 1 → 2 costs 100; each level adds 60 more than the previous span.
    static func xpSpan(forLevel level: Int) -> Int {
        let clamped = max(1, level)
        return 100 + (clamped - 1) * 60
    }

    /// Cumulative XP needed to *reach* the start of `level` (level 1 starts at 0).
    static func cumulativeXP(toReach level: Int) -> Int {
        guard level > 1 else { return 0 }
        var total = 0
        for l in 1..<level { total += xpSpan(forLevel: l) }
        return total
    }

    /// Resolve a total-XP figure into a `LevelProgress` standing.
    static func levelProgress(totalXP: Int) -> LevelProgress {
        let xp = max(0, totalXP)
        var level = 1
        // Walk levels until the next boundary exceeds our XP. Bounded so a huge
        // XP value can never spin forever.
        while level < 999 {
            let nextBoundary = cumulativeXP(toReach: level + 1)
            if xp < nextBoundary { break }
            level += 1
        }
        let floorXP = cumulativeXP(toReach: level)
        let span = xpSpan(forLevel: level)
        return LevelProgress(
            totalXP: xp,
            level: level,
            xpIntoLevel: xp - floorXP,
            xpForLevel: span)
    }

    /// Provisional level computed from *activity only* (used to evaluate the
    /// `.level` milestone badges without a circular dependency on badge XP).
    static func provisionalLevel(metrics: AchievementMetrics) -> Int {
        levelProgress(totalXP: baseXP(from: metrics)).level
    }

    /// The full ship-time badge catalog. Stable IDs are persisted as @AppStorage
    /// keys for unlock dates, so never rename or remove an id.
    static let catalog: [AchievementDef] = [
        // 连续打卡
        .init(id: "streak_3", title: "三日之约", blurb: "连续学习 3 天，好习惯开始啦！",
              lockedHint: "连续打卡 3 天即可点亮", systemImage: "flame.fill",
              metric: .streak, threshold: 3, tier: .bronze, xp: 60),
        .init(id: "streak_7", title: "一周不断", blurb: "连续 7 天坚持，自律小达人！",
              lockedHint: "连续打卡 7 天即可点亮", systemImage: "flame.fill",
              metric: .streak, threshold: 7, tier: .silver, xp: 120),
        .init(id: "streak_30", title: "月度坚持", blurb: "整整一个月每天都来，太了不起了！",
              lockedHint: "连续打卡 30 天即可点亮", systemImage: "flame.circle.fill",
              metric: .streak, threshold: 30, tier: .gold, xp: 300),
        .init(id: "streak_100", title: "百日筑基", blurb: "连续 100 天！这份坚持闪闪发光。",
              lockedHint: "连续打卡 100 天即可点亮", systemImage: "crown.fill",
              metric: .streak, threshold: 100, tier: .platinum, xp: 800),
        // 累计解题
        .init(id: "solve_10", title: "解题新星", blurb: "解出 10 道题，思路越来越清晰！",
              lockedHint: "累计解出 10 道题即可点亮", systemImage: "checkmark.seal.fill",
              metric: .problemsSolved, threshold: 10, tier: .bronze, xp: 60),
        .init(id: "solve_50", title: "解题能手", blurb: "解出 50 道题，难题也不怕了！",
              lockedHint: "累计解出 50 道题即可点亮", systemImage: "checkmark.seal.fill",
              metric: .problemsSolved, threshold: 50, tier: .silver, xp: 150),
        .init(id: "solve_200", title: "解题大师", blurb: "解出 200 道题，实力满满！",
              lockedHint: "累计解出 200 道题即可点亮", systemImage: "rosette",
              metric: .problemsSolved, threshold: 200, tier: .gold, xp: 400),
        // 攻克错题
        .init(id: "mistake_5", title: "错题克星", blurb: "攻克 5 道错题，弱点变强项！",
              lockedHint: "把 5 道错题练到掌握即可点亮", systemImage: "bandage.fill",
              metric: .mistakesMastered, threshold: 5, tier: .bronze, xp: 80),
        .init(id: "mistake_25", title: "查漏补缺", blurb: "攻克 25 道错题，基础越来越牢！",
              lockedHint: "把 25 道错题练到掌握即可点亮", systemImage: "shield.lefthalf.filled",
              metric: .mistakesMastered, threshold: 25, tier: .gold, xp: 260),
        // 掌握知识点
        .init(id: "kp_5", title: "融会贯通", blurb: "掌握 5 个知识点，知识树长出新枝！",
              lockedHint: "掌握 5 个知识点即可点亮", systemImage: "brain.head.profile",
              metric: .knowledgeMastered, threshold: 5, tier: .silver, xp: 120),
        .init(id: "kp_20", title: "知识图谱", blurb: "掌握 20 个知识点，体系日益完整！",
              lockedHint: "掌握 20 个知识点即可点亮", systemImage: "point.3.connected.trianglepath.dotted",
              metric: .knowledgeMastered, threshold: 20, tier: .gold, xp: 350),
        // 学单词
        .init(id: "word_20", title: "词汇起步", blurb: "学会 20 个单词，开口更自信！",
              lockedHint: "学会 20 个单词即可点亮", systemImage: "character.book.closed.fill",
              metric: .wordsLearned, threshold: 20, tier: .bronze, xp: 70),
        .init(id: "word_100", title: "词汇达人", blurb: "学会 100 个单词，词汇量飞跃！",
              lockedHint: "学会 100 个单词即可点亮", systemImage: "text.book.closed.fill",
              metric: .wordsLearned, threshold: 100, tier: .gold, xp: 320),
        // 等级里程碑
        .init(id: "level_5", title: "崭露头角", blurb: "升到 5 级，进步看得见！",
              lockedHint: "升到 5 级即可点亮", systemImage: "star.leadinghalf.filled",
              metric: .level, threshold: 5, tier: .silver, xp: 150),
        .init(id: "level_10", title: "勤学之星", blurb: "升到 10 级，闪耀的学习之星！",
              lockedHint: "升到 10 级即可点亮", systemImage: "star.circle.fill",
              metric: .level, threshold: 10, tier: .platinum, xp: 500),
    ]
}
