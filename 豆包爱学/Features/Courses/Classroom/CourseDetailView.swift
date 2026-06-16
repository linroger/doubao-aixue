//
//  CourseDetailView.swift
//  豆包爱学 — Features/Courses/Classroom
//
//  豆包课堂 — the immersive AI lesson player (RESEARCH §4.3 / F23–F27). Pushed via
//  `Route.course(UUID)`; the integrator wires `CourseDetailView(courseID:)` into
//  AppDestinations.
//
//  A 课程 is an authored 课件 whose [TutorSegment] script lives on `CourseEntity`.
//  This screen plays it as 情景短片 + 知识点精讲: the hero 动态板书 (reused
//  `TutorBlackboard`) reveals each segment's BoardElements progressively in sync
//  with TTS narration; an inline 互动习题 appears at each TutorCheckpoint; below
//  sit chapter (章节) markers + a transcript (字幕). "向老师提问" hands off to the
//  live tutor via `router.present(.tutor(...))`. Progress is saved to
//  `LessonProgress` so the student resumes where they stopped.
//
//  Camera / Pencil are not used, so the screen behaves identically on iOS and
//  macOS; the only platform guard is the inline title-display mode.
//

import SwiftUI
import SwiftData

struct CourseDetailView: View {
    // MARK: Input (the exact init the integrator wires from Route.course)
    let courseID: UUID

    init(courseID: UUID) { self.courseID = courseID }

    // MARK: Environment
    @Environment(TTSService.self) private var tts
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass

    // MARK: Data
    @Query private var courses: [CourseEntity]
    @Query private var progresses: [LessonProgress]

    // MARK: Player state
    @State private var model: LessonPlayerModel?
    @State private var showTranscript = false
    @State private var didStart = false
    @State private var showCustomLesson = false

    private var isRegular: Bool { sizeClass != .compact }

    private var course: CourseEntity? { courses.first { $0.id == courseID } }
    private var progress: LessonProgress? { progresses.first { $0.courseID == courseID } }

    var body: some View {
        Group {
            if let course {
                if course.generationStatusRaw == "generating" || course.generationStatusRaw == "pending" {
                    generatingState(course)
                } else if course.generationStatusRaw == "failed" {
                    DBStateView(kind: .error, title: "课程生成失败",
                                message: "这节定制课暂时没能生成，回到课程列表重新试试吧～",
                                systemImage: "exclamationmark.triangle.fill")
                } else if course.segments.isEmpty {
                    DBStateView(kind: .empty, title: "课程内容准备中",
                                message: "这节课还没有课件，换一节课先学起来吧～")
                } else if let model {
                    player(course: course, model: model)
                } else {
                    DBStateView(kind: .loading, title: "豆包老师正在备课…")
                }
            } else {
                DBStateView(kind: .error, title: "找不到这节课",
                            message: "课程可能已被移除，回到课程列表看看吧～",
                            systemImage: "questionmark.folder")
            }
        }
        .background(Color.dbBackground)
        .navigationTitle(course?.title ?? "豆包课堂")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .sheet(isPresented: $showCustomLesson) {
            CustomLessonSheet { newID in
                router.navigate(.course(newID), regular: isRegular)
            }
        }
        .task { setUpModelIfNeeded() }
        .onChange(of: course?.id) { _, _ in setUpModelIfNeeded() }
        .onChange(of: course?.segments.count) { _, _ in setUpModelIfNeeded() }
        .onDisappear {
            persistProgress()
            model?.tearDown()
        }
    }

    // MARK: - Setup

    private func setUpModelIfNeeded() {
        guard let course, !course.segments.isEmpty else { return }
        guard model == nil else { return }
        let m = LessonPlayerModel(courseID: courseID, segments: course.segments, tts: tts)
        model = m
        if !didStart {
            didStart = true
            // Resume from the saved chapter, but never resume *at* the last index
            // if the course was already completed — start it fresh in that case.
            let resumeIndex = (progress?.completed == true) ? 0 : (progress?.lastSegmentIndex ?? 0)
            m.start(at: resumeIndex)
        }
    }

