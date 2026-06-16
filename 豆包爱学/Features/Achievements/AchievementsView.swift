//
//  AchievementsView.swift
//  豆包爱学 — Features/Achievements
//
//  成就 — a Duolingo-class motivation screen. It DERIVES everything from the
//  learner's existing seeded SwiftData history (no new @Model):
//    · XP total + level + progress-to-next-level ring (AchievementEngine)
//    · 连续打卡 calendar heat-strip built from ActivityLog dates
//    · a grid of badge tiles (locked / unlocked) whose unlock dates persist in
//      @AppStorage so a freshly-earned badge keeps its 解锁日期 forever
//    · a celebratory pop on the just-unlocked badge (respects Reduce Motion)
//
//  Contract: `struct AchievementsView: View` with a no-arg `init()`. The shell
//  owns the NavigationStack; this view only sets a title and returns content.
//  Wired by the integrator via AppSection / a new ToolKind → AchievementsView().
//

import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Live, seeded history — the only source of truth for all derived stats.
    @Query private var profiles: [LearnerProfile]
    @Query private var masteries: [MasteryRecord]
    @Query private var mistakes: [MistakeItem]
    @Query private var words: [WordCard]
    @Query private var problems: [ProblemRecord]
    @Query(sort: \ActivityLog.date, order: .forward) private var logs: [ActivityLog]
    @Query private var streaks: [StudyStreak]

    /// Persisted unlock dates, JSON-encoded [badgeID: epochSeconds]. Survives
    /// relaunch so a badge earned today still shows its 解锁日期 next week.
    @AppStorage("achievementUnlockDates") private var unlockDatesData = Data()

    /// Remembers which badge to celebrate so the pop fires once per new unlock.
    @State private var celebratedBadgeID: String?
    @State private var pulse = false

    init() {}

    private var isRegular: Bool { sizeClass != .compact }

    // MARK: - Derived data

    private var profile: LearnerProfile? { profiles.first }

    private var learnerName: String { profile?.nickname ?? "小学员" }

    /// Best available streak: prefer a dedicated StudyStreak, fall back to the
    /// profile counter so the screen is meaningful even before streaks seed.
    private var streakDays: Int {
        let fromStreak = streaks.map(\.current).max() ?? 0
        return max(fromStreak, profile?.streakDays ?? 0)
    }

    private var metrics: AchievementMetrics {
        AchievementMetrics(
            streakDays: streakDays,
            problemsSolved: max(profile?.problemsSolved ?? 0, problems.count),
            mistakesMastered: mistakes.filter { $0.mastery == .mastered }.count,
            knowledgeMastered: masteries.filter { $0.state == .mastered }.count,
            wordsLearned: words.filter { $0.mastery == .mastered }.count)
    }

    /// Activity-only level, used to evaluate `.level` milestone badges before
    /// badge XP is folded in (prevents a circular dependency).
    private var provisionalLevel: Int {
        AchievementEngine.provisionalLevel(metrics: metrics)
    }

    /// Stored unlock dates keyed by badge id.
    private var storedUnlockDates: [String: Date] {
        guard let map = try? JSONDecoder().decode([String: Double].self, from: unlockDatesData) else {
            return [:]
        }
        return map.mapValues { Date(timeIntervalSince1970: $0) }
    }

    /// Every badge resolved against the live metrics + persisted unlock dates.
    private var badges: [AchievementBadge] {
        let m = metrics
        let level = provisionalLevel
        let stored = storedUnlockDates
        return AchievementEngine.catalog.map { def in
            let value = m.value(for: def.metric, level: level)
            let unlocked = value >= def.threshold
            return AchievementBadge(
                def: def,
                currentValue: value,
                isUnlocked: unlocked,
                unlockedDate: unlocked ? (stored[def.id] ?? Date()) : nil)
        }
    }

    private var unlockedBadges: [AchievementBadge] { badges.filter(\.isUnlocked) }
    private var lockedBadges: [AchievementBadge] { badges.filter { !$0.isUnlocked } }

    /// Total XP folds activity XP together with the XP of unlocked badges.
    private var totalXP: Int {
        let badgeXP = unlockedBadges.reduce(0) { $0 + $1.def.xp }
        return AchievementEngine.totalXP(metrics: metrics, unlockedBadgeXP: badgeXP)
    }

    private var level: LevelProgress {
        AchievementEngine.levelProgress(totalXP: totalXP)
    }

    /// True when the learner has literally no derivable progress yet.
    private var hasNoProgress: Bool {
        metrics.problemsSolved == 0
            && metrics.streakDays == 0
            && metrics.mistakesMastered == 0
            && metrics.knowledgeMastered == 0
            && metrics.wordsLearned == 0
            && unlockedBadges.isEmpty
    }

    private var badgeColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: DBSpacing.md),
              count: isRegular ? 4 : 3)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.xl) {
                if hasNoProgress {
                    emptyState
                } else {
                    levelHeroCard
                    statStrip
                    streakSection
                    badgeSection
                    footerNudge
                }
            }
            .padding(.horizontal, DBSpacing.screenInset)
            .padding(.top, DBSpacing.sm)
            .padding(.bottom, DBSpacing.xxxl)
        }
        .background(Color.dbBackground)
        .scrollIndicators(.hidden)
        .navigationTitle("成就")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            HapticEngine.play(.light)
            persistNewUnlocks()
            celebrateLatestIfNeeded()
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: DBSpacing.lg) {
            DBMascot(mood: .cheering, size: 96)
            DBStateView(
                kind: .empty,
                title: "成就墙等你点亮",
                message: "去拍一道题、攻克一个错题、连续打卡几天，第一枚徽章很快就会亮起来啦～",
                systemImage: "trophy.fill")
            Button {
                HapticEngine.play(.light)
                router.present(.capture(.solve))
            } label: {
                Label("拍照解题，赚取第一份 XP", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.db(.primary, fullWidth: true))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DBSpacing.xxl)
    }

    // MARK: - Level hero (XP ring)

    private var levelHeroCard: some View {
        DBCard(elevation: .medium) {
            HStack(spacing: DBSpacing.lg) {
                ZStack {
                    DBProgressRing(
                        progress: level.fraction,
                        lineWidth: 11,
                        tint: .dbPrimary)
                    .frame(width: 96, height: 96)
                    VStack(spacing: 0) {
                        Text("Lv.\(level.level)")
                            .font(.dbTitle2)
                            .foregroundStyle(Color.dbTextPrimary)
                        Text("\(Int((level.fraction * 100).rounded()))%")
                            .font(.dbCaption2)
                            .foregroundStyle(Color.dbTextSecondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("当前等级 \(level.level) 级，距离下一级还差 \(level.xpToNext) 经验")

                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text("\(learnerName)的成就")
                        .font(.dbHeadline)
                        .foregroundStyle(Color.dbTextPrimary)
                    HStack(spacing: DBSpacing.xs) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.dbSecondary)
                        Text("\(totalXP) XP")
                            .font(.dbBodyEmph)
                            .foregroundStyle(Color.dbTextPrimary)
                            .contentTransition(.numericText())
                    }
                    Text(level.xpToNext > 0
                         ? "再得 \(level.xpToNext) XP 就能升到 \(level.level + 1) 级！"
                         : "已达本阶段顶级，继续保持哦！")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Stat strip

    private var statStrip: some View {
        HStack(spacing: DBSpacing.sm) {
            DBValueStat(
                value: "\(unlockedBadges.count)/\(badges.count)",
                caption: "已获徽章",
                systemImage: "medal.fill",
                tint: .dbSecondary)
            statDivider
            DBValueStat(
                value: "\(streakDays)",
                caption: "连续天数",
                systemImage: "flame.fill",
                tint: .dbWarning)
            statDivider
            DBValueStat(
                value: "\(metrics.knowledgeMastered)",
                caption: "掌握知识点",
                systemImage: "brain.head.profile",
                tint: .dbSuccess)
        }
        .padding(.vertical, DBSpacing.md)
        .padding(.horizontal, DBSpacing.sm)
        .dbSurfaceStyle(cornerRadius: DBRadius.lg)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.dbSeparator)
            .frame(width: 1, height: 28)
    }

    // MARK: - 连续打卡 heat-strip

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            DBSectionHeader(
                "连续打卡",
                subtitle: streakDays > 0 ? "已连续 \(streakDays) 天，别中断哦～" : "今天打卡，点亮第一格",
                systemImage: "calendar")

            DBCard {
                VStack(alignment: .leading, spacing: DBSpacing.md) {
                    HStack(spacing: 6) {
                        ForEach(heatStrip) { day in
                            heatCell(day)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: DBSpacing.md) {
                        legendDot(Color.dbPrimarySoft, "较少")
                        legendDot(Color.dbPrimary.opacity(0.65), "适中")
                        legendDot(Color.dbPrimary, "充分")
                        Spacer(minLength: 0)
                        Text("近 14 天")
                            .font(.dbCaption2)
                            .foregroundStyle(Color.dbTextTertiary)
                    }
                }
            }
        }
    }

    private func heatCell(_ day: HeatDay) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: DBRadius.xs, style: .continuous)
                .fill(day.fill)
                .frame(height: 30)
                .overlay {
                    if day.isToday {
                        RoundedRectangle(cornerRadius: DBRadius.xs, style: .continuous)
                            .strokeBorder(Color.dbPrimaryDeep, lineWidth: 2)
                    }
                }
            Text(day.weekdayLabel)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Color.dbTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.accessibilityLabel)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.dbCaption2)
                .foregroundStyle(Color.dbTextTertiary)
        }
    }

    /// Daily study minutes over the last 14 days, derived from ActivityLog.
    private var heatStrip: [HeatDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Bucket logged minutes by start-of-day.
        var minutesByDay: [Date: Double] = [:]
        for log in logs {
            let day = calendar.startOfDay(for: log.date)
            minutesByDay[day, default: 0] += log.minutes
        }

        return (0..<14).reversed().compactMap { offset -> HeatDay? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let minutes = minutesByDay[day] ?? 0
            return HeatDay(
                date: day,
                minutes: minutes,
                isToday: offset == 0,
                weekdayLabel: Self.weekdayLabel(for: day, calendar: calendar))
        }
    }

    private static func weekdayLabel(for date: Date, calendar: Calendar) -> String {
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        let index = calendar.component(.weekday, from: date) - 1
        return symbols[(index % 7 + 7) % 7]
    }

    // MARK: - Badge grid

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            DBSectionHeader(
                "徽章墙",
                subtitle: "已点亮 \(unlockedBadges.count) 枚 · 还有 \(lockedBadges.count) 枚待解锁",
                systemImage: "trophy.fill")

            LazyVGrid(columns: badgeColumns, spacing: DBSpacing.md) {
                ForEach(badges) { badge in
                    badgeTile(badge)
                }
            }
        }
    }

    private func badgeTile(_ badge: AchievementBadge) -> some View {
        let tint = tierColor(badge.def.tier)
        let isCelebrating = badge.isUnlocked && badge.id == celebratedBadgeID
        return VStack(spacing: DBSpacing.xs) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? tint.opacity(0.16) : Color.dbSurfaceRaised)
                    .frame(width: 60, height: 60)

                if badge.isUnlocked {
                    Image(systemName: badge.def.systemImage)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(tint)
                } else {
                    // Locked: faint glyph + progress ring so it still feels reachable.
                    DBProgressRing(
                        progress: badge.progress,
                        lineWidth: 4,
                        tint: Color.dbTextTertiary)
                    .frame(width: 60, height: 60)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.dbTextTertiary)
                }
            }
            .scaleEffect(isCelebrating && pulse ? 1.18 : 1)

            Text(badge.def.title)
                .font(.dbCaption.weight(.medium))
                .foregroundStyle(badge.isUnlocked ? Color.dbTextPrimary : Color.dbTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(minHeight: 30, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DBSpacing.sm)
        .dbSurfaceStyle(cornerRadius: DBRadius.md)
        .overlay(alignment: .topTrailing) {
            if badge.isUnlocked {
                DBTag(badge.def.tier.displayName, tint: tint)
                    .padding(DBSpacing.xs)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: badge))
        .accessibilityHint("查看徽章详情")
        .contentShape(Rectangle())
        .onTapGesture {
            HapticEngine.play(.selection)
            selectedBadge = badge
        }
    }

    @State private var selectedBadge: AchievementBadge?

    // MARK: - Footer

    private var footerNudge: some View {
        HStack(spacing: DBSpacing.md) {
            DBMascot(mood: unlockedBadges.count > badges.count / 2 ? .cheering : .happy, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(nextGoalHeadline)
                    .font(.dbBodyEmph)
                    .foregroundStyle(Color.dbTextPrimary)
                Text("每一次练习都在为下一枚徽章蓄力 💪")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DBSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dbPrimarySoft,
                    in: RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
        .sheet(item: $selectedBadge) { badge in
            badgeDetailSheet(badge)
        }
    }

    /// The closest locked badge (highest progress) becomes the headline goal.
    private var nextGoalHeadline: String {
        guard let next = lockedBadges.max(by: { $0.progress < $1.progress }) else {
            return "全部徽章已点亮，太厉害啦！"
        }
        if next.def.metric == .level {
            return "升到 \(next.def.threshold) 级，解锁「\(next.def.title)」"
        }
        return "再 \(next.remaining) 个，解锁「\(next.def.title)」"
    }

    // MARK: - Badge detail sheet

    private func badgeDetailSheet(_ badge: AchievementBadge) -> some View {
        let tint = tierColor(badge.def.tier)
        return NavigationStack {
            ScrollView {
                VStack(spacing: DBSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(badge.isUnlocked ? tint.opacity(0.18) : Color.dbSurfaceRaised)
                            .frame(width: 120, height: 120)
                        Image(systemName: badge.isUnlocked ? badge.def.systemImage : "lock.fill")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(badge.isUnlocked ? tint : Color.dbTextTertiary)
                    }
                    .padding(.top, DBSpacing.lg)

                    VStack(spacing: DBSpacing.xs) {
                        Text(badge.def.title)
                            .font(.dbTitle2)
                            .foregroundStyle(Color.dbTextPrimary)
                        DBTag(badge.def.tier.displayName, tint: tint)
                    }

                    Text(badge.isUnlocked ? badge.def.blurb : badge.def.lockedHint)
                        .font(.dbCallout)
                        .foregroundStyle(Color.dbTextSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DBSpacing.lg)

                    DBCard {
                        VStack(spacing: DBSpacing.md) {
                            HStack {
                                Label("奖励经验", systemImage: "sparkles")
                                    .font(.dbCallout)
                                    .foregroundStyle(Color.dbTextSecondary)
                                Spacer()
                                Text("+\(badge.def.xp) XP")
                                    .font(.dbBodyEmph)
                                    .foregroundStyle(Color.dbSecondary)
                            }
                            if !badge.isUnlocked {
                                Divider()
                                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                                    HStack {
                                        Text("进度")
                                            .font(.dbCallout)
                                            .foregroundStyle(Color.dbTextSecondary)
                                        Spacer()
                                        Text("\(badge.currentValue) / \(badge.def.threshold)")
                                            .font(.dbBodyEmph)
                                            .foregroundStyle(Color.dbTextPrimary)
                                    }
                                    ProgressView(value: badge.progress)
                                        .tint(tint)
                                }
                            } else if let date = badge.unlockedDate {
                                Divider()
                                HStack {
                                    Label("解锁日期", systemImage: "calendar.badge.checkmark")
                                        .font(.dbCallout)
                                        .foregroundStyle(Color.dbTextSecondary)
                                    Spacer()
                                    Text(date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.dbBodyEmph)
                                        .foregroundStyle(Color.dbTextPrimary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DBSpacing.screenInset)

                    Spacer(minLength: DBSpacing.xl)
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color.dbBackground)
            .navigationTitle("徽章详情")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { selectedBadge = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Tier color (MainActor — touches Color.db*)

    private func tierColor(_ tier: AchievementTier) -> Color {
        switch tier {
        case .bronze: Color(hex: 0xC08552)
        case .silver: Color(hex: 0x9AA3AE)
        case .gold: .dbWarning
        case .platinum: .dbPrimary
        }
    }

    // MARK: - Accessibility copy

    private func accessibilityLabel(for badge: AchievementBadge) -> String {
        if badge.isUnlocked {
            return "\(badge.def.title)，\(badge.def.tier.displayName)徽章，已点亮"
        }
        return "\(badge.def.title)，未解锁，进度 \(badge.currentValue) / \(badge.def.threshold)"
    }

    // MARK: - Persistence + celebration

    /// Stamp any newly-unlocked badge with today's date the first time we see it
    /// unlocked, so its 解锁日期 stays stable across launches.
    private func persistNewUnlocks() {
        var stored = storedUnlockDates
        var changed = false
        let now = Date()
        for badge in unlockedBadges where stored[badge.id] == nil {
            stored[badge.id] = now
            changed = true
        }
        guard changed else { return }
        let map = stored.mapValues(\.timeIntervalSince1970)
        if let data = try? JSONEncoder().encode(map) {
            unlockDatesData = data
        }
    }

    /// Find the most-recently unlocked badge and pop it once. Reduce Motion
    /// users still get the haptic + a static highlight, just no scale animation.
    private func celebrateLatestIfNeeded() {
        let stored = storedUnlockDates
        let latest = unlockedBadges
            .filter { stored[$0.id] != nil }
            .max { (stored[$0.id] ?? .distantPast) < (stored[$1.id] ?? .distantPast) }
        guard let latest, latest.id != celebratedBadgeID else { return }
        celebratedBadgeID = latest.id
        HapticEngine.play(.success)
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) {
            pulse = true
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.55)) {
            pulse = false
        }
    }
}

// MARK: - Heat-strip day

private struct HeatDay: Identifiable {
    let date: Date
    let minutes: Double
    let isToday: Bool
    let weekdayLabel: String

    var id: Date { date }

    /// Intensity bucket → fill color. Empty days read as a faint surface.
    @MainActor var fill: Color {
        switch minutes {
        case ..<0.5: Color.dbSurfaceRaised
        case ..<10: Color.dbPrimarySoft
        case ..<25: Color.dbPrimary.opacity(0.65)
        default: Color.dbPrimary
        }
    }

    var accessibilityLabel: String {
        let day = date.formatted(date: .abbreviated, time: .omitted)
        if minutes < 0.5 {
            return "\(day)，未学习"
        }
        return "\(day)，学习约 \(Int(minutes.rounded())) 分钟"
    }
}

// MARK: - Preview

#Preview("Achievements") {
    NavigationStack {
        AchievementsView()
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}
