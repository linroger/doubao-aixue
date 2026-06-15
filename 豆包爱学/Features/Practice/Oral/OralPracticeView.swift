//
//  OralPracticeView.swift
//  豆包爱学 — Features/Practice/Oral
//
//  英语口语 / 口语陪练 (F36). A scenario picker leading into a call-style screen:
//  Doubao (the chosen persona) speaks an English line aloud (TTS, "en-US/GB"),
//  the student holds the mic to reply (SpeechRecognitionCoordinator), live
//  subtitles appear, and `intelligence.scorePronunciation` returns accuracy /
//  fluency / completeness gauges (DBProgressRing) plus a per-word colour heatmap.
//  Common spoken slips surface as wrong→right correction bubbles.
//
//  Wired to ToolKind.oral. Pushed by the shell → no self-wrapped NavigationStack.
//

import SwiftUI
import SwiftData

// MARK: - Per-turn result

/// The graded outcome of one spoken reply, retained so the call screen can show
/// gauges + heatmap and let the student re-record.
@MainActor
@Observable
final class OralTurnResult {
    let said: String
    let score: PronunciationScore
    let correction: OralCorrection?

    init(said: String, score: PronunciationScore, correction: OralCorrection?) {
        self.said = said
        self.score = score
        self.correction = correction
    }
}

// MARK: - View model

/// Drives the call: which scenario/persona is active, the current turn, the live
/// transcript, the most recent grading, and the running average score. UI state
/// only — nothing is persisted (口语陪练 is ephemeral practice).
@MainActor
@Observable
final class OralPracticeModel {
    /// `nil` means the picker is showing; non-nil means a call is in progress.
    var scenario: OralScenario?
    var avatar: OralAvatar = .default

    var turnIndex = 0
    /// Grading state for the *current* turn.
    var grading: ViewState<OralTurnResult> = .idle
    /// Live subtitle text shown while the mic is held.
    var liveSubtitle = ""

    /// Per-turn best scores collected this session (for the closing summary).
    private(set) var sessionScores: [Double] = []

    var turns: [OralTurnScript] { scenario?.turns ?? [] }
    var currentTurn: OralTurnScript? {
        guard turnIndex >= 0, turnIndex < turns.count else { return nil }
        return turns[turnIndex]
    }
    var isFinished: Bool { scenario != nil && turnIndex >= turns.count }

    var sessionAverage: Double {
        guard !sessionScores.isEmpty else { return 0 }
        return sessionScores.reduce(0, +) / Double(sessionScores.count)
    }

    // MARK: Lifecycle

    func start(_ scenario: OralScenario) {
        self.scenario = scenario
        turnIndex = 0
        grading = .idle
        liveSubtitle = ""
        sessionScores = []
    }

    func exitToPicker() {
        scenario = nil
        turnIndex = 0
        grading = .idle
        liveSubtitle = ""
        sessionScores = []
    }

    func advance() {
        guard !isFinished else { return }
        if let best = currentBestScore { sessionScores.append(best) }
        turnIndex += 1
        grading = .idle
        liveSubtitle = ""
    }

    func retryTurn() {
        grading = .idle
        liveSubtitle = ""
    }

    func restart() {
        guard let scenario else { return }
        start(scenario)
    }

    private var currentBestScore: Double? {
        if case let .loaded(result) = grading { return result.score.overall }
        return nil
    }

    // MARK: Grading

    /// Score `spoken` against the current turn's suggested reply and surface any
    /// known correction. Pure async call into the injected intelligence service.
    func grade(spoken: String, using intelligence: any IntelligenceService) async {
        guard let turn = currentTurn else { return }
        let said = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !said.isEmpty else {
            grading = .empty(message: "没有听清，再按住麦克风说一次吧")
            return
        }
        grading = .loading
        do {
            let score = try await intelligence.scorePronunciation(
                PronunciationRequest(referenceText: turn.suggestedReply, recognizedText: said))
            let correction = OralCorrection.match(in: said)
            grading = .loaded(OralTurnResult(said: said, score: score, correction: correction))
            HapticEngine.play(score.overall >= 75 ? .success : .light)
        } catch {
            grading = .error(message: "评分失败了，请再试一次")
        }
    }
}

