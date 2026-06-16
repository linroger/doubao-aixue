//
//  FocusTimerView.swift
//  豆包爱学 — Features/Focus
//
//  专注 · 番茄钟 — a calm, distraction-free study-session timer.
//
//  The learner sets a focus length and a break length (persisted via
//  @AppStorage), then runs alternating 专注 ↔ 休息 cycles. A large circular
//  countdown (DBProgressRing over a Canvas tick dial) reads at a glance; the
//  controls are a quiet start/pause and reset. Every COMPLETED focus block is
//  written to the shared store as an `ActivityLog(kindRaw: "focus", minutes:)`
//  so the time flows into 学习报告 / 今日 like any other activity. Completion
//  is gentle: a HapticEngine cue plus an optional TTSService chime line.
//
//  A running 本次专注 summary (blocks done · total focused minutes) sits below
//  so progress feels tangible without being noisy. Fully semantic-colored for
//  Dark Mode, VoiceOver-labeled, Dynamic-Type friendly, and respectful of the
//  reduce-motion setting.
//
//  Contract: `struct FocusTimerView: View` with a no-arg `init()`. The
//  integrator maps a ToolKind / route → FocusTimerView(). No new model: persist
//  via the existing ActivityLog. Pushed view — no self-owned NavigationStack.
//

import SwiftUI
import SwiftData
import Combine

