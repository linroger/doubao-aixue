//
//  ParentModeView.swift
//  豆包爱学 — Features/Parent
//
//  家长模式 / 家长验证 (RESEARCH F40/F56). Presented as `AppSheet.parentGate(reason:)`.
//
//  A child-safe guardian gate — NOT real ID collection. The parent proves they
//  are an adult with either a quick mental-math challenge (e.g. 7 × 8) or a
//  4-digit 家长口令. Once passed, the sheet reveals parent controls bound to the
//  single `ParentControls` record:
//    • 隐藏解题步骤 (hideSolutionSteps) — coach-only / 只看思路
//    • 作文范文需验证 (gateEssayReveal)
//    • 每日学习时长上限 (dailyTimeLimitMinutes, stepper, 0 = 不限制)
//    • 周报推送 (weeklyReportEnabled)
//  …plus a read-only 学情周报 built from `ActivityLog` (@Query). Every change is
//  persisted to `ParentControls` and saved immediately.
//
//  States: locked (challenge) · verifying (checking) · unlocked (controls).
//  The `reason` string explains, warmly, why the gate appeared. The view does
//  NOT wrap itself in a NavigationStack — `AppSheet.parentGate` is hosted by
//  `SheetScaffold` which supplies the nav bar, title「家长验证」and 完成 button.
//
//  Full Dark Mode (semantic Color.db* only); both platforms (no camera/Pencil).
//

import SwiftUI
import SwiftData

// MARK: - Gate state

/// Lifecycle of the guardian check. `nonisolated` plain value type.
private enum ParentGatePhase: Equatable {
    case locked
    case verifying
    case unlocked
}

/// Which proof the parent is using right now.
private enum ParentChallengeKind: String, CaseIterable, Identifiable {
    case math
    case code

    var id: String { rawValue }

    var title: String {
        switch self {
        case .math: "算一算"
        case .code: "家长口令"
        }
    }

    var systemImage: String {
        switch self {
        case .math: "function"
        case .code: "lock.rectangle.stack"
        }
    }
}

// MARK: - ParentModeView

struct ParentModeView: View {
    @Environment(\.modelContext) private var modelContext

    /// Single source of truth for parental controls. Seeded/created on demand.
    @Query private var controlsRows: [ParentControls]
    /// Read-only activity for the weekly summary.
    @Query(sort: \ActivityLog.date, order: .reverse) private var activityLogs: [ActivityLog]

    private let reason: String

    @State private var phase: ParentGatePhase = .locked
    @State private var challengeKind: ParentChallengeKind = .math
    @State private var challenge = MathChallenge.random()
    @State private var mathAnswer = ""
    @State private var codeAnswer = ""
    @State private var attemptFailed = false
    @State private var attempts = 0

    /// The guardian passcode. Fixed, friendly default that the in-app 提示 reveals
    /// — this is an anti-impulse speed bump for a child, not a security boundary.
    private static let guardianCode = "1230"

