//
//  TodayView.swift
//  豆包爱学 — Features/Today
//
//  今日 — a single-glance daily planner. It aggregates everything the learner
//  should do *today* from the already-seeded SwiftData store, so one screen
//  answers "我今天学什么？":
//    · a warm header with a daily-goal ring (今日学习时长 vs 目标) + 打卡 streak + mascot
//    · 今日靶向练习 — the weakest MasteryRecord (via StudyPlanner) → openDrill
//    · 错题复习 — MistakeItems whose nextReviewAt has come due → mistakeDetail
//    · 背单词 — WordCards due today (WordDeck.dueCount) → openTool(.vocabulary)
//    · 继续学习 — the most recently-touched in-progress course → navigate(.course)
//    · 学习时长 mini-chart — last 7 days of ActivityLog minutes (Swift Charts)
//  Every task is a tappable DBCard that deep-links through the AppRouter.
//
//  Everything is *derived* from existing models — no new @Model type is added.
//  All states are handled: a fully-loaded plan, an "all caught up" celebration
//  when every task is done, and a gentle empty state before any data exists.
//
//  Contract: `struct TodayView: View` with a no-arg `init()`. The shell owns the
//  NavigationStack, so this view only sets a title and returns content. The
//  integrator maps a new route/ToolKind → TodayView().
//

import SwiftUI
import SwiftData
import Charts

