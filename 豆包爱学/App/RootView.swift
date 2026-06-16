//
//  RootView.swift
//  豆包爱学
//
//  Gates between onboarding and the main shell based on the learner profile.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [LearnerProfile]

    var body: some View {
        if let profile = profiles.first, profile.onboardingComplete {
            AppShell()
        } else {
            OnboardingView()
        }
    }
}

/// Minimal first-run welcome that creates a default profile so the app is never
/// stuck. Replaced by the full onboarding wizard (Features/Onboarding) in Wave 1.
private struct Wave0Welcome: View {
    let hasProfile: Bool
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(spacing: DBSpacing.xl) {
            DBMascot(mood: .cheering, size: 120)
            VStack(spacing: DBSpacing.sm) {
                Text("欢迎来到豆包爱学").font(.dbLargeTitle)
                Text("你的 AI 学习搭子，端侧私密、随时陪练。").font(.dbCallout)
                    .foregroundStyle(Color.dbTextSecondary).multilineTextAlignment(.center)
            }
            Button("开始学习") { start() }
                .buttonStyle(.db(.primary, fullWidth: true))
                .frame(maxWidth: 320)
        }
        .padding(DBSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dbBackground)
    }

    private func start() {
        let profile: LearnerProfile
        if let existing = try? context.fetch(FetchDescriptor<LearnerProfile>()).first {
            profile = existing
        } else {
            profile = LearnerProfile()
            profile.subjects = [.math, .chinese, .english]
            context.insert(profile)
        }
        profile.onboardingComplete = true
        context.saveLogging()
    }
}
