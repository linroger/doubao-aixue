//
//  WordDeckReviewView.swift
//  豆包爱学 — Features/Practice/Vocabulary
//
//  背单词 复习 (RESEARCH F35). The flashcard surface pushed from VocabularyView via
//  Route.wordDeck(UUID). Two modes share one deck:
//   • 闪卡 (flashcards): a swipeable stack of due cards. Tap to flip (英 → 释义/例句),
//     hear the headword via TTS "en-US", then self-rate (不会/模糊/会/简单). The
//     ReviewGrade drives SRSScheduler.update on the card's SM-2 fields and remaps
//     mastery; everything is persisted to SwiftData immediately. A progress ring
//     tracks how many of today's due cards are done.
//   • 小测 (quiz): a quick multiple-choice round built from the deck (definition →
//     pick the headword) with instant right/wrong feedback and a score summary.
//
//  Pushed view: no NavigationStack here — sets .navigationTitle and returns content.
//  Full Dark Mode via semantic Color.db*; TTS is en-US; both platforms supported
//  (no camera/Pencil needed). All states handled (missing deck / empty / caught-up).
//

import SwiftUI
import SwiftData

struct WordDeckReviewView: View {
    let deckID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(TTSService.self) private var tts
    @Query(sort: \WordDeck.createdAt, order: .forward) private var decks: [WordDeck]

    @State private var mode: ReviewMode = .flashcards

    init(deckID: UUID) { self.deckID = deckID }

    private var deck: WordDeck? { decks.first { $0.id == deckID } }

    /// Navigation title: the deck name when present, else a generic fallback.
    private var title: String {
        if let name = deck?.name, !name.isEmpty { return name }
        return "背单词"
    }

    var body: some View {
        Group {
            if let deck {
                content(for: deck)
            } else {
                DBStateView(kind: .empty,
                            title: "单词本不存在",
                            message: "它可能已被移除，换一本继续背吧。",
                            systemImage: "character.book.closed")
            }
        }
        .background(Color.dbBackground)
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("模式", selection: $mode) {
                    ForEach(ReviewMode.allCases) { m in
                        Label(m.displayName, systemImage: m.symbolName).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
        }
    }

    @ViewBuilder
    private func content(for deck: WordDeck) -> some View {
        let cards = deck.cards ?? []
        if cards.isEmpty {
            DBStateView(kind: .empty,
                        title: "这本还没有单词",
                        message: "课本单元同步后，这里就会出现要背的单词。",
                        systemImage: "tray")
        } else {
            switch mode {
            case .flashcards:
                FlashcardReviewSurface(deck: deck)
                    .id(deck.id)                 // reset session if the deck changes
            case .quiz:
                QuizSurface(deck: deck)
                    .id(deck.id)
            }
        }
    }
}

// MARK: - Review mode

private enum ReviewMode: String, CaseIterable, Identifiable {
    case flashcards, quiz
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .flashcards: "闪卡"
        case .quiz: "小测"
        }
    }
    var symbolName: String {
        switch self {
        case .flashcards: "rectangle.on.rectangle.angled"
        case .quiz: "checklist"
        }
    }
}

// MARK: - Flashcard review surface

/// The swipeable flashcard session for one deck. Pulls the cards due today (falling
/// back to the whole deck when nothing is due so the screen is never a dead end),
/// shows them one at a time, and applies an SRS update + mastery remap on each
/// self-rating before advancing. Owns only transient session state; the durable SRS
/// fields live on the SwiftData `WordCard`.
private struct FlashcardReviewSurface: View {
    let deck: WordDeck

    @Environment(\.modelContext) private var modelContext
    @Environment(TTSService.self) private var tts

    @State private var queue: [WordCard] = []
    @State private var index = 0
    @State private var flipped = false
    @State private var reviewedCount = 0
    @State private var loggedSession = false
    @State private var dragOffset: CGSize = .zero

