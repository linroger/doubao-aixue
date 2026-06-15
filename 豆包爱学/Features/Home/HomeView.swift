//
//  HomeView.swift
//  豆包爱学 — Features/Home
//
//  The default tab (首页). A warm, scrollable launchpad that puts the camera
//  hero front-and-center and surfaces personalized, seeded content:
//    • greeting header (avatar · 打卡 streak · quick stats)
//    • HERO 拍照解题 entry (+ 批改 shortcut)
//    • 今日靶向练习 card driven by the learner's weakest 知识点
//    • 继续学习 row of recent 豆包课堂 courses
//    • 常用工具 quick-entry grid (deep-links into 工具 flows)
//    • 推荐课程 精品课程 carousel
//
//  Everything is driven by @Query over the seeded SwiftData store, adapts to
//  regular width (iPad/Mac), and supports full Dark Mode via semantic colors.
//
//  Contract: `struct HomeView: View` with a no-arg `init()`. The integrator
//  maps AppTab.home / AppSection.home → HomeView().
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass

    // Seeded personalization & content.
    @Query private var profiles: [LearnerProfile]
    @Query private var masteries: [MasteryRecord]
    @Query private var knowledgePoints: [KnowledgePointEntity]
    @Query private var courses: [CourseEntity]

    init() {}

    // MARK: Derived data

    private var isRegular: Bool { sizeClass != .compact }

    private var profile: LearnerProfile? { profiles.first }

    /// The single weakest knowledge point (lowest mastery score) — the focus of
    /// 今日靶向练习. Falls back gracefully when no mastery is seeded.
    private var weakestMastery: MasteryRecord? {
        masteries
            .filter { $0.state != .mastered }
            .min { $0.score < $1.score }
            ?? masteries.min { $0.score < $1.score }
    }

    private func knowledgePointName(for id: String) -> String? {
        knowledgePoints.first { $0.id == id }?.name
    }

    /// 精品课程 (PGC, review-verified, ready) sorted newest-first for the carousel.
    private var recommendedCourses: [CourseEntity] {
        courses
            .filter { !$0.isUGC && $0.reviewVerified }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Recent courses for the 继续学习 row (all ready courses, newest first).
    private var recentCourses: [CourseEntity] {
        courses.sorted { $0.createdAt > $1.createdAt }
    }

    /// Quick-entry tools surfaced on Home (deep-link into 工具 flows).
    private let quickTools: [ToolKind] = [
        .solve, .gradeEssay, .mistakeNotebook, .dictation,
        .vocabulary, .classroom, .knowledgeQA, .classical,
    ]

    private var toolColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: DBSpacing.md),
              count: isRegular ? 6 : 4)
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.xl) {
                greetingHeader
                heroSection
                if weakestMastery != nil { targetedPracticeSection }
                if !recentCourses.isEmpty { continueLearningSection }
                quickToolsSection
                if !recommendedCourses.isEmpty { recommendedSection }
                footerNudge
            }
            .padding(.horizontal, DBSpacing.screenInset)
            .padding(.top, DBSpacing.sm)
            .padding(.bottom, DBSpacing.xxxl)
        }
        .background(Color.dbBackground)
        .scrollIndicators(.hidden)
        .navigationTitle("首页")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.present(.search)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("搜索")
            }
        }
    }

    // MARK: - Greeting header

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            HStack(spacing: DBSpacing.md) {
                DBAvatar(
                    name: profile?.nickname ?? "同学",
                    size: 54,
                    gradeBadge: profile?.grade.displayName
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(greetingPrefix)，\(profile?.nickname ?? "同学")")
                        .font(.dbTitle2)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text(encouragement)
                        .font(.dbCallout)
                        .foregroundStyle(Color.dbTextSecondary)
                }
                Spacer(minLength: DBSpacing.sm)
                DBStreakView(days: profile?.streakDays ?? 0)
            }

            statStrip
        }
    }

    private var statStrip: some View {
        HStack(spacing: DBSpacing.sm) {
            DBValueStat(
                value: "\(profile?.problemsSolved ?? 0)",
                caption: "已解题",
                systemImage: "checkmark.seal.fill"
            )
            statDivider
            DBValueStat(
                value: "\(masteredCount)",
                caption: "已掌握",
                systemImage: "star.fill",
                tint: .dbSecondary
            )
            statDivider
            DBValueStat(
                value: "\(weakCount)",
                caption: "待加强",
                systemImage: "bolt.fill",
                tint: .dbWarning
            )
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

    private var masteredCount: Int {
        masteries.filter { $0.state == .mastered }.count
    }

    private var weakCount: Int {
        masteries.filter { $0.state == .new || $0.state == .weak }.count
    }

    // MARK: - Hero capture entry

    private var heroSection: some View {
        VStack(spacing: DBSpacing.md) {
            Button {
                HapticEngine.play(.light)
                router.present(.capture(.solve))
            } label: {
                HStack(spacing: DBSpacing.md) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("拍照解题")
                            .font(.dbTitle3)
                            .foregroundStyle(.white)
                        Text("一拍即得 · 思路 · 步骤 · 讲解")
                            .font(.dbFootnote)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.dbBody.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(DBSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.dbHeroGradient,
                    in: RoundedRectangle(cornerRadius: DBRadius.xl, style: .continuous)
                )
                .dbShadow(.medium)
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开相机拍下题目，获取详细解析")

            HStack(spacing: DBSpacing.md) {
                heroSecondary(
                    title: "作业批改",
                    subtitle: "口算 · ✓✗ 批改",
                    systemImage: "checkmark.rectangle.stack.fill",
                    tint: .dbSecondary
                ) {
                    HapticEngine.play(.light)
                    router.present(.capture(.grade))
                }
                heroSecondary(
                    title: "问豆包",
                    subtitle: "随时答疑解惑",
                    systemImage: "bubble.left.and.bubble.right.fill",
                    tint: .dbAccent
                ) {
                    HapticEngine.play(.light)
                    router.openTool(.knowledgeQA, regular: isRegular)
                }
            }
        }
    }

    private func heroSecondary(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DBSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.dbBodyEmph)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text(subtitle)
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(DBSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dbSurfaceStyle(cornerRadius: DBRadius.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 今日靶向练习

    @ViewBuilder
    private var targetedPracticeSection: some View {
        if let weak = weakestMastery {
            let name = knowledgePointName(for: weak.knowledgePointID) ?? weak.subject.displayName
            let tint = DBSubjectColor.color(for: weak.subject)

            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader(
                    "今日靶向练习",
                    subtitle: "针对薄弱点，5–10 分钟巩固",
                    systemImage: "target"
                )

                Button {
                    HapticEngine.play(.selection)
                    router.navigate(.knowledgePoint(weak.knowledgePointID), regular: isRegular)
                } label: {
                    DBCard {
                        HStack(spacing: DBSpacing.lg) {
                            DBProgressRing(
                                progress: weak.score,
                                lineWidth: 9,
                                tint: tint
                            )
                            .frame(width: 70, height: 70)

                            VStack(alignment: .leading, spacing: DBSpacing.xs) {
                                HStack(spacing: DBSpacing.sm) {
                                    DBSubjectChip(weak.subject)
                                    DBTag(weak.state.displayName,
                                          tint: weak.state == .mastered ? .dbSuccess : .dbWarning)
                                }
                                Text(name)
                                    .font(.dbHeadline)
                                    .foregroundStyle(Color.dbTextPrimary)
                                    .lineLimit(2)
                                Text("掌握度 \(Int(weak.score * 100))% · 攻克它，离满分更近一步")
                                    .font(.dbFootnote)
                                    .foregroundStyle(Color.dbTextSecondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.dbFootnote.weight(.semibold))
                                .foregroundStyle(Color.dbTextTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Button {
                    HapticEngine.play(.light)
                    router.openDrill(knowledgePointID: weak.knowledgePointID, regular: isRegular)
                } label: {
                    Label("开始举一反三练习", systemImage: "square.grid.3x3.fill")
                }
                .buttonStyle(.db(.secondary, fullWidth: true))
            }
        }
    }

    // MARK: - 继续学习 (recent courses row)

    private var continueLearningSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            DBSectionHeader("继续学习", systemImage: "play.circle.fill") {
                Button("更多") {
                    router.openTool(.classroom, regular: isRegular)
                }
                .font(.dbFootnote.weight(.medium))
                .buttonStyle(.plain)
                .foregroundStyle(Color.dbPrimary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DBSpacing.md) {
                    ForEach(Array(recentCourses.prefix(6))) { course in
                        Button {
                            HapticEngine.play(.selection)
                            router.navigate(.course(course.id), regular: isRegular)
                        } label: {
                            courseCard(course, width: 220)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - 常用工具 grid

    private var quickToolsSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            DBSectionHeader("常用工具", systemImage: "square.grid.2x2.fill") {
                Button("全部") {
                    router.selectedTab = .tools
                    router.sidebarSelection = .tools
                }
                .font(.dbFootnote.weight(.medium))
                .buttonStyle(.plain)
                .foregroundStyle(Color.dbPrimary)
            }

            LazyVGrid(columns: toolColumns, spacing: DBSpacing.md) {
                ForEach(quickTools) { tool in
                    DBToolTile(
                        title: tool.displayName,
                        systemImage: tool.symbolName,
                        tint: toolTint(for: tool),
                        compact: true
                    ) {
                        HapticEngine.play(.selection)
                        router.openTool(tool, regular: isRegular)
                    }
                }
            }
            .padding(DBSpacing.sm)
            .dbSurfaceStyle(cornerRadius: DBRadius.lg)
        }
    }

    /// Warm, distinct color per tool category so the grid reads playfully.
    private func toolTint(for tool: ToolKind) -> Color {
        switch tool.category {
        case .qa: .dbPrimary
        case .grade: .dbSecondary
        case .memory: .dbAccent
        case .expression: .dbInfo
        case .extend: .dbSuccess
        }
    }

    // MARK: - 推荐课程 carousel

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            DBSectionHeader(
                "豆包课堂 · 精品推荐",
                subtitle: "沉浸式 AI 视频课，边看边学",
                systemImage: "sparkles.tv.fill"
            ) {
                Button("更多") {
                    router.openTool(.classroom, regular: isRegular)
                }
                .font(.dbFootnote.weight(.medium))
                .buttonStyle(.plain)
                .foregroundStyle(Color.dbPrimary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DBSpacing.md) {
                    ForEach(Array(recommendedCourses.prefix(8))) { course in
                        Button {
                            HapticEngine.play(.selection)
                            router.navigate(.course(course.id), regular: isRegular)
                        } label: {
                            recommendedCard(course)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Course cards

    private func courseCard(_ course: CourseEntity, width: CGFloat) -> some View {
        let tint = DBSubjectColor.color(for: course.subject)
        return VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [tint.opacity(0.85), tint.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: course.thumbnailSymbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                VStack {
                    HStack {
                        Spacer()
                        Text(durationLabel(course.durationSec))
                            .font(.dbCaption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, DBSpacing.sm)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.28), in: Capsule())
                    }
                    Spacer()
                }
                .padding(DBSpacing.sm)
            }
            .frame(height: 96)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: DBRadius.lg,
                topTrailingRadius: DBRadius.lg,
                style: .continuous
            ))

            VStack(alignment: .leading, spacing: DBSpacing.xs) {
                Text(course.title)
                    .font(.dbBodyEmph)
                    .foregroundStyle(Color.dbTextPrimary)
                    .lineLimit(1)
                Text(course.summary.isEmpty ? course.subject.displayName : course.summary)
                    .font(.dbCaption)
                    .foregroundStyle(Color.dbTextSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DBSpacing.md)
        }
        .frame(width: width)
        .dbSurfaceStyle(cornerRadius: DBRadius.lg)
    }

    private func recommendedCard(_ course: CourseEntity) -> some View {
        let tint = DBSubjectColor.color(for: course.subject)
        return VStack(alignment: .leading, spacing: DBSpacing.sm) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [tint.opacity(0.9), tint.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Image(systemName: course.thumbnailSymbol)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(spacing: DBSpacing.xs) {
                    Image(systemName: course.subject.symbolName)
                    Text(course.subject.displayName)
                }
                .font(.dbCaption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, DBSpacing.sm)
                .padding(.vertical, 3)
                .background(.black.opacity(0.25), in: Capsule())
                .padding(DBSpacing.sm)
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))

            Text(course.title)
                .font(.dbBodyEmph)
                .foregroundStyle(Color.dbTextPrimary)
                .lineLimit(1)

            HStack(spacing: DBSpacing.xs) {
                if !course.dynasty.isEmpty {
                    Text(course.dynasty)
                    Text("·")
                }
                if !course.author.isEmpty {
                    Text(course.author)
                } else {
                    Text(course.grade.displayName)
                }
                Spacer(minLength: 0)
                Label(durationLabel(course.durationSec), systemImage: "clock")
            }
            .font(.dbCaption)
            .foregroundStyle(Color.dbTextSecondary)
            .lineLimit(1)
        }
        .frame(width: 200)
        .padding(DBSpacing.sm)
        .dbSurfaceStyle(cornerRadius: DBRadius.lg)
    }

    // MARK: - Footer nudge

    private var footerNudge: some View {
        HStack(spacing: DBSpacing.md) {
            DBMascot(mood: .cheering, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("每天进步一点点")
                    .font(.dbBodyEmph)
                    .foregroundStyle(Color.dbTextPrimary)
                Text("坚持打卡，豆包陪你一起加油 💪")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(DBSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dbPrimarySoft,
                    in: RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
    }

    // MARK: - Helpers

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

    private var encouragement: String {
        let streak = profile?.streakDays ?? 0
        if streak >= 7 { return "已连续学习 \(streak) 天，真棒！" }
        if streak > 0 { return "今天也要元气满满哦～" }
        return "新的一天，从一道题开始吧～"
    }

    private func durationLabel(_ seconds: Int) -> String {
        let minutes = max(1, Int((Double(seconds) / 60.0).rounded()))
        return "\(minutes) 分钟"
    }
}

// MARK: - Preview

#Preview("Home") {
    NavigationStack {
        HomeView()
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}
