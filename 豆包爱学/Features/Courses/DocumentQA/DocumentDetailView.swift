//
//  DocumentDetailView.swift
//  豆包爱学 — Features/Courses/DocumentQA
//
//  文档详情 + 问答 — pushed via `Route.document(UUID)`.
//
//  Shows the AI 摘要 / 要点 / 大纲 cards for an imported `DocumentEntity`, the
//  full selectable document text (tap a paragraph → 解释 / 翻译 sheet), and a
//  threaded Q&A area backed by `intelligence.answerAboutDocument`. If the
//  document was imported before summarization finished (best-effort on import),
//  this screen re-runs `intelligence.summarizeDocument` and persists the result.
//
//  Every async path is funneled through `ViewState` so loading / empty / error /
//  offline are always handled, and the screen renders identically on iOS/macOS.
//

import SwiftUI
import SwiftData

// MARK: - View model

/// Drives summarization + Q&A for one document. MainActor by default (UI).
@MainActor
@Observable
final class DocumentDetailModel {

    /// One turn in the document Q&A thread.
    struct QATurn: Identifiable, Equatable {
        let id = UUID()
        var question: String
        var answer: String
        var citedSpans: [String]
        var route: IntelligenceRoute
    }

    /// Inline explain/translate result shown in a sheet for a selected span.
    struct SpanResult: Identifiable, Equatable {
        let id = UUID()
        var kind: Kind
        var source: String
        var answer: String
        var route: IntelligenceRoute
        enum Kind: Equatable {
            case explain, translate
            var title: String { self == .explain ? "解释" : "翻译" }
            var systemImage: String { self == .explain ? "lightbulb.fill" : "character.book.closed.fill" }
        }
    }

    private(set) var summaryState: ViewState<DocumentSummary> = .idle
    private(set) var turns: [QATurn] = []
    private(set) var isAnswering = false
    var spanResult: SpanResult?
    private(set) var spanLoading: SpanResult.Kind?

    /// Ensure 摘要/要点/大纲 exist. If the persisted entity already carries a
    /// summary, surface it instantly; otherwise generate and persist.
    func loadSummary(
        documentID: UUID,
        title: String,
        text: String,
        existingSummary: String,
        existingKeyPoints: [String],
        existingOutline: [String],
        intelligence: any IntelligenceService,
        context: ModelContext,
        documents: [DocumentEntity]
    ) async {
        if !existingSummary.isEmpty || !existingKeyPoints.isEmpty {
            summaryState = .loaded(DocumentSummary(
                summary: existingSummary,
                keyPoints: existingKeyPoints,
                outline: existingOutline,
                route: .mock
            ))
            return
        }
        guard !text.isEmpty else {
            summaryState = .empty(message: "这份文档还没有可分析的文字内容。")
            return
        }
        summaryState = .loading
        do {
            let summary = try await intelligence.summarizeDocument(
                DocSummarizeRequest(title: title, text: text)
            )
            if let entity = documents.first(where: { $0.id == documentID }) {
                entity.summary = summary.summary
                entity.keyPoints = summary.keyPoints
                entity.outline = summary.outline
                context.saveLogging()
            }
            summaryState = .loaded(summary)
        } catch let error as IntelligenceError {
            summaryState = mapError(error)
        } catch {
            summaryState = .error(message: "摘要生成失败，请重试。")
        }
    }

    /// Ask a free-form question about the document.
    func ask(_ question: String, documentText: String, intelligence: any IntelligenceService) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAnswering else { return }
        isAnswering = true
        defer { isAnswering = false }
        do {
            let answer = try await intelligence.answerAboutDocument(
                DocQARequest(documentText: documentText, question: trimmed)
            )
            turns.append(QATurn(
                question: trimmed,
                answer: answer.answer,
                citedSpans: answer.citedSpans,
                route: answer.route
            ))
            HapticEngine.play(.light)
        } catch {
            turns.append(QATurn(
                question: trimmed,
                answer: "抱歉，这个问题暂时没能回答，换个说法再试试？",
                citedSpans: [],
                route: .mock
            ))
        }
    }

    /// Explain or translate a selected paragraph, reusing the document Q&A route
    /// so the answer is grounded in the document's own wording.
    func resolveSpan(_ kind: SpanResult.Kind, span: String, documentText: String, intelligence: any IntelligenceService) async {
        let source = span.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, spanLoading == nil else { return }
        spanLoading = kind
        defer { spanLoading = nil }
        let prompt: String = switch kind {
        case .explain: "请用通俗易懂的话解释这句话的意思：\(source)"
        case .translate: "请把这句话翻译成简明的现代汉语：\(source)"
        }
        do {
            let answer = try await intelligence.answerAboutDocument(
                DocQARequest(documentText: documentText, question: prompt)
            )
            spanResult = SpanResult(kind: kind, source: source, answer: answer.answer, route: answer.route)
            HapticEngine.play(.selection)
        } catch {
            spanResult = SpanResult(kind: kind, source: source, answer: "暂时无法处理这段文字，请稍后再试。", route: .mock)
        }
    }

    private func mapError(_ error: IntelligenceError) -> ViewState<DocumentSummary> {
        switch error {
        case .unavailable: .offline(message: "智能服务暂时离线，连上网络后再来看看吧。")
        case .emptyInput: .empty(message: "这份文档还没有可分析的文字内容。")
        case .generationFailed(let reason): .error(message: reason.isEmpty ? "分析失败，请重试。" : reason)
        }
    }
}

