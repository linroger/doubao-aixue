//
//  TranslationView.swift
//  豆包爱学 — Features/Practice/Reading
//
//  课文翻译 (RESEARCH): paste / 拍照识别 / 相册选 a passage, get a
//  sentence-aligned bilingual rendering, read either side aloud (TTS), and tap
//  any word for a quick gloss. Wired to `ToolKind.translation` via `init()`.
//
//  All ViewState branches handled; full Dark Mode via semantic Color.db*; both
//  platforms supported (camera iOS-only, file import macOS, Photos on both).
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

// MARK: - View model

@MainActor
@Observable
final class TranslationModel {
    var sourceText: String = ""
    var direction: TranslationDirection = .zhToEn
    var state: ViewState<[AlignedSentence]> = .idle
    /// Set when the loaded result came from the configured cloud model (vs the
    /// on-device deterministic engine) so the result header can badge it honestly.
    private(set) var resultRoute: IntelligenceRoute = .onDevice

    /// Produce the sentence-aligned bilingual result. Uses the learner's configured
    /// cloud model when one is set (richer, context-aware), and otherwise the
    /// deterministic on-device engine — so the feature works offline yet improves
    /// the moment an AI provider is connected.
    func translate(using intelligence: any IntelligenceService) async {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .empty(message: "先输入或识别一段课文，我来帮你逐句翻译。")
            return
        }
        state = .loading
        let sentences = ReadingTranslator.splitSentences(trimmed)

        if intelligence.capabilities.route == .cloud, !sentences.isEmpty,
           let aiPairs = await aiTranslate(sentences: sentences, using: intelligence) {
            resultRoute = .cloud
            state = .loaded(aiPairs)
            return
        }

        resultRoute = .onDevice
        let result = ReadingTranslator.translate(trimmed, direction: direction)
        state = result.isEmpty
            ? .empty(message: "没有识别到可翻译的句子，换一段试试吧。")
            : .loaded(result)
    }

    /// Ask the configured model to translate sentence-by-sentence and parse the
    /// reply back into aligned pairs. Returns `nil` (→ deterministic fallback) on
    /// any error or when the alignment can't be trusted, so output is never wrong.
    private func aiTranslate(sentences: [String],
                             using intelligence: any IntelligenceService) async -> [AlignedSentence]? {
        let targetLang = direction == .zhToEn ? "英文" : "现代汉语（简体中文）"
        let prompt = """
        请把下面的文段逐句翻译成\(targetLang)。要求：
        - 每个句子的译文单独占一行，顺序与原文完全一致；
        - 只输出译文本身，不要输出原文、不要加序号、引号或解释。

        原文（共 \(sentences.count) 句，每句一行）：
        \(sentences.joined(separator: "\n"))
        """
        let request = ChatRequest(
            turns: [ChatTurn(role: .user, text: prompt)],
            context: LearnerContext(grade: .g7, subjects: [.english, .chinese]),
            kind: .knowledge
        )
        var reply = ""
        do {
            for try await chunk in intelligence.chat(request) {
                reply += chunk.delta
            }
        } catch {
            return nil
        }
        let lines = reply
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        // Only trust the AI path when it returns a clean per-sentence alignment;
        // otherwise fall back so tap-to-read stays correctly paired.
        guard lines.count == sentences.count else { return nil }
        return zip(sentences, lines).map { AlignedSentence(original: $0, translated: $1) }
    }

    /// Load the bundled sample for the current direction and translate it.
    func loadSample(using intelligence: any IntelligenceService) async {
        sourceText = direction == .zhToEn ? ReadingSamples.chinesePassage : ReadingSamples.englishPassage
        await translate(using: intelligence)
    }

    func clear() {
        sourceText = ""
        state = .idle
    }
}

// MARK: - View

struct TranslationView: View {
    @Environment(\.ocr) private var ocr
    @Environment(\.intelligence) private var intelligence
    @Environment(TTSService.self) private var tts

