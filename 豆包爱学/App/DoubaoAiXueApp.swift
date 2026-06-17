//
//  DoubaoAiXueApp.swift
//  豆包爱学 — Doubao Ai Xue (native iOS + macOS reimagining)
//
//  App entry point. Builds the SwiftData container, seeds sample content,
//  injects the router + intelligence/TTS services, and shows RootView.
//

import SwiftUI
import SwiftData

@main
struct DoubaoAiXueApp: App {
    private let container = ModelContainerFactory.make()
    @State private var router = AppRouter()
    @State private var tts = TTSService()
    // Cloud-AI configuration (provider/model/key). Reading `aiStore.resolved`
    // below makes the scene re-inject the right IntelligenceService whenever the
    // user changes the provider, model, or key in 设置 → AI 模型.
    @State private var aiStore = AICredentialStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(tts)
                .environment(aiStore)
                .environment(\.intelligence, IntelligenceFactory.make(aiStore.resolved))
                .environment(\.ocr, OCRService())
                .tint(Color.dbPrimary)
                .task { SampleData.seedIfNeeded(container.mainContext) }
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1180, height: 800)
        .commands { StudyCommands(router: router) }
        #endif

        // Standard macOS preferences window (⌘,), hosting the same settings UI as
        // the iOS personal center so the two platforms stay in lockstep.
        #if os(macOS)
        Settings {
            MacSettingsView()
                .environment(router)
                .environment(tts)
                .environment(aiStore)
                .environment(\.intelligence, IntelligenceFactory.make(aiStore.resolved))
                .environment(\.ocr, OCRService())
                .tint(Color.dbPrimary)
        }
        .modelContainer(container)
        #endif
    }
}
