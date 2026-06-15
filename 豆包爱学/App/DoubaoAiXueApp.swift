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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(tts)
                .environment(\.intelligence, RoutePolicy.defaultService())
                .environment(\.ocr, OCRService())
                .tint(Color.dbPrimary)
                .task { SampleData.seedIfNeeded(container.mainContext) }
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1180, height: 800)
        #endif
    }
}
