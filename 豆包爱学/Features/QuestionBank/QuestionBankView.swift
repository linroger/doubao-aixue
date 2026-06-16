//
//  QuestionBankView.swift
//  豆包爱学 — Features/QuestionBank
//
//  题库 (the review databank): every question saved from 作业批改 / 拍题解题 / 错题本,
//  or added manually, collected for later review. Filter by subject / starred, reveal
//  answers, star and delete, and — the headline feature — select questions and let the
//  AI generate fresh 同类练习 (智能出题) seeded by what the learner needs to review.
//
//  Wired to `ToolKind.questionBank` via the no-argument `init()`.
//

import SwiftUI
import SwiftData

struct QuestionBankView: View {
    @Environment(\.intelligence) private var intelligence
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \BankedQuestion.createdAt, order: .reverse) private var questions: [BankedQuestion]
    @Query private var profiles: [LearnerProfile]

    @State private var model = QuestionBankModel()
    @State private var subjectFilter: Subject?
    @State private var starredOnly = false
    @State private var revealedAnswers: Set<UUID> = []

    private var grade: GradeLevel { profiles.first?.grade ?? .g5 }
    private var isRegular: Bool { sizeClass != .compact }

    private var filtered: [BankedQuestion] {
        questions.filter { subjectFilter == nil || $0.subject == subjectFilter }
            .filter { !starredOnly || $0.starred }
    }

    private var subjectsPresent: [Subject] {
        Array(Set(questions.map(\.subject))).sorted { $0.displayName < $1.displayName }
    }

    private var seedsForPractice: [BankedQuestion] {
        if !model.selectedIDs.isEmpty {
            return questions.filter { model.selectedIDs.contains($0.id) }
        }
        return filtered
    }

    var body: some View {
        Group {
            if questions.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("题库")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if !questions.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(model.selecting ? "完成" : "选择") {
                        withAnimation { model.selecting.toggle(); model.selectedIDs.removeAll() }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { practiceBar }
        .sheet(isPresented: $model.showPractice) {
            GeneratedPracticeSheet(model: model, grade: grade)
        }
    }

    private var emptyState: some View {
        DBStateView(kind: .empty, title: "题库还是空的",
                    message: "在「作业批改」「拍题解题」「错题本」里点「加入题库」，或收藏想复习的题目，它们都会出现在这里。")
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                practiceCallout
                filterBar
                ForEach(filtered) { q in
                    card(q)
                }
                if filtered.isEmpty {
                    DBStateView(kind: .success, title: "没有符合条件的题目", message: "换个筛选看看。")
                        .frame(height: 180)
                }
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
    }

    private var practiceCallout: some View {
        DBCard(fill: .dbPrimarySoft, elevation: .none) {
            HStack(spacing: DBSpacing.md) {
                DBMascot(mood: .cheering, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("智能出题，举一反三")
                        .font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
                    Text("选几道题（或直接用当前列表），我帮你生成同类练习。")
                        .font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
                }
                Spacer(minLength: 0)
                Button {
                    Task { await model.generatePractice(seeds: seedsForPractice, grade: grade, using: intelligence) }
                    HapticEngine.play(.light)
                } label: {
                    Label("智能出题", systemImage: "sparkles")
                }
                .buttonStyle(.db(.primary))
                .disabled(filtered.isEmpty)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DBSpacing.sm) {
                Button { starredOnly.toggle() } label: {
                    DBChip("星标", systemImage: "star.fill", tint: .dbAccent, isSelected: starredOnly)
                }.buttonStyle(.plain)
                Rectangle().fill(Color.dbSeparator).frame(width: 1, height: 22)
                Button { subjectFilter = nil } label: {
                    DBChip("全部学科", tint: .dbSecondary, isSelected: subjectFilter == nil)
                }.buttonStyle(.plain)
                ForEach(subjectsPresent) { s in
                    Button { subjectFilter = (subjectFilter == s ? nil : s) } label: {
                        DBSubjectChip(s, isSelected: subjectFilter == s)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func card(_ q: BankedQuestion) -> some View {
        DBCard {
            HStack(alignment: .top, spacing: DBSpacing.md) {
                if model.selecting {
                    Image(systemName: model.selectedIDs.contains(q.id) ? "checkmark.circle.fill" : "circle")
                        .font(.dbTitle3)
                        .foregroundStyle(model.selectedIDs.contains(q.id) ? Color.dbPrimary : Color.dbTextTertiary)
                }
                VStack(alignment: .leading, spacing: DBSpacing.sm) {
                    if q.subject.isSTEM || q.type == .calculation {
                        MathText(q.questionText, font: .dbBody).lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(q.questionText).font(.dbBody).foregroundStyle(Color.dbTextPrimary)
                            .lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if revealedAnswers.contains(q.id), !q.correctAnswer.isEmpty {
                        Label(q.correctAnswer, systemImage: "checkmark.seal.fill")
                            .font(.dbCallout.weight(.medium))
                            .foregroundStyle(Color.dbSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !q.explanation.isEmpty {
                            Text(q.explanation).font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else if !q.correctAnswer.isEmpty {
                        Button("看答案") { _ = revealedAnswers.insert(q.id); HapticEngine.play(.light) }
                            .font(.dbFootnote.weight(.medium))
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.dbPrimary)
                    }

                    HStack(spacing: DBSpacing.sm) {
                        DBSubjectChip(q.subject)
                        DBTag(q.source.displayName, tint: .dbInfo)
                        Spacer(minLength: 0)
                        Text(q.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.dbCaption2).foregroundStyle(Color.dbTextTertiary)
                    }
                }
                if !model.selecting {
                    Button { toggleStar(q) } label: {
                        Image(systemName: q.starred ? "star.fill" : "star")
                            .foregroundStyle(q.starred ? Color.dbAccent : Color.dbTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if model.selecting { model.toggle(q.id) } }
        }
        .contextMenu {
            Button { router.present(.tutor(problemText: "请讲讲这道题：\(q.questionText)", subject: q.subject, grade: grade)) } label: {
                Label("让豆包老师讲", systemImage: "person.wave.2.fill")
            }
            Button(role: .destructive) { delete(q) } label: { Label("从题库移除", systemImage: "trash") }
        }
    }

    @ViewBuilder
    private var practiceBar: some View {
        if model.selecting {
            HStack {
                Text("已选 \(model.selectedIDs.count) 题").font(.dbCallout).foregroundStyle(Color.dbTextSecondary)
                Spacer()
                Button {
                    Task { await model.generatePractice(seeds: seedsForPractice, grade: grade, using: intelligence) }
                } label: {
                    Label("智能出题", systemImage: "sparkles")
                }
                .buttonStyle(.db(.primary))
                .disabled(model.selectedIDs.isEmpty)
            }
            .padding(DBSpacing.md)
            .background(.bar)
        }
    }

    private func toggleStar(_ q: BankedQuestion) {
        q.starred.toggle()
        modelContext.saveLogging()
        HapticEngine.play(.selection)
    }

    private func delete(_ q: BankedQuestion) {
        modelContext.delete(q)
        modelContext.saveLogging()
        HapticEngine.play(.light)
    }
}

// MARK: - Generated practice sheet

struct GeneratedPracticeSheet: View {
    @Bindable var model: QuestionBankModel
    let grade: GradeLevel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                DBStateContainer(model.practiceState) { problems in
                    VStack(spacing: DBSpacing.md) {
                        DBCard(fill: .dbPrimarySoft, elevation: .none) {
                            HStack(spacing: DBSpacing.md) {
                                DBMascot(mood: .cheering, size: 48)
                                Text("根据你题库里的题目，生成了 \(problems.count) 道同类练习。先自己做做看，再核对答案！")
                                    .font(.dbCallout).foregroundStyle(Color.dbTextPrimary)
                                Spacer(minLength: 0)
                            }
                        }
                        ForEach(Array(problems.enumerated()), id: \.element.id) { index, problem in
                            practiceCard(index: index + 1, problem: problem)
                        }
                    }
                    .padding(DBSpacing.screenInset)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: model.practiceState.value == nil ? 420 : nil)
            }
            .background(Color.dbBackground)
            .navigationTitle("智能出题")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 540, minHeight: 580)
        #endif
    }

    private func practiceCard(index: Int, problem: GeneratedProblem) -> some View {
        let subject = model.lastSeedSubjects.first ?? .general
        let revealed = model.revealedIDs.contains(problem.id)
        let banked = model.bankedGeneratedIDs.contains(problem.id)
        return DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                HStack {
                    Text("第 \(index) 题").font(.dbFootnote.weight(.semibold)).foregroundStyle(Color.dbPrimary)
                    Spacer()
                    Text(String(repeating: "★", count: max(1, min(5, problem.difficulty))))
                        .font(.dbCaption).foregroundStyle(Color.dbAccent)
                }
                MathText(problem.question, font: .dbBody)
                    .foregroundStyle(Color.dbTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)

                if revealed {
                    Divider().overlay(Color.dbSeparator)
                    Label("参考答案", systemImage: "checkmark.seal.fill")
                        .font(.dbFootnote.weight(.medium)).foregroundStyle(Color.dbSecondary)
                    MathText(problem.answer, font: .dbBodyEmph).foregroundStyle(Color.dbSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(problem.steps) { step in
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(step.index). \(step.title)").font(.dbCaption.weight(.medium))
                                .foregroundStyle(Color.dbTextPrimary)
                            if !step.detail.isEmpty {
                                Text(step.detail).font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
                            }
                        }
                    }
                } else {
                    Button("先做做看，再看答案") { model.reveal(problem.id) }
                        .buttonStyle(.db(.ghost, fullWidth: true))
                }

                Button {
                    model.bankGenerated(problem, subject: subject, context: modelContext)
                } label: {
                    Label(banked ? "已加入题库" : "加入题库",
                          systemImage: banked ? "checkmark" : "tray.full.fill")
                        .font(.dbFootnote.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(banked ? Color.dbTextTertiary : Color.dbPrimary)
                .disabled(banked)
            }
        }
    }
}

#Preview("题库") {
    NavigationStack { QuestionBankView() }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
        .environment(TTSService())
}
