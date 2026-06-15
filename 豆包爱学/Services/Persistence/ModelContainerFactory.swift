//
//  ModelContainerFactory.swift
//  豆包爱学
//
//  Builds the SwiftData schema/container. Falls back to in-memory if the
//  on-disk store can't open, so the app never crashes on launch.
//

import Foundation
import SwiftData

public enum ModelContainerFactory {

    /// Every persistent model in the app.
    public static let models: [any PersistentModel.Type] = [
        LearnerProfile.self,
        ProblemRecord.self,
        MistakeItem.self,
        KnowledgePointEntity.self,
        MasteryRecord.self,
        EssayRecord.self,
        PracticeSession.self,
        PracticeAttempt.self,
        WordDeck.self,
        WordCard.self,
        DictationList.self,
        DictationResult.self,
        CourseEntity.self,
        LessonProgress.self,
        DocumentEntity.self,
        Conversation.self,
        ChatMessageEntity.self,
        StudyPlan.self,
        StudyReminder.self,
        ActivityLog.self,
        StudyStreak.self,
        ParentControls.self,
    ]

    public static func make(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Last-resort in-memory container keeps the app launchable.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }
}