    init(reason: String = "") {
        self.reason = reason
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                switch phase {
                case .locked, .verifying:
                    gateSection
                case .unlocked:
                    controlsSection
                }
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dbBackground)
        .animation(.snappy, value: phase)
        .task { ensureControlsExist(); syncInitialPhase() }
    }

    // MARK: - Locked / verifying

    private var gateSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            reasonCard
            challengePickerCard
            challengeCard
            assuranceFootnote
        }
    }

    private var reasonCard: some View {
        DBCard(fill: .dbPrimarySoft, elevation: .none) {
            HStack(alignment: .top, spacing: DBSpacing.md) {
                DBMascot(mood: .thinking, size: 64)
                VStack(alignment: .leading, spacing: DBSpacing.xxs) {
                    Text("请家长来一下～")
                        .font(.dbHeadline)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text(reasonText)
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("不需要填写任何身份证件，只是一道小题", systemImage: "checkmark.shield.fill")
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbPrimaryDeep)
                        .padding(.top, DBSpacing.xxs)
                }
            }
        }
    }

    private var reasonText: String {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "打开家长模式，可以设置学习时长、隐藏解题步骤、管理周报。完成下面的小验证就可以进入。"
        }
        return trimmed
    }

    private var challengePickerCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                DBSectionHeader("验证方式", subtitle: "二选一即可，都很简单", systemImage: "person.badge.shield.checkmark")
                HStack(spacing: DBSpacing.sm) {
                    ForEach(ParentChallengeKind.allCases) { kind in
                        Button {
                            guard challengeKind != kind else { return }
                            challengeKind = kind
                            resetEntry()
                            HapticEngine.play(.selection)
                        } label: {
                            DBChip(kind.title,
                                   systemImage: kind.systemImage,
                                   tint: .dbSecondary,
                                   isSelected: challengeKind == kind)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var challengeCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                switch challengeKind {
                case .math:
                    mathChallengeContent
                case .code:
                    codeChallengeContent
                }

                if attemptFailed {
                    Label(failureHint, systemImage: "exclamationmark.bubble.fill")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbError)
                        .transition(.opacity)
                }

                Button(action: submit) {
                    if phase == .verifying {
                        HStack(spacing: DBSpacing.xs) {
                            ProgressView().tint(Color.dbOnPrimary)
                            Text("正在验证…")
                        }
                    } else {
                        Label("确认进入家长模式", systemImage: "lock.open.fill")
                    }
                }
                .buttonStyle(.db(.primary, fullWidth: true))
                .disabled(!canSubmit || phase == .verifying)
                .opacity(canSubmit ? 1 : 0.5)
            }
        }
    }

    private var mathChallengeContent: some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            DBSectionHeader("算一算", subtitle: "请家长口算这道题", systemImage: "function")
            HStack(spacing: DBSpacing.md) {
                MathText(challenge.prompt, font: .dbTitle2)
                    .padding(.horizontal, DBSpacing.md)
                    .padding(.vertical, DBSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.dbBackgroundAlt,
                                in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
                Button {
                    challenge = MathChallenge.random()
                    resetEntry()
                    HapticEngine.play(.selection)
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.dbTitle3)
                        .foregroundStyle(Color.dbPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("换一道题")
            }

            TextField("答案", text: $mathAnswer)
                .font(.dbTitle3.monospacedDigit())
                .multilineTextAlignment(.center)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .textFieldStyle(.plain)
                .padding(DBSpacing.sm)
                .background(Color.dbBackgroundAlt,
                            in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                .onChange(of: mathAnswer) { _, newValue in
                    mathAnswer = String(newValue.filter(\.isNumber).prefix(4))
                    if attemptFailed { attemptFailed = false }
                }
        }
    }

    private var codeChallengeContent: some View {
        VStack(alignment: .leading, spacing: DBSpacing.md) {
            DBSectionHeader("家长口令", subtitle: "默认口令见下方提示", systemImage: "lock.rectangle.stack")
            TextField("4 位数字口令", text: $codeAnswer)
                .font(.dbTitle3.monospacedDigit())
                .multilineTextAlignment(.center)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .textFieldStyle(.plain)
                .padding(DBSpacing.sm)
                .background(Color.dbBackgroundAlt,
                            in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                .onChange(of: codeAnswer) { _, newValue in
                    codeAnswer = String(newValue.filter(\.isNumber).prefix(4))
                    if attemptFailed { attemptFailed = false }
                }
            Label("默认家长口令：\(Self.guardianCode)（家长可在脑中记住，孩子不易随手输入）",
                  systemImage: "key.fill")
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var assuranceFootnote: some View {
        HStack(alignment: .top, spacing: DBSpacing.xs) {
            Image(systemName: "hand.raised.fingers.spread.fill")
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextTertiary)
            Text("家长模式仅在本机生效，不联网、不收集身份信息。设置随时可在「我的」里调整。")
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DBSpacing.xs)
    }

    private var failureHint: String {
        switch challengeKind {
        case .math:
            return attempts >= 2 ? "再算一次，提示：仔细看运算符号哦" : "答案不对，请家长再算一次"
        case .code:
            return "口令不对，默认口令是 \(Self.guardianCode)"
        }
    }

    private var canSubmit: Bool {
        switch challengeKind {
        case .math: !mathAnswer.isEmpty
        case .code: codeAnswer.count == 4
        }
    }

    // MARK: - Unlocked controls

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.lg) {
            unlockedHeaderCard
            togglesCard
            timeLimitCard
            weeklyReportCard
            weeklySummaryCard
            relockButton
        }
    }

    private var unlockedHeaderCard: some View {
        DBCard(fill: .dbSuccessSoft, elevation: .none) {
            HStack(alignment: .top, spacing: DBSpacing.md) {
                DBMascot(mood: .cheering, size: 64)
                VStack(alignment: .leading, spacing: DBSpacing.xxs) {
                    Text("已进入家长模式")
                        .font(.dbHeadline)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text("在这里帮孩子安排学习节奏、控制看答案的方式。所有设置会立即保存。")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var togglesCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                DBSectionHeader("防抄答案", subtitle: "鼓励先思考，再看解析", systemImage: "shield.lefthalf.filled")

                Toggle(isOn: hideSolutionStepsBinding) {
                    controlLabel(title: "隐藏解题步骤",
                                 detail: "孩子只看思路与提示，解题步骤需家长开启",
                                 systemImage: "list.number")
                }
                .tint(Color.dbPrimary)

                Divider().overlay(Color.dbSeparator)

                Toggle(isOn: gateEssayRevealBinding) {
                    controlLabel(title: "作文范文需验证",
                                 detail: "查看升格范文前再做一次家长验证，避免照抄",
                                 systemImage: "doc.text.magnifyingglass")
                }
                .tint(Color.dbPrimary)
            }
        }
    }

    private var timeLimitCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("每日学习时长上限",
                                subtitle: timeLimitSubtitle,
                                systemImage: "hourglass") {
                    Text(timeLimitBadge)
                        .font(.dbScore)
                        .foregroundStyle(timeLimitMinutes == 0 ? Color.dbTextTertiary : Color.dbPrimary)
                }

                Stepper(value: timeLimitBinding, in: 0...180, step: 10) {
                    controlLabel(title: timeLimitMinutes == 0 ? "暂不限制" : "上限 \(timeLimitMinutes) 分钟",
                                 detail: "到达上限后温柔提醒休息，建议 30–60 分钟",
                                 systemImage: "timer")
                }
                .tint(Color.dbPrimary)

                HStack(spacing: DBSpacing.sm) {
                    presetButton(minutes: 0, title: "不限")
                    presetButton(minutes: 30, title: "30 分钟")
                    presetButton(minutes: 45, title: "45 分钟")
                    presetButton(minutes: 60, title: "60 分钟")
                }
            }
        }
    }

    private func presetButton(minutes: Int, title: String) -> some View {
        Button {
            setTimeLimit(minutes)
            HapticEngine.play(.selection)
        } label: {
            DBChip(title,
                   tint: .dbSecondary,
                   isSelected: timeLimitMinutes == minutes)
        }
        .buttonStyle(.plain)
    }

    private var weeklyReportCard: some View {
        DBCard {
            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                DBSectionHeader("学情周报", subtitle: "每周一推送上一周的学习概览", systemImage: "calendar.badge.clock")
                Toggle(isOn: weeklyReportBinding) {
                    controlLabel(title: "周报推送",
                                 detail: "开启后每周自动整理学习时长、错题与进步",
                                 systemImage: "bell.badge.fill")
                }
                .tint(Color.dbPrimary)
            }
        }
    }

    // MARK: - Read-only weekly summary

    private var weeklySummaryCard: some View {
        let summary = WeeklySummary(logs: activityLogs)
        return DBCard(fill: .dbSurface, elevation: .low) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader("本周学情",
                                subtitle: summary.hasData ? "近 7 天的学习概览" : "本周还没有学习记录",
                                systemImage: "chart.bar.doc.horizontal.fill")

                if summary.hasData {
                    HStack(spacing: DBSpacing.md) {
                        DBValueStat(value: "\(summary.totalMinutes)′",
                                    caption: "学习时长",
                                    systemImage: "clock.fill",
                                    tint: .dbPrimary)
                        DBValueStat(value: "\(summary.activeDays) 天",
                                    caption: "学习天数",
                                    systemImage: "calendar",
                                    tint: .dbSecondary)
                        DBValueStat(value: "\(summary.sessions)",
                                    caption: "学习次数",
                                    systemImage: "checkmark.circle.fill",
                                    tint: .dbSuccess)
                    }

                    weekBars(summary)

                    if !summary.topSubjects.isEmpty {
                        VStack(alignment: .leading, spacing: DBSpacing.xs) {
                            Text("主要科目")
                                .font(.dbCaption)
                                .foregroundStyle(Color.dbTextTertiary)
                            DBFlowLayout(spacing: DBSpacing.sm) {
                                ForEach(summary.topSubjects, id: \.self) { subject in
                                    DBSubjectChip(subject)
                                }
                            }
                        }
                    }

                    Text(summary.encouragement)
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: DBSpacing.md) {
                        DBMascot(mood: .sleepy, size: 52)
                        Text("本周还没有学习记录。陪孩子拍题、听写或上一节课，这里就会出现成长曲线～")
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    /// A compact, accessible 7-day bar row without depending on Swift Charts so the
    /// summary stays self-contained inside the gate sheet.
    private func weekBars(_ summary: WeeklySummary) -> some View {
        let peak = max(summary.peakMinutes, 1)
        return HStack(alignment: .bottom, spacing: DBSpacing.xs) {
            ForEach(summary.days) { day in
                VStack(spacing: DBSpacing.xxs) {
                    RoundedRectangle(cornerRadius: DBRadius.xs, style: .continuous)
                        .fill(day.isToday ? Color.dbPrimary : Color.dbPrimary.opacity(0.45))
                        .frame(height: barHeight(for: day.minutes, peak: peak))
                        .frame(maxWidth: .infinity)
                    Text(day.weekdaySymbol)
                        .font(.dbCaption2)
                        .foregroundStyle(day.isToday ? Color.dbPrimary : Color.dbTextTertiary)
                }
            }
        }
        .frame(height: 92, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("本周每日学习时长，近 7 天累计 \(summary.totalMinutes) 分钟")
    }

    private func barHeight(for minutes: Int, peak: Int) -> CGFloat {
        let minBar: CGFloat = 6
        let maxBar: CGFloat = 64
        guard minutes > 0 else { return minBar }
        let ratio = CGFloat(minutes) / CGFloat(peak)
        return minBar + (maxBar - minBar) * ratio
    }

    private var relockButton: some View {
        Button {
            HapticEngine.play(.light)
            withAnimation { phase = .locked }
            resetEntry()
        } label: {
            Label("退出家长模式", systemImage: "lock.fill")
        }
        .buttonStyle(.db(.ghost, fullWidth: true))
    }

    // MARK: - Shared control label

    private func controlLabel(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: DBSpacing.sm) {
            Image(systemName: systemImage)
                .font(.dbBody)
                .foregroundStyle(Color.dbPrimary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.dbBodyEmph)
                    .foregroundStyle(Color.dbTextPrimary)
                Text(detail)
                    .font(.dbCaption)
                    .foregroundStyle(Color.dbTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - ParentControls persistence

    /// The live controls record. `ensureControlsExist()` runs in `.task` before
    /// any control renders, so the row is already inserted; the inline fallback
    /// only guards a theoretical first-frame read and never saves during `body`
    /// (saving while SwiftUI is computing a view triggers update warnings).
    private var controls: ParentControls {
        if let existing = controlsRows.first { return existing }
        let created = ParentControls()
        modelContext.insert(created)
        return created
    }

    /// Inserts the single `ParentControls` row once, from `.task` (outside the
    /// body-evaluation pass) so bindings always resolve to a saved object.
    private func ensureControlsExist() {
        guard controlsRows.isEmpty else { return }
        modelContext.insert(ParentControls())
        modelContext.saveLogging()
    }

    private func persist() {
        controls.updatedAt = Date()
        modelContext.saveLogging()
    }

    private var hideSolutionStepsBinding: Binding<Bool> {
        Binding(
            get: { controls.hideSolutionSteps },
            set: { newValue in
                controls.hideSolutionSteps = newValue
                persist()
                HapticEngine.play(.selection)
            }
        )
    }

    private var gateEssayRevealBinding: Binding<Bool> {
        Binding(
            get: { controls.gateEssayReveal },
            set: { newValue in
                controls.gateEssayReveal = newValue
                persist()
                HapticEngine.play(.selection)
            }
        )
    }

    private var weeklyReportBinding: Binding<Bool> {
        Binding(
            get: { controls.weeklyReportEnabled },
            set: { newValue in
                controls.weeklyReportEnabled = newValue
                persist()
                HapticEngine.play(.selection)
            }
        )
    }

    private var timeLimitMinutes: Int { controls.dailyTimeLimitMinutes }

    private var timeLimitBinding: Binding<Int> {
        Binding(
            get: { controls.dailyTimeLimitMinutes },
            set: { setTimeLimit($0) }
        )
    }

    private func setTimeLimit(_ minutes: Int) {
        let clamped = min(max(minutes, 0), 180)
        guard clamped != controls.dailyTimeLimitMinutes else { return }
        controls.dailyTimeLimitMinutes = clamped
        persist()
    }

    private var timeLimitSubtitle: String {
        timeLimitMinutes == 0 ? "当前不限制每日学习时长" : "到点后温柔提醒孩子休息"
    }

    private var timeLimitBadge: String {
        timeLimitMinutes == 0 ? "不限" : "\(timeLimitMinutes)′"
    }

    // MARK: - Gate logic

    private func syncInitialPhase() {
        // If a guardian already verified in a previous session, skip straight to
        // the controls — re-verification on every open would be tiresome for the
        // parent, and `ParentControls.verified` records that consent.
        if controlsRows.first?.verified == true {
            phase = .unlocked
        }
    }

    private var isCorrect: Bool {
        switch challengeKind {
        case .math:
            return Int(mathAnswer) == challenge.answer
        case .code:
            return codeAnswer == Self.guardianCode
        }
    }

    private func submit() {
        guard canSubmit, phase != .verifying else { return }
        attempts += 1
        phase = .verifying
        let success = isCorrect

        // Brief artificial pause so the .verifying state is perceptible and the
        // gate feels deliberate (matches the modal "checking" affordance in F40).
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            if success {
                attemptFailed = false
                controls.verified = true
                persist()
                HapticEngine.play(.success)
                withAnimation { phase = .unlocked }
            } else {
                attemptFailed = true
                HapticEngine.play(.error)
                withAnimation { phase = .locked }
                if challengeKind == .math {
                    challenge = MathChallenge.random()
                }
                clearEntryValues()
            }
        }
    }

    private func resetEntry() {
        attemptFailed = false
        clearEntryValues()
    }

    private func clearEntryValues() {
        mathAnswer = ""
        codeAnswer = ""
    }
}

// MARK: - Math challenge (nonisolated value type)

/// A simple adult-level mental-math prompt. `nonisolated` so it can be created
/// off the main actor if needed; it carries no UI types.
private nonisolated struct MathChallenge: Equatable {
    let prompt: String
    let answer: Int

    static func random() -> MathChallenge {
        // Mix of products and sums that an adult solves instantly but a young
        // child cannot reliably guess — a child-safe speed bump, not a barrier.
        if Bool.random() {
            let a = Int.random(in: 6...9)
            let b = Int.random(in: 6...9)
            return MathChallenge(prompt: "\(a) × \(b) = ?", answer: a * b)
        } else {
            let a = Int.random(in: 24...59)
            let b = Int.random(in: 13...39)
            return MathChallenge(prompt: "\(a) + \(b) = ?", answer: a + b)
        }
    }
}

// MARK: - Weekly summary (nonisolated value type)

/// Read-only aggregation of `ActivityLog` over the trailing 7 calendar days.
/// `nonisolated` plain value type — holds only `Int`/`Subject` data.
private nonisolated struct WeeklySummary {
    struct Day: Identifiable {
        let id = UUID()
        let date: Date
        let minutes: Int
        let weekdaySymbol: String
        let isToday: Bool
    }

    let days: [Day]
    let totalMinutes: Int
    let activeDays: Int
    let sessions: Int
    let peakMinutes: Int
    let topSubjects: [Subject]

    var hasData: Bool { totalMinutes > 0 || sessions > 0 }

    var encouragement: String {
        switch totalMinutes {
        case 0:
            return "本周还没有积累学习时长，陪孩子一起开个头吧。"
        case 1..<60:
            return "本周已经迈出了第一步，继续保持每天的小习惯。"
        case 60..<180:
            return "本周学习节奏不错，记得也安排适度的休息时间。"
        default:
            return "本周学习投入很充分，别忘了劳逸结合、保护视力哦。"
        }
    }

    init(logs: [ActivityLog]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]

        let weekLogs = logs.filter { $0.date >= weekStart }

        // Build the trailing-7-day buckets (oldest → newest).
        var dayList: [Day] = []
        for offset in (0..<7).reversed() {
            let dayStart = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let minutes = weekLogs
                .filter { calendar.isDate($0.date, inSameDayAs: dayStart) }
                .reduce(0.0) { $0 + $1.minutes }
            let weekdayIndex = calendar.component(.weekday, from: dayStart) - 1
            dayList.append(Day(date: dayStart,
                               minutes: Int(minutes.rounded()),
                               weekdaySymbol: symbols[(weekdayIndex % 7 + 7) % 7],
                               isToday: calendar.isDateInToday(dayStart)))
        }

        self.days = dayList
        self.totalMinutes = dayList.reduce(0) { $0 + $1.minutes }
        self.activeDays = dayList.filter { $0.minutes > 0 }.count
        self.sessions = weekLogs.count
        self.peakMinutes = dayList.map(\.minutes).max() ?? 0

        // Rank subjects by accumulated minutes this week (most-studied first).
        var minutesBySubject: [Subject: Double] = [:]
        for log in weekLogs {
            guard let subject = log.subject else { continue }
            minutesBySubject[subject, default: 0] += max(log.minutes, 0.1)
        }
        self.topSubjects = minutesBySubject
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map(\.key)
    }
}

// MARK: - Previews

#Preview("家长验证 · 锁定") {
    NavigationStack {
        ParentModeView(reason: "查看升格范文需要家长确认，避免直接照抄。")
            .navigationTitle("家长验证")
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
}

#Preview("家长模式 · 已解锁") {
    let container = PreviewSampleData.container
    let controls = ParentControls()
    controls.verified = true
    controls.dailyTimeLimitMinutes = 45
    container.mainContext.insert(controls)
    try? container.mainContext.save()
    return NavigationStack {
        ParentModeView(reason: "在「我的」里打开了家长模式。")
            .navigationTitle("家长验证")
    }
    .modelContainer(container)
    .environment(AppRouter())
}
