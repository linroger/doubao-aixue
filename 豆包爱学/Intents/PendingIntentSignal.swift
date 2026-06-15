//
//  PendingIntentSignal.swift
//  豆包爱学 — Intents
//
//  RESEARCH §8.10 (OS-level reach via App Intents / Siri / Spotlight). Self-
//  contained navigation seam for App Intents.
//
//  The App Intents in this folder cannot edit `AppRouter` / `AppShell` (shared
//  files owned by the integrator). So instead of reaching into navigation
//  directly, an intent records a lightweight, *durable* "pending intent" into
//  `UserDefaults`. When the app next becomes active it can read & clear this
//  signal (one line in the App's `.task`/`scenePhase` handler) and deep-link to
//  the right screen via `AppRouter`. Until that wiring exists the signal is
//  simply persisted — everything here compiles and runs on both platforms with
//  no edits to shared files.
//
//  Pure value type → marked `nonisolated`, `Codable`, `Sendable` so the intent
//  process (which is *not* MainActor) can encode it safely.
//

import Foundation

/// A durable hint, written by an App Intent, telling the app which screen to
/// open the next time it launches/activates. Designed to round-trip through
/// `UserDefaults` as a small JSON blob.
public nonisolated enum PendingIntentSignal: Codable, Sendable, Hashable {
    /// "拍作业 / solve this homework" → open the capture-and-solve flow.
    case solveProblem(prefilledText: String?)
    /// "开始今天的听写 / start today's dictation" → open the 听写 tool.
    case startDictation
    /// "复习错题 / review my mistakes" → open the 错题本.
    case reviewMistakes
    /// "找豆包老师讲一讲 / start the AI tutor" → open the 豆包老师 tutor.
    case startTutor(prompt: String?)

    /// A stable identifier handy for analytics / Spotlight donation.
    public var rawIdentifier: String {
        switch self {
        case .solveProblem:   "solveProblem"
        case .startDictation: "startDictation"
        case .reviewMistakes: "reviewMistakes"
        case .startTutor:     "startTutor"
        }
    }
}

/// Persists the most-recent ``PendingIntentSignal`` so the host app can consume
/// it on next activation. Intentionally tiny and dependency-free.
///
/// The store holds **no** stored properties — `UserDefaults` is *not* `Sendable`,
/// so a `Sendable` value type must never capture an instance of it. Instead each
/// operation resolves the backing `UserDefaults` inline (`.standard`, or an
/// optional App-Group suite identified only by its `String` name, which *is*
/// `Sendable`). This keeps the type trivially `Sendable` and safe to touch from
/// an App Intent's `nonisolated` `perform()`.
public nonisolated struct PendingIntentStore: Sendable {

    /// Key under which the encoded signal lives.
    public static let defaultsKey = "com.doubaoaixue.pendingIntent"

    /// Optional App-Group suite name. `String?` is `Sendable`; the actual
    /// `UserDefaults` instance is resolved inline per call (see ``defaults``).
    /// If a future build adds an App Group entitlement, construct the store with
    /// that suite name so a Share-Extension / Widget can share this mailbox.
    private let appGroup: String?

    /// The process-wide shared mailbox used by the App Intents below.
    public static let shared = PendingIntentStore()

    public init(appGroup: String? = nil) {
        self.appGroup = appGroup
    }

    /// Resolves the backing store inline. Never stored on `self` so the type
    /// stays `Sendable`. Falls back to `.standard` when no (valid) suite exists,
    /// so the store never traps and the intents always work.
    private var defaults: UserDefaults {
        if let appGroup, let suite = UserDefaults(suiteName: appGroup) {
            return suite
        }
        return .standard
    }

    /// Records a pending signal (overwriting any earlier, unconsumed one — the
    /// freshest user request wins).
    public func post(_ signal: PendingIntentSignal) {
        guard let data = try? JSONEncoder().encode(signal) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    /// Reads the current pending signal **without** clearing it.
    public func peek() -> PendingIntentSignal? {
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return nil }
        return try? JSONDecoder().decode(PendingIntentSignal.self, from: data)
    }

    /// Reads and clears the pending signal — the host app calls this once on
    /// activation, then routes accordingly.
    @discardableResult
    public func consume() -> PendingIntentSignal? {
        let value = peek()
        defaults.removeObject(forKey: Self.defaultsKey)
        return value
    }
}
