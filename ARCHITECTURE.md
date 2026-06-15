# ARCHITECTURE.md — 豆包爱学 (Doubao Ai Xue) Native iOS + macOS

> A native, Apple-platform reimagining of ByteDance's 豆包爱学 K12 AI-study app —
> **better integrated, more intuitive, optimized, and enhanced** with on-device
> intelligence. This document is the **authoritative blueprint** every build agent
> codes against. It is grounded in `RESEARCH.md` (the 67-feature product dossier).

**Targets:** iOS 26 (iPhone + iPad) · macOS 26 (Apple silicon). One universal SwiftUI codebase.
**Language:** Swift 6 (language mode 6.0), `MainActor` default isolation, strict concurrency.
**Frameworks:** SwiftUI · SwiftData · Observation · Swift Charts · Vision/VisionKit · Speech/AVFoundation · PencilKit · App Intents · (optional) FoundationModels.
**Build model:** single app target, `PBXFileSystemSynchronizedRootGroup` → any file under `豆包爱学/` is compiled automatically (no `.pbxproj` edits to add sources).

---

## 1. Design Goals & Guiding Principles

1. **On-device-first intelligence.** Unlike the cloud-only original, every capability has an on-device path (Foundation Models / Vision / Speech) so the app works **offline and privately**. Cloud is an optional enhancement behind a transparent route policy. This is the headline differentiator (see RESEARCH §8 Tier 0).
2. **Pedagogy, not answer-dumping.** Default "Learn Mode": attempt-first, graduated Socratic hints, the 豆包老师 dynamic-blackboard tutor. Trust posture for students, parents, schools.
3. **One adaptive codebase.** `TabView` on iPhone, `NavigationSplitView` on iPad/Mac — same feature views, idiomatic per platform. True multi-pane study sessions on big screens.
4. **Provider-abstracted AI.** All model calls go through `IntelligenceService`. A fully functional **`MockIntelligenceService`** ships by default (deterministic, offline, demoable). A `FoundationModelsService` is used when Apple Intelligence is available. The app NEVER hard-depends on a network backend.
5. **Local-first persistence, sync-ready.** SwiftData is the source of truth; models are CloudKit-compatible so cross-device sync (错题本, plans, decks, knowledge graph) can be switched on without a schema change.
6. **Green build is sacred.** Every increment compiles for iOS + macOS. Features degrade gracefully (`#if os()`, availability checks) rather than break the build.
7. **Warm, child-friendly, Liquid-Glass-native.** Rounded, soft, mascot-led design language (RESEARCH §5) expressed through one design system, full Dark Mode, Dynamic Type, VoiceOver, SF Symbols, haptics.

---

## 2. Layered Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  App layer        DoubaoAiXueApp · RootView · AppShell · AppRouter    │
│                   ModelContainer + AppEnvironment injection           │
├─────────────────────────────────────────────────────────────────────┤
│  Feature layer    Home · Solve · Tutor · Practice(Essay/Arithmetic/   │
│  (SwiftUI views   Dictation/Vocabulary/Oral/Drill) · Knowledge(Mistake│
│   + @Observable   Notebook/Graph/Point) · Courses(Classroom/DocQA) ·  │
│   view models)    Companion(Chat/GrowthFriend) · Reports · Tools ·    │
│                   Profile · Onboarding · Parent · Settings · Search   │
├─────────────────────────────────────────────────────────────────────┤
│  Domain services  IntelligenceService (Mock | FoundationModels)       │
│                   + RoutePolicy · OCRService (Vision) · CaptureService │
│                   · SpeechService (ASR+TTS) · SRSScheduler ·          │
│                   ContentCatalog · StudyPlanner · NotificationService │
├─────────────────────────────────────────────────────────────────────┤
│  Data layer       SwiftData @Model entities · ModelContainerFactory · │
│                   SampleData seeding · (CloudKit-ready config)         │
├─────────────────────────────────────────────────────────────────────┤
│  Design system    DBTheme tokens · components · Liquid Glass · states │
├─────────────────────────────────────────────────────────────────────┤
│  System integ.    App Intents · Spotlight · Widgets/Live Activities*  │
│                   · Handoff · Continuity Camera · Family Controls*     │
└─────────────────────────────────────────────────────────────────────┘
  * extension-target features are architected & data-ready; the extension
    targets themselves are a documented follow-up (kept out of the single
    app target to preserve a frictionless green build).