struct TodayView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Seeded personalization & content — everything is derived from these.
    @Query private var profiles: [LearnerProfile]
    @Query private var masteries: [MasteryRecord]
    @Query private var knowledgePoints: [KnowledgePointEntity]
    @Query private var mistakes: [MistakeItem]
    @Query private var decks: [WordDeck]
    @Query private var courses: [CourseEntity]
    @Query private var lessonProgress: [LessonProgress]
    @Query(sort: \ActivityLog.date, order: .forward) private var logs: [ActivityLog]

    init() {}

    // MARK: - Environment-derived helpers

    private var isRegular: Bool { sizeClass != .compact }
    private var profile: LearnerProfile? { profiles.first }
    private var learnerName: String { profile?.nickname ?? "同学" }

    // MARK: - Daily-goal ring

    /// The learner's daily study-minute target (falls back to a friendly 20 min).
    private let dailyGoalMinutes: Double = 20

    /// Minutes already studied *today*, summed from today's ActivityLog rows.
    private var minutesToday: Double {
        let cal = Calendar.current
        return logs
            .filter { cal.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.minutes }
    }

    /// Today's goal progress, clamped to 0…1 for the ring.
    private var goalProgress: Double {
        guard dailyGoalMinutes > 0 else { return 0 }
        return min(1, max(0, minutesToday / dailyGoalMinutes))
    }

    private var goalReached: Bool { minutesToday >= dailyGoalMinutes }

    // MARK: - Task derivations

    /// The single weakest, not-yet-mastered knowledge point — the focus of today's
    /// 靶向练习. Uses StudyPlanner so the ordering matches the rest of the app.
    private var weakestPoint: WeakPoint? {
        let candidates: [WeakPoint] = masteries
            .filter { $0.state != .mastered }
            .map { record in
                WeakPoint(
                    id: record.knowledgePointID,
                    name: knowledgePointName(for: record.knowledgePointID)
                        ?? record.subject.displayName,
                    subject: record.subject,
                    score: record.score)
            }
        return StudyPlanner.weakest(candidates, limit: 1).first
    }

    private func knowledgePointName(for id: String) -> String? {
        knowledgePoints.first { $0.id == id }?.name
    }

    /// Mistakes whose spaced-repetition review has come due (nextReviewAt <= now),
    /// excluding ones already mastered, soonest-due first.
    private var dueMistakes: [MistakeItem] {
        let now = Date()
        return mistakes
            .filter { $0.mastery != .mastered && $0.nextReviewAt <= now }
            .sorted { $0.nextReviewAt < $1.nextReviewAt }
    }

    /// The single mistake to surface as today's review entry.
    private var nextMistake: MistakeItem? { dueMistakes.first }

    /// Total word cards due today across every deck.
    private var dueWordCount: Int {
        decks.reduce(0) { $0 + $1.dueCount }
    }

    /// The deck with the most due cards (so the entry deep-links somewhere useful).
    private var topDueDeck: WordDeck? {
        decks
            .filter { $0.dueCount > 0 }
            .max { $0.dueCount < $1.dueCount }
    }

    /// The course to "continue" — the most recently-touched, not-yet-completed
    /// in-progress lesson. Falls back to any ready course the learner can start.
    private var continueCourse: (course: CourseEntity, progress: LessonProgress?)? {
        let readyCourses = courses.filter { $0.generationStatusRaw == "ready" }
        guard !readyCourses.isEmpty else { return nil }

        // Prefer an in-progress lesson (has progress, not completed), newest touch.
        let inProgress = lessonProgress
            .filter { !$0.completed && $0.lastSegmentIndex > 0 }
            .sorted { $0.updatedAt > $1.updatedAt }

        for progress in inProgress {
            if let course = readyCourses.first(where: { $0.id == progress.courseID }) {
                return (course, progress)
            }
        }

        // Otherwise suggest a fresh course to begin (newest first).
        if let fresh = readyCourses.sorted(by: { $0.createdAt > $1.createdAt }).first {
            return (fresh, nil)
        }
        return nil
    }

    /// Fraction of `continueCourse` already watched, for its progress label.
    private func courseProgress(_ course: CourseEntity, _ progress: LessonProgress?) -> Double {
        guard let progress, course.segments.count > 1 else { return 0 }
        let denom = Double(course.segments.count - 1)
        guard denom > 0 else { return 0 }
        return min(1, max(0, Double(progress.lastSegmentIndex) / denom))
    }

    // MARK: - Task model

    /// A single actionable "今日任务". Built purely from derived data above; the
    /// view renders these uniformly and routes on tap.
    private struct DailyTask: Identifiable {
        let id: String
        let title: String
        let detail: String
        let systemImage: String
        let tint: Color
        let badge: Int?
        let action: () -> Void
    }

    private var tasks: [DailyTask] {
        var result: [DailyTask] = []

        if let weak = weakestPoint {
            result.append(DailyTask(
                id: "drill",
                title: "靶向练习 · \(weak.name)",
                detail: "掌握度 \(Int(weak.score * 100))% · 针对薄弱点，\(StudyPlanner.estimatedMinutes(forTargets: 1)) 分钟巩固",
                systemImage: "target",
                tint: DBSubjectColor.color(for: weak.subject),
                badge: nil,
                action: {
                    HapticEngine.play(.selection)
                    router.openDrill(knowledgePointID: weak.id, regular: isRegular)
                }))
        }

        if let mistake = nextMistake {
            let extra = dueMistakes.count - 1
            let detail = extra > 0
                ? "\(mistake.subject.displayName) · 还有 \(extra) 道错题等待复习"
                : "\(mistake.subject.displayName) · 趁热打铁，巩固这道易错题"
            result.append(DailyTask(
                id: "mistake",
                title: "错题复习",
                detail: detail,
                systemImage: "book.closed.fill",
                tint: .dbWarning,
                badge: dueMistakes.count,
                action: {
                    HapticEngine.play(.selection)
                    router.navigate(.mistakeDetail(mistake.id), regular: isRegular)
                }))
        }

        if dueWordCount > 0 {
            let deckName = topDueDeck?.name
            let detail = deckName.map { "\($0) · 今日待复习 \(dueWordCount) 个" }
                ?? "今日待复习 \(dueWordCount) 个单词"
            result.append(DailyTask(
                id: "vocabulary",
                title: "背单词打卡",
                detail: detail,
                systemImage: "character.book.closed.fill",
                tint: .dbAccent,
                badge: dueWordCount,
                action: {
                    HapticEngine.play(.selection)
                    router.openTool(.vocabulary, regular: isRegular)
                }))
        }

        if let entry = continueCourse {
            let pct = Int(courseProgress(entry.course, entry.progress) * 100)
            let detail = entry.progress == nil
                ? "新课程 · \(durationLabel(entry.course.durationSec))，开启今天的第一课吧"
                : "已学 \(pct)% · 接着上次继续学习"
            result.append(DailyTask(
                id: "course",
                title: "继续学习 · \(entry.course.title)",
                detail: detail,
                systemImage: "play.tv.fill",
                tint: DBSubjectColor.color(for: entry.course.subject),
                badge: nil,
                action: {
                    HapticEngine.play(.selection)
                    router.navigate(.course(entry.course.id), regular: isRegular)
                }))
        }

        return result
    }

    // MARK: - 学习时长 mini-chart

    private struct DayBucket: Identifiable {
        let id: Date
        let date: Date
        let minutes: Double
        let isToday: Bool
    }

    /// The last 7 calendar days (oldest → newest), each summed from ActivityLog so
    /// the chart always shows a full week even with sparse activity.
    private var weekBuckets: [DayBucket] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Pre-bucket logs by day for an O(n) pass.
        var byDay: [Date: Double] = [:]
        for log in logs {
            let day = cal.startOfDay(for: log.date)
            byDay[day, default: 0] += log.minutes
        }
        return (0..<7).reversed().compactMap { offset -> DayBucket? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayBucket(
                id: day,
                date: day,
                minutes: byDay[day] ?? 0,
                isToday: offset == 0)
        }
    }

    private var weekTotalMinutes: Double {
        weekBuckets.reduce(0) { $0 + $1.minutes }
    }

    private var hasAnyWeeklyActivity: Bool { weekTotalMinutes > 0 }

    // MARK: - Overall state

    /// True before the learner has *any* seeded mastery / mistakes / decks / courses
    /// to plan around — the cold-start empty state.
    private var hasNoContent: Bool {
        masteries.isEmpty && mistakes.isEmpty && decks.isEmpty && courses.isEmpty
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.xl) {
                header

                if hasNoContent {
                    emptyState
                } else {
                    let todays = tasks
                    if todays.isEmpty {
                        allCaughtUp
                    } else {
                        taskSection(todays)
                    }
                    studyTimeSection
                    footerNudge
                }
            }
            .padding(.horizontal, DBSpacing.screenInset)
            .padding(.top, DBSpacing.sm)
            .padding(.bottom, DBSpacing.xxxl)
            .frame(maxWidth: isRegular ? 720 : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dbBackground)
        .scrollIndicators(.hidden)
        .navigationTitle("今日")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Header (greeting + daily-goal ring + mascot)

    private var header: some View {
        DBCard(elevation: .medium) {
            HStack(alignment: .center, spacing: DBSpacing.lg) {
                VStack(alignment: .leading, spacing: DBSpacing.sm) {
                    Text("\(greetingPrefix)，\(learnerName)")
                        .font(.dbTitle2)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text(headerSubtitle)
                        .font(.dbCallout)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: DBSpacing.sm) {
                        DBStreakView(days: profile?.streakDays ?? 0)
                        if goalReached {
                            DBTag("今日已达标", tint: .dbSuccess)
                        }
                    }
                    .padding(.top, DBSpacing.xxs)
                }

                Spacer(minLength: 0)

                goalRing
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerAccessibilityLabel)
    }

    private var goalRing: some View {
        ZStack {
            DBProgressRing(
                progress: goalProgress,
                lineWidth: 9,
                tint: goalReached ? .dbSuccess : .dbPrimary)
            .frame(width: 92, height: 92)

            VStack(spacing: 0) {
                Text("\(Int(minutesToday.rounded()))")
                    .font(.dbScore)
                    .foregroundStyle(Color.dbTextPrimary)
                    .monospacedDigit()
                Text("/ \(Int(dailyGoalMinutes)) 分钟")
                    .font(.dbCaption2)
                    .foregroundStyle(Color.dbTextSecondary)
            }
        }
        .accessibilityHidden(true)
    }

    private var headerAccessibilityLabel: String {
        let streak = profile?.streakDays ?? 0
        let goal = goalReached
            ? "今日学习目标已完成"
            : "今日已学习 \(Int(minutesToday.rounded())) 分钟，目标 \(Int(dailyGoalMinutes)) 分钟"
        return "\(greetingPrefix)，\(learnerName)。已连续打卡 \(streak) 天。\(goal)。"
    }

    // MARK: - 今日任务

    private func taskSection(_ todays: [DailyTask]) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            DBSectionHeader(
                "今日计划",
                subtitle: "为你精选 \(todays.count) 件小事，逐个完成更轻松",
                systemImage: "checklist")

            VStack(spacing: DBSpacing.cardGap) {
                ForEach(todays) { task in
                    taskCard(task)
                }
            }
        }
    }

    private func taskCard(_ task: DailyTask) -> some View {
        Button(action: task.action) {
            DBCard {
                HStack(spacing: DBSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                            .fill(task.tint.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: task.systemImage)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(task.tint)
                    }

                    VStack(alignment: .leading, spacing: DBSpacing.xxs) {
                        Text(task.title)
                            .font(.dbBodyEmph)
                            .foregroundStyle(Color.dbTextPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(task.detail)
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    if let badge = task.badge, badge > 0 {
                        DBBadge(count: badge, tint: task.tint)
                    }
                    Image(systemName: "chevron.right")
                        .font(.dbFootnote.weight(.semibold))
                        .foregroundStyle(Color.dbTextTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title)。\(task.detail)")
        .accessibilityHint("轻点开始")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - All caught up (celebration)

    private var allCaughtUp: some View {
        DBCard(elevation: .medium) {
            VStack(spacing: DBSpacing.md) {
                DBMascot(mood: .cheering, size: 88)
                Text("今日任务全部完成！")
                    .font(.dbTitle3)
                    .foregroundStyle(Color.dbTextPrimary)
                Text("没有待复习的错题与单词，薄弱点也都在掌握中。给坚持的自己点个赞，明天继续加油～")
                    .font(.dbCallout)
                    .foregroundStyle(Color.dbTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    HapticEngine.play(.light)
                    router.present(.capture(.solve))
                } label: {
                    Label("再拍一道题挑战自己", systemImage: "camera.viewfinder")
                }
                .buttonStyle(.db(.primary, fullWidth: true))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DBSpacing.sm)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今日任务全部完成。可以再拍一道题挑战自己。")
    }

    // MARK: - Empty (cold start)

    private var emptyState: some View {
        DBStateView(
            kind: .empty,
            title: "今日计划还在准备中",
            message: "先去拍一道题、听写一组词，或上一节豆包课堂，今日就会为你生成专属学习计划啦～",
            systemImage: "sparkles") {
                router.present(.capture(.solve))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 280)
    }

    // MARK: - 学习时长 mini-chart

    private var studyTimeSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            DBSectionHeader(
                "学习时长",
                subtitle: "近 7 天共 \(Int(weekTotalMinutes.rounded())) 分钟 · 今日 \(Int(minutesToday.rounded())) 分钟",
                systemImage: "clock.badge.checkmark.fill")

            DBCard {
                if hasAnyWeeklyActivity {
                    weekChart
                } else {
                    weekChartEmpty
                }
            }
        }
    }

    private var weekChart: some View {
        Chart(weekBuckets) { bucket in
            BarMark(
                x: .value("日期", bucket.date, unit: .day),
                y: .value("分钟", bucket.minutes),
                width: .ratio(0.55))
            .foregroundStyle(bucket.isToday ? Color.dbPrimary : Color.dbPrimarySoft)
            .cornerRadius(DBRadius.xs)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(weekdayLabel(for: date))
                            .font(.dbCaption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text("\(Int(minutes))")
                            .font(.dbCaption2)
                    }
                }
            }
        }
        .frame(height: 170)
        .accessibilityLabel("近 7 天学习时长图表")
        .accessibilityValue("近 7 天共 \(Int(weekTotalMinutes.rounded())) 分钟，今日 \(Int(minutesToday.rounded())) 分钟")
    }

    private var weekChartEmpty: some View {
        HStack {
            Spacer()
            VStack(spacing: DBSpacing.sm) {
                Image(systemName: "chart.bar")
                    .font(.dbTitle2)
                    .foregroundStyle(Color.dbTextTertiary)
                Text("近 7 天还没有学习记录，今天就从一道题开始吧")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextTertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(minHeight: 140)
    }

    // MARK: - Footer nudge

    private var footerNudge: some View {
        HStack(spacing: DBSpacing.md) {
            DBMascot(mood: .happy, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text("一步一个脚印")
                    .font(.dbBodyEmph)
                    .foregroundStyle(Color.dbTextPrimary)
                Text(footerMessage)
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DBSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.dbPrimarySoft,
            in: RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Copy helpers

    private var greetingPrefix: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "早上好"
        case 11..<14: return "中午好"
        case 14..<18: return "下午好"
        case 18..<23: return "晚上好"
        default: return "夜深了"
        }
    }

    private var headerSubtitle: String {
        if hasNoContent {
            return "新的一天，先拍一道题热热身吧～"
        }
        if goalReached {
            return "今日目标已完成，超棒的坚持！"
        }
        let remaining = max(0, Int((dailyGoalMinutes - minutesToday).rounded()))
        if minutesToday > 0 {
            return "再学 \(remaining) 分钟就能完成今日目标啦～"
        }
        return "今日的学习计划已经备好，一起开始吧！"
    }

    private var footerMessage: String {
        let streak = profile?.streakDays ?? 0
        if goalReached {
            return "今天的目标已达成，豆包为你骄傲 🎉"
        }
        if streak >= 7 {
            return "已连续打卡 \(streak) 天，别让连胜断在今天哦～"
        }
        return "完成今日计划，记得回来打卡，豆包陪你一起加油 💪"
    }

    private func durationLabel(_ seconds: Int) -> String {
        let minutes = max(1, Int((Double(seconds) / 60.0).rounded()))
        return "\(minutes) 分钟"
    }

    private func weekdayLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("今日") {
    NavigationStack {
        TodayView()
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}
