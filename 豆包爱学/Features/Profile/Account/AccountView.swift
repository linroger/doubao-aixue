//
//  AccountView.swift
//  豆包爱学 — Features/Profile/Account
//
//  F53 账号登录 · A warm, privacy-forward account screen.
//
//  Two states, one screen:
//    • Signed-out — mascot welcome, “Sign in with Apple”, “以游客身份继续”, and a
//      short privacy line. 游客模式 is always the reliable path: the app is fully
//      usable without an account, and "Sign in with Apple" only completes at
//      runtime when the entitlement is present, so its failure is handled
//      gracefully without ever blocking the user.
//    • Signed-in — avatar + name, an account-type chip, a multi-device-sync
//      blurb, and 退出登录 (with confirmation).
//
//  State is persisted with `@AppStorage` under `db.account.*` (see AccountStore),
//  so this feature is fully self-contained and needs no SwiftData changes.
//
//  Contract: `struct AccountView: View` with a no-argument `init() {}`.
//

import SwiftUI
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

struct AccountView: View {
    // Mirror the persisted account state directly so the view reacts to changes
    // made here or in onboarding without any external wiring.
    @AppStorage(AccountStorageKey.type) private var typeRaw: String = AccountType.none.rawValue
    @AppStorage(AccountStorageKey.displayName) private var storedName: String = ""
    @AppStorage(AccountStorageKey.email) private var storedEmail: String = ""

    @AppStorage("db.appearance") private var appearanceRaw: String = ProfileAppearance.system.rawValue

    @State private var showSignOutConfirm = false
    @State private var signInError: String?

    init() {}

    private var accountType: AccountType {
        AccountType(rawValue: typeRaw) ?? .none
    }

    /// A presentable name even when the user shared nothing.
    private var resolvedName: String {
        let trimmed = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        switch accountType {
        case .apple: return "Apple 用户"
        case .guest: return "游客同学"
        case .none:  return "小学员"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DBSpacing.lg) {
                if accountType.isSignedIn {
                    signedInContent
                } else {
                    signedOutContent
                }
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dbBackground)
        .navigationTitle("账号")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .preferredColorScheme((ProfileAppearance(rawValue: appearanceRaw) ?? .system).colorScheme)
        .confirmationDialog(
            "确定要退出登录吗？",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("退出登录", role: .destructive) { signOut() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("退出后将切换为游客模式。你的学习数据保存在本机，不会因此丢失。")
        }
    }

    // MARK: - Signed-out

    @ViewBuilder private var signedOutContent: some View {
        // Welcome hero.
        VStack(spacing: DBSpacing.md) {
            DBMascot(mood: .happy, size: 96)
            VStack(spacing: DBSpacing.xs) {
                Text("登录豆包爱学")
                    .font(.dbTitle)
                    .foregroundStyle(Color.dbTextPrimary)
                Text("登录是可选的，游客模式也能完整使用全部功能。\n登录仅用于在多台设备间同步学习进度。")
                    .font(.dbCallout)
                    .foregroundStyle(Color.dbTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DBSpacing.md)
        .accessibilityElement(children: .combine)

        // Benefits.
        DBCard(padding: DBSpacing.md, fill: .dbSurface, elevation: .low) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                AccountBenefitRow(
                    icon: "arrow.triangle.2.circlepath",
                    tint: .dbPrimary,
                    title: "多设备同步",
                    detail: "在 iPhone、iPad、Mac 上接着学"
                )
                ProfileRowDivider()
                AccountBenefitRow(
                    icon: "lock.iphone",
                    tint: .dbSecondary,
                    title: "数据端侧保存",
                    detail: "作业与错题默认只存在你的设备上"
                )
                ProfileRowDivider()
                AccountBenefitRow(
                    icon: "person.badge.shield.checkmark.fill",
                    tint: .dbAccent,
                    title: "无广告 · 无会员",
                    detail: "登录不会带来任何付费或骚扰"
                )
            }
        }

        // Actions.
        VStack(spacing: DBSpacing.md) {
            appleSignInButton

            Button {
                continueAsGuest()
            } label: {
                Label("以游客身份继续", systemImage: "person.crop.circle.dashed")
            }
            .buttonStyle(.db(.secondary, fullWidth: true))

            if let signInError {
                Label(signInError, systemImage: "exclamationmark.triangle.fill")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbWarning)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }
        }

        // Privacy line.
        privacyFootnote
    }

