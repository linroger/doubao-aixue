//
//  StudyCommands.swift
//  豆包爱学 — App
//
//  Native macOS menu-bar commands + keyboard shortcuts, wired straight to the
//  AppRouter so the Mac app feels like a first-class desktop citizen: launch a
//  capture, jump to any section, or open practice without touching the mouse.
//  macOS-only (the menu bar is a Mac concept); the router it drives is shared.
//

#if os(macOS)
import SwiftUI

struct StudyCommands: Commands {
    /// The same @Observable router the scene injects into the view tree — mutating
    /// it here drives the split-view selection / sheets exactly like an in-app tap.
    let router: AppRouter

    var body: some Commands {
        CommandMenu("学习") {
            Button("拍照解题") { router.present(.capture(.solve)) }
                .keyboardShortcut("n", modifiers: .command)
            Button("作业批改") { router.present(.capture(.grade)) }
                .keyboardShortcut("g", modifiers: [.command, .shift])

            Divider()

            Button("今日练习") { router.openDrill(knowledgePointID: nil, regular: true) }
                .keyboardShortcut("t", modifiers: .command)
            Button("问豆包") { router.sidebarSelection = .companion }
                .keyboardShortcut("l", modifiers: .command)

            Divider()

            Button("全局搜索…") { router.present(.search) }
                .keyboardShortcut("f", modifiers: .command)
        }

        CommandMenu("前往") {
            ForEach(Array(AppSection.allCases.enumerated()), id: \.element) { index, section in
                Button(section.displayName) { router.sidebarSelection = section }
                    .keyboardShortcut(shortcutKey(for: index), modifiers: .command)
            }

            Divider()

            Button("我的成就") { router.navigate(.achievements, regular: true) }
        }
    }

    /// ⌘1…⌘9 for the first nine sections; later ones get no number (still clickable).
    private func shortcutKey(for index: Int) -> KeyEquivalent {
        guard index < 9 else { return .init(Character("0")) }
        return KeyEquivalent(Character("\(index + 1)"))
    }
}
#endif