// MARK: - Main view

/// 文档详情 + 问答 detail screen. Pushed by the shell — does NOT wrap NavigationStack.
struct DocumentDetailView: View {
    let documentID: UUID

    @Environment(\.intelligence) private var intelligence
    @Environment(\.modelContext) private var modelContext
    @Environment(TTSService.self) private var tts
    @Environment(AppRouter.self) private var router

    @Query private var documents: [DocumentEntity]
    @Query private var profiles: [LearnerProfile]

    @State private var model = DocumentDetailModel()
    @State private var question = ""
    @State private var showFullText = false

    init(documentID: UUID) {
        self.documentID = documentID
    }

    private var document: DocumentEntity? {
        documents.first { $0.id == documentID }
    }

    var body: some View {
        Group {
            if let document {
                content(for: document)
            } else {
                DBStateView(
                    kind: .empty,
                    title: "文档不存在",
                    message: "这份文档可能已被删除，回到列表重新选择吧。"
                )
            }
        }
        .background(Color.dbBackground)
        .navigationTitle(document?.title ?? "文档详情")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $model.spanResult) { result in
            spanSheet(result)
        }
        .task(id: documentID) {
            await loadSummaryIfNeeded()
        }
    }

    // MARK: Content

    private func content(for document: DocumentEntity) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                summarySection(for: document)
                studyActionsCard(for: document)
                textSection(for: document)
                qaSection(for: document)
            }
            .padding(DBSpacing.screenInset)
        }
        .safeAreaInset(edge: .bottom) {
            askBar(for: document)
        }
    }

    // MARK: Study actions (escalate the document into a taught lesson)

    /// Turn passive reading into active learning: hand the document's topic to the
    /// 豆包老师 for a voice-first, blackboard explanation. Closes the loop so a
    /// document isn't a dead-end — it flows into the same tutor every other feature uses.
    private func studyActionsCard(for document: DocumentEntity) -> some View {
        DBCard(fill: .dbSecondarySoft, elevation: .none) {
            HStack(spacing: DBSpacing.md) {
                DBMascot(mood: .curious, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("让豆包老师精讲")
                        .font(.dbBodyEmph)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text("把这份资料的重点，用讲解的方式听一遍")
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbTextSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Button {
                    HapticEngine.play(.light)
                    let grade = profiles.first?.grade ?? .g6
                    router.present(.tutor(
                        problemText: "请围绕《\(document.title)》这份资料，给我讲一讲它的重点内容和需要掌握的地方。",
                        subject: .general,
                        grade: grade
                    ))
                } label: {
                    Label("精讲", systemImage: "person.wave.2.fill")
                }
                .buttonStyle(.db(.secondary))
            }
        }
    }

    // MARK: Summary / key points / outline

    @ViewBuilder
    private func summarySection(for document: DocumentEntity) -> some View {
        DBStateContainer(model.summaryState) { summary in
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBCard(fill: Color.dbSurfaceRaised) {
                    VStack(alignment: .leading, spacing: DBSpacing.sm) {
                        HStack {
                            Label("内容摘要", systemImage: "text.alignleft")
                                .font(.dbHeadline)
                                .foregroundStyle(Color.dbTextPrimary)
                            Spacer()
                            DBRouteBadge(summary.route)
                        }
                        Text(summary.summary)
                            .font(.dbBody)
                            .foregroundStyle(Color.dbTextSecondary)
                            .textSelection(.enabled)
                        Button {
                            speak(summary.summary)
                        } label: {
                            Label(tts.isSpeaking ? "停止朗读" : "朗读摘要",
                                  systemImage: tts.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                        }
                        .buttonStyle(.db(.ghost))
                    }
                }

                if !summary.keyPoints.isEmpty {
                    keyPointsCard(summary.keyPoints)
                }
                if !summary.outline.isEmpty {
                    outlineCard(summary.outline)
                }
            }
        }
    }

    private func keyPointsCard(_ points: [String]) -> some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                DBSectionHeader("核心要点", systemImage: "checklist")
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: DBSpacing.sm) {
                        Text("\(index + 1)")
                            .font(.dbCaption.weight(.bold))
                            .foregroundStyle(Color.dbOnPrimary)
                            .frame(width: 22, height: 22)
                            .background(Color.dbPrimary, in: Circle())
                        Text(point)
                            .font(.dbCallout)
                            .foregroundStyle(Color.dbTextPrimary)
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func outlineCard(_ outline: [String]) -> some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                DBSectionHeader("文章大纲", systemImage: "list.bullet.indent")
                ForEach(Array(outline.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: DBSpacing.sm) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(Color.dbAccent)
                        Text(item)
                            .font(.dbCallout)
                            .foregroundStyle(Color.dbTextSecondary)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: Original text (selectable → 解释 / 翻译)

    @ViewBuilder
    private func textSection(for document: DocumentEntity) -> some View {
        let paragraphs = DocumentPresentation.paragraphs(in: document.parsedText)
        if !paragraphs.isEmpty {
            DBCard {
                VStack(alignment: .leading, spacing: DBSpacing.sm) {
                    DBSectionHeader("原文", subtitle: "点按句子可让豆包解释或翻译", systemImage: "doc.plaintext")
                    let shown = showFullText ? paragraphs : Array(paragraphs.prefix(6))
                    ForEach(Array(shown.enumerated()), id: \.offset) { _, paragraph in
                        paragraphRow(paragraph, documentText: document.parsedText)
                    }
                    if paragraphs.count > 6 {
                        Button(showFullText ? "收起原文" : "展开全文（共 \(paragraphs.count) 段）") {
                            withAnimation { showFullText.toggle() }
                        }
                        .buttonStyle(.db(.ghost))
                    }
                }
            }
        }
    }

    private func paragraphRow(_ paragraph: String, documentText: String) -> some View {
        Menu {
            Button {
                Task { await model.resolveSpan(.explain, span: paragraph, documentText: documentText, intelligence: intelligence) }
            } label: {
                Label("解释这句", systemImage: "lightbulb")
            }
            Button {
                Task { await model.resolveSpan(.translate, span: paragraph, documentText: documentText, intelligence: intelligence) }
            } label: {
                Label("翻译这句", systemImage: "character.book.closed")
            }
        } label: {
            HStack(alignment: .top, spacing: DBSpacing.sm) {
                Text(paragraph)
                    .font(.dbBody)
                    .foregroundStyle(Color.dbTextPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "ellipsis.circle")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextTertiary)
            }
            .padding(.vertical, DBSpacing.xs)
        }
        .buttonStyle(.plain)
    }

    // MARK: Q&A thread

    @ViewBuilder
    private func qaSection(for document: DocumentEntity) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            DBSectionHeader("向豆包提问", subtitle: "针对这份文档随时追问", systemImage: "bubble.left.and.text.bubble.right.fill")

            if model.turns.isEmpty && !model.isAnswering {
                suggestionChips(for: document)
            }

            ForEach(model.turns) { turn in
                qaBubble(turn)
            }

            if model.isAnswering {
                DBCard {
                    HStack(spacing: DBSpacing.sm) {
                        ProgressView()
                        Text("豆包正在查阅文档…")
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextSecondary)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func suggestionChips(for document: DocumentEntity) -> some View {
        DBFlowLayout(spacing: DBSpacing.sm) {
            ForEach(suggestions(for: document), id: \.self) { suggestion in
                Button {
                    submit(suggestion, documentText: document.parsedText)
                } label: {
                    DBChip(suggestion, systemImage: "sparkle", tint: .dbSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func qaBubble(_ turn: DocumentDetailModel.QATurn) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            HStack {
                Spacer(minLength: DBSpacing.xxl)
                Text(turn.question)
                    .font(.dbCallout)
                    .foregroundStyle(Color.dbOnPrimary)
                    .padding(DBSpacing.md)
                    .background(Color.dbPrimary, in: RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
            }
            DBCard {
                VStack(alignment: .leading, spacing: DBSpacing.sm) {
                    HStack {
                        Label("豆包", systemImage: "graduationcap.fill")
                            .font(.dbCaption.weight(.semibold))
                            .foregroundStyle(Color.dbPrimary)
                        Spacer()
                        DBRouteBadge(turn.route)
                    }
                    Text(turn.answer)
                        .font(.dbBody)
                        .foregroundStyle(Color.dbTextPrimary)
                        .textSelection(.enabled)
                    if !turn.citedSpans.isEmpty {
                        ForEach(Array(turn.citedSpans.enumerated()), id: \.offset) { _, span in
                            HStack(alignment: .top, spacing: DBSpacing.xs) {
                                Image(systemName: "quote.opening")
                                    .font(.dbCaption2)
                                    .foregroundStyle(Color.dbTextTertiary)
                                Text(span)
                                    .font(.dbFootnote)
                                    .foregroundStyle(Color.dbTextSecondary)
                            }
                            .padding(DBSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.dbBackgroundAlt, in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    // MARK: Ask bar

    private func askBar(for document: DocumentEntity) -> some View {
        HStack(spacing: DBSpacing.sm) {
            TextField("问问这份文档…", text: $question, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.dbBody)
                .lineLimit(1...3)
                .padding(.horizontal, DBSpacing.md)
                .padding(.vertical, DBSpacing.sm)
                .background(Color.dbSurface, in: Capsule())
                .onSubmit { submit(question, documentText: document.parsedText) }
            Button {
                submit(question, documentText: document.parsedText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.dbTitle2)
                    .foregroundStyle(question.trimmingCharacters(in: .whitespaces).isEmpty || model.isAnswering ? Color.dbTextTertiary : Color.dbPrimary)
            }
            .buttonStyle(.plain)
            .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || model.isAnswering)
        }
        .padding(DBSpacing.md)
        .background(.bar)
    }

    // MARK: Span sheet (解释 / 翻译)

    private func spanSheet(_ result: DocumentDetailModel.SpanResult) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DBSpacing.lg) {
                    DBCard(fill: Color.dbBackgroundAlt) {
                        VStack(alignment: .leading, spacing: DBSpacing.xs) {
                            Text("原文")
                                .font(.dbCaption.weight(.semibold))
                                .foregroundStyle(Color.dbTextTertiary)
                            Text(result.source)
                                .font(.dbBody)
                                .foregroundStyle(Color.dbTextPrimary)
                                .textSelection(.enabled)
                        }
                    }
                    DBCard {
                        VStack(alignment: .leading, spacing: DBSpacing.sm) {
                            HStack {
                                Label(result.kind.title, systemImage: result.kind.systemImage)
                                    .font(.dbHeadline)
                                    .foregroundStyle(Color.dbPrimary)
                                Spacer()
                                DBRouteBadge(result.route)
                            }
                            Text(result.answer)
                                .font(.dbBody)
                                .foregroundStyle(Color.dbTextPrimary)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(DBSpacing.screenInset)
            }
            .background(Color.dbBackground)
            .navigationTitle(result.kind.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { model.spanResult = nil }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    // MARK: Actions

    private func loadSummaryIfNeeded() async {
        guard let document else { return }
        await model.loadSummary(
            documentID: document.id,
            title: document.title,
            text: document.parsedText,
            existingSummary: document.summary,
            existingKeyPoints: document.keyPoints,
            existingOutline: document.outline,
            intelligence: intelligence,
            context: modelContext,
            documents: documents
        )
    }

    private func submit(_ text: String, documentText: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        question = ""
        Task { await model.ask(trimmed, documentText: documentText, intelligence: intelligence) }
    }

    private func suggestions(for document: DocumentEntity) -> [String] {
        var base = ["这篇文档主要讲了什么？", "帮我总结核心观点", "有哪些重点需要记住？"]
        if document.fileType.lowercased() == "txt" {
            base.append("这里面有不懂的地方，能讲讲吗？")
        }
        return base
    }

    private func speak(_ text: String) {
        if tts.isSpeaking {
            tts.stop()
        } else {
            tts.speak(text, language: "zh-CN")
        }
    }
}

// MARK: - Previews

#Preview("文档详情") {
    NavigationStack {
        DocumentDetailPreview()
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}

/// Seeds one document into the shared preview store and opens its detail screen
/// so the preview always has content regardless of seed ordering.
private struct DocumentDetailPreview: View {
    @Environment(\.modelContext) private var context
    @Query private var documents: [DocumentEntity]
    @State private var seededID: UUID?

    var body: some View {
        Group {
            if let id = seededID ?? documents.first?.id {
                DocumentDetailView(documentID: id)
            } else {
                DBStateView(kind: .loading, title: "准备示例文档…")
            }
        }
        .task {
            guard documents.isEmpty, seededID == nil else { return }
            let sample = DocumentParser.sampleDocument()
            let entity = DocumentEntity()
            entity.title = sample.title
            entity.fileType = sample.fileType
            entity.pageCount = sample.pageCount
            entity.parsedText = sample.text
            context.insert(entity)
            context.saveLogging()
            seededID = entity.id
        }
    }
}