    @ViewBuilder private var appleSignInButton: some View {
        #if canImport(AuthenticationServices) && (os(iOS) || os(macOS))
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            handleAppleSignIn(result)
        }
        .signInWithAppleButtonStyle(signInButtonStyle)
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .clipShape(Capsule(style: .continuous))
        .accessibilityLabel("使用 Apple 登录")
        #else
        EmptyView()
        #endif
    }

    /// Match the system look in both appearances (white-on-dark, black-on-light).
    private var signInButtonStyle: SignInWithAppleButton.Style {
        #if canImport(AuthenticationServices) && (os(iOS) || os(macOS))
        (ProfileAppearance(rawValue: appearanceRaw) ?? .system) == .dark ? .white : .black
        #else
        .black
        #endif
    }

    // MARK: - Signed-in

    @ViewBuilder private var signedInContent: some View {
        // Identity card.
        DBCard(padding: DBSpacing.lg, fill: .dbSurface, elevation: .low) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                HStack(spacing: DBSpacing.lg) {
                    DBAvatar(name: resolvedName, size: 68)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(resolvedName)
                            .font(.dbTitle2)
                            .foregroundStyle(Color.dbTextPrimary)
                        AccountTypeChip(type: accountType)
                        if !storedEmail.isEmpty {
                            Text(storedEmail)
                                .font(.dbFootnote)
                                .foregroundStyle(Color.dbTextSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
        }

        // Multi-device sync blurb.
        DBCard(padding: DBSpacing.md, fill: .dbSecondarySoft, elevation: .none) {
            HStack(spacing: DBSpacing.md) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.dbTitle3)
                    .foregroundStyle(Color.dbSecondary)
                    .frame(width: 40, height: 40)
                    .background(Color.dbSurface, in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("已开启多设备同步")
                        .font(.dbBodyEmph)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text("学习进度会安全地在你的 Apple 设备间同步。")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }

        // Sign out.
        DBCard(padding: DBSpacing.md, fill: .dbSurface, elevation: .low) {
            Button {
                showSignOutConfirm = true
            } label: {
                HStack(spacing: DBSpacing.md) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.dbBody)
                        .foregroundStyle(Color.dbError)
                        .frame(width: 34, height: 34)
                        .background(Color.dbErrorSoft, in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                    Text("退出登录")
                        .font(.dbBody)
                        .foregroundStyle(Color.dbError)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.dbFootnote.weight(.semibold))
                        .foregroundStyle(Color.dbTextTertiary)
                }
                .contentShape(Rectangle())
                .padding(.vertical, DBSpacing.xs)
            }
            .buttonStyle(.plain)
        }

        privacyFootnote
    }

    // MARK: - Shared

    private var privacyFootnote: some View {
        HStack(alignment: .top, spacing: DBSpacing.xs) {
            Image(systemName: "hand.raised.fill")
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextTertiary)
            Text("豆包爱学 不会出售你的数据。登录仅用于多设备同步，可随时退出。")
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DBSpacing.xs)
        .padding(.top, DBSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    #if canImport(AuthenticationServices) && (os(iOS) || os(macOS))
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        withAnimation(.spring(duration: 0.3)) { signInError = nil }
        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                // An unexpected credential type — fall back to guest reliability.
                continueAsGuest()
                return
            }
            let name = credential.fullName.flatMap(Self.formattedName)
            typeRaw = AccountType.apple.rawValue
            storedName = name ?? storedName
            storedEmail = credential.email ?? storedEmail
            UserDefaults.standard.set(credential.user, forKey: AccountStorageKey.appleUserID)
            HapticEngine.play(.success)
        case .failure:
            // The user canceled, or the entitlement is missing in this build.
            // Keep 游客模式 as the reliable path and nudge gently — never block.
            HapticEngine.play(.warning)
            withAnimation(.spring(duration: 0.3)) {
                signInError = "暂时无法使用 Apple 登录，你可以先以游客身份继续。"
            }
        }
    }

    private static func formattedName(_ components: PersonNameComponents) -> String? {
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        let name = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
    #endif

    private func continueAsGuest() {
        withAnimation(.spring(duration: 0.3)) { signInError = nil }
        typeRaw = AccountType.guest.rawValue
        HapticEngine.play(.light)
    }

    private func signOut() {
        typeRaw = AccountType.none.rawValue
        storedName = ""
        storedEmail = ""
        UserDefaults.standard.removeObject(forKey: AccountStorageKey.appleUserID)
        HapticEngine.play(.selection)
    }
}

// MARK: - Subviews

/// A benefit row used on the signed-out screen, mirroring the Profile settings
/// row visual language (icon chip + title + detail).
private struct AccountBenefitRow: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: DBSpacing.md) {
            Image(systemName: icon)
                .font(.dbBody)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.dbBody)
                    .foregroundStyle(Color.dbTextPrimary)
                Text(detail)
                    .font(.dbCaption)
                    .foregroundStyle(Color.dbTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

/// A small pill describing the current account type.
private struct AccountTypeChip: View {
    let type: AccountType

    var body: some View {
        Label(type.chipTitle, systemImage: type.chipSymbol)
            .font(.dbCaption2.weight(.semibold))
            .padding(.horizontal, DBSpacing.sm)
            .padding(.vertical, 3)
            .foregroundStyle(type.chipTint)
            .background(type.chipTint.opacity(0.15), in: Capsule(style: .continuous))
            .accessibilityLabel("账号类型 \(type.chipTitle)")
    }
}

// MARK: - Previews

#Preview("登录 · 未登录") {
    NavigationStack {
        AccountView()
    }
    .onAppear {
        UserDefaults.standard.set(AccountType.none.rawValue, forKey: AccountStorageKey.type)
    }
}

#Preview("登录 · 已登录") {
    NavigationStack {
        AccountView()
    }
    .onAppear {
        UserDefaults.standard.set(AccountType.apple.rawValue, forKey: AccountStorageKey.type)
        UserDefaults.standard.set("林同学", forKey: AccountStorageKey.displayName)
        UserDefaults.standard.set("study@icloud.com", forKey: AccountStorageKey.email)
    }
}
