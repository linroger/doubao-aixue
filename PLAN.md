# PLAN.md — 豆包爱学 Native Build Plan (Atomic Tasks)

> Execution plan for building the app defined in `ARCHITECTURE.md` from the
> `RESEARCH.md` backlog. Tasks are atomic, owned, ordered by dependency, and each
> has an acceptance check. Status legend: `[ ]` planned · `[~]` in progress ·
> `[x]` done · `[!]` blocked. Keep this file and `feature_list.json` in sync.

**Invariant:** after every wave, `./init.sh` builds GREEN for iOS + macOS.
**Orchestration:** Wave 0 by the main loop (single writer). Waves 1–2 by parallel
subagent workflows, one agent per feature folder, coding against
`docs/FOUNDATION_API.md`. Integration + fix passes between waves.

---

## Wave 0 — Foundation (single-writer; critical path)

> Defines every shared contract. Nothing else can start until this is GREEN.

### 0.A Design System
- [ ] **T0.1** `DesignSystem/Theme/` — `DBColors` (semantic + subject palette, Dark-Mode dynamic), `DBTypography` (rounded scale), `DBSpacing`, `DBRadius`, `DBShadow`, `DBTheme` aggregator. *Accept:* compiles; a preview renders a swatch sheet.
- [ ] **T0.2** `DesignSystem/Components/` — `DBCard`, `DBButtonStyle`, `DBChip`, `DBTag`, `DBSectionHeader`, `DBProgressRing`, `DBAvatar`, `DBMascot`, `DBToolTile`, `DBBadge`, `DBStreakView`, `DBSearchField`, `DBValueStat`. *Accept:* each has a `#Preview`; compiles.
- [ ] **T0.3** `DesignSystem/Components/DBStateView.swift` + `ViewState<T>` enum. *Accept:* empty/loading/error/offline render with mascot.
- [ ] **T0.4** `DesignSystem/Glass/LiquidGlass.swift` — availability-guarded glass modifiers. *Accept:* compiles on both platforms with fallback.
- [ ] **T0.5** `DesignSystem/Math/MathText.swift` — accessible attributed math renderer. *Accept:* renders `x^2 + \frac{1}{2}` style input; VoiceOver label.

### 0.B Data Models
- [ ] **T0.6** `Models/AppEnums.swift` — `Subject`, `GradeStage`, `GradeBand`, `TextbookEdition`, `MasteryState`, `ProblemSource`, `ToolKind`, `AppTab`, `AppSection`, etc. (all `String`-raw, `Sendable`, `CaseIterable`).
- [ ] **T0.7** `Models/` SwiftData `@Model`s (CloudKit-compatible): `LearnerProfile`, `ProblemRecord`, `MistakeItem`, `KnowledgePointEntity`, `MasteryRecord`, `EssayRecord`, `WordDeck`, `WordCard`, `DictationList`, `DictationResult`, `CourseEntity`, `LessonProgress`, `Conversation`, `ChatMessageEntity`, `PracticeSession`, `PracticeAttempt`, `DocumentEntity`, `StudyPlan`, `StudyReminder`, `ActivityLog`, `StudyStreak`, `ParentControls`. *Accept:* schema builds in a `ModelContainer`.
- [ ] **T0.8** `Models/Codable payloads` — `SolutionPayload`, `EssayFeedbackPayload`, etc. stored as JSON `Data`. *Accept:* round-trips.

### 0.C Intelligence Layer
- [ ] **T0.9** `Services/Intelligence/IntelligenceDTOs.swift` — all request/response value types (`SolveRequest`/`SolvedProblem`/`SolutionStep`, `EssayGradeRequest`/`EssayFeedback`, `ArithmeticGradeRequest`/`GradedArithmetic`, `SimilarRequest`/`GeneratedProblem`, `TutorRequest`/`TutorEvent`/`BoardOp`, `ChatRequest`/`ChatChunk`, `ExplainRequest`/`KnowledgeExplanation`, `DocSummarizeRequest`/`DocumentSummary`, `DocQARequest`/`DocAnswer`, `LessonRequest`/`GeneratedLesson`, `DictationGradeRequest`/`DictationGrading`, `PronunciationRequest`/`PronunciationScore`, `LearnerContext`, `IntelligenceCapabilities`). All `Sendable`. *Accept:* compiles.
- [ ] **T0.10** `Services/Intelligence/IntelligenceService.swift` — protocol (§5). `IntelligenceEnvironment.swift` — `EnvironmentKey` + `\.intelligence`.
- [ ] **T0.11** `Services/Intelligence/MockIntelligenceService.swift` — full deterministic implementation driven by `ContentCatalog`; streaming via chunked `AsyncThrowingStream`. *Accept:* unit-callable; returns plausible structured data for every method.
- [ ] **T0.12** `Services/Intelligence/FoundationModelsService.swift` — `#if canImport(FoundationModels)` provider with `@Generable` outputs + Mock fallback. *Accept:* compiles whether or not FM is present.
- [ ] **T0.13** `Services/Intelligence/RoutePolicy.swift` — task→route mapping + badge. *Accept:* compiles.

