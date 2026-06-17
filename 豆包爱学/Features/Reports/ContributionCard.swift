//
//  ContributionCard.swift
//  豆包爱学 — Features/Reports
//
//  "答题足迹" — a GitHub-style daily contribution card. It rolls up every
//  ActivityLog's question `count` into a daily heatmap so the learner can see, at
//  a glance, how consistently they've been practicing. Surfaced in 个人中心, 今日,
//  and 学习报告. Every practice / grading / drill / dictation event feeds it via
//  `ActivityRecorder`, so the chart is the single honest picture of daily effort.
//

import SwiftUI

struct ContributionCard: View {
    let logs: [ActivityLog]
    /// Number of week-columns to render (18 ≈ 4 months fills the width nicely).
    var weeks: Int = 18

    private var series: [ContributionStats.DayCount] {
        ContributionStats.dailySeries(logs, weeks: weeks)
    }
    private var windowTotal: Int { series.reduce(0) { $0 + $1.questions } }
    private var allTimeTotal: Int { ContributionStats.totalQuestions(logs) }
    private var streak: Int { ContributionStats.currentStreak(logs) }
    private var activeDays: Int { series.filter { $0.questions > 0 }.count }
    private var hasData: Bool { allTimeTotal > 0 }

    var body: some View {
        DBCard(fill: .dbSurface, elevation: .low) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader(
                    "答题足迹",
                    subtitle: hasData
                        ? "累计答对答错都算数，每天练一点点"
                        : "每答一道题，这里就会亮起一格",
                    systemImage: "square.grid.3x3.fill"
                ) {
                    if streak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                            Text("\(streak) 天")
                        }
                        .font(.dbCaption.weight(.semibold))
                        .foregroundStyle(Color.dbPrimary)
                    }
                }

                if hasData {
                    statStrip
                    DBContributionGraph(series: series)
                    HStack {
                        Text("近 \(weeks) 周共练习 \(windowTotal) 题")
                            .font(.dbCaption2)
                            .foregroundStyle(Color.dbTextTertiary)
                        Spacer(minLength: DBSpacing.md)
                        DBContributionLegend()
                    }
                } else {
                    emptyState
                }
            }
        }
    }

    private var statStrip: some View {
        HStack(spacing: DBSpacing.md) {
            DBValueStat(value: "\(allTimeTotal)", caption: "累计答题", systemImage: "checkmark.seal.fill", tint: .dbSuccess)
            DBValueStat(value: "\(streak)", caption: "连续天数", systemImage: "flame.fill", tint: .dbPrimary)
            DBValueStat(value: "\(activeDays)", caption: "活跃天数", systemImage: "calendar", tint: .dbSecondary)
        }
    }

    private var emptyState: some View {
        HStack(spacing: DBSpacing.md) {
            DBMascot(mood: .curious, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text("还没有答题记录")
                    .font(.dbBodyEmph)
                    .foregroundStyle(Color.dbTextPrimary)
                Text("做一次作业批改、拍道题，或来一组智能练习，足迹就会点亮～")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DBSpacing.sm)
    }
}

#Preview("Contribution card") {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let logs: [ActivityLog] = (0..<90).compactMap { offset in
        guard offset % 4 != 0 else { return nil }
        let log = ActivityLog()
        log.kindRaw = "practice"
        log.count = (offset * 5) % 12 + 1
        log.date = cal.date(byAdding: .day, value: -offset, to: today) ?? today
        return log
    }
    return ScrollView {
        VStack(spacing: 16) {
            ContributionCard(logs: logs)
            ContributionCard(logs: [])
        }
        .padding()
    }
    .background(Color.dbBackground)
}
