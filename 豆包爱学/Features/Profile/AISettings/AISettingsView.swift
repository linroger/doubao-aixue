//
//  AISettingsView.swift
//  豆包爱学 — Features/Profile/AISettings
//
//  设置 → AI 模型 · 增强智能（云端）配置中心。
//
//  One screen that powers the whole app's cloud AI: turn on 增强智能（云端）, pick a
//  provider from `AIProvider.catalog`, pick a model, enter + save that provider's
//  API key (Keychain), and run a one-shot 测试连接 probe. Everything writes through
//  the shared `AICredentialStore`, so every AI feature (拍题解题 / 豆包老师 /
//  作文批改 / AI 伙伴 …) follows the selection automatically.
//
//  Privacy-forward by design: keys live only in the on-device Keychain, and when
//  cloud is off the app falls back to 端侧/离线 intelligence — the reliable path.
//
//  Contract: `struct AISettingsView: View` with a no-argument `init() {}`.
//

import SwiftUI

struct AISettingsView: View {
    @Environment(AICredentialStore.self) private var ai
    @AppStorage("db.appearance") private var appearanceRaw: String = ProfileAppearance.system.rawValue

    /// Local mirror of the current provider's stored key. Mirrored from
    /// `ai.currentKey` on appear and whenever the provider changes, so editing
    /// stays responsive and the field always reflects the right provider's key.
    @State private var keyDraft: String = ""
    /// Live outcome of the 测试连接 probe.
    @State private var testState: TestState = .idle

    init() {}

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                cloudToggleCard

                if ai.cloudEnabled {
                    providerSection
                    if let provider = ai.provider {
                        modelSection(for: provider)
                        keySection(for: provider)
                        testSection(for: provider)
                    }
                } else {
                    offlineHint
                }