### 0.D Vision / Speech / Planner / System services
- [ ] **T0.14** `Services/Vision/OCRService.swift`, `CaptureService.swift`, `ImageCalibration.swift` — Vision/VisionKit wrappers + mock recognizer (returns sample LaTeX/text). *Accept:* protocol + mock compile on both platforms.
- [ ] **T0.15** `Services/Speech/SpeechService.swift` (ASR), `TTSService.swift`, `PronunciationScorer.swift` — AVFoundation/Speech wrappers + mock. *Accept:* compiles; mock TTS no-ops gracefully.
- [ ] **T0.16** `Services/Planner/SRSScheduler.swift` (SM-2/Leitner), `StudyPlanner.swift`. *Accept:* scheduling unit math verified.
- [ ] **T0.17** `Services/System/NotificationService.swift`, `HapticEngine.swift`. *Accept:* compiles, guarded per platform.

### 0.E Catalog & Persistence
- [ ] **T0.18** `Services/Catalog/ContentCatalog.swift` + `CatalogModels.swift` — sample subjects, textbook tree, tool catalog, 11 sample 豆包课堂 courses, classical poems, word lists, sample problems, knowledge-point graph. Immutable `Sendable`. *Accept:* compiles; non-empty.
- [ ] **T0.19** `Services/Persistence/ModelContainerFactory.swift` + `SampleData.swift` — schema + first-run seeding. *Accept:* container builds; seeds visible.

### 0.F App Shell
- [ ] **T0.20** `App/AppRouter.swift` — `@Observable` router, `AppTab`, `AppSection`, `Route`, `AppSheet`, navigation API.
- [ ] **T0.21** `App/AppEnvironment.swift` — DI container (intelligence, ocr, speech, catalog, planner) injected into environment.
- [ ] **T0.22** `App/AppShell.swift` — adaptive `TabView` ↔ `NavigationSplitView`; routes tab/section → feature roots (temporary placeholders until features land).
- [ ] **T0.23** `App/RootView.swift` + `DoubaoAiXueApp.swift` — gate onboarding vs shell; install `ModelContainer` + environment. *Accept:* **app launches; GREEN iOS + macOS.**
- [ ] **T0.24** `docs/FOUNDATION_API.md` — generated reference of every shared symbol for Wave 1/2 agents.

**Wave 0 exit:** `./init.sh` GREEN both platforms; app launches into a shell with seeded data and placeholder feature screens; `FOUNDATION_API.md` published.

---

## Wave 1 — P0 Features (parallel subagents)

> One agent per folder. Each builds a real, mock-backed, all-states, previewed feature.

- [ ] **T1.1 Onboarding** (`Features/Onboarding/`) — F52/F53: grade-stage wizard, subject multi-select, textbook edition, permissions priming, writes `LearnerProfile`. (RESEARCH F52, F26.)
- [ ] **T1.2 Home** (`Features/Home/`) — F51 hero Solve entry, recommended carousels, continue-learning row, quick tool tiles, streak header. Adaptive.
- [ ] **T1.3 Solve** (`Features/Solve/`) — F1–F11: capture/import → OCR (Vision/mock) → editable recognized question → structured solution (思路/步骤/答案/知识点 via MathText) → action row (相似题 | 讲一讲 | 加入错题本 | 追问). Learn-Mode gating.
- [ ] **T1.4 Tutor 豆包老师** (`Features/Tutor/`) — F18–F22: streamed `TutorEvent` → animated blackboard (SwiftUI Canvas) + narration (TTS) + "是否听懂了" hold-to-talk loop + transcript + interruptible 追问; 3-pane on regular width.
- [ ] **T1.5 MistakeNotebook 错题本** (`Features/Knowledge/MistakeNotebook/`) — F12/F38/F46: filterable list (subject/error-type/time/knowledge point), entry detail (original+correct+错因+tags), multi-select 组卷 + export, forgetting-curve review queue.
- [ ] **T1.6 Essay 作文批改** (`Features/Practice/Essay/`) — F31: capture/type → 综合点评 + 分句点评 + score radar (Swift Charts) + 升格作文 diff + read-aloud; "coach not write" + parent gate.
- [ ] **T1.7 Arithmetic 口算批改** (`Features/Practice/Arithmetic/`) — F32: page capture → per-item ✓/✗ overlay + summary + 错因 + auto-add to 错题本.
- [ ] **T1.8 ToolsHub 工具** (`Features/Tools/`) — F58: categorized grid of `DBToolTile`s deep-linking to feature flows; search.
- [ ] **T1.9 Profile 我的** (`Features/Profile/`) — F54: header + stats + grade/subject settings + history/favorites/downloads + entries to reports/parent/settings.
- [ ] **T1.10 Companion Chat** (`Features/Companion/Chat/`) — F23/F27/F28: streamed chat, rich cards (text/math/image), suggested chips, intent dispatch, resumable history.
- [ ] **T1.11 Knowledge Explanation** (`Features/Knowledge/Point/`) — F44: structured 知识点 explanation (背景→内容→价值), 图文, 延伸提问, save-to-错题本.

