//
//  DocumentQAView.swift
//  豆包爱学 — Features/Courses/DocumentQA
//
//  文档问答 (Document Q&A) — RESEARCH F-documentQA. Wired to
//  AppSection.documents and ToolKind.documentQA.
//
//  Lists every imported `DocumentEntity` (@Query), lets the learner import a
//  new PDF / 文本 via `.fileImporter`, or open a bundled 示例文档 with one tap.
//  On import the document text is parsed and `intelligence.summarizeDocument`
//  produces 摘要 / 要点 / 大纲 which are persisted to SwiftData, so opening the
//  document later is instant. Tapping a row pushes `DocumentDetailView` via
//  `Route.document(UUID)`.
//
//  All states (空 / 加载 / 出错) are handled and the screen renders identically
//  on iOS and macOS (file import is cross-platform).
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Main list view

/// 文档问答 list screen. Pushed by the shell — does NOT wrap a NavigationStack.
struct DocumentQAView: View {
    @Environment(\.intelligence) private var intelligence
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    @Query(sort: \DocumentEntity.createdAt, order: .reverse) private var documents: [DocumentEntity]

    @State private var importing = false
    /// While a freshly imported / sample document is being summarized.
    @State private var processingTitle: String?
    @State private var importError: String?

    init() {}

    private var isRegular: Bool {
        #if os(iOS)
        sizeClass != .compact
        #else
        true
        #endif
    }

    var body: some View {
        Group {
            if documents.isEmpty && processingTitle == nil {
                emptyState
            } else {
                content
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("文档问答")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    importing = true
                } label: {
                    Label("导入文档", systemImage: "tray.and.arrow.down.fill")
                }
                .disabled(processingTitle != nil)
            }
        }
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.pdf, .plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("导入失败", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("好的", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    // MARK: States

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: DBSpacing.xl) {
                DBStateView(
                    kind: .empty,
                    title: "还没有文档",
                    message: "导入一份 PDF 或文本，豆包会帮你提炼摘要、梳理要点，还能随时追问。"
                )
                importCard
            }
            .padding(DBSpacing.screenInset)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                importCard

                if let title = processingTitle {
                    DBCard {
                        HStack(spacing: DBSpacing.md) {
                            ProgressView()
                            VStack(alignment: .leading, spacing: DBSpacing.xxs) {
                                Text("正在解析「\(title)」")
                                    .font(.dbBodyEmph)
                                    .foregroundStyle(Color.dbTextPrimary)
                                Text("豆包正在提炼摘要与要点…")
                                    .font(.dbFootnote)
                                    .foregroundStyle(Color.dbTextSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }

                if !documents.isEmpty {
                    DBSectionHeader("我的文档", subtitle: "共 \(documents.count) 份", systemImage: "doc.on.doc.fill")
                    ForEach(documents) { doc in
                        row(doc)
                    }
                }
            }
            .padding(DBSpacing.screenInset)
        }
    }

    // MARK: Import card

    private var importCard: some View {
        DBCard(fill: Color.dbSurfaceRaised) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                HStack(spacing: DBSpacing.sm) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.dbTitle2)
                        .foregroundStyle(Color.dbPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("把文档交给豆包")
                            .font(.dbHeadline)
                            .foregroundStyle(Color.dbTextPrimary)
                        Text("支持 PDF 与文本，自动生成摘要、要点和大纲")
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextSecondary)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: DBSpacing.sm) {
                    Button {
                        importing = true
                    } label: {
                        Label("导入文档", systemImage: "tray.and.arrow.down")
                    }
                    .buttonStyle(.db(.primary))
                    .disabled(processingTitle != nil)

                    Button {
                        loadSampleDocument()
                    } label: {
                        Label("用示例文档", systemImage: "sparkles")
                    }
                    .buttonStyle(.db(.secondary))
                    .disabled(processingTitle != nil)
                }
            }
        }
    }

    // MARK: Row

    private func row(_ doc: DocumentEntity) -> some View {
        Button {
            router.navigate(.document(doc.id), regular: isRegular)
        } label: {
            DBCard {
                HStack(alignment: .top, spacing: DBSpacing.md) {
                    Image(systemName: DocumentPresentation.symbol(forFileType: doc.fileType))
                        .font(.dbTitle2)
                        .foregroundStyle(Color.dbPrimary)
                        .frame(width: 40)
                    VStack(alignment: .leading, spacing: DBSpacing.xs) {
                        Text(doc.title)
                            .font(.dbBodyEmph)
                            .foregroundStyle(Color.dbTextPrimary)
                            .lineLimit(2)
                        if !doc.summary.isEmpty {
                            Text(doc.summary)
                                .font(.dbFootnote)
                                .foregroundStyle(Color.dbTextSecondary)
                                .lineLimit(2)
                        }
                        HStack(spacing: DBSpacing.sm) {
                            DBTag(DocumentPresentation.typeLabel(forFileType: doc.fileType), tint: .dbSecondary)
                            if doc.pageCount > 1 {
                                DBTag("\(doc.pageCount) 页", tint: .dbInfo)
                            }
                            if !doc.keyPoints.isEmpty {
                                DBTag("\(doc.keyPoints.count) 个要点", tint: .dbAccent)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.dbCaption.weight(.semibold))
                                .foregroundStyle(Color.dbTextTertiary)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                delete(doc)
            } label: {
                Label("删除文档", systemImage: "trash")
            }
        }
    }

    // MARK: Import handling

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let parsed = DocumentParser.parse(url: url)
            switch parsed {
            case .failure(let error):
                importError = error.message
            case .success(let parsedDoc):
                ingest(parsedDoc)
            }
        }
    }

    private func loadSampleDocument() {
        let sample = DocumentParser.sampleDocument()
        ingest(sample)
    }

    /// Insert the entity immediately (so it's persisted even if summarization is
    /// interrupted), then enrich it with the AI summary.
    private func ingest(_ parsed: ParsedDocument) {
        let entity = DocumentEntity()
        entity.title = parsed.title
        entity.fileType = parsed.fileType
        entity.pageCount = parsed.pageCount
        entity.parsedText = parsed.text
        modelContext.insert(entity)
        // Only proceed once the document is actually persisted — otherwise summarization
        // would target an entity the @Query can't see, silently losing the import.
        guard modelContext.saveLogging() else {
            modelContext.delete(entity)
            HapticEngine.play(.error)
            return
        }
        HapticEngine.play(.success)

        let targetID = entity.id
        processingTitle = parsed.title
        Task {
            await summarize(documentID: targetID, title: parsed.title, text: parsed.text)
            processingTitle = nil
        }
    }

    private func summarize(documentID: UUID, title: String, text: String) async {
        do {
            let summary = try await intelligence.summarizeDocument(
                DocSummarizeRequest(title: title, text: text)
            )
            guard let entity = documents.first(where: { $0.id == documentID }) else { return }
            entity.summary = summary.summary
            entity.keyPoints = summary.keyPoints
            entity.outline = summary.outline
            modelContext.saveLogging()
        } catch {
            // Summarization is best-effort; the detail screen can re-run it. Keep
            // the imported document so the learner never loses their file.
        }
    }

    private func delete(_ doc: DocumentEntity) {
        modelContext.delete(doc)
        modelContext.saveLogging()
        HapticEngine.play(.light)
    }
}

// MARK: - Previews

#Preview("文档列表") {
    NavigationStack { DocumentQAView() }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
}
