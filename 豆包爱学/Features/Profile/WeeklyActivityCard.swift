//
//  WeeklyActivityCard.swift
//  豆包爱学 — Features/Profile
//
//  Weekly study-minutes summary rendered with Swift Charts. Aggregates
//  ActivityLog entries into the last 7 calendar days. Shows a friendly empty
//  state when there is no recorded activity yet.
//

import SwiftUI
import Charts

/// One day's aggregated study minutes for the weekly chart.
private struct ProfileDayMinutes: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Double
    var isToday: Bool { Calendar.current.isDateInToday(date) }
}

struct WeeklyActivityCard: View {
    let logs: [ActivityLog]

    private var days: [ProfileDayMinutes] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Build the last 7 day-buckets (oldest → newest).
        return (0..<7).reversed().map { offset -> ProfileDayMinutes in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let total = logs
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0.0) { $0 + $1.minutes }
            return ProfileDayMinutes(date: day, minutes: total)
        }
    }

    private var totalMinutes: Double { days.reduce(0) { $0 + $1.minutes } }
    private var hasData: Bool { totalMinutes > 0 }

    var body: some View {
        DBCard(fill: .dbSurface, elevation: .low) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader(
                    "本周学习时长",
                    subtitle: hasData ? "近 7 天累计 \(Int(totalMinutes.rounded())) 分钟" : "记录你的每日学习",
                    systemImage: "clock.badge.checkmark.fill"
                ) {
                    if hasData {
                        Text("\(Int(totalMinutes.rounded()))′")
                            .font(.dbScore)
                            .foregroundStyle(Color.dbPrimary)
                    }
                }

                if hasData {
                    chart
                } else {
                    emptyState
                }
            }
        }
    }

    private var chart: some View {
        // Use the actual day as the x value so bars stay in chronological order
        // (a categorical String axis would reorder them alphabetically).
        Chart(days) { day in
            BarMark(
                x: .value("日期", day.date, unit: .day),
                y: .value("分钟", day.minutes),
                width: .ratio(0.55)
            )
            .cornerRadius(DBRadius.xs)
            .foregroundStyle(
                day.isToday
                    ? AnyShapeStyle(Color.dbHeroGradient)
                    : AnyShapeStyle(Color.dbPrimary.opacity(0.55))
            )
            .annotation(position: .top, alignment: .center) {
                if day.minutes > 0 {
                    Text("\(Int(day.minutes.rounded()))")
                        .font(.dbCaption2)
                        .foregroundStyle(Color.dbTextTertiary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Color.dbSeparator.opacity(0.6))
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text("\(Int(minutes))")
                            .font(.dbCaption2)
                            .foregroundStyle(Color.dbTextTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: days.map(\.date)) { value in
                AxisValueLabel(centered: true) {
                    if let date = value.as(Date.self) {
                        Text(weekdaySymbol(for: date))
                            .font(.dbCaption)
                            .foregroundStyle(
                                Calendar.current.isDateInToday(date)
                                    ? Color.dbPrimary
                                    : Color.dbTextSecondary
                            )
                    }
                }
            }
        }
        .frame(height: 168)
        .accessibilityLabel("本周每日学习时长柱状图，近 7 天累计 \(Int(totalMinutes.rounded())) 分钟")
    }

    private func weekdaySymbol(for date: Date) -> String {
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        let weekday = Calendar.current.component(.weekday, from: date) // 1...7
        return symbols[(weekday - 1) % 7]
    }

    private var emptyState: some View {
        HStack(spacing: DBSpacing.md) {
            DBMascot(mood: .curious, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text("还没有学习记录哦")
                    .font(.dbBodyEmph)
                    .foregroundStyle(Color.dbTextPrimary)
                Text("开始拍题、听写或上一节课，这里就会出现你的成长曲线～")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DBSpacing.sm)
    }
}

#Preview("Weekly activity") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let sample: [ActivityLog] = (0..<7).map { offset in
        let log = ActivityLog()
        log.date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        log.minutes = Double([12, 0, 25, 18, 30, 8, 22][offset])
        return log
    }
    return ScrollView {
        VStack(spacing: DBSpacing.lg) {
            WeeklyActivityCard(logs: sample)
            WeeklyActivityCard(logs: [])
        }
        .padding(DBSpacing.screenInset)
    }
    .background(Color.dbBackground)
}