    /// Snapshot of how many cards this session started with — denominator of the ring.
    @State private var sessionTotal = 0

    private var currentCard: WordCard? {
        guard index < queue.count else { return nil }
        return queue[index]
    }

    private var progress: Double {
        guard sessionTotal > 0 else { return 0 }
        return min(1, Double(reviewedCount) / Double(sessionTotal))
    }

    var body: some View {
        Group {
            if let card = currentCard {
                session(card)
            } else {
                completed
            }
        }
        .onAppear { buildQueueIfNeeded() }
    }

    // MARK: Session

    private func session(_ card: WordCard) -> some View {
        VStack(spacing: DBSpacing.lg) {
            header
            Spacer(minLength: 0)
            cardFace(card)
                .offset(dragOffset)
                .rotationEffect(.degrees(Double(dragOffset.width / 18)))
                .gesture(swipeGesture(for: card))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: index)
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: flipped)
            Spacer(minLength: 0)
            controls(for: card)
        }
        .padding(DBSpacing.screenInset)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack(spacing: DBSpacing.md) {
            DBProgressRing(progress: progress,
                           lineWidth: 7,
                           tint: .dbPrimary,
                           label: "\(reviewedCount)/\(sessionTotal)")
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("第 \(min(index + 1, queue.count)) / \(queue.count) 张")
                    .font(.dbHeadline)
                    .foregroundStyle(Color.dbTextPrimary)
                Text("点卡片翻面，再如实评价掌握程度")
                    .font(.dbCaption)
                    .foregroundStyle(Color.dbTextSecondary)
            }
            Spacer()
        }
    }

    private func cardFace(_ card: WordCard) -> some View {
        Button {
            withAnimation { flipped.toggle() }
            HapticEngine.play(.selection)
        } label: {
            DBCard(elevation: .high) {
                VStack(spacing: DBSpacing.md) {
                    HStack {
                        DBTag(card.mastery.displayName,
                              tint: VocabPresentation.masteryTint(card.mastery))
                        Spacer()
                        Image(systemName: flipped ? "arrow.uturn.backward" : "hand.tap.fill")
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextTertiary)
                    }

                    Spacer(minLength: DBSpacing.sm)

                    if flipped {
                        backContent(card)
                    } else {
                        frontContent(card)
                    }

                    Spacer(minLength: DBSpacing.sm)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 240)
            }
        }
        .buttonStyle(.plain)
    }

    private func frontContent(_ card: WordCard) -> some View {
        VStack(spacing: DBSpacing.sm) {
            Text(card.headword)
                .font(.dbLargeTitle)
                .foregroundStyle(Color.dbTextPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            if !card.phonetic.isEmpty {
                Text(card.phonetic)
                    .font(.dbMonoBody)
                    .foregroundStyle(Color.dbTextSecondary)
            }
            Button {
                speak(card.headword)
            } label: {
                Label("朗读", systemImage: "speaker.wave.2.fill")
            }
            .buttonStyle(.db(.ghost))
        }
    }

    private func backContent(_ card: WordCard) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            HStack(spacing: DBSpacing.sm) {
                Text(card.headword)
                    .font(.dbTitle2)
                    .foregroundStyle(Color.dbTextPrimary)
                if !card.phonetic.isEmpty {
                    Text(card.phonetic)
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextTertiary)
                }
                Spacer()
                Button {
                    speak(card.headword)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.dbBody)
                        .foregroundStyle(Color.dbPrimary)
                }
                .buttonStyle(.plain)
            }
            Divider().overlay(Color.dbSeparator)
            Text(card.definition.isEmpty ? "（暂无释义）" : card.definition)
                .font(.dbBodyEmph)
                .foregroundStyle(Color.dbTextPrimary)
            if !card.examples.isEmpty {
                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Label("例句", systemImage: "text.quote")
                        .font(.dbCaption.weight(.semibold))
                        .foregroundStyle(Color.dbTextSecondary)
                    ForEach(Array(card.examples.enumerated()), id: \.offset) { _, ex in
                        Text(ex)
                            .font(.dbCallout)
                            .foregroundStyle(Color.dbTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Controls

    @ViewBuilder
    private func controls(for card: WordCard) -> some View {
        if flipped {
            VStack(spacing: DBSpacing.sm) {
                Text("还记得这个词吗？如实选择，下次复习时间会自动调整")
                    .font(.dbCaption)
                    .foregroundStyle(Color.dbTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                HStack(spacing: DBSpacing.sm) {
                    ForEach(ReviewGrade.allCases, id: \.rawValue) { grade in
                        gradeButton(grade, for: card)
                    }
                }
            }
        } else {
            Button {
                withAnimation { flipped = true }
            } label: {
                Label("翻面看释义", systemImage: "rectangle.portrait.rotate")
            }
            .buttonStyle(.db(.secondary, fullWidth: true))
        }
    }

    private func gradeButton(_ grade: ReviewGrade, for card: WordCard) -> some View {
        let tint = VocabPresentation.gradeTint(grade)
        return Button {
            rate(card, grade: grade)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: VocabPresentation.gradeSymbol(grade))
                    .font(.dbBody)
                Text(grade.displayName)
                    .font(.dbCaption.weight(.semibold))
                Text(VocabPresentation.intervalPreview(for: card, grade: grade))
                    .font(.dbCaption2)
                    .foregroundStyle(Color.dbTextTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DBSpacing.sm)
            .background(tint.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                    .strokeBorder(tint.opacity(0.4), lineWidth: 1)
            )
            .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }

    // MARK: Completed

    private var completed: some View {
        VStack(spacing: DBSpacing.lg) {
            DBMascot(mood: .cheering, size: 96)
            Text("这一轮复习完成啦！")
                .font(.dbTitle2)
                .foregroundStyle(Color.dbTextPrimary)
            Text(reviewedCount > 0
                 ? "本轮复习了 \(reviewedCount) 张卡片，坚持就是胜利。"
                 : "这本暂时没有到复习时间的卡片，明天再来吧。")
                .font(.dbBody)
                .foregroundStyle(Color.dbTextSecondary)
                .multilineTextAlignment(.center)
            DBValueStat(value: "\(deck.dueCount)",
                        caption: "剩余待复习",
                        systemImage: "bell.badge.fill",
                        tint: deck.dueCount > 0 ? .dbWarning : .dbSuccess)
            if deck.dueCount > 0 {
                Button {
                    restart()
                } label: {
                    Label("继续复习剩余 \(deck.dueCount) 张", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.db(.primary, fullWidth: true))
            }
        }
        .padding(DBSpacing.screenInset)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .onAppear(perform: logSessionIfNeeded)
    }

    /// Count this review session's cards toward the 答题足迹 contribution heatmap, once.
    private func logSessionIfNeeded() {
        guard !loggedSession, reviewedCount > 0 else { return }
        loggedSession = true
        ActivityRecorder.log(
            modelContext, kind: .vocabulary, subject: deck.subject,
            questions: reviewedCount, detail: "背单词 · \(deck.name)")
    }

    // MARK: Logic

    /// Build the session queue once: cards due now, sorted soonest-first. When nothing
    /// is due we still offer the whole deck so the learner can pre-study.
    private func buildQueueIfNeeded() {
        guard queue.isEmpty, sessionTotal == 0 else { return }
        let all = deck.cards ?? []
        let now = Date()
        let due = all.filter { $0.dueDate <= now }.sorted { $0.dueDate < $1.dueDate }
        let session = due.isEmpty ? all.sorted { $0.dueDate < $1.dueDate } : due
        queue = session
        sessionTotal = session.count
    }

    private func restart() {
        index = 0
        flipped = false
        reviewedCount = 0
        loggedSession = false
        sessionTotal = 0
        queue = []
        dragOffset = .zero
        buildQueueIfNeeded()
    }

    /// Apply the self-rating: update the card's SM-2 state, remap mastery, persist,
    /// then advance to the next card.
    private func rate(_ card: WordCard, grade: ReviewGrade) {
        let state = SRSState(easeFactor: card.easeFactor,
                             intervalDays: card.intervalDays,
                             repetitions: card.repetitions,
                             dueDate: card.dueDate)
        let next = SRSScheduler.update(state, grade: grade)
        card.easeFactor = next.easeFactor
        card.intervalDays = next.intervalDays
        card.repetitions = next.repetitions
        card.dueDate = next.dueDate
        card.mastery = SRSScheduler.mastery(forInterval: next.intervalDays)
        modelContext.saveLogging()

        reviewedCount += 1
        HapticEngine.play(grade == .again ? .warning : .success)
        advance()
    }

    private func advance() {
        flipped = false
        dragOffset = .zero
        withAnimation { index += 1 }
    }

    private func speak(_ word: String) {
        guard !word.isEmpty else { return }
        tts.speak(word, language: "en-US", rate: VocabPresentation.speakRate)
    }

    /// A horizontal swipe is a shortcut: right = 会 (good), left = 不会 (again). Only
    /// active once flipped so the learner has seen the answer.
    private func swipeGesture(for card: WordCard) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard flipped else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard flipped else { dragOffset = .zero; return }
                let threshold: CGFloat = 110
                if value.translation.width > threshold {
                    rate(card, grade: .good)
                } else if value.translation.width < -threshold {
                    rate(card, grade: .again)
                } else {
                    withAnimation { dragOffset = .zero }
                }
            }
    }
}

// MARK: - Quiz surface

/// A short multiple-choice round (definition → pick the headword) built by the pure
/// `VocabQuizBuilder`. Gives immediate right/wrong feedback per question and a score
/// summary at the end. Read-only — it doesn't touch SRS state, it's a confidence
/// check that complements the flashcard review.
private struct QuizSurface: View {
    let deck: WordDeck

    @State private var questions: [VocabQuizQuestion] = []
    @State private var index = 0
    @State private var selected: String?
    @State private var correctCount = 0
    @State private var finished = false

    private var current: VocabQuizQuestion? {
        guard index < questions.count else { return nil }
        return questions[index]
    }

    var body: some View {
        Group {
            if questions.isEmpty {
                DBStateView(kind: .empty,
                            title: "暂时无法出题",
                            message: "这本单词太少啦，先去闪卡多背几个词再来小测。",
                            systemImage: "questionmark.circle")
            } else if finished {
                summary
            } else if let q = current {
                quiz(q)
            } else {
                summary
            }
        }
        .onAppear(perform: buildIfNeeded)
    }

    private func quiz(_ q: VocabQuizQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                HStack {
                    Text("第 \(index + 1) / \(questions.count) 题")
                        .font(.dbHeadline)
                        .foregroundStyle(Color.dbTextPrimary)
                    Spacer()
                    DBValueStat(value: "\(correctCount)",
                                caption: "答对",
                                systemImage: "checkmark.seal.fill",
                                tint: .dbSuccess)
                }
                ProgressView(value: Double(index), total: Double(questions.count))
                    .tint(.dbPrimary)

                DBCard(elevation: .medium) {
                    VStack(alignment: .leading, spacing: DBSpacing.xs) {
                        Text("根据释义选出正确的单词")
                            .font(.dbCaption)
                            .foregroundStyle(Color.dbTextTertiary)
                        Text(q.prompt)
                            .font(.dbTitle3)
                            .foregroundStyle(Color.dbTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(spacing: DBSpacing.sm) {
                    ForEach(q.options, id: \.self) { option in
                        optionButton(option, in: q)
                    }
                }

                if selected != nil {
                    Button {
                        next()
                    } label: {
                        Label(index + 1 == questions.count ? "查看结果" : "下一题",
                              systemImage: "arrow.right")
                    }
                    .buttonStyle(.db(.primary, fullWidth: true))
                }
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    private func optionButton(_ option: String, in q: VocabQuizQuestion) -> some View {
        let isPicked = selected == option
        let answered = selected != nil
        let isAnswer = q.isCorrect(option)
        // Color logic: after answering, the right option turns green and a wrong pick
        // turns red; before answering everything is neutral.
        let tint: Color = {
            guard answered else { return .dbTextPrimary }
            if isAnswer { return .dbSuccess }
            if isPicked { return .dbError }
            return .dbTextTertiary
        }()
        let fill: Color = {
            guard answered else { return .dbSurface }
            if isAnswer { return .dbSuccessSoft }
            if isPicked { return .dbErrorSoft }
            return .dbSurface
        }()
        return Button {
            guard selected == nil else { return }
            selected = option
            if isAnswer {
                correctCount += 1
                HapticEngine.play(.success)
            } else {
                HapticEngine.play(.error)
            }
        } label: {
            HStack(spacing: DBSpacing.sm) {
                Text(option)
                    .font(.dbBodyEmph)
                    .foregroundStyle(tint)
                Spacer()
                if answered, isAnswer {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(tint)
                } else if answered, isPicked {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(tint)
                }
            }
            .padding(DBSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                    .strokeBorder(answered && (isAnswer || isPicked) ? tint.opacity(0.5) : Color.dbSeparator,
                                  lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(answered)
    }

    private var summary: some View {
        let total = max(questions.count, 1)
        let ratio = Double(correctCount) / Double(total)
        return VStack(spacing: DBSpacing.lg) {
            DBMascot(mood: ratio >= 0.8 ? .cheering : (ratio >= 0.5 ? .happy : .thinking), size: 96)
            DBProgressRing(progress: ratio,
                           lineWidth: 12,
                           tint: ratio >= 0.6 ? .dbSuccess : .dbWarning,
                           label: "\(correctCount)/\(questions.count)")
                .frame(width: 120, height: 120)
            Text(summaryTitle(ratio))
                .font(.dbTitle2)
                .foregroundStyle(Color.dbTextPrimary)
            Text("答对 \(correctCount) 题，共 \(questions.count) 题。")
                .font(.dbBody)
                .foregroundStyle(Color.dbTextSecondary)
            Button {
                restart()
            } label: {
                Label("再测一次", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.db(.primary, fullWidth: true))
        }
        .padding(DBSpacing.screenInset)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    private func summaryTitle(_ ratio: Double) -> String {
        switch ratio {
        case 0.8...: "太厉害了！"
        case 0.5..<0.8: "不错，继续加油！"
        default: "再多背背就更稳啦"
        }
    }

    // MARK: Logic

    private func buildIfNeeded() {
        guard questions.isEmpty else { return }
        questions = VocabQuizBuilder.makeQuestions(from: deck.cards ?? [], limit: 8)
    }

    private func next() {
        selected = nil
        if index + 1 == questions.count {
            finished = true
        } else {
            withAnimation { index += 1 }
        }
    }

    private func restart() {
        index = 0
        selected = nil
        correctCount = 0
        finished = false
        questions = []
        buildIfNeeded()
    }
}

// MARK: - Preview

/// Resolves the first seeded deck's id so the flashcard/quiz surfaces render with
/// real data in previews (the view itself only takes a UUID, matching its route init).
private struct WordDeckReviewPreview: View {
    @Query(sort: \WordDeck.createdAt, order: .forward) private var decks: [WordDeck]
    var body: some View {
        if let id = decks.first?.id {
            WordDeckReviewView(deckID: id)
        } else {
            WordDeckReviewView(deckID: UUID())
        }
    }
}

#Preview("背单词 · 复习") {
    NavigationStack {
        WordDeckReviewPreview()
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}

#Preview("背单词 · 单词本不存在") {
    NavigationStack {
        WordDeckReviewView(deckID: UUID())
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}
