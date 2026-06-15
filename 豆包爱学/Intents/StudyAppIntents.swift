//
//  StudyAppIntents.swift
//  豆包爱学 — Intents
//
//  RESEARCH §8.10 — "OS-level reach via App Intents / Siri / Spotlight /
//  Shortcuts." Four headless AppIntents that bring the highest-frequency study
//  flows to Siri, Spotlight, the Shortcuts app, the Action Button, and
//  system-suggested actions:
//
//    • SolveProblemIntent   — "拍作业 / solve this homework"  → capture & solve
//    • StartDictationIntent — "开始今天的听写 / start dictation" → 听写 tool
//    • ReviewMistakesIntent — "复习错题 / review my mistakes"  → 错题本
//    • StartTutorIntent     — "找豆包老师讲一讲 / start the tutor" → 豆包老师
//
//  Each intent brings the app to the foreground (`openAppWhenRun = true`) and
//  records a ``PendingIntentSignal`` via ``PendingIntentStore``. The host app
//  consumes that signal on activation and deep-links through `AppRouter`.
//  Because the intents only touch their own self-contained store, they compile
//  and run on iOS 26 and macOS 26 with no edits to any shared file.
//
//  The module compiles with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, but
//  `AppIntent` refines `Sendable`, its `perform()` is invoked off the main actor,
//  and `init()` is invoked from the `nonisolated` `AppShortcutsProvider`. Each
//  intent is therefore declared `nonisolated` so it stays trivially `Sendable`
//  and constructible/performable from those non-main contexts. The `@Parameter`
//  wrapper is itself `Sendable`, so it lives happily inside a `nonisolated`
//  intent. Writes go to the pure, `Sendable` ``PendingIntentStore``, so touching
//  it from `perform()` stays data-race-safe.
//

import AppIntents
import Foundation

// MARK: - 拍作业 / Solve a homework problem

/// Opens the capture-and-solve flow so the student can photograph (iOS) or type
/// (macOS) a homework problem and get a guided, step-by-step explanation.
@available(iOS 26.0, macOS 26.0, *)
struct SolveProblemIntent: AppIntent {
    static let title: LocalizedStringResource = "拍作业 / 解题"
    static let description = IntentDescription(
        "打开豆包爱学的拍照解题，拍一拍或输入题目，豆包老师带你一步步弄懂这道题。",
        categoryName: "学习",
        searchKeywords: ["拍照", "解题", "答疑", "作业", "solve", "homework", "math"]
    )

    /// Launch the app so the live viewfinder / solve screen can appear.
    static let openAppWhenRun = true

    @Parameter(
        title: "题目",
        description: "可选：直接说出或输入题目文字，跳过拍照。",
        requestValueDialog: "想解哪道题？可以直接念出来，或者打开后拍照。"
    )
    var problemText: String?

    static var parameterSummary: some ParameterSummary {
        Summary("解题：\(\.$problemText)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = problemText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefilled = (trimmed?.isEmpty == false) ? trimmed : nil
        PendingIntentStore.shared.post(.solveProblem(prefilledText: prefilled))
        let dialog: IntentDialog = prefilled == nil
            ? "好的，正在打开拍照解题，对准题目拍一拍就行。"
            : "好的，正在为你解这道题，豆包老师马上带你一步步弄懂。"
        return .result(dialog: dialog)
    }
}

// MARK: - 开始今天的听写 / Start today's dictation

/// Opens the 听写 (dictation) tool so 豆包 can read words aloud one-by-one for
/// the student to write down.
@available(iOS 26.0, macOS 26.0, *)
struct StartDictationIntent: AppIntent {
    static let title: LocalizedStringResource = "开始听写"
    static let description = IntentDescription(
        "打开豆包爱学的听写练习，豆包会一个一个把今天的字词读给你听，你来写。",
        categoryName: "学习",
        searchKeywords: ["听写", "默写", "字词", "单词", "dictation", "spelling"]
    )

    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        PendingIntentStore.shared.post(.startDictation)
        return .result(dialog: "好的，开始今天的听写，准备好纸笔，豆包来读啦。")
    }
}

// MARK: - 复习错题 / Review mistakes

/// Opens the 错题本 (mistake notebook) so the student can review questions that
/// are due on the forgetting-curve schedule.
@available(iOS 26.0, macOS 26.0, *)
struct ReviewMistakesIntent: AppIntent {
    static let title: LocalizedStringResource = "复习错题"
    static let description = IntentDescription(
        "打开豆包爱学的错题本，按遗忘曲线复习今天该巩固的错题。",
        categoryName: "学习",
        searchKeywords: ["错题", "错题本", "复习", "巩固", "review", "mistakes"]
    )

    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        PendingIntentStore.shared.post(.reviewMistakes)
        return .result(dialog: "好的，打开错题本，我们一起把今天该复习的错题搞定。")
    }
}

// MARK: - 找豆包老师讲一讲 / Start the AI tutor

/// Opens the 豆包老师 voice-first tutor with an optional topic to start from.
@available(iOS 26.0, macOS 26.0, *)
struct StartTutorIntent: AppIntent {
    static let title: LocalizedStringResource = "找豆包老师讲一讲"
    static let description = IntentDescription(
        "打开豆包老师，用语音和动态板书，一步一步把知识点讲清楚。",
        categoryName: "学习",
        searchKeywords: ["豆包老师", "讲解", "辅导", "讲一讲", "tutor", "explain"]
    )

    static let openAppWhenRun = true

    @Parameter(
        title: "讲什么",
        description: "可选：想让豆包老师讲哪道题或哪个知识点。",
        requestValueDialog: "想让豆包老师讲什么？说个题目或知识点就行。"
    )
    var topic: String?

    static var parameterSummary: some ParameterSummary {
        Summary("讲一讲：\(\.$topic)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = topic?.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = (trimmed?.isEmpty == false) ? trimmed : nil
        PendingIntentStore.shared.post(.startTutor(prompt: prompt))
        let dialog: IntentDialog = prompt == nil
            ? "好的，正在叫豆包老师，马上来给你讲。"
            : "好的，豆包老师这就来给你讲讲这个，认真听哦。"
        return .result(dialog: dialog)
    }
}
