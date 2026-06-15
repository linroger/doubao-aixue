//
//  TutorSessionView.swift
//  豆包爱学 — Features/Tutor
//
//  豆包老师 — the flagship voice-first dynamic-blackboard tutor (RESEARCH §4.2
//  F18–F22). Presented modally via `AppSheet.tutor(problemText:subject:grade:)`.
//
//  The PRIMARY surface is the animated 动态板书 (TutorBlackboard): BoardElements
//  appear progressively as each TutorSegment streams from
//  `intelligence.tutorSession(_:)`, synced with TTS narration. A persistent
//  voice / 字幕 bar sits below it. At a TutorCheckpoint the session pauses and
//  shows the "是否听懂了?" prompt with hold-to-talk (SpeechRecognitionCoordinator)
//  plus a typed-reply fallback. The student can interrupt to 追问 at any time.
//
//  Layout adapts: on regular width a 3-pane-friendly layout (problem | board |
//  追问 chat); on compact a full-screen board with a bottom bar. Camera/Pencil
//  are not used here, so the screen works identically on iOS and macOS.
//

import SwiftUI
import SwiftData

struct TutorSessionView: View {
    // MARK: Inputs (the exact init the integrator wires from AppSheet.tutor)
    let problemText: String
    let subject: Subject
    let grade: GradeLevel

    init(problemText: String, subject: Subject, grade: GradeLevel) {
        self.problemText = problemText
        self.subject = subject
        self.grade = grade
    }

    // MARK: Environment
    @Environment(\.intelligence) private var intelligence
    @Environment(TTSService.self) private var tts
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss

    // MARK: State
    @State private var model: TutorSessionModel?
    @State private var speech = SpeechRecognitionCoordinator()
    @State private var followUpDraft = ""
    @State private var didPersist = false
    @State private var showFollowUpSheet = false

