//
//  DBContributionGraph.swift
//  豆包爱学 — Design System
//
//  A GitHub-style daily contribution heatmap. Each small rounded square is one
//  calendar day; its color intensity grows with the number of questions the
//  learner answered that day. Columns are calendar weeks (oldest → newest), the
//  last column is the current week, and days still in the future render faintly.
//
//  The grid is horizontally scrollable and auto-anchors to today, so long
//  histories (a full year) stay usable on iPhone while filling the width on Mac.
//
//  Pure presentation: feed it a `ContributionStats.DayCount` series (built by
//  `ContributionStats.dailySeries`). A 0-question day is a valid, visible cell.
//

import SwiftUI

struct DBContributionGraph: View {
    /// Day buckets, oldest → newest, length a multiple of 7 (one week per column).
    let series: [ContributionStats.DayCount]
    /// Square edge length. Cells scale down a touch in compact width.
    var cellSize: CGFloat = 13
    var spacing: CGFloat = 3

    @Environment(\.calendar) private var calendar

    private var today: Date { calendar.startOfDay(for: Date()) }

    /// Chunk the flat series into week columns of 7 (row 0 == firstWeekday).
    private var columns: [[ContributionStats.DayCount]] {
        stride(from: 0, to: series.count, by: 7).map {
            Array(series[$0 ..< min($0 + 7, series.count)])
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: spacing) {
                    weekdayLabels
                    VStack(alignment: .leading, spacing: spacing) {
                        monthLabels
                        grid
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 2)
            }
            .onAppear { proxy.scrollTo(columns.count - 1, anchor: .trailing) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("答题贡献热力图")
    }

    // MARK: Grid

    private var grid: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, week in
                VStack(spacing: spacing) {
                    ForEach(week) { day in
                        cell(day)
                    }
                }
                .id(index)
            }
        }
    }

    private func cell(_ day: ContributionStats.DayCount) -> some View {
        let isFuture = day.date > today
        let level = Self.level(for: day.questions)
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Self.fill(for: level, isFuture: isFuture))
            .frame(width: cellSize, height: cellSize)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color.dbSeparator.opacity(level == 0 && !isFuture ? 0.0 : 0.18), lineWidth: 0.5)
            )
            .opacity(isFuture ? 0.35 : 1)
            .accessibilityLabel(accessibilityLabel(for: day, isFuture: isFuture))
    }

    // MARK: Month labels (aligned above each week column)

    private var monthLabels: some View {
        HStack(spacing: spacing) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, week in
                Text(monthLabel(forColumn: index, week: week))
                    .font(.dbCaption2)
                    .foregroundStyle(Color.dbTextTertiary)
                    .frame(width: cellSize, alignment: .leading)
                    .fixedSize()
            }
        }
        .frame(height: 12, alignment: .bottom)
    }

    /// Show a "M月" label only on the first column of each new month.
    private func monthLabel(forColumn index: Int, week: [ContributionStats.DayCount]) -> String {
        guard let firstDay = week.first?.date else { return "" }
        let month = calendar.component(.month, from: firstDay)
        if index == 0 {
            // Only label column 0 if it actually starts near a month boundary,
            // to avoid a stray label mid-month.
            let day = calendar.component(.day, from: firstDay)
            return day <= 7 ? "\(month)月" : ""
        }
        guard let prevFirst = columns[index - 1].first?.date else { return "" }
        let prevMonth = calendar.component(.month, from: prevFirst)
        return month != prevMonth ? "\(month)月" : ""
    }

    // MARK: Weekday labels (left rail)

    private var weekdayLabels: some View {
        VStack(alignment: .trailing, spacing: spacing) {
            // Reserve space matching the month-label row so the grid aligns.
            Color.clear.frame(width: 16, height: 12)
            ForEach(0..<7, id: \.self) { row in
                Text(weekdaySymbol(row: row))
                    .font(.dbCaption2)
                    .foregroundStyle(Color.dbTextTertiary)
                    .frame(width: 16, height: cellSize, alignment: .trailing)
            }
        }
    }

    /// GitHub shows alternating weekday labels; we label rows 1/3/5.
    private func weekdaySymbol(row: Int) -> String {
        guard row % 2 == 1 else { return "" }
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        let weekday = ((calendar.firstWeekday - 1 + row) % 7)
        return symbols[weekday]
    }

    // MARK: Accessibility

    private func accessibilityLabel(for day: ContributionStats.DayCount, isFuture: Bool) -> String {
        let m = calendar.component(.month, from: day.date)
        let d = calendar.component(.day, from: day.date)
        if isFuture { return "\(m)月\(d)日" }
        return day.questions == 0 ? "\(m)月\(d)日，没有练习" : "\(m)月\(d)日，\(day.questions) 题"
    }

    // MARK: Intensity scale

    /// Bucket a day's question count into 0…4. Tuned for K12 daily volume.
    static func level(for questions: Int) -> Int {
        switch questions {
        case 0: 0
        case 1...2: 1
        case 3...5: 2
        case 6...9: 3
        default: 4
        }
    }

    /// Green "growth" scale that reads as contributions in light & dark.
    static func fill(for level: Int, isFuture: Bool) -> Color {
        if isFuture { return Color.dbSeparator.opacity(0.18) }
        switch level {
        case 0: return Color(light: Color(hex: 0xEBEDF0), dark: Color(hex: 0x24242E))
        case 1: return Color(light: Color(hex: 0xB7E4C7), dark: Color(hex: 0x1F4A33))
        case 2: return Color(light: Color(hex: 0x6FCF97), dark: Color(hex: 0x2E7D52))
        case 3: return Color(light: Color(hex: 0x39B36B), dark: Color(hex: 0x3FA76A))
        default: return Color(light: Color(hex: 0x2FB36B), dark: Color(hex: 0x4CCB86))
        }
    }
}

/// A compact "少 ▢▢▢▢ 多" legend matching the heatmap scale.
struct DBContributionLegend: View {
    var cellSize: CGFloat = 11

    var body: some View {
        HStack(spacing: 4) {
            Text("少").font(.dbCaption2).foregroundStyle(Color.dbTextTertiary)
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(DBContributionGraph.fill(for: level, isFuture: false))
                    .frame(width: cellSize, height: cellSize)
            }
            Text("多").font(.dbCaption2).foregroundStyle(Color.dbTextTertiary)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Contribution graph") {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let logs: [ActivityLog] = (0..<80).compactMap { offset in
        guard offset % 3 != 0 else { return nil }
        let log = ActivityLog()
        log.kindRaw = "practice"
        log.count = (offset * 7) % 13
        log.date = cal.date(byAdding: .day, value: -offset, to: today) ?? today
        return log
    }
    let series = ContributionStats.dailySeries(logs, weeks: 18)
    return VStack(alignment: .leading, spacing: 16) {
        DBContributionGraph(series: series)
        DBContributionLegend()
    }
    .padding()
    .background(Color.dbBackground)
}
