//
//  SearchView.swift
//  豆包爱学 — Features/Search
//
//  全局搜索 (RESEARCH F-search): one place to find anything across the app.
//  Presented modally via AppSheet.search (wrapped by SheetScaffold, which already
//  supplies a NavigationStack + 完成 button — so this view does NOT self-wrap a
//  stack). A live DBSearchField filters across every learning surface at once:
//    • 工具 (ToolKind)            • 错题 (MistakeItem)
//    • 单词 (WordCard)            • 课程 (CourseEntity)
//    • 文档 (DocumentEntity)      • 知识点 (KnowledgePointEntity)
//    • 对话 (Conversation)
//  Results are grouped under headers with counts. Tapping a row dismisses the
//  sheet and routes via AppRouter (router.openTool / router.navigate). When the
//  query is empty we show warm suggestion chips to get the learner moving.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @Query(sort: \MistakeItem.createdAt, order: .reverse) private var mistakes: [MistakeItem]
    @Query private var words: [WordCard]
    @Query(sort: \CourseEntity.createdAt, order: .reverse) private var courses: [CourseEntity]
    @Query(sort: \DocumentEntity.createdAt, order: .reverse) private var documents: [DocumentEntity]
    @Query(sort: \KnowledgePointEntity.name) private var knowledgePoints: [KnowledgePointEntity]
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    @State private var query: String = ""

    init() {}

    private var isRegular: Bool { sizeClass != .compact }

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            DBSearchField(text: $query, placeholder: "搜索工具、错题、单词、课程…")
                .padding(.horizontal, DBSpacing.screenInset)
                .padding(.top, DBSpacing.sm)
                .padding(.bottom, DBSpacing.md)

            if trimmed.isEmpty {
                emptyQueryState
            } else if totalResultCount == 0 {
                noResultsState
            } else {
                resultsList
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("搜索")
    }

    // MARK: - States

    private var emptyQueryState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                DBSectionHeader("快速开始", subtitle: "试试搜索一个工具，或直接进入常用功能",
                                systemImage: "sparkles")
                DBFlowLayout(spacing: DBSpacing.sm) {
                    ForEach(suggestedTools) { tool in
                        Button {
                            route(toTool: tool)
                        } label: {
                            DBChip(tool.displayName, systemImage: tool.symbolName, tint: .dbPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !mistakes.isEmpty || !words.isEmpty || !courses.isEmpty {
                    DBSectionHeader("最近内容", subtitle: "你最近学习过的内容",
                                    systemImage: "clock.arrow.circlepath")
                        .padding(.top, DBSpacing.sm)
                    VStack(spacing: DBSpacing.sm) {
                        ForEach(recentRows) { result in
                            resultRow(result)
                        }
                    }
                }
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var noResultsState: some View {
        DBStateView(kind: .empty,
                    title: "没有找到“\(trimmed)”",
                    message: "换个关键词试试，或从下方工具直接开始学习吧。",
                    systemImage: "magnifyingglass")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DBSpacing.lg, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedResults) { group in
                    Section {
                        VStack(spacing: DBSpacing.sm) {
                            ForEach(group.results) { result in
                                resultRow(result)
                            }
                        }
                    } header: {
                        sectionHeader(group)
                    }
                }
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionHeader(_ group: SearchResultGroup) -> some View {
        HStack(spacing: DBSpacing.sm) {
            DBSectionHeader(group.kind.title, systemImage: group.kind.symbol)
            DBBadge(count: group.results.count, tint: .dbPrimary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, DBSpacing.xs)
        .background(Color.dbBackground)
    }

    private func resultRow(_ result: SearchResult) -> some View {
        Button {
            route(result)
        } label: {
            DBCard {
                HStack(spacing: DBSpacing.md) {
                    Image(systemName: result.symbol)
                        .font(.dbTitle3)
                        .foregroundStyle(result.tint)
                        .frame(width: 34, height: 34)
                        .background(result.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.title)
                            .font(.dbBodyEmph)
                            .foregroundStyle(Color.dbTextPrimary)
                            .lineLimit(1)
                        if let subtitle = result.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.dbFootnote)
                                .foregroundStyle(Color.dbTextSecondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: DBSpacing.xs)
                    Image(systemName: "chevron.right")
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbTextTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Routing

    private func route(_ result: SearchResult) {
        switch result.destination {
        case .tool(let tool):
            route(toTool: tool)
        case .route(let r):
            dismiss()
            router.navigate(r, regular: isRegular)
        }
    }

    private func route(toTool tool: ToolKind) {
        dismiss()
        router.openTool(tool, regular: isRegular)
    }

    // MARK: - Suggestions (empty query)

    private var suggestedTools: [ToolKind] {
        [.solve, .mistakeNotebook, .vocabulary, .dictation, .classical, .knowledgeQA, .classroom, .documentQA]
    }

    /// A short "recent" mix shown when no query is typed, so the sheet never feels empty.
    private var recentRows: [SearchResult] {
        var rows: [SearchResult] = []
        rows.append(contentsOf: mistakes.prefix(2).map(SearchMapper.result(for:)))
        rows.append(contentsOf: courses.prefix(2).map(SearchMapper.result(for:)))
        rows.append(contentsOf: words.prefix(2).map(SearchMapper.result(for:)))
        return Array(rows.prefix(5))
    }

    // MARK: - Matching & grouping

    private var groupedResults: [SearchResultGroup] {
        let q = trimmed
        guard !q.isEmpty else { return [] }

        var groups: [SearchResultGroup] = []

        let toolHits = ToolKind.allCases
            .filter { $0.displayName.localizedCaseInsensitiveContains(q) }
            .map { SearchMapper.result(for: $0) }
        if !toolHits.isEmpty { groups.append(SearchResultGroup(kind: .tools, results: toolHits)) }

        let mistakeHits = mistakes
            .filter { SearchMapper.matches(q, $0.questionText, $0.correctAnswer, $0.errorReason, $0.subject.displayName) }
            .prefix(20).map(SearchMapper.result(for:))
        if !mistakeHits.isEmpty { groups.append(SearchResultGroup(kind: .mistakes, results: Array(mistakeHits))) }

        let wordHits = words
            .filter { SearchMapper.matches(q, $0.headword, $0.definition, $0.phonetic) }
            .prefix(20).map(SearchMapper.result(for:))
        if !wordHits.isEmpty { groups.append(SearchResultGroup(kind: .words, results: Array(wordHits))) }

        let courseHits = courses
            .filter { SearchMapper.matches(q, $0.title, $0.author, $0.summary, $0.dynasty) }
            .prefix(20).map(SearchMapper.result(for:))
        if !courseHits.isEmpty { groups.append(SearchResultGroup(kind: .courses, results: Array(courseHits))) }

        let docHits = documents
            .filter { SearchMapper.matches(q, $0.title, $0.summary, $0.parsedText) }
            .prefix(20).map(SearchMapper.result(for:))
        if !docHits.isEmpty { groups.append(SearchResultGroup(kind: .documents, results: Array(docHits))) }

        let kpHits = knowledgePoints
            .filter { SearchMapper.matches(q, $0.name, $0.summary, $0.chapter, $0.subject.displayName) }
            .prefix(20).map(SearchMapper.result(for:))
        if !kpHits.isEmpty { groups.append(SearchResultGroup(kind: .knowledgePoints, results: Array(kpHits))) }

        let convoHits = conversations
            .filter { SearchMapper.matches(q, $0.title, $0.sortedMessages.last?.text) }
            .prefix(20).map(SearchMapper.result(for:))
        if !convoHits.isEmpty { groups.append(SearchResultGroup(kind: .conversations, results: Array(convoHits))) }

        return groups
    }

    private var totalResultCount: Int {
        groupedResults.reduce(0) { $0 + $1.results.count }
    }
}

// MARK: - Result group

private struct SearchResultGroup: Identifiable {
    let kind: SearchGroupKind
    let results: [SearchResult]
    var id: SearchGroupKind { kind }
}

private enum SearchGroupKind: Hashable, CaseIterable {
    case tools, mistakes, words, courses, documents, knowledgePoints, conversations

    var title: String {
        switch self {
        case .tools: "工具"
        case .mistakes: "错题"
        case .words: "单词"
        case .courses: "课程"
        case .documents: "文档"
        case .knowledgePoints: "知识点"
        case .conversations: "对话"
        }
    }
    var symbol: String {
        switch self {
        case .tools: "square.grid.2x2.fill"
        case .mistakes: "book.closed.fill"
        case .words: "textformat.abc"
        case .courses: "play.tv.fill"
        case .documents: "doc.text.magnifyingglass"
        case .knowledgePoints: "point.3.connected.trianglepath.dotted"
        case .conversations: "bubble.left.and.bubble.right.fill"
        }
    }
}

// MARK: - Result row model

private struct SearchResult: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let symbol: String
    let tint: Color
    let destination: SearchDestination
}

private enum SearchDestination {
    case tool(ToolKind)
    case route(Route)
}

// MARK: - Mapping helpers (MainActor: Color.db* are MainActor)

@MainActor
private enum SearchMapper {
    /// True if any of the supplied (optional) fields contains the query, case-insensitively.
    static func matches(_ query: String, _ fields: String?...) -> Bool {
        fields.contains { ($0?.localizedCaseInsensitiveContains(query)) == true }
    }

    static func result(for tool: ToolKind) -> SearchResult {
        SearchResult(
            id: "tool-\(tool.rawValue)",
            title: tool.displayName,
            subtitle: tool.category.displayName,
            symbol: tool.symbolName,
            tint: .dbPrimary,
            destination: .tool(tool))
    }

    static func result(for item: MistakeItem) -> SearchResult {
        SearchResult(
            id: "mistake-\(item.id.uuidString)",
            title: item.questionText.isEmpty ? "错题" : item.questionText,
            subtitle: "\(item.subject.displayName) · \(item.errorType.displayName)",
            symbol: "book.closed.fill",
            tint: DBSubjectColor.color(for: item.subject),
            destination: .route(.mistakeDetail(item.id)))
    }

    static func result(for card: WordCard) -> SearchResult {
        let subtitle = card.definition.isEmpty ? card.phonetic : card.definition
        let deckID = card.deck?.id
        let destination: SearchDestination = deckID.map { .route(.wordDeck($0)) } ?? .tool(.vocabulary)
        return SearchResult(
            id: "word-\(card.id.uuidString)",
            title: card.headword.isEmpty ? "单词" : card.headword,
            subtitle: subtitle.isEmpty ? nil : subtitle,
            symbol: "textformat.abc",
            tint: .dbSecondary,
            destination: destination)
    }

    static func result(for course: CourseEntity) -> SearchResult {
        var parts: [String] = []
        if !course.author.isEmpty { parts.append(course.author) }
        if !course.dynasty.isEmpty { parts.append(course.dynasty) }
        if parts.isEmpty, !course.summary.isEmpty { parts.append(course.summary) }
        return SearchResult(
            id: "course-\(course.id.uuidString)",
            title: course.title.isEmpty ? "课程" : course.title,
            subtitle: parts.isEmpty ? course.subject.displayName : parts.joined(separator: " · "),
            symbol: course.thumbnailSymbol.isEmpty ? "play.tv.fill" : course.thumbnailSymbol,
            tint: DBSubjectColor.color(for: course.subject),
            destination: .route(.course(course.id)))
    }

    static func result(for doc: DocumentEntity) -> SearchResult {
        let subtitle = doc.summary.isEmpty
            ? "\(doc.fileType.uppercased()) · \(doc.pageCount) 页"
            : doc.summary
        return SearchResult(
            id: "doc-\(doc.id.uuidString)",
            title: doc.title.isEmpty ? "文档" : doc.title,
            subtitle: subtitle,
            symbol: "doc.text.magnifyingglass",
            tint: .dbInfo,
            destination: .route(.document(doc.id)))
    }

    static func result(for kp: KnowledgePointEntity) -> SearchResult {
        var parts: [String] = [kp.subject.displayName]
        if !kp.chapter.isEmpty { parts.append(kp.chapter) }
        return SearchResult(
            id: "kp-\(kp.id)",
            title: kp.name.isEmpty ? "知识点" : kp.name,
            subtitle: kp.summary.isEmpty ? parts.joined(separator: " · ") : kp.summary,
            symbol: "point.3.connected.trianglepath.dotted",
            tint: DBSubjectColor.color(for: kp.subject),
            destination: .route(.knowledgePoint(kp.id)))
    }

    static func result(for convo: Conversation) -> SearchResult {
        let preview = convo.sortedMessages.last?.text ?? ""
        return SearchResult(
            id: "convo-\(convo.id.uuidString)",
            title: convo.title.isEmpty ? "对话" : convo.title,
            subtitle: preview.isEmpty ? nil : preview,
            symbol: "bubble.left.and.bubble.right.fill",
            tint: .dbAccent,
            destination: .route(.conversation(convo.id)))
    }
}

#Preview {
    NavigationStack { SearchView() }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
}