    // MARK: - States

    private func generatingState(_ course: CourseEntity) -> some View {
        VStack(spacing: DBSpacing.lg) {
            DBMascot(mood: .thinking, size: 72)
            Text("豆包老师正在备课")
                .font(.dbTitle3).foregroundStyle(Color.dbTextPrimary)
            Text("正在为「\(course.title)」准备情景短片和动态板书，稍等片刻～")
                .font(.dbCallout).foregroundStyle(Color.dbTextSecondary)
                .multilineTextAlignment(.center)
            ProgressView().controlSize(.large).tint(Color.dbPrimary)
        }
        .padding(DBSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Player (adaptive)

    @ViewBuilder
    private func player(course: CourseEntity, model: LessonPlayerModel) -> some View {
        if isRegular {
            HStack(spacing: 0) {
                ScrollView {
                    sidePanel(course: course, model: model)
                        .padding(DBSpacing.lg)
                }
                .frame(width: 320)
                .background(Color.dbBackgroundAlt)

                Divider()

                VStack(spacing: DBSpacing.md) {
                    boardSection(model)
                    bottomControls(course: course, model: model)
                }
                .padding(DBSpacing.lg)
                .frame(maxWidth: .infinity)
            }
        } else {
            ScrollView {
                VStack(spacing: DBSpacing.md) {
                    boardSection(model)
                        .frame(height: 380)
                    bottomControls(course: course, model: model)
                    LessonChapterRail(
                        segments: model.segments,
                        currentIndex: model.currentIndex,
                        onJump: { model.jump(to: $0) }
                    )
                    if showTranscript {
                        LessonTranscriptView(
                            segments: model.segments,
                            currentIndex: model.currentIndex,
                            onJump: { model.jump(to: $0) }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(DBSpacing.md)
            }
        }
    }

    // MARK: - Board

    private func boardSection(_ model: LessonPlayerModel) -> some View {
        TutorBlackboard(
            elements: model.visibleBoardElements,
            stepCaption: boardCaption(model),
            isSpeaking: tts.isSpeaking
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func boardCaption(_ model: LessonPlayerModel) -> String {
        guard !model.segments.isEmpty else { return "动态板书" }
        if model.isFinished { return "学完啦 · 共 \(model.segments.count) 节" }
        return "第 \(model.currentIndex + 1) / \(model.segments.count) 节"
    }

    // MARK: - Bottom controls

    @ViewBuilder
    private func bottomControls(course: CourseEntity, model: LessonPlayerModel) -> some View {
        VStack(spacing: DBSpacing.md) {
            if model.isWaitingOnCheckpoint, let checkpoint = model.activeCheckpoint {
                LessonCheckpointCard(
                    checkpoint: checkpoint,
                    selection: model.checkpointSelection,
                    onAnswer: { model.answerCheckpoint($0) }
                )
            } else if let checkpoint = model.activeCheckpoint, let selection = model.checkpointSelection {
                LessonCheckpointCard(
                    checkpoint: checkpoint,
                    selection: selection,
                    onAnswer: { _ in }
                )
            }

            if model.isFinished {
                finishedCard(course: course, model: model)
            } else {
                LessonControlRail(
                    progress: model.progress,
                    stepText: "第 \(model.currentIndex + 1) / \(model.segments.count) 节",
                    canGoBack: model.hasPreviousSegment,
                    canAdvance: model.canAdvance && !model.isWaitingOnCheckpoint,
                    isSpeaking: tts.isSpeaking,
                    ttsEnabled: model.ttsEnabled,
                    transcriptOpen: $showTranscript,
                    pace: Binding(get: { model.paceMultiplier },
                                  set: { model.paceMultiplier = $0 }),
                    onBack: { model.goBack() },
                    onReplay: { model.replayCurrent() },
                    onAdvance: { model.advance(); persistProgress() },
                    onRepeatNarration: { model.repeatNarration() },
                    onToggleTTS: { model.toggleTTS() }
                )
            }

            askTeacherButton(course: course)
        }
    }

    private func askTeacherButton(course: CourseEntity) -> some View {
        Button {
            tts.stop()
            let problem = currentTeacherPrompt(course)
            router.present(.tutor(problemText: problem, subject: course.subject, grade: course.grade))
        } label: {
            Label("向老师提问", systemImage: "hand.raised.fill")
                .font(.dbBodyEmph)
        }
        .buttonStyle(.db(.secondary, fullWidth: true))
    }

    /// Build a contextual seed question for the live tutor from the current chapter.
    private func currentTeacherPrompt(_ course: CourseEntity) -> String {
        guard let segment = model?.currentSegment else { return course.title }
        let topic = segment.board.first(where: { $0.kind == .title })?.content
            ?? segment.board.first(where: { $0.kind == .bullet })?.content
        if let topic, !topic.isEmpty {
            return "我在学《\(course.title)》，关于“\(topic)”这部分，能再给我讲讲吗？"
        }
        return "我在学《\(course.title)》，能再给我讲讲这部分吗？"
    }

    private func finishedCard(course: CourseEntity, model: LessonPlayerModel) -> some View {
        DBCard(fill: .dbSuccessSoft, elevation: .none) {
            HStack(spacing: DBSpacing.md) {
                DBMascot(mood: .cheering, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("这节课学完啦！")
                        .font(.dbHeadline).foregroundStyle(Color.dbTextPrimary)
                    let total = model.segments.filter { $0.checkpoint != nil }.count
                    if total > 0 {
                        Text("互动习题答对 \(model.quizCorrect) / \(total) 道，真棒～")
                            .font(.dbFootnote).foregroundStyle(Color.dbTextSecondary)
                    } else {
                        Text("跟着豆包老师又掌握了一个知识点～")
                            .font(.dbFootnote).foregroundStyle(Color.dbTextSecondary)
                    }
                }
                Spacer(minLength: 0)
                Button("再学一遍") {
                    model.restart()
                    persistProgress()
                }
                .buttonStyle(.db(.ghost))
            }
        }
        .onAppear { persistProgress() }
    }

    // MARK: - Side panel (regular width): course meta + chapters + transcript

    private func sidePanel(course: CourseEntity, model: LessonPlayerModel) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            LessonHeaderCard(course: course)
            DBSectionHeader("章节", systemImage: "list.bullet.rectangle")
            LessonChapterRail(
                segments: model.segments,
                currentIndex: model.currentIndex,
                onJump: { model.jump(to: $0) }
            )
            DBSectionHeader("字幕", systemImage: "text.bubble")
            LessonTranscriptView(
                segments: model.segments,
                currentIndex: model.currentIndex,
                onJump: { model.jump(to: $0) }
            )
        }
    }

    // MARK: - Persistence

    /// Upsert the LessonProgress row (resume point + completion + quiz score).
    private func persistProgress() {
        guard let model else { return }
        let record = progress ?? {
            let new = LessonProgress()
            new.courseID = courseID
            modelContext.insert(new)
            return new
        }()
        record.lastSegmentIndex = model.currentIndex
        record.completed = model.isFinished
        record.quizCorrect = model.quizCorrect
        record.updatedAt = Date()
        modelContext.saveLogging()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { showCustomLesson = true } label: {
                Label("定制课程", systemImage: "wand.and.stars")
            }
        }
    }
}

/// Preview wrapper that resolves the first seeded course id from the container,
/// then renders the real `CourseDetailView` against it.
private struct CourseDetailPreviewHost: View {
    @Query(sort: \CourseEntity.createdAt, order: .reverse) private var courses: [CourseEntity]
    var body: some View {
        if let course = courses.first {
            CourseDetailView(courseID: course.id)
        } else {
            DBStateView(kind: .loading, title: "加载课程…")
        }
    }
}

#Preview("课程播放器 — compact") {
    NavigationStack {
        CourseDetailPreviewHost()
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}

#Preview("课程播放器 — regular") {
    NavigationStack {
        CourseDetailPreviewHost()
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
    .frame(minWidth: 1000, minHeight: 660)
}
