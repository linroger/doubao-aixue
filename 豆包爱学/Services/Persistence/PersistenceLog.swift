//
//  PersistenceLog.swift
//  豆包爱学 — Services/Persistence
//
//  A tiny, app-wide helper for saving a SwiftData context without silently
//  swallowing errors. Replaces the pervasive `try? context.save()` pattern at the
//  feature layer: failures are logged (so disk-full / schema / corruption issues are
//  visible in Console) instead of disappearing. Returns whether the save succeeded
//  so callers that must reflect persistence (e.g. "已加入错题本") can gate UI state on
//  the real outcome rather than optimistically.
//

import Foundation
import SwiftData
import OSLog

public enum AppLog {
    // `nonisolated` so nonisolated services (e.g. CloudIntelligenceService) can log too.
    // `Logger` is Sendable and these are immutable, so this is safe under Swift 6.
    public nonisolated static let persistence = Logger(subsystem: "com.doubao.aixue", category: "persistence")
    public nonisolated static let ai = Logger(subsystem: "com.doubao.aixue", category: "intelligence")
}

public extension ModelContext {
    /// Save the context, logging any error. Returns `true` on success.
    @discardableResult
    func saveLogging(_ context: String = #function) -> Bool {
        do {
            try save()
            return true
        } catch {
            AppLog.persistence.error("SwiftData save failed in \(context, privacy: .public): \(String(describing: error), privacy: .public)")
            return false
        }
    }
}