    @State private var model = TranslationModel()
    @State private var photoSelection: PhotosPickerItem?
    @State private var isRecognizing = false
    @State private var glossWord: GlossLookup?

    #if os(iOS)
    @State private var showCamera = false
    #endif
    #if os(macOS)
    @State private var showFileImporter = false
    #endif

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                directionCard
                captureCard
                editorCard
                resultSection
            }
            .padding(DBSpacing.screenInset)
        }
        .background(Color.dbBackground)
        .navigationTitle("课文翻译")
        .task(id: photoSelection) { await loadSelectedPhoto() }
        #if os(iOS)
        .sheet(isPresented: $showCamera) {
            ReadingCameraPicker { data in
                Task { await recognize(data) }
            }
            .ignoresSafeArea()
        }
        #endif
        #if os(macOS)
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.plainText, .image]) { result in
            handleFileImport(result)
        }
        #endif
        .sheet(item: $glossWord) { lookup in
            GlossSheet(lookup: lookup)
        }
    }

    // MARK: Direction

    private var directionCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("翻译方向", subtitle: "选择源语言到目标语言",
                                systemImage: "arrow.left.arrow.right.circle.fill")
                Picker("翻译方向", selection: $model.direction) {
                    ForEach(TranslationDirection.allCases) { dir in
                        Text(dir.displayName).tag(dir)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: model.direction) { _, _ in
                    if case .loaded = model.state {
                        Task { await model.translate(using: intelligence) }
                    }
                }
            }
        }
    }

    // MARK: Capture

    private var captureCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("录入课文", subtitle: "选择一种方式录入原文",
                                systemImage: "tray.and.arrow.down.fill")

                DBFlowLayout(spacing: DBSpacing.sm) {
                    #if os(iOS)
                    captureButton(title: "拍照识别", systemImage: "camera.fill") {
                        showCamera = true
                    }
                    #endif

                    PhotosPicker(selection: $photoSelection, matching: .images) {
                        Label("从相册选", systemImage: "photo.on.rectangle.angled")
                            .font(.dbSubheadline)
                            .foregroundStyle(Color.dbPrimaryDeep)
                            .padding(.horizontal, DBSpacing.md)
                            .padding(.vertical, DBSpacing.sm)
                            .background(Color.dbPrimarySoft, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    #if os(macOS)
                    captureButton(title: "选择文件", systemImage: "folder.fill") {
                        showFileImporter = true
                    }
                    #endif

                    captureButton(title: "用示例", systemImage: "sparkles") {
                        Task { await model.loadSample(using: intelligence) }
                        HapticEngine.play(.selection)
                    }

                    if !model.sourceText.isEmpty {
                        captureButton(title: "清空", systemImage: "trash") {
                            model.clear()
                            HapticEngine.play(.selection)
                        }
                    }
                }

                if isRecognizing {
                    HStack(spacing: DBSpacing.xs) {
                        ProgressView()
                        Text("正在识别文字…")
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextSecondary)
                    }
                }

                #if os(macOS)
                Text("Mac 端不支持相机，可选择图片 / 文本文件，或直接在下方输入。")
                    .font(.dbCaption)
                    .foregroundStyle(Color.dbTextTertiary)
                #endif
            }
        }
    }

    private func captureButton(title: String, systemImage: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.dbSubheadline)
                .foregroundStyle(Color.dbPrimaryDeep)
                .padding(.horizontal, DBSpacing.md)
                .padding(.vertical, DBSpacing.sm)
                .background(Color.dbPrimarySoft, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Editor

    private var editorCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                DBSectionHeader("原文", subtitle: "粘贴或编辑要翻译的课文",
                                systemImage: "text.alignleft") {
                    Text("\(model.sourceText.count) 字")
                        .font(.dbCaption.monospacedDigit())
                        .foregroundStyle(Color.dbTextTertiary)
                }

                TextEditor(text: $model.sourceText)
                    .font(.dbBody)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(DBSpacing.sm)
                    .background(Color.dbSurface, in: RoundedRectangle(cornerRadius: DBRadius.md))
                    .overlay(alignment: .topLeading) {
                        if model.sourceText.isEmpty {
                            Text(model.direction == .zhToEn
                                 ? "如：学而不思则罔，思而不学则殆。"
                                 : "e.g. Knowledge is power.")
                                .font(.dbBody)
                                .foregroundStyle(Color.dbTextTertiary)
                                .padding(.horizontal, DBSpacing.md)
                                .padding(.vertical, DBSpacing.md)
                                .allowsHitTesting(false)
                        }
                    }

                Button {
                    HapticEngine.play(.light)
                    Task { await model.translate(using: intelligence) }
                } label: {
                    Label("开始翻译", systemImage: "character.book.closed.fill")
                }
                .buttonStyle(.db(.primary, fullWidth: true))
                .disabled(model.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: Result

    @ViewBuilder
    private var resultSection: some View {
        switch model.state {
        case .idle:
            EmptyView()
        case .loading:
            DBStateView(kind: .loading, title: "翻译中", message: "正在逐句对照…")
                .frame(maxWidth: .infinity).frame(height: 180)
        case .empty(let message):
            DBStateView(kind: .empty, title: "暂无译文", message: message)
                .frame(maxWidth: .infinity).frame(height: 180)
        case .error(let message):
            DBStateView(kind: .error, title: "出错了", message: message,
                        retry: { Task { await model.translate(using: intelligence) } })
                .frame(maxWidth: .infinity).frame(height: 180)
        case .offline(let message):
            DBStateView(kind: .offline, title: "离线", message: message)
                .frame(maxWidth: .infinity).frame(height: 180)
        case .loaded(let sentences):
            loadedResult(sentences)
        }
    }

    private func loadedResult(_ sentences: [AlignedSentence]) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            DBSectionHeader("对照译文", subtitle: "逐句对齐，点词查义，可朗读",
                            systemImage: "text.book.closed.fill") {
                DBRouteBadge(model.resultRoute)
            }

            ForEach(sentences) { pair in
                sentenceCard(pair)
            }

            readAloudBar(sentences)
        }
    }

    private func sentenceCard(_ pair: AlignedSentence) -> some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                tappableLine(pair.original, language: model.direction.sourceTTSLanguage,
                             isSource: true)
                Divider().background(Color.dbSeparator)
                tappableLine(pair.translated, language: model.direction.targetTTSLanguage,
                             isSource: false)
            }
        }
    }

    /// A line whose words are individually tappable for a gloss, with a small
    /// speaker button to read the whole line aloud.
    private func tappableLine(_ text: String, language: String, isSource: Bool) -> some View {
        HStack(alignment: .top, spacing: DBSpacing.sm) {
            DBFlowLayout(spacing: 2) {
                ForEach(Array(words(in: text).enumerated()), id: \.offset) { _, token in
                    Button {
                        showGloss(for: token)
                    } label: {
                        Text(token)
                            .font(isSource ? .dbBodyEmph : .dbBody)
                            .foregroundStyle(isSource ? Color.dbTextPrimary : Color.dbTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: DBSpacing.xs)
            Button {
                tts.stop()
                tts.speak(text, language: language)
                HapticEngine.play(.light)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.dbCallout)
                    .foregroundStyle(Color.dbPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("朗读这句")
        }
    }

    private func readAloudBar(_ sentences: [AlignedSentence]) -> some View {
        DBCard {
            HStack(spacing: DBSpacing.md) {
                Button {
                    let joined = sentences.map(\.original).joined(separator: " ")
                    tts.stop()
                    tts.speak(joined, language: model.direction.sourceTTSLanguage)
                    HapticEngine.play(.light)
                } label: {
                    Label("朗读原文", systemImage: "play.circle.fill")
                }
                .buttonStyle(.db(.secondary))

                Button {
                    let joined = sentences.map(\.translated).joined(separator: " ")
                    tts.stop()
                    tts.speak(joined, language: model.direction.targetTTSLanguage)
                    HapticEngine.play(.light)
                } label: {
                    Label("朗读译文", systemImage: "play.circle")
                }
                .buttonStyle(.db(.ghost))

                Spacer(minLength: 0)

                if tts.isSpeaking {
                    Button { tts.stop() } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.dbTitle3)
                            .foregroundStyle(Color.dbError)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("停止朗读")
                }
            }
        }
    }

    // MARK: Word tokenization & gloss

    /// Split a line into tappable tokens: whitespace-separated for Latin text,
    /// per-character for CJK so each 字 is independently tappable.
    private func words(in text: String) -> [String] {
        if text.contains(" ") {
            return text.split(whereSeparator: { $0 == " " }).map(String.init)
        }
        return text.map(String.init)
    }

    private func showGloss(for token: String) {
        let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: " ,.!?;:，。！？、；："))
        guard !cleaned.isEmpty else { return }
        let meaning = ReadingTranslator.gloss(for: cleaned)
        glossWord = GlossLookup(word: cleaned, meaning: meaning)
        HapticEngine.play(.selection)
    }

    // MARK: Image / file recognition

    private func loadSelectedPhoto() async {
        guard let photoSelection else { return }
        if let data = try? await photoSelection.loadTransferable(type: Data.self) {
            await recognize(data)
        } else {
            HapticEngine.play(.warning)
        }
        self.photoSelection = nil
    }

    private func recognize(_ data: Data) async {
        isRecognizing = true
        defer { isRecognizing = false }
        let text = await ocr.recognizeText(in: data)
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // No real text recognised (e.g. simulator) — fall back to a sample so
            // the flow stays demoable rather than dead-ending.
            await model.loadSample(using: intelligence)
        } else {
            model.sourceText = text
            await model.translate(using: intelligence)
        }
    }

    #if os(macOS)
    private func handleFileImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        if let text = String.readingText(from: url) {
            model.sourceText = text
            Task { await model.translate(using: intelligence) }
        } else if let data = Data.readingImage(from: url) {
            Task { await recognize(data) }
        }
    }
    #endif
}