struct FocusTimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TTSService.self) private var tts
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Persisted preferences (minutes). Sensible 番茄钟 defaults: 25 focus / 5 break.
    @AppStorage("focus.minutes") private var focusMinutes: Int = 25
    @AppStorage("focus.breakMinutes") private var breakMinutes: Int = 5
    @AppStorage("focus.chimeEnabled") private var chimeEnabled: Bool = true

    @State private var model = FocusSessionModel()

    init() {}

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: DBSpacing.xl) {
                phaseHeader
                timerDial
                controlRow
                if model.phase == .idle {
                    durationSettings
                } else {
                    runningHint
                }
                sessionSummary
            }
            .padding(.horizontal, DBSpacing.screenInset)
            .padding(.top, DBSpacing.sm)
            .padding(.bottom, DBSpacing.xxxl)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(backgroundTint.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("专注")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { model.configure(focus: focusMinutes, breakLen: breakMinutes) }
        .onChange(of: focusMinutes) { _, new in model.updateFocusLength(new) }
        .onChange(of: breakMinutes) { _, new in model.updateBreakLength(new) }
        .onChange(of: scenePhase) { _, phase in
            // Pause when the app leaves the foreground so the wall-clock timer
            // never silently drifts; the learner resumes deliberately.
            if phase != .active, model.phase == .focusing || model.phase == .breaking {
                model.pause()
            }
        }
        .onReceive(model.ticker) { _ in
            model.tick(onPhaseComplete: handlePhaseCompletion)
        }
    }

    // MARK: Phase header

    private var phaseHeader: some View {
        VStack(spacing: DBSpacing.sm) {
            DBMascot(mood: mascotMood, size: 64)
                .accessibilityHidden(true)
            Text(model.phase.title)
                .font(.dbTitle3)
                .foregroundStyle(Color.dbTextPrimary)
            Text(phaseSubtitle)
                .font(.dbCallout)
                .foregroundStyle(Color.dbTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, DBSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var mascotMood: DBMascotMood {
        switch model.phase {
        case .idle: .curious
        case .focusing: .thinking
        case .breaking: .sleepy
        case .done: .cheering
        }
    }

    private var phaseSubtitle: String {
        switch model.phase {
        case .idle:
            "调好专注与休息时长，开始一段不被打扰的学习吧～"
        case .focusing:
            "正在专注 · 第 \(model.completedFocusBlocks + 1) 个番茄钟，加油！"
        case .breaking:
            "放松一下，喝口水、远眺一会儿，待会儿继续～"
        case .done:
            "本次专注结束，你真的很棒！记得给自己一个小奖励 🎉"
        }
    }

    // MARK: Timer dial

    private var timerDial: some View {
        ZStack {
            // A soft, hand-drawn tick dial behind the ring for a calm focus look.
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 2
                let tickCount = 60
                for i in 0..<tickCount {
                    let angle = (Double(i) / Double(tickCount)) * 2 * .pi - .pi / 2
                    let isMajor = i % 5 == 0
                    let inner = radius - (isMajor ? 12 : 7)
                    let start = CGPoint(
                        x: center.x + CGFloat(cos(angle)) * inner,
                        y: center.y + CGFloat(sin(angle)) * inner)
                    let end = CGPoint(
                        x: center.x + CGFloat(cos(angle)) * radius,
                        y: center.y + CGFloat(sin(angle)) * radius)
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(
                        path,
                        with: .color(phaseTint.opacity(isMajor ? 0.32 : 0.14)),
                        lineWidth: isMajor ? 2 : 1)
                }
            }
            .frame(width: 244, height: 244)
            .accessibilityHidden(true)

            DBProgressRing(
                progress: model.progress,
                lineWidth: 14,
                tint: phaseTint,
                label: model.remainingClock)
            .frame(width: 210, height: 210)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: model.progress)
            .accessibilityElement()
            .accessibilityLabel("\(model.phase.title)倒计时")
            .accessibilityValue(model.remainingSpokenClock)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DBSpacing.md)
    }

    // MARK: Controls

    private var controlRow: some View {
        HStack(spacing: DBSpacing.md) {
            Button {
                HapticEngine.play(.selection)
                model.reset()
            } label: {
                Label("重置", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.db(.secondary))
            .disabled(model.phase == .idle && model.completedFocusBlocks == 0)
            .accessibilityHint("清空当前计时，回到准备状态")

            Button {
                togglePrimary()
            } label: {
                Label(primaryLabel, systemImage: primarySymbol)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.db(.primary))
            .accessibilityHint(primaryHint)
        }
    }

    private var primaryLabel: String {
        switch model.phase {
        case .idle: "开始专注"
        case .focusing: model.isRunning ? "暂停" : "继续"
        case .breaking: model.isRunning ? "暂停休息" : "继续休息"
        case .done: "再来一组"
        }
    }

    private var primarySymbol: String {
        switch model.phase {
        case .idle: "play.fill"
        case .focusing, .breaking: model.isRunning ? "pause.fill" : "play.fill"
        case .done: "arrow.clockwise"
        }
    }

    private var primaryHint: String {
        switch model.phase {
        case .idle: "开始一个 \(focusMinutes) 分钟的专注番茄钟"
        case .focusing, .breaking: model.isRunning ? "暂停当前计时" : "继续当前计时"
        case .done: "开启新的一段专注"
        }
    }

    private func togglePrimary() {
        switch model.phase {
        case .idle:
            HapticEngine.play(.light)
            model.start()
        case .focusing, .breaking:
            HapticEngine.play(.selection)
            model.togglePause()
        case .done:
            HapticEngine.play(.light)
            model.startFresh()
        }
    }

    // MARK: Duration settings (idle only)

    private var durationSettings: some View {
        VStack(spacing: DBSpacing.md) {
            DBSectionHeader("时长设置", systemImage: "slider.horizontal.3")
            DBCard {
                VStack(spacing: DBSpacing.lg) {
                    durationStepper(
                        title: "专注时长",
                        systemImage: "brain.head.profile",
                        tint: .dbPrimary,
                        value: $focusMinutes,
                        range: 5...90,
                        step: 5)
                    Divider().background(Color.dbSeparator)
                    durationStepper(
                        title: "休息时长",
                        systemImage: "cup.and.saucer.fill",
                        tint: .dbSecondary,
                        value: $breakMinutes,
                        range: 1...30,
                        step: 1)
                    Divider().background(Color.dbSeparator)
                    Toggle(isOn: $chimeEnabled) {
                        Label("完成时语音提醒", systemImage: "speaker.wave.2.fill")
                            .font(.dbBody)
                            .foregroundStyle(Color.dbTextPrimary)
                    }
                    .tint(.dbPrimary)
                    .accessibilityHint("每段专注或休息结束时，豆包用语音轻声提醒你")
                }
            }
        }
    }

    private func durationStepper(
        title: String,
        systemImage: String,
        tint: Color,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        HStack(spacing: DBSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.dbBodyEmph)
                    .foregroundStyle(Color.dbTextPrimary)
                Text("\(value.wrappedValue) 分钟")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)
            }
            Spacer(minLength: 0)
            Stepper(
                value: value,
                in: range,
                step: step
            ) {
                EmptyView()
            }
            .labelsHidden()
            .accessibilityLabel("\(title) \(value.wrappedValue) 分钟")
        }
    }

    private var runningHint: some View {
        HStack(spacing: DBSpacing.sm) {
            Image(systemName: "moon.stars.fill")
                .foregroundStyle(Color.dbAccent)
            Text("保持这一页打开，专注计时正在进行。")
                .font(.dbFootnote)
                .foregroundStyle(Color.dbTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(DBSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dbAccentSoft,
                    in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Session summary

    private var sessionSummary: some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            DBSectionHeader(
                "本次专注",
                subtitle: model.completedFocusBlocks == 0
                    ? "完成第一个番茄钟后，这里会记录你的成果"
                    : "已记入学习报告，继续保持～",
                systemImage: "checklist")
            HStack(spacing: DBSpacing.md) {
                DBValueStat(
                    value: "\(model.completedFocusBlocks)",
                    caption: "番茄钟",
                    systemImage: "checkmark.seal.fill",
                    tint: .dbPrimary)
                DBValueStat(
                    value: "\(model.totalFocusedMinutes)",
                    caption: "专注分钟",
                    systemImage: "clock.fill",
                    tint: .dbSecondary)
                DBValueStat(
                    value: "\(model.completedBreaks)",
                    caption: "休息次数",
                    systemImage: "cup.and.saucer.fill",
                    tint: .dbAccent)
            }
        }
    }

    // MARK: Phase-completion side effects

    /// Called by the model when a phase reaches zero. We keep persistence + I/O
    /// in the View (it owns the environment) while the model owns pure timing.
    private func handlePhaseCompletion(_ finished: FocusSessionModel.Phase) {
        switch finished {
        case .focusing:
            logCompletedFocusBlock()
            HapticEngine.play(.success)
            chime("一个番茄钟完成啦，先休息一下吧～")
        case .breaking:
            HapticEngine.play(.light)
            chime("休息结束，准备好继续专注了吗？")
        case .idle, .done:
            break
        }
    }

    /// Insert one ActivityLog for the focus block so it shows in 报告 / 今日.
    private func logCompletedFocusBlock() {
        let log = ActivityLog()
        log.kindRaw = "focus"
        log.detail = "专注番茄钟 · \(model.lastFocusLengthMinutes) 分钟"
        log.minutes = Double(model.lastFocusLengthMinutes)
        log.date = Date()
        modelContext.insert(log)
        try? modelContext.save()
    }

    private func chime(_ line: String) {
        guard chimeEnabled else { return }
        tts.speak(line, language: "zh-CN", rate: 0.46)
    }

    // MARK: Tints

    private var phaseTint: Color {
        switch model.phase {
        case .idle: .dbPrimary
        case .focusing: .dbPrimary
        case .breaking: .dbSecondary
        case .done: .dbSuccess
        }
    }

    private var backgroundTint: Color {
        switch model.phase {
        case .breaking: .dbBackgroundAlt
        default: .dbBackground
        }
    }
}

// MARK: - Session model (pure timing state)

/// Owns the pomodoro state machine and the per-second tick. Kept free of any
/// SwiftData / TTS / haptics so it stays trivially testable; the View injects
/// side effects through the `onPhaseComplete` closure. MainActor by default.
@MainActor
@Observable
final class FocusSessionModel {

    enum Phase: Equatable {
        case idle
        case focusing
        case breaking
        case done

        var title: String {
            switch self {
            case .idle: "准备专注"
            case .focusing: "专注中"
            case .breaking: "休息中"
            case .done: "完成"
            }
        }
    }

    private(set) var phase: Phase = .idle
    private(set) var isRunning = false

    /// Seconds remaining in the current phase and the phase's full length.
    private(set) var remainingSeconds: Int = 25 * 60
    private(set) var phaseTotalSeconds: Int = 25 * 60

    private(set) var completedFocusBlocks = 0
    private(set) var completedBreaks = 0
    private(set) var totalFocusedMinutes = 0
    /// Length (minutes) of the focus block that just finished — used for logging.
    private(set) var lastFocusLengthMinutes = 25

    private var focusLengthMinutes = 25
    private var breakLengthMinutes = 5

    /// One shared 1-second publisher. We gate work on `isRunning` in `tick`, so
    /// it is safe to always observe it.
    let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: Configuration

    func configure(focus: Int, breakLen: Int) {
        focusLengthMinutes = max(1, focus)
        breakLengthMinutes = max(1, breakLen)
        if phase == .idle {
            phaseTotalSeconds = focusLengthMinutes * 60
            remainingSeconds = phaseTotalSeconds
        }
    }

    func updateFocusLength(_ minutes: Int) {
        focusLengthMinutes = max(1, minutes)
        if phase == .idle {
            phaseTotalSeconds = focusLengthMinutes * 60
            remainingSeconds = phaseTotalSeconds
        }
    }

    func updateBreakLength(_ minutes: Int) {
        breakLengthMinutes = max(1, minutes)
    }

    // MARK: Derived display

    /// 0…1 elapsed fraction of the current phase (drives the ring).
    var progress: Double {
        guard phaseTotalSeconds > 0 else { return 0 }
        let elapsed = phaseTotalSeconds - remainingSeconds
        return min(1, max(0, Double(elapsed) / Double(phaseTotalSeconds)))
    }

    var remainingClock: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// VoiceOver-friendly remaining time, e.g. "还剩 24 分 30 秒".
    var remainingSpokenClock: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        if m > 0 && s > 0 { return "还剩 \(m) 分 \(s) 秒" }
        if m > 0 { return "还剩 \(m) 分钟" }
        return "还剩 \(s) 秒"
    }

    // MARK: Transitions

    func start() {
        phase = .focusing
        phaseTotalSeconds = focusLengthMinutes * 60
        remainingSeconds = phaseTotalSeconds
        isRunning = true
    }

    /// Reset every counter and return to idle (used by "再来一组" after .done).
    func startFresh() {
        completedFocusBlocks = 0
        completedBreaks = 0
        totalFocusedMinutes = 0
        phase = .idle
        phaseTotalSeconds = focusLengthMinutes * 60
        remainingSeconds = phaseTotalSeconds
        isRunning = false
        start()
    }

    func togglePause() {
        guard phase == .focusing || phase == .breaking else { return }
        isRunning.toggle()
    }

    func pause() {
        isRunning = false
    }

    func reset() {
        phase = .idle
        isRunning = false
        completedFocusBlocks = 0
        completedBreaks = 0
        totalFocusedMinutes = 0
        phaseTotalSeconds = focusLengthMinutes * 60
        remainingSeconds = phaseTotalSeconds
    }

    // MARK: Tick

    /// Advance one second. Calls `onPhaseComplete` with the phase that just
    /// ended so the View can persist / chime / haptic, then auto-advances:
    /// focus → break → focus … keeping `done` reachable only via reset paths.
    func tick(onPhaseComplete: (Phase) -> Void) {
        guard isRunning, phase == .focusing || phase == .breaking else { return }

        if remainingSeconds > 1 {
            remainingSeconds -= 1
            return
        }

        // Phase just completed.
        remainingSeconds = 0
        let finished = phase

        switch finished {
        case .focusing:
            completedFocusBlocks += 1
            totalFocusedMinutes += focusLengthMinutes
            lastFocusLengthMinutes = focusLengthMinutes
            onPhaseComplete(.focusing)
            // Auto-roll into a break.
            phase = .breaking
            phaseTotalSeconds = breakLengthMinutes * 60
            remainingSeconds = phaseTotalSeconds
        case .breaking:
            completedBreaks += 1
            onPhaseComplete(.breaking)
            // Auto-roll into the next focus block.
            phase = .focusing
            phaseTotalSeconds = focusLengthMinutes * 60
            remainingSeconds = phaseTotalSeconds
        case .idle, .done:
            break
        }
    }
}

// MARK: - Preview

#Preview("Focus Timer") {
    NavigationStack {
        FocusTimerView()
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}
