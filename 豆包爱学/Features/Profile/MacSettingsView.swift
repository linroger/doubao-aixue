//
//  MacSettingsView.swift
//  豆包爱学 — Features/Profile
//
//  The macOS Settings (⌘,) scene. Rather than maintain a second settings surface,
//  it hosts the exact same `ProfileSettingsCard` the iOS personal center uses —
//  账号 · AI 模型 · 外观 · 语音 · 提醒 · 智能来源 · 学习模式 · 恢复示例数据 — so the
//  two platforms can never drift. A NavigationStack lets the card's 账号 / AI 模型
//  rows push their detail screens inside the preferences window.
//

#if os(macOS)
import SwiftUI
import SwiftData

struct MacSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TTSService.self) private var tts
    @Query private var profiles: [LearnerProfile]

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if let profile = profiles.first {
                        ProfileSettingsCard(profile: profile, onRestoreSampleData: restoreSampleData)
                    } else {
                        DBStateView(kind: .empty, title: "设置暂不可用",
                                    message: "完成首次引导后即可在此调整账号与 AI 设置。")
                            .frame(minHeight: 200)
                    }
                }
                .padding(DBSpacing.screenInset)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color.dbBackground)
            .navigationTitle("设置")
        }
        .frame(minWidth: 520, idealWidth: 600, minHeight: 520, idealHeight: 680)
    }

    /// Mirrors ProfileView.restoreSampleData so the action behaves identically.
    private func restoreSampleData() {
        SampleData.reset(modelContext)
        HapticEngine.play(.success)
        tts.enabled = true
    }
}
#endif