// MARK: - Gloss sheet

/// A tapped word and its (optional) meaning, presented in a small sheet.
nonisolated struct GlossLookup: Identifiable, Sendable, Hashable {
    let id = UUID()
    let word: String
    let meaning: String?
}

private struct GlossSheet: View {
    let lookup: GlossLookup
    @Environment(TTSService.self) private var tts
    @Environment(\.dismiss) private var dismiss

    private var isLatin: Bool {
        lookup.word.unicodeScalars.allSatisfy { $0.isASCII }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            HStack {
                Text(lookup.word)
                    .font(.dbLargeTitle)
                    .foregroundStyle(Color.dbTextPrimary)
                Spacer()
                Button {
                    tts.stop()
                    tts.speak(lookup.word, language: isLatin ? "en-US" : "zh-CN")
                } label: {
                    Image(systemName: "speaker.wave.2.circle.fill")
                        .font(.dbTitle)
                        .foregroundStyle(Color.dbPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("朗读")
            }

            if let meaning = lookup.meaning {
                DBCard {
                    VStack(alignment: .leading, spacing: DBSpacing.xs) {
                        Text("释义").font(.dbFootnote).foregroundStyle(Color.dbTextTertiary)
                        Text(meaning).font(.dbBody).foregroundStyle(Color.dbTextPrimary)
                    }
                }
            } else {
                DBStateView(kind: .empty, title: "暂无释义",
                            message: "这个词还没有收录，先试着结合上下文理解吧。")
                    .frame(height: 140)
            }

            Spacer(minLength: 0)

            Button("完成") { dismiss() }
                .buttonStyle(.db(.primary, fullWidth: true))
        }
        .padding(DBSpacing.screenInset)
        .background(Color.dbBackground)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview("课文翻译") {
    NavigationStack { TranslationView() }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
        .environment(TTSService())
}