// MARK: - Main view

struct OralPracticeView: View {
    @Environment(\.intelligence) private var intelligence
    @Environment(TTSService.self) private var tts

    @State private var model = OralPracticeModel()
    @State private var speech = SpeechRecognitionCoordinator()

    init() {}

    var body: some View {
        Group {
            if model.scenario == nil {
                ScenarioPicker(model: model)
            } else {
                CallScreen(model: model, speech: speech, tts: tts, intelligence: intelligence)
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("英语口语")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onDisappear { tts.stop() }
    }
}

// MARK: - Scenario picker

private struct ScenarioPicker: View {
    @Bindable var model: OralPracticeModel

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: DBSpacing.md)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                hero
                personaSection
                DBSectionHeader("选个场景开口说", subtitle: "豆包会陪你一句一句练")
                LazyVGrid(columns: columns, spacing: DBSpacing.md) {
                    ForEach(OralScenario.allCases) { scenario in
                        Button { model.start(scenario) } label: {
                            scenarioTile(scenario)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(DBSpacing.screenInset)
        }
    }

    private var hero: some View {
        HStack(spacing: DBSpacing.md) {
            DBMascot(mood: .cheering, size: 72)
            VStack(alignment: .leading, spacing: DBSpacing.xs) {
                Text("和豆包练口语")
                    .font(.dbTitle3).foregroundStyle(Color.dbOnPrimary)
                Text("挑一个生活场景，按住麦克风说英语，\n豆包会即时打分并纠正发音。")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbOnPrimary.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DBSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dbHeroGradient,
                    in: RoundedRectangle(cornerRadius: DBRadius.lg, style: .continuous))
        .dbShadow(.low)
    }

    private var personaSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("选择口语搭子", subtitle: "不同搭子有不同的口音")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DBSpacing.sm) {
                    ForEach(OralAvatar.all) { avatar in
                        Button { model.avatar = avatar } label: {
                            DBChip(
                                "\(avatar.name) · \(avatar.personaCN)",
                                systemImage: avatar.symbolName,
                                tint: .dbPrimary,
                                isSelected: model.avatar.id == avatar.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, DBSpacing.xxs)
            }
        }
    }

    private func scenarioTile(_ scenario: OralScenario) -> some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                Image(systemName: scenario.systemImage)
                    .font(.dbTitle2)
                    .foregroundStyle(scenario.tint)
                Text(scenario.title)
                    .font(.dbHeadline).foregroundStyle(Color.dbTextPrimary)
                Text(scenario.subtitle)
                    .font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
                    .lineLimit(2, reservesSpace: true)
                DBTag("豆包扮演 \(scenario.partnerRoleCN)", tint: scenario.tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Call screen

private struct CallScreen: View {
    @Bindable var model: OralPracticeModel
    @Bindable var speech: SpeechRecognitionCoordinator
    let tts: TTSService
    let intelligence: any IntelligenceService

    var body: some View {
        Group {
            if model.isFinished {
                summary
            } else if let turn = model.currentTurn, let scenario = model.scenario {
                conversation(turn: turn, scenario: scenario)
            } else {
                DBStateView(kind: .empty, title: "暂无内容",
                            message: "这个场景还没有对话，换一个试试吧",
                            retry: { model.exitToPicker() })
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("退出") {
                    tts.stop()
                    model.exitToPicker()
                }
            }
        }
    }

    // MARK: Conversation

    private func conversation(turn: OralTurnScript, scenario: OralScenario) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                callHeader(scenario: scenario)
                progressLine(scenario: scenario)
                partnerBubble(turn: turn, scenario: scenario)
                hintBubble(turn: turn)
                gradingArea(turn: turn, scenario: scenario)
            }
            .padding(DBSpacing.screenInset)
            .padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom) {
            micBar(turn: turn, scenario: scenario)
        }
    }

    private func callHeader(scenario: OralScenario) -> some View {
        HStack(spacing: DBSpacing.md) {
            DBMascot(mood: model.avatar.mascotMood, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.avatar.name) · \(scenario.partnerRole)")
                    .font(.dbHeadline).foregroundStyle(Color.dbTextPrimary)
                HStack(spacing: DBSpacing.xs) {
                    Image(systemName: "waveform")
                    Text(model.avatar.personaCN)
                }
                .font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
            }
            Spacer(minLength: 0)
            Button {
                tts.speak(scenario.turns[model.turnIndex].modelLine,
                          language: model.avatar.voiceLanguage, rate: model.avatar.rate)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.dbTitle3).foregroundStyle(scenario.tint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("再听一遍")
        }
    }

    private func progressLine(scenario: OralScenario) -> some View {
        let total = scenario.turns.count
        return VStack(alignment: .leading, spacing: DBSpacing.xs) {
            HStack {
                Text("第 \(model.turnIndex + 1) / \(total) 句")
                    .font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
                Spacer()
            }
            ProgressView(value: Double(model.turnIndex), total: Double(total))
                .tint(scenario.tint)
        }
    }

    private func partnerBubble(turn: OralTurnScript, scenario: OralScenario) -> some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.xs) {
                HStack(spacing: DBSpacing.xs) {
                    Image(systemName: scenario.systemImage).foregroundStyle(scenario.tint)
                    Text(model.avatar.name).font(.dbCaption).foregroundStyle(Color.dbTextTertiary)
                }
                Text(turn.modelLine)
                    .font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
                Text(turn.gloss)
                    .font(.dbFootnote).foregroundStyle(Color.dbTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func hintBubble(turn: OralTurnScript) -> some View {
        HStack(alignment: .top, spacing: DBSpacing.sm) {
            Image(systemName: "lightbulb.fill").foregroundStyle(Color.dbWarning)
            VStack(alignment: .leading, spacing: 2) {
                Text("提示").font(.dbCaption).foregroundStyle(Color.dbTextTertiary)
                Text(turn.hint).font(.dbFootnote).foregroundStyle(Color.dbTextSecondary)
                Text("参考：\(turn.suggestedReply)")
                    .font(.dbFootnote).foregroundStyle(Color.dbTextTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(DBSpacing.md)
        .dbSurfaceStyle(cornerRadius: DBRadius.md, fill: Color.dbWarning.opacity(0.10))
    }

    // MARK: Grading area (gauges + heatmap + correction)

    @ViewBuilder
    private func gradingArea(turn: OralTurnScript, scenario: OralScenario) -> some View {
        switch model.grading {
        case .idle:
            if !model.liveSubtitle.isEmpty {
                liveSubtitleBubble
            }
        case .loading:
            DBStateView(kind: .loading, title: "豆包正在听…", message: "正在分析你的发音")
                .frame(maxWidth: .infinity).frame(height: 180)
        case let .loaded(result):
            resultCard(result: result, scenario: scenario)
        case let .empty(message), let .offline(message):
            DBStateView(kind: .empty, title: "再来一次", message: message,
                        retry: { model.retryTurn() })
                .frame(maxWidth: .infinity).frame(height: 160)
        case let .error(message):
            DBStateView(kind: .error, title: "出错了", message: message,
                        retry: { model.retryTurn() })
                .frame(maxWidth: .infinity).frame(height: 160)
        }
    }

    private var liveSubtitleBubble: some View {
        HStack(alignment: .top, spacing: DBSpacing.sm) {
            Image(systemName: "text.bubble.fill").foregroundStyle(Color.dbPrimary)
            Text(model.liveSubtitle.isEmpty ? "聆听中…" : model.liveSubtitle)
                .font(.dbBody).foregroundStyle(Color.dbTextPrimary)
            Spacer(minLength: 0)
        }
        .padding(DBSpacing.md)
        .dbSurfaceStyle(cornerRadius: DBRadius.md, fill: Color.dbPrimarySoft)
    }

    private func resultCard(result: OralTurnResult, scenario: OralScenario) -> some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                HStack {
                    DBSectionHeader("你说", systemImage: "person.wave.2.fill")
                    Spacer()
                    DBRouteBadge(result.score.route)
                }
                Text("“\(result.said)”")
                    .font(.dbBody).foregroundStyle(Color.dbTextPrimary)

                gauges(score: result.score)

                wordHeatmap(result.score.perWord)

                if let correction = result.correction {
                    correctionBubble(correction)
                }

                Text(OralScorePalette.verdict(forOverall: result.score.overall))
                    .font(.dbCallout).foregroundStyle(Color.dbTextSecondary)

                HStack(spacing: DBSpacing.md) {
                    Button { model.retryTurn() } label: {
                        Label("再说一次", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.db(.secondary))
                    Button {
                        tts.stop()
                        model.advance()
                    } label: {
                        Label(model.turnIndex + 1 >= scenario.turns.count ? "完成" : "下一句",
                              systemImage: "arrow.right")
                    }
                    .buttonStyle(.db(.primary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func gauges(score: PronunciationScore) -> some View {
        HStack(spacing: DBSpacing.md) {
            gauge("准确度", value: score.accuracy)
            gauge("流利度", value: score.fluency)
            gauge("完整度", value: score.completeness)
        }
    }

    private func gauge(_ caption: String, value: Double) -> some View {
        VStack(spacing: DBSpacing.xs) {
            DBProgressRing(progress: value / 100,
                           lineWidth: 8,
                           tint: OralScorePalette.tint(forScore: value),
                           label: "\(Int(value.rounded()))")
                .frame(width: 70, height: 70)
            Text(caption).font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func wordHeatmap(_ words: [WordScore]) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.xs) {
            Text("逐词发音").font(.dbCaption).foregroundStyle(Color.dbTextTertiary)
            DBFlowLayout(spacing: DBSpacing.xs) {
                ForEach(words) { word in
                    Text(word.word)
                        .font(.dbCallout)
                        .foregroundStyle(Color.dbTextPrimary)
                        .padding(.horizontal, DBSpacing.sm)
                        .padding(.vertical, DBSpacing.xxs)
                        .background(
                            Capsule().fill(OralScorePalette.tint(forScore: word.score).opacity(0.22)))
                        .overlay(
                            Capsule().stroke(OralScorePalette.tint(forScore: word.score).opacity(0.5),
                                             lineWidth: 1))
                }
            }
        }
    }

    private func correctionBubble(_ correction: OralCorrection) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.xs) {
            HStack(spacing: DBSpacing.xs) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.dbSuccess)
                Text("纠正").font(.dbCaption).foregroundStyle(Color.dbTextTertiary)
            }
            HStack(spacing: DBSpacing.sm) {
                Text(correction.wrong)
                    .font(.dbFootnote).foregroundStyle(Color.dbError)
                    .strikethrough()
                Image(systemName: "arrow.right").font(.dbCaption).foregroundStyle(Color.dbTextTertiary)
                Text(correction.right)
                    .font(.dbFootnote.weight(.semibold)).foregroundStyle(Color.dbSuccess)
            }
            Text(correction.note).font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DBSpacing.md)
        .dbSurfaceStyle(cornerRadius: DBRadius.md, fill: Color.dbSuccessSoft)
    }

    // MARK: Mic bar (hold-to-talk)

    @ViewBuilder
    private func micBar(turn: OralTurnScript, scenario: OralScenario) -> some View {
        if case .loaded = model.grading {
            EmptyView()
        } else {
            VStack(spacing: DBSpacing.xs) {
                Text(speech.isListening ? "松开结束 · 正在听你说" : "按住麦克风，说出你的回答")
                    .font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
                micButton(turn: turn, scenario: scenario)
            }
            .frame(maxWidth: .infinity)
            .padding(DBSpacing.md)
            .background(.bar)
        }
    }

    private func micButton(turn: OralTurnScript, scenario: OralScenario) -> some View {
        Image(systemName: speech.isListening ? "mic.fill" : "mic")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(Color.dbOnPrimary)
            .frame(width: 78, height: 78)
            .background(
                Circle().fill(speech.isListening ? scenario.tint : Color.dbPrimary))
            .overlay(
                Circle().stroke(scenario.tint.opacity(speech.isListening ? 0.4 : 0),
                                lineWidth: 8)
                    .scaleEffect(speech.isListening ? 1.25 : 1)
                    .animation(.easeOut(duration: 0.6).repeatForever(autoreverses: true),
                               value: speech.isListening))
            .dbShadow(.medium)
            .accessibilityLabel(speech.isListening ? "松开结束录音" : "按住开始说话")
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !speech.isListening {
                            tts.stop()
                            speech.startListening()
                            model.liveSubtitle = ""
                            model.grading = .idle
                            HapticEngine.play(.light)
                            // Live subtitle preview while held.
                            model.liveSubtitle = previewSubtitle(for: turn)
                        }
                    }
                    .onEnded { _ in
                        guard speech.isListening else { return }
                        let said = speech.stopListening(simulated: simulatedReply(for: turn))
                        model.liveSubtitle = said
                        HapticEngine.play(.selection)
                        Task { await model.grade(spoken: said, using: intelligence) }
                    })
    }

    /// A partial transcript shown as a live subtitle while the mic is held.
    private func previewSubtitle(for turn: OralTurnScript) -> String {
        let words = turn.suggestedReply.split(separator: " ")
        let take = max(1, words.count / 2)
        return words.prefix(take).joined(separator: " ") + "…"
    }

    /// The deterministic transcript the ASR seam returns. We feed the suggested
    /// reply, but occasionally inject a known slip so the correction bubble and a
    /// lower score are demonstrable on alternating turns.
    private func simulatedReply(for turn: OralTurnScript) -> String {
        if turn.id % 2 == 1, let slip = nearbySlip(for: turn) {
            return slip
        }
        return turn.suggestedReply
    }

    /// If a known slip's corrected form is a substring of the suggested reply,
    /// return a version containing the wrong form so the correction triggers.
    private func nearbySlip(for turn: OralTurnScript) -> String? {
        let lowered = turn.suggestedReply.lowercased()
        guard let match = OralCorrection.bank.first(where: { lowered.contains($0.right.lowercased()) })
        else { return nil }
        return turn.suggestedReply.replacingOccurrences(
            of: match.right, with: match.wrong, options: [.caseInsensitive])
    }

    // MARK: Summary

    private var summary: some View {
        ScrollView {
            VStack(spacing: DBSpacing.lg) {
                DBMascot(mood: model.sessionAverage >= 75 ? .cheering : .happy, size: 96)
                Text("这一组练完啦！")
                    .font(.dbTitle3).foregroundStyle(Color.dbTextPrimary)
                DBProgressRing(progress: model.sessionAverage / 100,
                               lineWidth: 12,
                               tint: OralScorePalette.tint(forScore: model.sessionAverage),
                               label: "\(Int(model.sessionAverage.rounded()))")
                    .frame(width: 130, height: 130)
                Text("综合得分 · \(OralScorePalette.verdict(forOverall: model.sessionAverage))")
                    .font(.dbCallout).foregroundStyle(Color.dbTextSecondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: DBSpacing.md) {
                    Button {
                        model.restart()
                    } label: {
                        Label("再练一遍", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.db(.primary, fullWidth: true))
                    Button {
                        model.exitToPicker()
                    } label: {
                        Label("换个场景", systemImage: "square.grid.2x2")
                    }
                    .buttonStyle(.db(.secondary, fullWidth: true))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(DBSpacing.screenInset)
        }
    }
}

// MARK: - Preview

#Preview("英语口语") {
    NavigationStack {
        OralPracticeView()
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}
