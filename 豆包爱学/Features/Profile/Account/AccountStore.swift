//
//  AccountStore.swift
//  豆包爱学 — Features/Profile/Account
//
//  Self-contained account state for F53 账号登录. The app is端侧优先 (on-device
//  first): account state is intentionally kept OUT of the SwiftData model so this
//  feature needs no migration. State persists via `@AppStorage` under the
//  `db.account.*` namespace so it can be read from anywhere with the same keys.
//
//  Keys & conventions (read these elsewhere with the same defaults):
//    • db.account.type        String  — "none" | "guest" | "apple"  (default "none")
//    • db.account.displayName String  — friendly name to show       (default "")
//    • db.account.appleUserID String  — opaque ASAuthorization user  (default "")
//    • db.account.email       String  — email if Apple shared it     (default "")
//

import SwiftUI

// MARK: - Account type

/// The three states the account can be in. Persisted as its `rawValue` String
/// under `db.account.type`. Pure data → `nonisolated` so it crosses actors
/// freely (Swift 6 default-MainActor isolation).
nonisolated enum AccountType: String, CaseIterable, Identifiable, Sendable {
    case none      // signed out — no choice made yet
    case guest     // 游客模式 — continuing without an account
    case apple     // signed in with Apple

    nonisolated var id: String { rawValue }

    /// Whether the user is in a "settled" state (made a choice).
    nonisolated var isSignedIn: Bool { self == .apple }

    var chipTitle: String {
        switch self {
        case .none:  "未登录"
        case .guest: "游客模式"
        case .apple: "Apple 账户"
        }
    }

    var chipSymbol: String {
        switch self {
        case .none:  "person.crop.circle.badge.questionmark"
        case .guest: "person.crop.circle.dashed"
        case .apple: "apple.logo"
        }
    }

    /// UI tint for the type chip. The `Color.db*` helpers are `@MainActor`, so
    /// this accessor is too — the rest of the enum stays `nonisolated` data.
    @MainActor var chipTint: Color {
        switch self {
        case .none:  .dbTextTertiary
        case .guest: .dbSecondary
        case .apple: .dbPrimary
        }
    }
}

// MARK: - Account keys

/// Centralized `@AppStorage` key names so callers elsewhere stay in sync.
nonisolated enum AccountStorageKey {
    static let type = "db.account.type"
    static let displayName = "db.account.displayName"
    static let appleUserID = "db.account.appleUserID"
    static let email = "db.account.email"
}

// MARK: - Account store

/// A small `@Observable` facade over the `@AppStorage`-backed account state.
/// Owns no source-of-truth of its own beyond `UserDefaults`; every mutation is
/// written straight through so a relaunch (or another reader of the same keys)
/// always sees the latest value. Designed to be created with a plain `init()`.
@MainActor
@Observable
final class AccountStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Reads

    var type: AccountType {
        AccountType(rawValue: defaults.string(forKey: AccountStorageKey.type) ?? "")
            ?? .none
    }

    var displayName: String {
        defaults.string(forKey: AccountStorageKey.displayName) ?? ""
    }

    var email: String {
        defaults.string(forKey: AccountStorageKey.email) ?? ""
    }

    var appleUserID: String {
        defaults.string(forKey: AccountStorageKey.appleUserID) ?? ""
    }

    /// A name that is always presentable, even when the user shared nothing.
    var resolvedDisplayName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        switch type {
        case .apple: return "Apple 用户"
        case .guest: return "游客同学"
        case .none:  return "小学员"
        }
    }

    // MARK: Mutations

    /// Persist a successful Sign in with Apple. Missing fields are tolerated —
    /// Apple only returns name/email on the very first authorization.
    func signInWithApple(userID: String, fullName: String?, email: String?) {
        defaults.set(AccountType.apple.rawValue, forKey: AccountStorageKey.type)
        defaults.set(userID, forKey: AccountStorageKey.appleUserID)

        let name = fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty {
            defaults.set(name, forKey: AccountStorageKey.displayName)
        }
        if let email, !email.isEmpty {
            defaults.set(email, forKey: AccountStorageKey.email)
        }
        notifyChange()
    }

    /// Choose 游客模式 — a settled, fully-functional state with no account.
    func continueAsGuest() {
        defaults.set(AccountType.guest.rawValue, forKey: AccountStorageKey.type)
        notifyChange()
    }

    /// 退出登录 — clear everything back to the signed-out baseline.
    func signOut() {
        defaults.removeObject(forKey: AccountStorageKey.type)
        defaults.removeObject(forKey: AccountStorageKey.displayName)
        defaults.removeObject(forKey: AccountStorageKey.appleUserID)
        defaults.removeObject(forKey: AccountStorageKey.email)
        notifyChange()
    }

    // MARK: Observation

    /// `@AppStorage` is the primary view binding (see `AccountView`); writes that
    /// go straight to `UserDefaults` are invisible to Observation. This token,
    /// read by `version`, lets a SwiftUI view that observes this store refresh
    /// after a mutation made through the store's API.
    private var changeToken = 0

    /// Read this in a view body to make the view re-render on store mutations.
    var version: Int { changeToken }

    private func notifyChange() { changeToken &+= 1 }
}
