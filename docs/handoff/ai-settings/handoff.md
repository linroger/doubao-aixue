# Handoff.md — AI 模型设置 (AISettingsView)

**Last Updated (UTC):** 2026-06-16
**Status:** Complete
**Current Focus:** Done — `AISettingsView` built; macOS + iOS builds SUCCEEDED with zero errors.

## 1) Request & Context
- **Request:** Implement ONE settings screen `AISettingsView` for the native iOS 26 + macOS 26 SwiftUI app "豆包爱学". Lets the user enable cloud AI, pick a provider (9 in catalog), pick a model, enter+save the provider API key, test the connection, and see a live status line. The screen drives the whole app's AI via the shared `AICredentialStore`.
- **Constraints:** Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, module DoubaoAiXue. Only create new file(s) under `豆包爱学/Features/Profile/AISettings/`; do NOT modify any shared/existing file (the store, provider catalog, chat client, ProfileSettingsCard). Gate platform bits with `#if os(iOS)` / `#if canImport(UIKit)`.
- **Entry point contract:** `struct AISettingsView: View` with no-arg `init() {}`. Wired into ProfileSettingsCard via NavigationLink by the user.
- **Non-goals:** No edits to AICredentialStore / AIProvider / CloudChatClient / ProfileSettingsCard. No init.sh, no default DerivedData.

## 2) Requirements → Acceptance Checks
| Requirement | Acceptance Check | Expected | Evidence |
|---|---|---|---|
| R1 Entry point | `struct AISettingsView: View` + `init() {}` | Compiles, matches contract | source + build |
| R2 Cloud toggle | Bound to `ai.cloudEnabled`/`ai.setCloudEnabled`; warm privacy line | Toggling enables/disables config sections | source |
| R3 Provider grid | Renders `AIProvider.catalog`; tap → `ai.selectProvider(id)`; selection highlighted | Selected provider visually distinct | source |
| R4 Model picker | Picker over `ai.provider?.models`; → `ai.selectModel(id)` | Updates selected model | source |
| R5 API key entry | SecureField prefilled from `ai.currentKey` via local @State mirrored on appear/provider change; keyHint placeholder; 保存 → `ai.setKey`; 获取 link to keyHelpURL | Saves to keychain; link opens | source |
| R6 Test connection | Builds `CloudChatClient(provider:modelID:apiKey:)`; spinner; green ✓+reply / red ✗+error; disabled when key empty | Runs async, shows result | source |
| R7 Status line | Shows `ai.statusSummary` live | Reflects state | source |
| R8 Nav title + preview | `.navigationTitle("AI 模型")` + `#Preview` injecting `.environment(AICredentialStore())` | Title set, preview compiles | source |
| R9 Builds | macOS + iOS isolated derivedData builds | `** BUILD SUCCEEDED **`, 0 errors | build logs |

## 3) Plan
1. Read all referenced APIs + design system + sibling settings screens (DONE).
2. Write `AISettingsView.swift` using DBCard/DBSectionHeader/DBChip/button styles, matching ProfileSettingsCard + AccountView voice.
3. Build macOS isolated; fix errors. Then build iOS once.
4. Update handoff with results.

## 4) To-Do & Progress Ledger
- [x] Read AICredentialStore / AIProvider / CloudChatClient — confirmed exact members.
- [x] Read design system tokens + components + sibling screens.
- [x] Write AISettingsView.swift.
- [x] macOS build `** BUILD SUCCEEDED **`, 0 errors (/tmp/dd-aiset).
- [x] iOS build `** BUILD SUCCEEDED **`, 0 errors (/tmp/dd-aiset-ios, iPhone 17 Pro).

## 8) Verification Summary
- macOS: `xcodebuild ... -destination 'platform=macOS' -derivedDataPath /tmp/dd-aiset` → `** BUILD SUCCEEDED **`.
- iOS: `xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/dd-aiset-ios` → `** BUILD SUCCEEDED **`.
- Only new file `豆包爱学/Features/Profile/AISettings/AISettingsView.swift` was created by this session. The `M` markers on ProfileSettingsCard.swift / ProfileView.swift are the USER's own NavigationLink wiring (`AISettingsView()` at ProfileSettingsCard.swift:268) — not touched by me. The successful build confirms the `init() {}` contract + `@Environment(AICredentialStore.self)` injection line up.

## 5) Findings, Decisions, Assumptions
- `@Bindable var ai` cannot be used on an `@Environment` value directly for two-way Toggle binding; will use an explicit `Binding(get:set:)` calling `ai.setCloudEnabled`.
- API key kept in local `@State` mirrored from `ai.currentKey` on `.onAppear` and `.onChange(of: ai.providerID)` so switching providers reloads the right key.
- Test result modeled as a local enum (`idle/running/success/failure`) for clean state rendering. Provider/model captured into a value snapshot before the Task to satisfy Sendable across the await boundary.
- Privacy line text per spec: "API Key 仅保存在本机钥匙串，端侧加密；不开启则使用端侧/离线智能。"

## 6) Issues, Mistakes, Recoveries
- (to fill during build)

## 7) Scenario-Focused Resolution Tests
- (to fill after build)

## 8) Verification Summary
- (to fill)

## 10) Updates
- 2026-06-16: Created handoff; read all APIs + design system; starting implementation.
