//
//  ProfilePreviewData.swift
//  豆包爱学 — Features/Profile
//
//  In-memory, seeded SwiftData container and a sample LearnerProfile used only
//  by the personal-center #Preview blocks. Not used at runtime.
//

import SwiftUI
import SwiftData

@MainActor
enum ProfilePreviewData {

    /// A rich, seeded in-memory container (profile, mastery, activity, mistakes…).
    static let container: ModelContainer = {
        let container = ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        SampleData.seedIfNeeded(context)
        seedActivityIfNeeded(context)
        return container
    }()

    /// The seeded learner profile (created on first access of `container`).
    static var sampleProfile: LearnerProfile {
        let context = container.mainContext
        if let existing = try? context.fetch(FetchDescriptor<LearnerProfile>()).first {
            return existing
        }
        let profile = LearnerProfile()
        profile.nickname = "小豆"
        profile.grade = .g5
        profile.subjects = [.math, .chinese, .english]
        profile.streakDays = 7
        profile.problemsSolved = 128
        context.insert(profile)
        try? context.save()
        return profile
    }

    /// Adds a week of activity logs so the weekly chart has data in previews.
    private static func seedActivityIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<ActivityLog>())) ?? 0
        guard existing == 0 else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let minutes: [Double] = [22, 8, 30, 18, 25, 0, 14]
        for (offset, value) in minutes.enumerated() where value > 0 {
            let log = ActivityLog()
            log.date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            log.minutes = value
            log.kindRaw = "solve"
            context.insert(log)
        }
        try? context.save()
    }
}
