//
//  ModelContainerFactory.swift
//  豆包爱学
//
//  Builds the SwiftData schema/container. Falls back to in-memory if the
//  on-disk store can't open, so the app never crashes on launch.
//

import Foundation
import SwiftData
import OSLog

public enum ModelContainerFactory {

    /// Every persistent model in the app.
    public static let models: [any PersistentModel.Type] = [
        LearnerProfile.self,
        ProblemRecord.self,
        MistakeItem.self,
        WorkbookGradeRecord.self,
        BankedQuestion.self,
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
            // The on-disk store failed to open (corruption, migration, permissions).
            // Fall back to an in-memory container so the app still launches.
            AppLog.persistence.error("On-disk ModelContainer failed (\(String(describing: error), privacy: .public)); falling back to in-memory.")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                // Both failed — the schema itself is unusable. Crash with a clear,
                // actionable message instead of an opaque force-unwrap trap.
                AppLog.persistence.fault("In-memory ModelContainer also failed: \(String(describing: error), privacy: .public)")
                fatalError("无法初始化数据库（schema 无效）：\(error)")
            }
        }
    }
}