    private var isRegular: Bool { sizeClass != .compact }

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                DBStateView(kind: .loading, title: "豆包老师马上就来…")
                    .background(Color.dbBackground)
            }
        }
        .navigationTitle("豆包老师")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .background(Color.dbBackground)
        .task { setUpModelIfNeeded() }
        .onDisappear { model?.tearDown() }
    }

    // MARK: - Setup

    private func setUpModelIfNeeded() {
        guard model == nil else { model?.start(); return }
        let request = TutorRequest(problemText: problemText, subject: subject, grade: grade, learnMode: true)
        let m = TutorSessionModel(request: request, intelligence: intelligence, tts: tts)
        model = m
        m.start()
    }

    // MARK: - Root content (adaptive)

    @ViewBuilder
    private func content(_ model: TutorSessionModel) -> some View {
        switch model.phase {
        case .failed(let message):
            DBStateView(kind: .offline, title: "暂时讲不了啦",
                        message: message, systemImage: "wifi.slash") {
                model.retry()
            }
        default:
            if isRegular {
                regularLayout(model)
            } else {
                compactLayout(model)
            }
        }
    }

    // MARK: - Regular (iPad / Mac) — 3 panes: problem | board | 追问

    private func regularLayout(_ model: TutorSessionModel) -> some View {
        HStack(spacing: 0) {
            TutorProblemPane(problemText: problemText, subject: subject,
                             grade: grade, route: model.route)
                .frame(width: 300)

            Divider()

            // Center: the dynamic blackboard (hero) + controls.
            VStack(spacing: DBSpacing.md) {
                boardSection(model, expandable: false)
                bottomControls(model)
            }
            .padding(DBSpacing.lg)
            .frame(maxWidth: .infinity)

            Divider()

            // Right: 追问 thread.
            followUpPanel(model)
                .frame(width: 320)
                .padding(DBSpacing.lg)
                .background(Color.dbBackgroundAlt)
        }
    }

    // MARK: - Compact (iPhone) — full-screen board + bottom bar

    private func compactLayout(_ model: TutorSessionModel) -> some View {
        VStack(spacing: DBSpacing.md) {
            boardSection(model, expandable: true)
                .frame(maxHeight: .infinity)
            bottomControls(model)
        }
        .padding(DBSpacing.md)
        .sheet(isPresented: $showFollowUpSheet) {
            followUpPanel(model)
                .padding(DBSpacing.lg)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .background(Color.dbBackground)
        }
    }

    // MARK: - Board + transcript

    @ViewBuilder
    private func boardSection(_ model: TutorSessionModel, expandable: Bool) -> some View {
        VStack(spacing: DBSpacing.sm) {
            TutorBlackboard(
                elements: model.visibleBoardElements,
                stepCaption: boardCaption(model),
                isSpeaking: tts.isSpeaking
            )
            .frame(maxHeight: .infinity)

            // Voice / 字幕 bar (always visible).
            voiceBarBinding(model)

            if model.transcriptExpanded {
                ScrollView {
                    TutorTranscriptView(
                        segments: model.segments,
                        currentIndex: model.currentIndex,
                        onJump: { _ in model.repeatNarration() }
                    )
                }
                .frame(maxHeight: expandable ? 220 : 260)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func voiceBarBinding(_ model: TutorSessionModel) -> some View {
        TutorVoiceBar(
            statusLabel: model.statusLabel,
            isSpeaking: tts.isSpeaking,
            ttsEnabled: model.ttsEnabled,
            transcriptExpanded: Binding(
                get: { model.transcriptExpanded },
                set: { model.transcriptExpanded = $0 }
            ),
            onReplayNarration: { model.repeatNarration() },
            onToggleTTS: { model.toggleTTS() }
        )
    }

    private func boardCaption(_ model: TutorSessionModel) -> String {
        guard !model.segments.isEmpty else { return "动态板书" }
        if model.isFinished { return "讲解完成 · 共 \(model.segments.count) 步" }
        return "第 \(model.currentIndex + 1) / \(max(model.segments.count, 1)) 步"
    }

    // MARK: - Bottom controls (checkpoint / progress / finished / 追问 entry)

    @ViewBuilder
    private func bottomControls(_ model: TutorSessionModel) -> some View {
        VStack(spacing: DBSpacing.sm) {
            switch model.phase {
            case .checkpoint, .awaitingVoice:
                if let checkpoint = model.activeCheckpoint {
                    TutorCheckpointBar(
                        checkpoint: checkpoint,
                        isListening: speech.isListening,
                        onPressMic: { model.beginVoiceReply(); speech.startListening() },
                        onReleaseMic: {
                            // SpeechRecognitionCoordinator returns a deterministic
                            // transcript; the friendly default is "听懂了".
                            let said = speech.stopListening(simulated: "听懂了")
                            model.resolveCheckpoint(fromTranscript: said)
                        },
                        onTypedReply: { understood in model.resolveCheckpoint(understood: understood) }
                    )
                }
            case .finished:
                finishedBar(model)
            default:
                TutorProgressRail(
                    progress: model.progress,
                    stepText: stepText(model),
                    canGoBack: model.hasPreviousSegment,
                    canAdvance: model.canAdvance,
                    onBack: { model.goBack() },
                    onReplay: { model.replayCurrent() },
                    onAdvance: { model.advance() }
                )
            }

            // Pace + 追问 entry (compact only — regular shows 追问 in its own pane).
            HStack(spacing: DBSpacing.md) {
                TutorPaceControl(pace: Binding(
                    get: { model.paceMultiplier }, set: { model.paceMultiplier = $0 }))
                Spacer()
                if !isRegular {
                    Button { showFollowUpSheet = true } label: {
                        Label("追问", systemImage: "hand.raised.fill")
                            .font(.dbFootnote.weight(.semibold))
                    }
                    .buttonStyle(.db(.secondary))
                }
            }
        }
    }

    private func stepText(_ model: TutorSessionModel) -> String {
        guard !model.segments.isEmpty else { return "讲解准备中…" }
        return "第 \(model.currentIndex + 1) / \(model.segments.count) 步"
    }

    private func finishedBar(_ model: TutorSessionModel) -> some View {
        DBCard(fill: .dbSuccessSoft, elevation: .none) {
            HStack(spacing: DBSpacing.md) {
                DBMascot(mood: .cheering, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("讲解完成啦！")
                        .font(.dbHeadline)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text("试着自己再做一道类似的题巩固一下吧～")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                }
                Spacer(minLength: 0)
                Button("再听一遍") { model.replayFrom(0) }
                    .buttonStyle(.db(.ghost))
            }
        }
        .onAppear { persistIfNeeded(model) }
    }

    // MARK: - 追问 panel

    private func followUpPanel(_ model: TutorSessionModel) -> some View {
        TutorFollowUpPanel(
            followUps: model.followUps,
            isAnswering: model.isAnsweringFollowUp,
            suggestions: followUpSuggestions,
            draft: $followUpDraft,
            isListeningVoice: speech.isListening,
            onSend: {
                let q = followUpDraft
                followUpDraft = ""
                model.askFollowUp(q)
            },
            onPickSuggestion: { s in model.askFollowUp(s) },
            onPressMic: { speech.startListening() },
            onReleaseMic: {
                let said = speech.stopListening(simulated: "为什么要这样做？")
                model.askFollowUp(said)
            }
        )
    }

    private var followUpSuggestions: [String] {
        switch subject {
        case .math, .physics, .chemistry:
            ["这一步是怎么想到的？", "能换个简单方法吗？", "再举一个例子"]
        case .chinese, .history:
            ["这句什么意思？", "作者想表达什么？", "再讲讲背景"]
        case .english:
            ["这个词怎么用？", "语法是什么？", "能造个句子吗？"]
        default:
            ["为什么这样做？", "能再讲一遍吗？", "举个例子"]
        }
    }

    // MARK: - Persistence

    /// Persist a lightweight record of this tutoring session: a ProblemRecord
    /// capturing the explained steps, and (if any) the 追问 conversation thread.
    private func persistIfNeeded(_ model: TutorSessionModel) {
        guard !didPersist, !model.segments.isEmpty else { return }
        didPersist = true

        // 1) ProblemRecord — the explained problem with its steps.
        let record = ProblemRecord()
        record.subject = subject
        record.source = .text
        record.recognizedText = problemText
        record.route = model.route
        record.approach = "豆包老师分步讲解"
        let steps: [SolutionStep] = model.segments.enumerated().compactMap { index, seg in
            guard !seg.board.isEmpty || !seg.narration.isEmpty else { return nil }
            let math = seg.board.first(where: { $0.kind == .formula || $0.kind == .answer })?.content
            return SolutionStep(index: index + 1,
                                title: seg.board.first?.content ?? "讲解",
                                detail: seg.narration,
                                math: math)
        }
        record.steps = steps
        if let answer = model.segments.last(where: { $0.board.contains(where: { $0.kind == .answer }) })?
            .board.first(where: { $0.kind == .answer })?.content {
            record.finalAnswer = answer
        }
        modelContext.insert(record)

        // 2) 追问 conversation (only if the student asked something).
        if !model.followUps.isEmpty {
            let convo = Conversation()
            convo.title = "豆包老师 · \(subject.displayName)"
            convo.kindRaw = ConversationKind.tutor.rawValue
            convo.subject = subject
            modelContext.insert(convo)
            for (offset, turn) in model.followUps.enumerated() where !turn.text.isEmpty {
                let message = ChatMessageEntity()
                message.role = turn.role
                message.text = turn.text
                message.route = model.route
                message.createdAt = convo.createdAt.addingTimeInterval(Double(offset))
                message.conversation = convo
                modelContext.insert(message)
            }
        }

        try? modelContext.save()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("完成") {
                model?.tearDown()
                dismiss()
            }
        }
    }
}

#Preview("Tutor — compact") {
    NavigationStack {
        TutorSessionView(
            problemText: "笼子里有若干只鸡和兔，共 35 个头，94 只脚。问鸡和兔各有多少只？",
            subject: .math,
            grade: .g3
        )
    }
    .environment(TTSService())
    .environment(AppRouter())
    .modelContainer(for: [ProblemRecord.self, Conversation.self, ChatMessageEntity.self], inMemory: true)
}

#Preview("Tutor — regular") {
    NavigationStack {
        TutorSessionView(
            problemText: "解方程：x² + 2x - 3 = 0",
            subject: .math,
            grade: .g8
        )
    }
    .environment(TTSService())
    .environment(AppRouter())
    .modelContainer(for: [ProblemRecord.self, Conversation.self, ChatMessageEntity.self], inMemory: true)
    .frame(minWidth: 1000, minHeight: 640)
}