```

**Dependency rule:** Features depend on Domain services, Data, and Design system — never on each other. Cross-feature navigation goes through `AppRouter` + typed routes, not direct view references. Domain services depend on Data + DTOs only. The Intelligence layer returns **value-type DTOs**; features map DTOs → SwiftData models for persistence.

---

## 3. Folder / Module Map (under `豆包爱学/`)

```
App/                 DoubaoAiXueApp.swift, RootView.swift, AppShell.swift,
                     AppRouter.swift, AppEnvironment.swift
DesignSystem/
  Theme/             DBTheme.swift, DBColors.swift, DBTypography.swift,
                     DBSpacing.swift, DBRadius.swift, DBShadow.swift
  Components/        DBCard, DBButtonStyle, DBChip, DBTag, DBSectionHeader,
                     DBStateView, DBProgressRing, DBAvatar, DBMascot,
                     DBSearchField, DBToolTile, DBBadge, DBStreakView, ...
  Glass/             LiquidGlass.swift (glass helpers, availability-guarded)
  Math/              MathText.swift (LaTeX-ish typeset rendering, accessible)
Models/              SwiftData @Model entities + shared enums/value types
                     (LearnerProfile, ProblemRecord, MistakeItem,
                      KnowledgePointEntity, MasteryRecord, EssayRecord,
                      WordDeck/WordCard, DictationList/DictationResult,
                      CourseEntity/LessonProgress, Conversation/Message,
                      PracticeSession, DocumentEntity, StudyPlan/Reminder,
                      ActivityLog/StudyStreak, ParentControls, AppEnums.swift)
Services/
  Intelligence/      IntelligenceService.swift (protocol), IntelligenceDTOs.swift,
                     MockIntelligenceService.swift, FoundationModelsService.swift,
                     RoutePolicy.swift, IntelligenceEnvironment.swift
  Vision/            OCRService.swift, CaptureService.swift, ImageCalibration.swift
  Speech/            SpeechService.swift (ASR), TTSService.swift, PronunciationScorer.swift
  Persistence/       ModelContainerFactory.swift, SampleData.swift
  Catalog/           ContentCatalog.swift (sample courses, poems, word lists,
                     textbook tree, tools), CatalogModels.swift
  Planner/           SRSScheduler.swift, StudyPlanner.swift
  System/            NotificationService.swift, HapticEngine.swift
Features/
  Home/  Solve/  Tutor/  Practice/{Essay,Arithmetic,Dictation,Vocabulary,Oral,Drill}/
  Knowledge/{MistakeNotebook,Graph,Point}/  Courses/{Classroom,DocumentQA}/
  Companion/{Chat,GrowthFriend}/  Reports/  Tools/  Profile/  Onboarding/
  Parent/  Settings/  Search/
Intents/             AppShortcuts + App Intents (SolveIntent, StartDictationIntent,
                     ReviewMistakesIntent, ...)