                statusFootnote
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .animation(.spring(duration: 0.3), value: ai.cloudEnabled)
            .animation(.spring(duration: 0.3), value: ai.providerID)
        }
        .background(Color.dbBackground)
        .navigationTitle("AI 模型")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .preferredColorScheme((ProfileAppearance(rawValue: appearanceRaw) ?? .system).colorScheme)
        .onAppear { keyDraft = ai.currentKey }
        .onChange(of: ai.providerID) { _, _ in
            // Switching providers reloads that provider's stored key and clears
            // any stale test result so the screen never lies about the new setup.
            keyDraft = ai.currentKey
            testState = .idle
        }
    }

    // MARK: - Cloud toggle

    private var cloudToggleCard: some View {
        DBCard(padding: DBSpacing.md, fill: .dbSurface, elevation: .low) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                Toggle(isOn: Binding(
                    get: { ai.cloudEnabled },
                    set: { newValue in
                        ai.setCloudEnabled(newValue)
                        HapticEngine.play(.selection)
                    }
                )) {
                    settingLabel(
                        title: "启用增强智能（云端）",
                        systemImage: ai.cloudEnabled ? "sparkles" : "cpu.fill",
                        tint: .dbPrimary,
                        subtitle: "接入大模型，讲解更细致、批改更准"
                    )
                }
                .tint(Color.dbPrimary)

                privacyLine
            }
        }
    }

    private var privacyLine: some View {
        HStack(alignment: .top, spacing: DBSpacing.xs) {
            Image(systemName: "lock.shield.fill")
                .font(.dbCaption)
                .foregroundStyle(Color.dbSecondary)
            Text("API Key 仅保存在本机钥匙串，端侧加密；不开启则使用端侧/离线智能。")
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var offlineHint: some View {
        DBCard(padding: DBSpacing.md, fill: .dbSecondarySoft, elevation: .none) {
            HStack(spacing: DBSpacing.md) {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.dbTitle3)
                    .foregroundStyle(Color.dbSecondary)
                    .frame(width: 40, height: 40)
                    .background(Color.dbSurface, in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("正在使用端侧/离线智能")
                        .font(.dbBodyEmph)
                        .foregroundStyle(Color.dbTextPrimary)
                    Text("无需联网，数据不出本机。开启云端可获得更强的讲解与批改。")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Provider

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("选择服务商", systemImage: "square.grid.2x2.fill")

            LazyVGrid(columns: providerColumns, spacing: DBSpacing.md) {
                ForEach(AIProvider.catalog) { provider in
                    ProviderTile(
                        provider: provider,
                        isSelected: provider.id == ai.providerID
                    ) {
                        guard provider.id != ai.providerID else { return }
                        ai.selectProvider(provider.id)
                        HapticEngine.play(.selection)
                    }
                }
            }
        }
        .transition(.opacity)
    }

    private var providerColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: DBSpacing.md)]
    }

    // MARK: - Model

    private func modelSection(for provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("模型", subtitle: provider.name, systemImage: "cube.fill")

            DBCard(padding: DBSpacing.md, fill: .dbSurface, elevation: .low) {
                Picker("模型", selection: Binding(
                    get: { ai.selectedModel?.id ?? provider.defaultModelID },
                    set: { ai.selectModel($0) }
                )) {
                    ForEach(provider.models) { model in
                        Text(model.name).tag(model.id)
                    }
                }
                #if os(iOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.menu)
                #endif
                .tint(Color.dbPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("选择模型")
            }
        }
    }

    // MARK: - API key

    private func keySection(for provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("API Key", systemImage: "key.fill")

            DBCard(padding: DBSpacing.md, fill: .dbSurface, elevation: .low) {
                VStack(alignment: .leading, spacing: DBSpacing.md) {
                    HStack(spacing: DBSpacing.sm) {
                        Image(systemName: "key.fill")
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextTertiary)
                        SecureField(provider.keyHint, text: $keyDraft)
                            .textFieldStyle(.plain)
                            .font(.dbBody)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            #endif
                            .onSubmit(saveKey)
                            .accessibilityLabel("\(provider.shortName) API Key")
                    }
                    .padding(.horizontal, DBSpacing.md)
                    .padding(.vertical, DBSpacing.sm + 2)
                    .background(Color.dbBackgroundAlt, in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous)
                            .stroke(Color.dbSeparator, lineWidth: 1)
                    )

                    HStack(spacing: DBSpacing.md) {
                        Link(destination: keyHelpURL(for: provider)) {
                            Label("获取 API Key", systemImage: "arrow.up.right.square")
                                .font(.dbFootnote.weight(.medium))
                                .foregroundStyle(Color.dbPrimary)
                        }
                        .accessibilityHint("在浏览器中打开 \(provider.shortName) 的密钥页面")

                        Spacer(minLength: 0)

                        Button(action: saveKey) {
                            Label("保存", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.db(.secondary))
                        .disabled(!keyChanged)
                    }
                }
            }
        }
        .transition(.opacity)
    }

    // MARK: - Test connection

    private func testSection(for provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBCard(padding: DBSpacing.md, fill: .dbSurface, elevation: .low) {
                VStack(alignment: .leading, spacing: DBSpacing.md) {
                    Button {
                        runTest(for: provider)
                    } label: {
                        HStack(spacing: DBSpacing.sm) {
                            if testState.isRunning {
                                ProgressView()
                                    .controlSize(.small)
                                    #if os(iOS)
                                    .tint(.white)
                                    #endif
                                Text("正在测试…")
                            } else {
                                Image(systemName: "bolt.horizontal.circle.fill")
                                Text("测试连接")
                            }
                        }
                    }
                    .buttonStyle(.db(.primary, fullWidth: true))
                    .disabled(trimmedKey.isEmpty || testState.isRunning)

                    if let banner = testState.banner {
                        TestResultBanner(result: banner)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .animation(.spring(duration: 0.3), value: testState)
        }
        .transition(.opacity)
    }

    // MARK: - Status footnote

    private var statusFootnote: some View {
        HStack(alignment: .top, spacing: DBSpacing.xs) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextTertiary)
            Text("当前状态：\(ai.statusSummary)")
                .font(.dbCaption)
                .foregroundStyle(Color.dbTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DBSpacing.xs)
        .padding(.top, DBSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Derived state

    private var trimmedKey: String {
        keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when the field differs from what's stored — enables 保存.
    private var keyChanged: Bool {
        trimmedKey != ai.currentKey && !trimmedKey.isEmpty
    }

    private func keyHelpURL(for provider: AIProvider) -> URL {
        URL(string: provider.keyHelpURL) ?? URL(string: "https://www.google.com")!
    }

    // MARK: - Actions

    private func saveKey() {
        let key = trimmedKey
        guard !key.isEmpty else { return }
        ai.setKey(key, for: ai.providerID)
        keyDraft = key
        testState = .idle
        HapticEngine.play(.success)
    }

    /// Build a `CloudChatClient` from the live selection + the entered key and run
    /// the one-shot probe. The provider/model/key are captured into a Sendable
    /// snapshot before the `await` so nothing MainActor-isolated crosses it.
    private func runTest(for provider: AIProvider) {
        let key = trimmedKey
        guard !key.isEmpty else { return }
        let modelID = ai.selectedModel?.id ?? provider.defaultModelID
        let client = CloudChatClient(provider: provider, modelID: modelID, apiKey: key)

        testState = .running
        Task {
            do {
                let reply = try await client.test()
                testState = .success(reply)
                HapticEngine.play(.success)
            } catch let error as CloudAIError {
                testState = .failure(error.description)
                HapticEngine.play(.error)
            } catch {
                testState = .failure(error.localizedDescription)
                HapticEngine.play(.error)
            }
        }
    }

    // MARK: - Shared label (mirrors ProfileSettingsCard's settingLabel)

    private func settingLabel(title: String, systemImage: String, tint: Color, subtitle: String? = nil) -> some View {
        HStack(spacing: DBSpacing.md) {
            Image(systemName: systemImage)
                .font(.dbBody)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.dbBody)
                    .foregroundStyle(Color.dbTextPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Test state

/// Local, value-typed model of the 测试连接 lifecycle so rendering stays declarative.
private enum TestState: Equatable {
    case idle
    case running
    case success(String)
    case failure(String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var banner: TestResultBanner.Result? {
        switch self {
        case .idle, .running: nil
        case .success(let reply): .success(reply)
        case .failure(let message): .failure(message)
        }
    }
}

// MARK: - Provider tile

/// A selectable provider card in the grid. Highlights when chosen and reads as a
/// single accessibility element with a selected trait.
private struct ProviderTile: View {
    let provider: AIProvider
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DBSpacing.sm) {
                Image(systemName: provider.symbolName)
                    .font(.dbTitle3)
                    .foregroundStyle(isSelected ? Color.dbOnPrimary : Color.dbPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        (isSelected ? AnyShapeStyle(Color.dbPrimary) : AnyShapeStyle(Color.dbPrimarySoft)),
                        in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(provider.shortName)
                        .font(.dbBodyEmph)
                        .foregroundStyle(Color.dbTextPrimary)
                        .lineLimit(1)
                    Text("\(provider.models.count) 个模型")
                        .font(.dbCaption2)
                        .foregroundStyle(Color.dbTextSecondary)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.dbFootnote)
                        .foregroundStyle(Color.dbPrimary)
                }
            }
            .padding(DBSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dbSurface, in: RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.dbPrimary : Color.dbSeparator, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(provider.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Test result banner

/// Green ✓ + reply on success, red ✗ + message on failure.
private struct TestResultBanner: View {
    enum Result: Equatable {
        case success(String)
        case failure(String)
    }

    let result: Result

    var body: some View {
        HStack(alignment: .top, spacing: DBSpacing.sm) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .font(.dbBody)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(isSuccess ? "连接成功" : "连接失败")
                    .font(.dbFootnote.weight(.semibold))
                    .foregroundStyle(tint)
                Text(message)
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DBSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(soft, in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isSuccess ? "连接成功" : "连接失败")，\(message)")
    }

    private var isSuccess: Bool {
        if case .success = result { return true }
        return false
    }

    private var message: String {
        switch result {
        case .success(let reply): reply
        case .failure(let text): text
        }
    }

    private var tint: Color { isSuccess ? .dbSuccess : .dbError }
    private var soft: Color { isSuccess ? .dbSuccessSoft : .dbErrorSoft }
}

// MARK: - Preview

#Preview("AI 模型") {
    NavigationStack {
        AISettingsView()
    }
    .environment(AICredentialStore())
}
