//
//  StudyView.swift
//  豆包爱学 — Features/Study
//
//  豆包课堂 course library (RESEARCH §4.3 / F23–F27). The home of the immersive
//  AI lesson player: a browsable list of 精品课程 (curated, 三重审核) and 我的课程
//  (UGC lessons the student generated via 定制课程). Tapping a course pushes
//  `Route.course(id)` into the shell stack → `CourseDetailView`. A 定制课程 button
//  generates a brand-new lesson on demand and navigates straight into it.
//
//  Contract preserved: `struct StudyView: View` with a no-arg `init()`.
//

import SwiftUI
import SwiftData

struct StudyView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \CourseEntity.createdAt, order: .reverse) private var courses: [CourseEntity]
    @Query private var progresses: [LessonProgress]

    @State private var libraryFilter: LibraryFilter = .featured
    @State private var subjectFilter: Subject?
    @State private var showCustomLesson = false

    init() {}

    private var isRegular: Bool { sizeClass != .compact }

    private enum LibraryFilter: String, CaseIterable, Identifiable {
        case featured, mine
        var id: String { rawValue }
        var displayName: String { self == .featured ? "精品课程" : "我的课程" }
    }

    private var filtered: [CourseEntity] {
        courses
            .filter { libraryFilter == .featured ? !$0.isUGC : $0.isUGC }
            .filter { subjectFilter == nil || $0.subject == subjectFilter }
    }

    private var subjectsPresent: [Subject] {
        let pool = courses.filter { libraryFilter == .featured ? !$0.isUGC : $0.isUGC }
        return Array(Set(pool.map(\.subject))).sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        Group {
            if courses.isEmpty {
                DBStateView(kind: .loading, title: "课程加载中", message: "稍等片刻就好～")
            } else {
                content
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("豆包课堂")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCustomLesson = true } label: {
                    Label("定制课程", systemImage: "wand.and.stars")
                }
            }
        }
        .sheet(isPresented: $showCustomLesson) {
            CustomLessonSheet { newID in
                router.navigate(.course(newID), regular: isRegular)
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("豆包课堂", subtitle: "沉浸式 AI 视频课 · 动态板书 + 互动习题",
                                systemImage: "play.tv.fill")

                Picker("课程库", selection: $libraryFilter) {
                    ForEach(LibraryFilter.allCases) { f in
                        Text(f.displayName).tag(f)
                    }
                }
                .pickerStyle(.segmented)

                if !subjectsPresent.isEmpty {
                    subjectFilterBar
                }

                if filtered.isEmpty {
                    emptyState
                } else {
                    ForEach(filtered) { course in
                        courseRow(course)
                    }
                }

                customLessonCard
            }
            .padding(DBSpacing.screenInset)
        }
    }

    private var subjectFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DBSpacing.sm) {
                Button { subjectFilter = nil } label: {
                    DBChip("全部学科", tint: .dbSecondary, isSelected: subjectFilter == nil)
                }
                .buttonStyle(.plain)
                ForEach(subjectsPresent) { s in
                    Button { subjectFilter = (subjectFilter == s ? nil : s) } label: {
                        DBSubjectChip(s, isSelected: subjectFilter == s)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch libraryFilter {
        case .featured:
            DBStateView(kind: .empty, title: "没有匹配的课程",
                        message: "换个学科筛选看看，或试试为自己定制一节课～")
                .frame(height: 220)
        case .mine:
            DBStateView(kind: .empty, title: "还没有我的课程",
                        message: "点击「定制课程」，让豆包老师为你量身打造一节专属课～")
                .frame(height: 220)
        }
    }

    private func courseRow(_ course: CourseEntity) -> some View {
        Button {
            router.navigate(.course(course.id), regular: isRegular)
        } label: {
            DBCard {
                HStack(spacing: DBSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                            .fill(DBSubjectColor.color(for: course.subject).opacity(0.16))
                            .frame(width: 52, height: 52)
                        Image(systemName: course.thumbnailSymbol)
                            .font(.system(size: 24))
                            .foregroundStyle(DBSubjectColor.color(for: course.subject))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.title)
                            .font(.dbBodyEmph)
                            .foregroundStyle(Color.dbTextPrimary)
                            .lineLimit(1)
                        Text("\(course.author.isEmpty ? "豆包老师" : course.author) · 约 \(max(1, course.durationSec / 60)) 分钟")
                            .font(.dbCaption)
                            .foregroundStyle(Color.dbTextSecondary)
                        HStack(spacing: DBSpacing.xs) {
                            DBSubjectChip(course.subject)
                            if course.isUGC {
                                DBTag("我的课程", tint: .dbAccent)
                            } else if course.reviewVerified {
                                DBTag("三重审核", tint: .dbSecondary)
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    progressIndicator(for: course)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func progressIndicator(for course: CourseEntity) -> some View {
        if let progress = progresses.first(where: { $0.courseID == course.id }) {
            let total = max(course.segments.count, 1)
            if progress.completed {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.dbTitle3)
                        .foregroundStyle(Color.dbSuccess)
                    Text("已学完").font(.dbCaption2).foregroundStyle(Color.dbTextTertiary)
                }
            } else {
                DBProgressRing(
                    progress: min(1, Double(progress.lastSegmentIndex) / Double(total)),
                    lineWidth: 5,
                    tint: Color.dbPrimary,
                    label: "继续")
                .frame(width: 44, height: 44)
            }
        } else {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.dbPrimary)
        }
    }

    private var customLessonCard: some View {
        Button { showCustomLesson = true } label: {
            DBCard(fill: .dbPrimarySoft, elevation: .none) {
                HStack(spacing: DBSpacing.md) {
                    Image(systemName: "wand.and.stars")
                        .font(.dbTitle2)
                        .foregroundStyle(Color.dbPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("定制专属课程")
                            .font(.dbBodyEmph)
                            .foregroundStyle(Color.dbTextPrimary)
                        Text("想学什么就学什么，豆包老师马上为你备课")
                            .font(.dbCaption)
                            .foregroundStyle(Color.dbTextSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { StudyView() }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
        .environment(TTSService())
}