Assets.xcassets/     (existing) AppIcon, AccentColor
```

Every folder is auto-included via the synchronized group. Agents add files to their feature folder only.

---

## 4. App Shell & Navigation

- **`AppRouter` (`@Observable`, `@MainActor`)** — single navigation source of truth:
  - `selectedTab: AppTab` (`home`, `study`, `tools`, `me`)
  - `path(for:)` → per-tab `NavigationPath`
  - `sidebarSelection: AppSection?` (iPad/Mac)
  - `presentedSheet: AppSheet?` (solve capture, tutor session, auth, parent gate, doc import)
  - typed `Route` enum for push destinations; `navigate(to:)`, `present(_:)`, `popToRoot(_:)`.
- **`AppShell`** chooses layout by size class / platform:
  - **Compact (iPhone):** `TabView` (4 tabs) + a prominent **center Solve action** (floating camera button / `.tabItem` accent). Camera is the hero.
  - **Regular (iPad/Mac):** `NavigationSplitView` — sidebar of `AppSection`s (Home, Solve, Tutor, 错题本, Knowledge Graph, Courses, Documents, Practice tools, Reports, Companion, Profile) · content list · detail. Enables 3-pane study (problem | whiteboard | chat).
- **`RootView`** gates on `LearnerProfile.onboardingComplete` → Onboarding wizard or `AppShell`.
- Cross-feature deep links (e.g., solution → "加入错题本", knowledge node → practice) resolve through `AppRouter.Route`.
- **Handoff / Continuity:** each major screen publishes an `NSUserActivity`; Continuity Camera scans from iPhone into Mac.

`AppTab`, `AppSection`, `AppRouter.Route`, `AppSheet` are defined in `App/AppRouter.swift` and are part of the shared contract.

---

## 5. Intelligence Layer (the core abstraction)

All AI flows through one protocol so the app is provider-agnostic and offline-capable.

```swift
protocol IntelligenceService: Sendable {
    var capabilities: IntelligenceCapabilities { get }                 // onDevice / cloud / mock
    func solve(_ req: SolveRequest) async throws -> SolvedProblem
    func gradeEssay(_ req: EssayGradeRequest) async throws -> EssayFeedback
    func gradeArithmetic(_ req: ArithmeticGradeRequest) async throws -> GradedArithmetic
    func similarProblems(_ req: SimilarRequest) async throws -> [GeneratedProblem]
    func tutorSession(_ req: TutorRequest) -> AsyncThrowingStream<TutorEvent, Error>  // streamed board+narration
    func chat(_ req: ChatRequest) -> AsyncThrowingStream<ChatChunk, Error>            // streamed tokens
    func explainKnowledgePoint(_ req: ExplainRequest) async throws -> KnowledgeExplanation
    func summarizeDocument(_ req: DocSummarizeRequest) async throws -> DocumentSummary
    func answerAboutDocument(_ req: DocQARequest) async throws -> DocAnswer
    func generateLesson(_ req: LessonRequest) async throws -> GeneratedLesson
    func gradeDictation(_ req: DictationGradeRequest) async throws -> DictationGrading
    func scorePronunciation(_ req: PronunciationRequest) async throws -> PronunciationScore
}
```

- **DTOs** (`IntelligenceDTOs.swift`) are pure `Sendable` value types (`SolvedProblem`, `SolutionStep`, `EssayFeedback`, `TutorEvent { .narration(String) | .board(BoardOp) | .checkpoint(Question) | .done }`, etc.). They contain **no** SwiftData/UI types.
- **`MockIntelligenceService`** (default, always available): deterministic, plausible, structured outputs driven by `ContentCatalog` + templated generators. Simulates streaming by chunking. Makes the entire app demoable offline with no entitlements. **This is the reference implementation — every feature must work against it.**
- **`FoundationModelsService`** (`#if canImport(FoundationModels)` + `@available(iOS 26, macOS 26, *)` + `SystemLanguageModel.isAvailable`): uses `LanguageModelSession` with `@Generable` structured outputs mapped to the same DTOs. Falls back to Mock when the model is unavailable.
- **`RoutePolicy`** maps `taskType → onDevice | cloud | mock`, exposes an **"on-device vs enhanced"** badge to the UI, and currently routes everything to on-device/mock (cloud is a documented seam).
- Injected via SwiftUI `Environment` (`\.intelligence`). Features depend only on the protocol.

