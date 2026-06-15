//
//  DoubaoAppShortcuts.swift
//  豆包爱学 — Intents
//
//  RESEARCH §8.10. Registers the four study App Intents as App Shortcuts so they
//  surface automatically in Spotlight, the Shortcuts app, and Siri — invokable
//  with natural Chinese *and* English phrases like:
//
//      "用豆包爱学拍作业"            "Solve homework with 豆包爱学"
//      "用豆包爱学开始今天的听写"      "Start dictation with 豆包爱学"
//      "用豆包爱学复习错题"          "Review mistakes with 豆包爱学"
//      "让豆包爱学讲一讲"            "Start the tutor with 豆包爱学"
//
//  Every phrase MUST contain `\(.applicationName)` — App Intents resolves that
//  to the app's display name (and any localized "Alternate App Names" from the
//  Info.plist), so users can also just say the app name. The provider compiles
//  on iOS 26 + macOS 26 and edits no shared files.
//

import AppIntents

@available(iOS 26.0, macOS 26.0, *)
nonisolated struct DoubaoAppShortcuts: AppShortcutsProvider {

    /// Tint for the shortcut tiles shown in the Shortcuts app gallery.
    static let shortcutTileColor: ShortcutTileColor = .grayBlue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SolveProblemIntent(),
            phrases: [
                "用\(.applicationName)拍作业",
                "用\(.applicationName)解题",
                "\(.applicationName)拍照搜题",
                "用\(.applicationName)拍照答疑",
                "Solve homework with \(.applicationName)",
                "Solve this problem in \(.applicationName)"
            ],
            shortTitle: "拍作业解题",
            systemImageName: "camera.viewfinder"
        )

        AppShortcut(
            intent: StartDictationIntent(),
            phrases: [
                "用\(.applicationName)开始今天的听写",
                "用\(.applicationName)听写",
                "\(.applicationName)开始听写",
                "用\(.applicationName)默写单词",
                "Start dictation with \(.applicationName)",
                "Start today's dictation in \(.applicationName)"
            ],
            shortTitle: "开始听写",
            systemImageName: "ear.fill"
        )

        AppShortcut(
            intent: ReviewMistakesIntent(),
            phrases: [
                "用\(.applicationName)复习错题",
                "打开\(.applicationName)错题本",
                "\(.applicationName)复习错题",
                "用\(.applicationName)巩固错题",
                "Review mistakes with \(.applicationName)",
                "Open my mistake notebook in \(.applicationName)"
            ],
            shortTitle: "复习错题",
            systemImageName: "book.closed.fill"
        )

        AppShortcut(
            intent: StartTutorIntent(),
            phrases: [
                "让\(.applicationName)讲一讲",
                "找\(.applicationName)的豆包老师",
                "用\(.applicationName)讲题",
                "\(.applicationName)豆包老师讲一讲",
                "Start the tutor with \(.applicationName)",
                "Ask the \(.applicationName) teacher to explain"
            ],
            shortTitle: "豆包老师讲一讲",
            systemImageName: "bubble.left.and.bubble.right.fill"
        )
    }
}