**Wave 1 exit:** all P0 features reachable from shell, mock-backed, all-states; GREEN both platforms; macOS smoke launch screenshot.

---

## Wave 2 — P1 Features (parallel subagents)

- [ ] **T2.1 KnowledgeGraph** (`Features/Knowledge/Graph/`) — F13/F39/F44: zoomable mastery map (Canvas/Charts), tap-node → explanation/practice; heatmap.
- [ ] **T2.2 Classroom 豆包课堂** (`Features/Courses/Classroom/`) — F42/F43: PGC grid + 我的课程, interactive video lesson player (AVKit) with timestamp quizzes + ask-the-teacher + 三重审核 trust badge.
- [ ] **T2.3 DocumentQA** (`Features/Courses/DocumentQA/`) — F47/F16: import PDF/image → summary/key-points/outline + chat Q&A + select-to-explain.
- [ ] **T2.4 Dictation 听写** (`Features/Practice/Dictation/`) — F34: list source → TTS one-by-one playback (speed/gap/repeat) → handwriting/OCR check → per-word ✓/✗ → wrong-to-错题本.
- [ ] **T2.5 Vocabulary SRS 背单词** (`Features/Practice/Vocabulary/`) — F35: textbook-synced decks, swipeable cards, self-rate, SM-2 scheduling, quiz, due-today.
- [ ] **T2.6 Oral 英语口语** (`Features/Practice/Oral/`) — F36/F54: scenario role-play, ASR + live subtitles + inline correction + numeric pronunciation scoring (color heatmap).
- [ ] **T2.7 Drill 举一反三/练习** (`Features/Practice/Drill/`) — F8/F33/F45: targeted practice runner, generation, auto-grade, mastery feedback, daily 靶向 set.
- [ ] **T2.8 Reports 学习报告** (`Features/Reports/`) — F48/F55: time/mastery/trend charts (Swift Charts), 薄弱点预警 cards, weekly shareable report.
- [ ] **T2.9 Translation 课文翻译** (`Features/Practice/`... or `Features/Courses/`) — F37: passage OCR → bilingual aligned + read-aloud + tap-to-gloss.
- [ ] **T2.10 Classical 古诗文** (`Features/Courses/Classroom/` or `Features/Knowledge/`) — F41: poem study page (原文/译文/注释/赏析/断句) + recite check + talk-to-poet.
- [ ] **T2.11 Search** (`Features/Search/`) — unified search across tools/history/错题本/decks/courses/docs.
- [ ] **T2.12 Parent 家长模式** (`Features/Parent/`) — F40/F56: verification gate, answer-hiding, controls, weekly report view.
- [ ] **T2.13 Settings** (`Features/Settings/`) — appearance, voice/dialect, route policy (on-device/enhanced), notifications, Learn Mode, account.
- [ ] **T2.14 App Intents** (`Intents/`) — F (§8): `SolveIntent`, `StartDictationIntent`, `ReviewMistakesIntent`, `StartTutorIntent`, `AppShortcuts`, Spotlight donation.

**Wave 2 exit:** P1 features integrated; GREEN both platforms; updated docs + screenshots.

---

## Wave 3 — Polish & Validation
- [ ] **T3.1** Cross-feature deep links verified (solution→错题本, graph→practice, report→course).
- [ ] **T3.2** Accessibility pass (VoiceOver labels, Dynamic Type, reduced motion), Dark Mode pass.
- [ ] **T3.3** Liquid Glass + haptics polish on bars/sheets/floating actions.
- [ ] **T3.4** `/code-review`-style self-review + `simplify` pass; remove dead code.
- [ ] **T3.5** macOS app launch + screenshot key flows; iOS simulator boot + screenshot; record in `handoff.md` §7–8.
- [ ] **T3.6** Final docs: update `RESEARCH→feature_list` traceability, `agent-progress.txt`, `handoff.md` → Complete.

---

## Risk Register
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| FoundationModels API absent/shape-mismatch | Med | Low | Mock is default; FM behind canImport+availability+fallback |
| Parallel agents collide on shared types | Med | Med | Frozen `FOUNDATION_API.md`; agents add files in own folder only; integrator owns shared dirs |
| Swift 6 concurrency friction in services | Med | Med | MainActor default; services Sendable/actor; DTO value types |
| Single-module compile error hides culprit | Med | Low | xcodebuild file:line; fix workflow; build after each wave |
| Scope (67 features) overruns | High | Med | Strict P0→P1→P2 ordering; every feature ships mock-backed & functional, enhanced later |
| Widgets/Live Activities need extra targets | Low | Low | Data-ready + App Intents in-app; extension targets documented as follow-up |