Vision/Speech are separate domain services (`OCRService`, `SpeechService`, `TTSService`, `PronunciationScorer`) wrapping VisionKit/Vision/Speech/AVFoundation with mock fallbacks for the simulator.

---

## 6. Data Layer (SwiftData)

- **`ModelContainerFactory.makeContainer(inMemory:)`** builds the schema and seeds `SampleData` on first run (sample profile, mistakes, decks, courses, poems, knowledge graph) so the app is rich on launch.
- **CloudKit compatibility rules (enforced for every `@Model`):** every stored property has a default value or is optional; **no `@Attribute(.unique)`**; all relationships are optional with explicit inverses; enums stored as raw `String`/`Int`; binary blobs (images) stored as `Data` with `.externalStorage`. This lets `CloudKitDatabase: .automatic` be enabled later without migration.
- **Key entities** (see `Models/`): `LearnerProfile`, `ProblemRecord`, `SolutionPayload`(Codable JSON), `MistakeItem`, `KnowledgePointEntity`, `MasteryRecord`, `EssayRecord`, `WordDeck`/`WordCard`, `DictationList`/`DictationResult`, `CourseEntity`/`LessonProgress`, `Conversation`/`ChatMessageEntity`, `PracticeSession`/`PracticeAttempt`, `DocumentEntity`, `StudyPlan`/`StudyReminder`, `ActivityLog`/`StudyStreak`, `ParentControls`.
- Large/structured AI payloads (solution steps, essay feedback) are stored as `Codable` structs encoded into a `Data`/JSON column to avoid deep relationship graphs.
- Identity: `id: UUID = UUID()` on every model (plain attribute, not unique-constrained).

---

## 7. Design System

- **Tokens** (`DBTheme`): semantic colors (primary warm-coral `豆包橙`, secondary teal, accent, success/warn/error, surfaces, subject colors), typography scale (rounded SF / `.rounded` design), spacing scale (4/8/12/16/20/24/32), corner radii (sm/md/lg/xl, pill), soft shadows. Defined in code (no asset edits required), Dark-Mode-aware via `Color` dynamic providers.
- **Components** (`DB*`): `DBCard`, `DBButtonStyle` (primary/secondary/ghost), `DBChip`, `DBTag`, `DBSectionHeader`, `DBStateView` (empty/loading/error/offline with mascot illustration), `DBProgressRing`, `DBAvatar`, `DBMascot`, `DBToolTile`, `DBBadge`, `DBStreakView`, `DBSearchField`, `DBValueStat`. All Dynamic-Type + VoiceOver friendly.
- **Liquid Glass** (`LiquidGlass.swift`): availability-guarded helpers applying iOS/macOS 26 glass materials to bars, sheets, and floating actions; graceful fallback to `.regularMaterial`.
- **MathText** (`DesignSystem/Math`): lightweight accessible math/formula renderer (attributed Core Text) used by solutions, essays, blackboard. No external dependency.
- **State system:** `ViewState<T>` enum (`idle/loading/loaded(T)/empty/error(Message)/offline`) + `DBStateView` so every async screen handles all states consistently (RESEARCH F59).

---

## 8. Cross-Cutting Systems

- **Learn Mode / Anti-cheat:** `LearnModePolicy` (attempt-first, graduated hints, paste-detection, effort logging). Solve/Essay/Tutor honor it. Parent-gated full-answer reveal.
- **Parent mode:** `ParentControls` model + verification gate; architected toward Family Controls/Screen Time (in-app simulation now, system APIs as a seam).
- **Search:** unified `SearchService` over tools/history/错题本/decks/courses/documents (the original lacks this) → Spotlight-indexable.
- **App Intents** (`Intents/`): `SolveIntent`, `StartDictationIntent`, `ReviewMistakesIntent`, `StartTutorIntent`, `DueReviewsProvider` — power Siri/Shortcuts/Spotlight and (future) widgets.
- **Notifications:** forgetting-curve review reminders, daily targeted-practice nudges, streak check-ins.
- **Accessibility & i18n:** VoiceOver labels, Dynamic Type, reduced-motion respect; Chinese-first copy with structure ready for localization (String Catalog generation is enabled).

