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
