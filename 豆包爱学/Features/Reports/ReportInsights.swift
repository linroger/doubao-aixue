//
//  ReportInsights.swift
//  豆包爱学 — Features/Reports
//
//  Richer, additive aggregations layered on top of `LearningReport` for the
//  enhanced 学习报告 dashboard:
//    · 学习时长 7-day rolling average (drawn as a line over the bars)
//    · 错题攻克 trend (新增 vs 已复习 over the period)
//    · 知识掌握分布 donut (counts per MasteryState)
//    · per-subject 掌握率 target line
//
//  All types are pure value types — UI-free, `nonisolated`, `Sendable` — so the
//  view layer can build them off raw @Query results cheaply on the main actor
//  without retaining any SwiftData model. The existing `ReportModels` /
//  `ReportBuilder` are left untouched; this file only *adds* to them.
//

import Foundation

// MARK: - Rolling average

/// One day on the 学习时长 chart together with its trailing rolling average,
/// so the bar chart can overlay a smooth 7 日均线 trend line.
public nonisolated struct ReportRollingPoint: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let minutes: Double
    public let rollingAverage: Double
    public let isCurrent: Bool

    public init(date: Date, minutes: Double, rollingAverage: Double, isCurrent: Bool) {
        self.date = date
        self.minutes = minutes
        self.rollingAverage = rollingAverage
        self.isCurrent = isCurrent
    }
}

// MARK: - 错题攻克 trend

/// One bucket of the 错题攻克 trend: how many mistakes were *added* versus how
/// many were *reviewed* (攻克中) on/within that date bucket.
public nonisolated struct ReportMistakeTrendPoint: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let added: Int          // 新增错题
    public let reviewed: Int        // 当日有复习动作的错题
    public let isCurrent: Bool

    public init(date: Date, added: Int, reviewed: Int, isCurrent: Bool) {
        self.date = date
        self.added = added
        self.reviewed = reviewed
        self.isCurrent = isCurrent
    }
}

// MARK: - 知识掌握分布 donut

/// A slice of the 掌握分布 donut: how many tracked knowledge points sit in each
/// `MasteryState` band (新学 / 薄弱 / 巩固中 / 已掌握).
public nonisolated struct ReportMasterySlice: Identifiable, Sendable {
    public var id: String { state.rawValue }
    public let state: MasteryState
    public let count: Int

    public init(state: MasteryState, count: Int) {
        self.state = state
        self.count = count
    }
}

/// The bundle of enhanced insights for a period. Built additively so the core
/// `LearningReport` contract stays frozen.
public nonisolated struct ReportInsights: Sendable {
    public let rollingTime: [ReportRollingPoint]
    public let mistakeTrend: [ReportMistakeTrendPoint]
    public let masteryDistribution: [ReportMasterySlice]
    /// The class/cohort target used as a reference line on the 掌握率 chart.
    public let masteryTarget: Double

    public init(
        rollingTime: [ReportRollingPoint],
        mistakeTrend: [ReportMistakeTrendPoint],
        masteryDistribution: [ReportMasterySlice],
        masteryTarget: Double
    ) {
        self.rollingTime = rollingTime
        self.mistakeTrend = mistakeTrend
        self.masteryDistribution = masteryDistribution
        self.masteryTarget = masteryTarget
    }

    /// Total knowledge points represented in the distribution donut.
    public var distributionTotal: Int {
        masteryDistribution.reduce(0) { $0 + $1.count }
    }

    /// True when the mistake trend has any movement worth charting.
    public var hasMistakeMovement: Bool {
        mistakeTrend.contains { $0.added > 0 || $0.reviewed > 0 }
    }
}
