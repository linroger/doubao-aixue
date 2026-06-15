//
//  KnowledgePointView.swift
//  豆包爱学 — Features/Knowledge/Point
//
//  知识点讲解 (Knowledge-Point Explanation / AI Teacher 2.0) — RESEARCH F44.
//
//  Looks up a `KnowledgePointEntity` by id, asks the Intelligence layer to
//  produce a structured 背景→内容→价值 explanation (with 板书 + 延伸提问), shows
//  the learner's mastery state, and offers actions: 讲一讲 (tutor), 去练习
//  (drill), and 收藏到错题本 (save to the wrong-question notebook).
//
//  All async work flows through `ViewState` so loading / streaming / error /
//  empty / offline are always handled. iOS-only size-class adaptivity is
//  guarded so the screen renders identically on macOS.
//

import SwiftUI
import SwiftData

// MARK: - View model

/// Drives the knowledge-point explanation screen. MainActor by default (UI).
@MainActor
@Observable
final class KnowledgePointModel {
    /// Resolved explanation payload for the loaded state.
    struct Payload: Equatable {
        var explanation: KnowledgeExplanation
        var point: ResolvedPoint
    }

    /// A lightweight, value snapshot of the looked-up knowledge point so the
    /// view never has to touch SwiftData on a background context.
    struct ResolvedPoint: Equatable {
        var id: String
        var name: String
        var subject: Subject
        var grade: GradeLevel
        var summary: String
        var chapter: String
        var relatedIDs: [String]
    }

    private(set) var state: ViewState<Payload> = .idle
    /// True while the structured explanation is being produced (drives a soft
    /// streaming shimmer on the already-known title/heading scaffold).
    private(set) var isStreaming = false

    /// Load (or reload) the explanation for a resolved point.
    func load(point: ResolvedPoint, using intelligence: any IntelligenceService) async {
        state = .loading
        isStreaming = true
        defer { isStreaming = false }
        do {
            let request = ExplainRequest(
                knowledgePoint: point.name,
                subject: point.subject,
                grade: point.grade
            )
            let explanation = try await intelligence.explainKnowledgePoint(request)
            guard !explanation.sections.isEmpty else {
                state = .empty(message: "暂时没有这个知识点的讲解，换一个试试吧。")
                return
            }
            state = .loaded(Payload(explanation: explanation, point: point))
        } catch let error as IntelligenceError {
            switch error {
            case .unavailable:
                state = .offline(message: "智能服务暂时离线，连上网络后再来听讲解吧。")
            case .emptyInput:
                state = .empty(message: "还没有选择知识点。")
            case .generationFailed(let reason):
                state = .error(message: reason.isEmpty ? "讲解生成失败，请重试。" : reason)
            }
        } catch {
            state = .error(message: "讲解生成失败，请重试。")
        }
    }
}

// MARK: - Main view

/// 知识点讲解 detail screen. Wired to `Route.knowledgePoint(String)`.
struct KnowledgePointView: View {
    let knowledgePointID: String

    @Environment(\.intelligence) private var intelligence
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(TTSService.self) private var tts
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    /// All knowledge points — used to resolve the target by id and to surface
    /// its related points without a second query.
    @Query private var allPoints: [KnowledgePointEntity]
    /// Mastery records — filtered in-memory by the target point id.
    @Query private var masteryRecords: [MasteryRecord]
    /// All mistakes — surfaced as "典型错题" for the point so learning ties to errors.
    @Query(sort: \MistakeItem.createdAt, order: .reverse) private var allMistakes: [MistakeItem]

    @State private var model = KnowledgePointModel()
    @State private var savedToMistakes = false

    init(knowledgePointID: String) {
        self.knowledgePointID = knowledgePointID
    }

    private var isRegular: Bool {
        #if os(iOS)
        sizeClass != .compact
        #else
        true
        #endif
    }

    /// The looked-up SwiftData entity (if seeded), else nil.
    private var entity: KnowledgePointEntity? {
        allPoints.first { $0.id == knowledgePointID }
    }

    /// Mastery record for this point, if the learner has any history.
    private var mastery: MasteryRecord? {
        masteryRecords.first { $0.knowledgePointID == knowledgePointID }
    }