---

## 9. Platform Adaptation Strategy

| Concern | iPhone (compact) | iPad / Mac (regular) |
|---|---|---|
| Shell | `TabView` + center Solve action | `NavigationSplitView` (sidebar/content/detail) |
| Tutor | full-screen board + voice bar | 3-pane: problem · board · chat |
| Solve capture | live camera viewfinder | Continuity Camera / file import / drag-drop |
| 错题本 | stacked list + filters sheet | master-detail with inline filters |
| Knowledge graph | zoomable canvas, sheet detail | canvas + side detail panel |
| Pencil | supported | first-class (handwritten math, board ink) |

Guard platform-only APIs with `#if os(iOS)` / `#if os(macOS)`. Camera/Pencil are iOS/iPadOS; Mac uses import + Continuity Camera. No feature is fully unavailable on a platform — it degrades to an import/typed path.

---

## 10. Concurrency Model

- `MainActor` default isolation (project-wide). Views, view models, routers are `@MainActor`.
- Heavy work (`IntelligenceService`, OCR, ASR/TTS) is `async` and `Sendable`; providers are actors or stateless `Sendable` structs. DTOs crossing boundaries are `Sendable` value types.
- No shared mutable singletons; dependencies injected via `Environment`/init. `ContentCatalog` is an immutable `Sendable` value.

---

## 11. Build Orchestration Plan (how the app gets built)

1. **Wave 0 — Foundation (single-writer, main loop):** design system, data models, intelligence protocol + DTOs + Mock service, Vision/Speech service shells, `ContentCatalog`, persistence, `AppRouter`/`AppShell`/app wiring. Establish + verify GREEN. Emit `docs/FOUNDATION_API.md` (exact shared symbols).
2. **Wave 1 — P0 features (parallel agents):** Home, Solve, Tutor, MistakeNotebook, Essay, Arithmetic, Onboarding, Profile, ToolsHub, Companion chat, Knowledge explanation. Each agent owns one folder, codes against `FOUNDATION_API.md`, never edits shared files.
3. **Wave 2 — P1 features (parallel agents):** KnowledgeGraph, Courses/Classroom, DocumentQA, Dictation, Vocabulary SRS, Oral, Drill, Reports/analytics, Translation, Classical Chinese, Search, Parent, Settings, App Intents.
4. **Integration passes:** build iOS + macOS after each wave; a fix workflow resolves compile errors; self-review + simplify.
5. **Validation:** launch macOS app, screenshot key flows, verify against acceptance checks; update `handoff.md`, `feature_list.json`, `agent-progress.txt`.

**Conflict-avoidance contract for agents:** (a) add files only under your feature folder; (b) never modify `Models/`, `Services/`, `DesignSystem/`, `App/` — request changes via the integrator; (c) use only symbols documented in `FOUNDATION_API.md` + Apple frameworks; (d) every view handles all `ViewState`s; (e) guard platform APIs; (f) provide `#Preview`s.

---

## 12. Acceptance / Definition of Done (architecture-level)

- Builds GREEN for `platform=macOS` and `platform=iOS Simulator` after every wave.
- App launches to onboarding → shell with seeded sample data; all 4 tabs populated.
- Every P0 feature is reachable and functional against `MockIntelligenceService` (offline, no network).
- Adaptive layout verified on iPhone (tabs) and Mac/iPad (split view).
- No placeholder/TODO code in shipped features; all states handled; previews compile.
- `RESEARCH.md` → feature backlog traceable to implemented views (`feature_list.json`).
