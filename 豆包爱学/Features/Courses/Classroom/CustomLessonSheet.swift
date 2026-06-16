//
//  CustomLessonSheet.swift
//  豆包爱学 — Features/Courses/Classroom
//
//  定制课程 — generate a brand-new 豆包课堂 lesson on demand (RESEARCH F27 / UGC).
//  The student types a topic, picks subject + grade (pre-filled from their
//  LearnerProfile), and `intelligence.generateLesson(_:)` returns an authored
//  [TutorSegment] script. We insert a UGC `CourseEntity` (isUGC = true) so it
//  shows up under 我的课程, then hand the new course id back to the caller so it
//  can navigate straight into the player.
//
//  Presented as a sheet from both StudyView and CourseDetailView. It builds its
//  own NavigationStack because it is modal (not pushed into the shell stack).
//

import SwiftUI
import SwiftData

struct CustomLessonSheet: View {
    /// Called with the freshly-inserted course id once generation succeeds, so the
    /// caller can navigate into it. The sheet dismisses itself first.
    let onCreated: (UUID) -> Void

    @Environment(\.intelligence) private var intelligence
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [LearnerProfile]
    private var profile: LearnerProfile? { profiles.first }

    @State private var topic = ""
    @State private var subject: Subject = .chinese
    @State private var grade: GradeLevel = .g6
    @State private var phase: Phase = .editing
    @State private var didPrefill = false

    private enum Phase: Equatable {
        case editing
        case generating
        case failed(String)
    }

    /// Topic suggestions tailored to the chosen subject (warm, age-appropriate).
    private var suggestions: [String] {
        switch subject {
        case .math: ["鸡兔同笼", "分数的加减法", "长方形的面积"]
        case .chinese: ["静夜思 赏析", "比喻句怎么写", "水调歌头·明月几时有"]
        case .english: ["一般现在时", "be 动词用法", "音标入门"]
        case .physics: ["浮力是怎么来的", "杠杆原理", "光的折射"]
        case .chemistry: ["原子的结构", "酸碱中和", "化学方程式配平"]
        case .biology: ["细胞的结构", "光合作用", "食物链"]
        case .history: ["丝绸之路", "唐朝的繁荣", "郑和下西洋"]
        case .geography: ["地球的自转", "季风气候", "等高线地形图"]
        default: ["这个知识点讲给我听", "帮我梳理一下重点", "举几个例子"]
        }
    }

    private var canGenerate: Bool {
        !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && phase != .generating
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .generating:
                    generatingState
                case .failed(let message):
                    DBStateView(kind: .error, title: "生成失败", message: message,
                                systemImage: "exclamationmark.triangle.fill") {
                        phase = .editing
                    }
                case .editing:
                    form
                }
            }
            .background(Color.dbBackground)
            .navigationTitle("定制课程")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("生成") { generate() }
                        .disabled(!canGenerate)
                }
            }
            .task { prefillFromProfile() }
        }
    }

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                DBCard(fill: .dbPrimarySoft, elevation: .none) {
                    HStack(spacing: DBSpacing.md) {
                        DBMascot(mood: .curious, size: 44)
                        Text("想学什么？告诉豆包老师，马上为你定制一节专属课程～")
                            .font(.dbCallout)
                            .foregroundStyle(Color.dbTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: DBSpacing.sm) {
                    Text("课程主题").font(.dbSubheadline).foregroundStyle(Color.dbTextSecondary)
                    TextField("例如：鸡兔同笼、静夜思赏析…", text: $topic, axis: .vertical)
                        .font(.dbBody)
                        .lineLimit(1...3)
                        .padding(DBSpacing.md)
                        .background(Color.dbSurface, in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                                .strokeBorder(Color.dbSeparator, lineWidth: 1)
                        )
                    DBFlowLayout(spacing: DBSpacing.xs) {
                        ForEach(suggestions, id: \.self) { s in
                            Button { topic = s } label: {
                                DBChip(s, systemImage: "sparkles", tint: .dbAccent, isSelected: topic == s)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: DBSpacing.sm) {
                    Text("学科").font(.dbSubheadline).foregroundStyle(Color.dbTextSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DBSpacing.sm) {
                            ForEach(subjectChoices, id: \.self) { s in
                                Button { subject = s } label: {
                                    DBSubjectChip(s, isSelected: subject == s)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: DBSpacing.sm) {
                    Text("年级").font(.dbSubheadline).foregroundStyle(Color.dbTextSecondary)
                    Picker("年级", selection: $grade) {
                        ForEach(GradeLevel.allCases, id: \.self) { g in
                            Text(g.displayName).tag(g)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.dbPrimary)
                }

                Button { generate() } label: {
                    Label("为我生成课程", systemImage: "wand.and.stars")
                        .font(.dbBodyEmph)
                }
                .buttonStyle(.db(.primary, fullWidth: true))
                .disabled(!canGenerate)
            }
            .padding(DBSpacing.screenInset)
        }
    }

    private var subjectChoices: [Subject] {
        let base: [Subject] = [.chinese, .math, .english, .physics, .chemistry,
                               .biology, .history, .geography]
        // Surface the learner's own subjects first, then the rest, de-duplicated.
        let preferred = profile?.subjects ?? []
        var ordered = preferred
        for s in base where !ordered.contains(s) { ordered.append(s) }
        return ordered
    }

    private var generatingState: some View {
        VStack(spacing: DBSpacing.lg) {
            DBMascot(mood: .thinking, size: 72)
            Text("豆包老师正在备课…")
                .font(.dbTitle3).foregroundStyle(Color.dbTextPrimary)
            Text("正在为「\(topic)」编写情景短片和动态板书～")
                .font(.dbCallout).foregroundStyle(Color.dbTextSecondary)
                .multilineTextAlignment(.center)
            ProgressView().controlSize(.large).tint(Color.dbPrimary)
        }
        .padding(DBSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Generation

    private func prefillFromProfile() {
        guard !didPrefill else { return }
        didPrefill = true
        if let profile {
            grade = profile.grade
            if let first = profile.subjects.first { subject = first }
        }
    }

    private func generate() {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, phase != .generating else { return }
        phase = .generating
        let request = LessonRequest(topic: trimmed, subject: subject, grade: grade)

        Task {
            do {
                let lesson = try await intelligence.generateLesson(request)
                let course = CourseEntity()
                course.title = lesson.title.isEmpty ? trimmed : lesson.title
                course.author = "豆包老师"
                course.subject = subject
                course.grade = grade
                course.summary = "为你定制的「\(course.title)」专属课程"
                course.durationSec = max(180, lesson.segments.count * 120)
                course.thumbnailSymbol = subject.symbolName
                course.isUGC = true
                course.reviewVerified = false
                course.generationStatusRaw = "ready"
                course.segments = lesson.segments
                course.knowledgePointIDs = lesson.knowledgePoints.map(\.id)
                modelContext.insert(course)
                modelContext.saveLogging()
                HapticEngine.play(.success)
                let newID = course.id
                dismiss()
                onCreated(newID)
            } catch {
                phase = .failed("这节课暂时没能生成，检查网络后再试试吧～")
                HapticEngine.play(.error)
            }
        }
    }
}

#Preview {
    CustomLessonSheet(onCreated: { _ in })
        .modelContainer(PreviewSampleData.container)
}