    /// Related knowledge points resolved from the entity's relatedIDs.
    private var relatedPoints: [KnowledgePointEntity] {
        guard let entity else { return [] }
        let ids = Set(entity.relatedIDs)
        return allPoints.filter { ids.contains($0.id) && $0.id != entity.id }
    }

    /// Mistakes the learner has logged that involve this knowledge point — closes
    /// the loop from "understand the concept" to "fix the errors you actually made".
    private var relatedMistakes: [MistakeItem] {
        allMistakes.filter { $0.knowledgePointIDs.contains(knowledgePointID) }
    }

    var body: some View {
        Group {
            if let entity {
                content(for: entity)
            } else {
                // The id didn't resolve to a seeded point — friendly empty state.
                DBStateView(
                    kind: .empty,
                    title: "找不到这个知识点",
                    message: "它可能还没有被收录，先去做几道题，知识图谱会慢慢长出来。"
                )
            }
        }
        .background(Color.dbBackground)
        .navigationTitle(entity?.name ?? "知识点讲解")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: knowledgePointID) {
            await reload()
        }
        .onDisappear { tts.stop() }
    }

    // MARK: Content

    @ViewBuilder
    private func content(for entity: KnowledgePointEntity) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                breadcrumb(for: entity)

                DBStateContainer(model.state, retry: { Task { await reload() } }) { payload in
                    explanationBody(payload: payload, entity: entity)
                }
                .frame(minHeight: model.state.value == nil ? 320 : 0)
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func explanationBody(payload: KnowledgePointModel.Payload, entity: KnowledgePointEntity) -> some View {
        let explanation = payload.explanation
        let tint = DBSubjectColor.color(for: entity.subject)

        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            headerCard(explanation: explanation, entity: entity, tint: tint)

            masteryCard(tint: tint)

            // 背景 → 内容 → 价值
            ForEach(Array(explanation.sections.enumerated()), id: \.element.id) { index, section in
                sectionCard(section: section, index: index, tint: tint)
            }

            if !explanation.board.isEmpty {
                boardStrip(explanation.board, tint: tint)
            }

            if !explanation.extensionQuestions.isEmpty {
                extensionQuestions(explanation.extensionQuestions, entity: entity, tint: tint)
            }

            if !relatedPoints.isEmpty {
                relatedSection(tint: tint)
            }

            if !relatedMistakes.isEmpty {
                relatedMistakesSection(tint: tint)
            }

            actionBar(explanation: explanation, entity: entity)
        }
    }

    // MARK: Breadcrumb

    @ViewBuilder
    private func breadcrumb(for entity: KnowledgePointEntity) -> some View {
        HStack(spacing: DBSpacing.xs) {
            Image(systemName: entity.subject.symbolName)
                .font(.dbCaption)
                .foregroundStyle(DBSubjectColor.color(for: entity.subject))
            Text(entity.subject.displayName)
            if !entity.chapter.isEmpty {
                Image(systemName: "chevron.right").font(.dbCaption2)
                Text(entity.chapter)
            }
            Image(systemName: "chevron.right").font(.dbCaption2)
            Text(entity.name).foregroundStyle(Color.dbTextPrimary)
        }
        .font(.dbFootnote)
        .foregroundStyle(Color.dbTextSecondary)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entity.subject.displayName)，\(entity.chapter)，\(entity.name)")
    }

    // MARK: Header

    @ViewBuilder
    private func headerCard(explanation: KnowledgeExplanation, entity: KnowledgePointEntity, tint: Color) -> some View {
        DBCard(fill: .dbPrimarySoft, elevation: .none) {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                HStack(alignment: .top, spacing: DBSpacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(explanation.title)
                            .font(.dbTitle2)
                            .foregroundStyle(Color.dbTextPrimary)
                        HStack(spacing: DBSpacing.xs) {
                            DBTag(entity.grade.displayName, tint: tint)
                            DBRouteBadge(explanation.route)
                        }
                    }
                    Spacer(minLength: 0)
                    DBMascot(mood: .happy, size: 56)
                }
                if !entity.summary.isEmpty {
                    Text(entity.summary)
                        .font(.dbCallout)
                        .foregroundStyle(Color.dbTextSecondary)
                }
            }
        }
    }

    // MARK: Mastery

    @ViewBuilder
    private func masteryCard(tint: Color) -> some View {
        let record = mastery
        let progress = record?.score ?? 0
        let state = record?.state ?? .new
        DBCard {
            HStack(spacing: DBSpacing.lg) {
                DBProgressRing(progress: progress, tint: masteryTint(state),
                               label: "\(Int(progress * 100))")
                    .frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text("我的掌握度").font(.dbBodyEmph)
                    DBTag(state.displayName, tint: masteryTint(state))
                    Text(masteryHint(for: state, attempts: record?.attempts ?? 0))
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func masteryTint(_ state: MasteryState) -> Color {
        switch state {
        case .new: .dbInfo
        case .weak: .dbError
        case .developing: .dbWarning
        case .mastered: .dbSuccess
        }
    }

    private func masteryHint(for state: MasteryState, attempts: Int) -> String {
        switch state {
        case .new: "这是一个新知识点，跟着讲解一步步来就好。"
        case .weak: attempts > 0 ? "还有点薄弱，多练几道同类题就能稳住。" : "先听一遍讲解，再去练习巩固。"
        case .developing: "已经入门啦，再加把劲就能熟练掌握。"
        case .mastered: "掌握得很棒，可以挑战更难的变式题。"
        }
    }

    // MARK: Section card (背景 / 内容 / 价值)

    @ViewBuilder
    private func sectionCard(section: ExplanationSection, index: Int, tint: Color) -> some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                HStack(spacing: DBSpacing.sm) {
                    Text("\(index + 1)")
                        .font(.dbCaption.weight(.bold))
                        .foregroundStyle(Color.dbOnPrimary)
                        .frame(width: 22, height: 22)
                        .background(tint, in: Circle())
                    Text(section.heading)
                        .font(.dbHeadline)
                        .foregroundStyle(Color.dbTextPrimary)
                    Spacer(minLength: 0)
                    Button {
                        speakSection(section)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.dbCallout)
                            .foregroundStyle(tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("朗读 \(section.heading)")
                }
                Text(section.body)
                    .font(.dbBody)
                    .foregroundStyle(Color.dbTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let math = section.math, !math.isEmpty {
                    MathText(math, font: .dbMonoBody)
                        .padding(DBSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
                }
            }
        }
    }

    // MARK: 板书 strip

    @ViewBuilder
    private func boardStrip(_ board: [BoardElement], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("板书", subtitle: "AI 老师写在黑板上的要点", systemImage: "pencil.and.outline")
            DBCard(fill: Color.dbTextPrimary.opacity(0.92), elevation: .medium) {
                VStack(alignment: .leading, spacing: DBSpacing.sm) {
                    ForEach(board) { element in
                        boardLine(element)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func boardLine(_ element: BoardElement) -> some View {
        let chalk = Color.dbBackground
        switch element.kind {
        case .title:
            Text(element.content)
                .font(.dbHeadline)
                .foregroundStyle(chalk)
                .underline()
        case .text:
            Text(element.content).font(.dbCallout).foregroundStyle(chalk.opacity(0.92))
        case .bullet:
            HStack(alignment: .top, spacing: DBSpacing.xs) {
                Text("•").font(.dbCallout).foregroundStyle(Color.dbSecondary)
                Text(element.content).font(.dbCallout).foregroundStyle(chalk.opacity(0.92))
            }
        case .formula:
            MathText(element.content, font: .dbMonoBody)
                .foregroundStyle(Color.dbSecondary)
        case .highlight:
            Text(element.content)
                .font(.dbCallout.weight(.semibold))
                .foregroundStyle(Color.dbWarning)
                .padding(.horizontal, DBSpacing.sm).padding(.vertical, 2)
                .background(Color.dbWarning.opacity(0.16), in: RoundedRectangle(cornerRadius: DBRadius.xs, style: .continuous))
        case .answer:
            HStack(spacing: DBSpacing.xs) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.dbSuccess)
                MathText(element.content, font: .dbBodyEmph).foregroundStyle(chalk)
            }
        case .divider:
            Rectangle().fill(chalk.opacity(0.25)).frame(height: 1)
        }
    }

    // MARK: 延伸提问

    @ViewBuilder
    private func extensionQuestions(_ questions: [String], entity: KnowledgePointEntity, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("延伸提问", subtitle: "点一点，让豆包老师继续讲", systemImage: "sparkles")
            DBFlowLayout(spacing: DBSpacing.sm) {
                ForEach(Array(questions.enumerated()), id: \.offset) { _, question in
                    Button {
                        askFollowUp(question, entity: entity)
                    } label: {
                        DBChip(question, systemImage: "questionmark.bubble", tint: tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("追问：\(question)")
                }
            }
        }
    }

    // MARK: Related points

    @ViewBuilder
    private func relatedSection(tint: Color) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("相关知识点", subtitle: "顺着知识网络继续学", systemImage: "point.3.connected.trianglepath.dotted")
            DBFlowLayout(spacing: DBSpacing.sm) {
                ForEach(relatedPoints) { point in
                    Button {
                        router.navigate(.knowledgePoint(point.id), regular: isRegular)
                    } label: {
                        DBChip(point.name, systemImage: "circle.hexagongrid.fill",
                               tint: DBSubjectColor.color(for: point.subject))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("查看知识点：\(point.name)")
                }
            }
        }
    }

    // MARK: 典型错题 (mistakes that involve this point)

    @ViewBuilder
    private func relatedMistakesSection(tint: Color) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("典型错题", subtitle: "这些题你做错过，复习时重点看", systemImage: "exclamationmark.bubble.fill")
            ForEach(relatedMistakes.prefix(3)) { mistake in
                Button {
                    HapticEngine.play(.selection)
                    router.navigate(.mistakeDetail(mistake.id), regular: isRegular)
                } label: {
                    DBCard {
                        HStack(spacing: DBSpacing.sm) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.dbCallout)
                                .foregroundStyle(Color.dbError)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mistake.questionText)
                                    .font(.dbCallout)
                                    .foregroundStyle(Color.dbTextPrimary)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if !mistake.errorReason.isEmpty {
                                    Text(mistake.errorReason)
                                        .font(.dbCaption)
                                        .foregroundStyle(Color.dbTextSecondary)
                                        .lineLimit(1)
                                }
                            }
                            Image(systemName: "chevron.right")
                                .font(.dbFootnote)
                                .foregroundStyle(Color.dbTextTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看错题：\(mistake.questionText)")
            }
        }
    }

    // MARK: Actions

    @ViewBuilder
    private func actionBar(explanation: KnowledgeExplanation, entity: KnowledgePointEntity) -> some View {
        VStack(spacing: DBSpacing.sm) {
            Button {
                HapticEngine.play(.light)
                router.present(.tutor(problemText: entity.name, subject: entity.subject, grade: entity.grade))
            } label: {
                Label("讲一讲", systemImage: "person.wave.2.fill")
            }
            .buttonStyle(.db(.primary, fullWidth: true))

            HStack(spacing: DBSpacing.sm) {
                Button {
                    HapticEngine.play(.selection)
                    router.openDrill(knowledgePointID: entity.id, regular: isRegular)
                } label: {
                    Label("去练习", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.db(.secondary, fullWidth: true))

                Button {
                    saveToMistakes(explanation: explanation, entity: entity)
                } label: {
                    Label(savedToMistakes ? "已收藏" : "收藏到错题本",
                          systemImage: savedToMistakes ? "checkmark.seal.fill" : "bookmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.db(savedToMistakes ? .ghost : .secondary, fullWidth: true))
                .disabled(savedToMistakes)
            }
        }
        .padding(.top, DBSpacing.xs)
    }

    // MARK: Behaviors

    private func reload() async {
        guard let entity else {
            return
        }
        let resolved = KnowledgePointModel.ResolvedPoint(
            id: entity.id,
            name: entity.name,
            subject: entity.subject,
            grade: entity.grade,
            summary: entity.summary,
            chapter: entity.chapter,
            relatedIDs: entity.relatedIDs
        )
        await model.load(point: resolved, using: intelligence)
        bumpConsecutiveExplains(for: entity)
    }

    private func speakSection(_ section: ExplanationSection) {
        let spoken = section.body
        tts.speak("\(section.heading)。\(spoken)", language: "zh-CN")
    }

    /// Continue the lesson conversationally via the tutor sheet, seeding it with
    /// the follow-up question so the teacher keeps the thread.
    private func askFollowUp(_ question: String, entity: KnowledgePointEntity) {
        HapticEngine.play(.selection)
        router.present(.tutor(
            problemText: "\(entity.name) — \(question)",
            subject: entity.subject,
            grade: entity.grade
        ))
    }

    /// Persist the point as a mistake-notebook entry for later review, carrying
    /// over its mastery state and a friendly explanation seeded from the AI body.
    private func saveToMistakes(explanation: KnowledgeExplanation, entity: KnowledgePointEntity) {
        let item = MistakeItem()
        item.subject = entity.subject
        item.questionText = entity.name
        item.errorReason = "知识点掌握待加强：\(entity.name)"
        item.errorType = .knowledgeGap
        item.mastery = mastery?.state ?? .weak
        item.knowledgePointIDs = [entity.id]
        // Seed a short solution outline from the explanation sections so the
        // notebook entry is reviewable, not just a bare title.
        item.steps = explanation.sections.enumerated().map { index, section in
            SolutionStep(index: index + 1, title: section.heading,
                         detail: section.body, math: section.math)
        }
        modelContext.insert(item)
        try? modelContext.save()
        savedToMistakes = true
        HapticEngine.play(.success)
    }

    /// Tracks how many times this point has been re-explained — feeds the
    /// 薄弱点预警 system (3 consecutive explains → push micro-course).
    private func bumpConsecutiveExplains(for entity: KnowledgePointEntity) {
        let record: MasteryRecord
        if let existing = mastery {
            record = existing
        } else {
            let fresh = MasteryRecord()
            fresh.knowledgePointID = entity.id
            fresh.subject = entity.subject
            modelContext.insert(fresh)
            record = fresh
        }
        record.consecutiveExplains += 1
        record.lastUpdated = Date()
        try? modelContext.save()
    }
}

// MARK: - Previews

#Preview("知识点讲解") {
    NavigationStack {
        KnowledgePointView(knowledgePointID: "kp-preview")
    }
    .modelContainer(KnowledgePreviewData.container)
    .environment(AppRouter())
    .environment(TTSService())
}

#Preview("未收录的知识点") {
    NavigationStack {
        KnowledgePointView(knowledgePointID: "does-not-exist")
    }
    .modelContainer(KnowledgePreviewData.container)
    .environment(AppRouter())
    .environment(TTSService())
}

/// In-memory seed used only by the previews above so they render with rich,
/// representative data without touching the app's real store.
@MainActor
enum KnowledgePreviewData {
    static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: KnowledgePointEntity.self, MasteryRecord.self, MistakeItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let point = KnowledgePointEntity()
        point.id = "kp-preview"
        point.name = "二次函数的图象与性质"
        point.subject = .math
        point.grade = .g9
        point.summary = "理解 y = ax² + bx + c 的开口方向、对称轴与顶点，能据此判断单调性与最值。"
        point.chapter = "第二章 · 二次函数"
        point.relatedIDs = ["kp-related-1", "kp-related-2"]
        context.insert(point)

        let r1 = KnowledgePointEntity()
        r1.id = "kp-related-1"; r1.name = "一元二次方程"; r1.subject = .math; r1.grade = .g9
        context.insert(r1)
        let r2 = KnowledgePointEntity()
        r2.id = "kp-related-2"; r2.name = "函数的单调性"; r2.subject = .math; r2.grade = .g9
        context.insert(r2)

        let mastery = MasteryRecord()
        mastery.knowledgePointID = "kp-preview"
        mastery.subject = .math
        mastery.score = 0.42
        mastery.attempts = 6
        mastery.correctCount = 3
        context.insert(mastery)

        try? context.save()
        return container
    }()
}
