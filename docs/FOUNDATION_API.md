# FOUNDATION_API.md — Contract for Feature Agents

> The Wave 0 foundation is built and **builds green on iOS 26 + macOS 26**. This
> document is the **authoritative API** you (a feature agent) must code against.
> Use ONLY the symbols documented here plus Apple frameworks. Do not invent
> foundation types; do not edit shared folders (`App/`, `DesignSystem/`,
> `Models/`, `Services/`). Add files ONLY to your assigned `Features/<X>/` folder.

---

## 0. Hard rules (read first)

1. **One module, synchronized files.** Every `.swift` file under `豆包爱学/` compiles into one target. Adding a file to your folder is enough — no project edits.
2. **Swift 6, `MainActor` default isolation.** Views, `@Observable` view models, and anything UI is MainActor by default — good. **Pure data value types (structs/enums) you add must be marked `nonisolated`** if a SwiftData `@Model` or a nonisolated service will touch them (this is why all shared enums/DTOs are `nonisolated`). When in doubt for a plain `Codable`/`Sendable` helper type, mark it `public nonisolated`.
3. **Every async screen handles all states** via `ViewState` + `DBStateView`/`DBStateContainer`.
4. **Provide `#Preview`s** for your main views.
5. **Guard platform APIs** with `#if os(iOS)` / `#if os(macOS)` / `#if canImport(UIKit)`. Camera/Pencil are iOS-only; on macOS fall back to file import / typed input. Never break either platform.
6. **Use the Mock-backed services** — never call a network. The injected `IntelligenceService` already returns rich, correct data offline.
7. **Chinese-first copy**, warm & encouraging, matching the product (see RESEARCH §5).
8. **Do NOT edit** `App/AppDestinations.swift`, `App/AppShell.swift`, `App/AppRouter.swift`, or anything in `Models/`, `Services/`, `DesignSystem/`. The integrator wires your view into navigation. Just build the view types named in your task.

---

## 1. Design System (`DesignSystem/`)

### Colors (`Color.db*`, all dynamic light/dark)
`dbPrimary, dbPrimaryDeep, dbPrimarySoft, dbSecondary, dbSecondarySoft, dbAccent, dbAccentSoft, dbBackground, dbBackgroundAlt, dbSurface, dbSurfaceRaised, dbSeparator, dbTextPrimary, dbTextSecondary, dbTextTertiary, dbOnPrimary, dbSuccess, dbWarning, dbError, dbInfo, dbSuccessSoft, dbErrorSoft`.
- `Color.dbHeroGradient` → `LinearGradient` for hero surfaces.
- `Color(hex: 0xRRGGBB)`, `Color(light:dark:)` initializers.
- `DBSubjectColor.color(for: Subject) -> Color`.

### Typography (`Font.db*`)
`dbLargeTitle, dbTitle, dbTitle2, dbTitle3, dbHeadline, dbBody, dbBodyEmph, dbCallout, dbSubheadline, dbFootnote, dbCaption, dbCaption2, dbMonoBody, dbScore`. All `.rounded`.

### Spacing / Radius / Shadow
- `DBSpacing.{xxs,xs,sm,md,lg,xl,xxl,xxxl,huge,screenInset,cardGap}` (CGFloat).
- `DBRadius.{xs,sm,md,lg,xl,xxl,pill}`.
- `.dbShadow(_ elevation: DBElevation = .low)` and `.dbSurfaceStyle(cornerRadius:fill:elevation:)` on any View. `DBElevation = .none|.low|.medium|.high`.

### Components (all `public`, with previews)
- `DBCard(padding:cornerRadius:fill:elevation:) { content }`.
- `Button(...).buttonStyle(.db(_ variant: DBButtonVariant = .primary, fullWidth: Bool = false))` — variants `.primary/.secondary/.ghost/.destructive`.
- `DBChip(_ title, systemImage:, tint:, isSelected:)`, `DBSubjectChip(_ Subject, isSelected:)`, `DBTag(_ text, tint:)`.
- `DBSectionHeader(_ title, subtitle:, systemImage:) { trailing }`.
- `DBStateView(kind:title:message:systemImage:retry:)` — kind `.empty/.loading/.error/.offline/.success`.
- `DBStateContainer(_ state: ViewState<T>, retry:) { value in … }`.
- `DBProgressRing(progress:lineWidth:tint:label:)`.
- `DBAvatar(name:size:gradeBadge:)`, `DBMascot(mood:size:)` — mood `.happy/.thinking/.cheering/.sleepy/.curious`.
- `DBToolTile(title:systemImage:tint:subtitle:compact:action:)`.
- `DBBadge(count:tint:)`, `DBStreakView(days:)`, `DBValueStat(value:caption:systemImage:tint:)`, `DBRouteBadge(_ IntelligenceRoute)`.
- `DBSearchField(text: Binding<String>, placeholder:)`.
- `DBFlowLayout(spacing:)` — wrapping `Layout` for chips.
- `LiquidGlass`: `.dbGlass(in:)`, `.dbGlassProminent(in:)`, `.dbGlassSurface(cornerRadius:)`.
- `MathText(_ expression: String, font: Font = .dbBody)` — renders LaTeX-ish math accessibly. Use for any formula/answer line.

### State system
```swift
enum ViewState<Value> { case idle, loading, loaded(Value), empty(message:), error(message:), offline(message:) }
```

---

## 2. Enums (`Models/AppEnums.swift`) — all `nonisolated`, `Codable`, `Sendable`

- `Subject`: math, physics, chemistry, biology, chinese, english, science, history, geography, politics, general — `.displayName`, `.symbolName`, `.isSTEM`.
- `GradeStage`: primary, juniorHigh, seniorHigh, college — `.displayName`, `.symbolName`.
- `GradeLevel`: g1…g12 (Int raw 1–12) — `.displayName`, `.stage`, Comparable.
- `TextbookEdition`: renjiao, beishida, sujiao, waiyan, huadong, rujiao, unspecified — `.displayName`.
- `MasteryState`: new, weak, developing, mastered — `.displayName`, `.progress` (0…1).
- `ErrorType`: concept, method, calculation, careless, knowledgeGap, comprehension — `.displayName`.
- `ProblemSource`: camera, album, document, text, voice, handwriting — `.displayName`, `.symbolName`.
- `CaptureMode`: solve, grade — `.displayName`, `.symbolName`.
- `ToolKind`: solve, gradeArithmetic, gradeEssay, mistakeNotebook, dictation, vocabulary, oral, translation, knowledgeQA, classical, documentQA, recognizeAnything, classroom, knowledgeGraph, drill, reports — `.displayName`, `.symbolName`, `.category`.
- `ToolCategory`: qa, grade, memory, expression, extend — `.displayName`.
- `IntelligenceRoute`: onDevice, cloud, mock — `.badgeLabel`, `.symbolName`.

## 3. Shared value types (`Models/SharedValueTypes.swift`) — `nonisolated`, Codable

`KnowledgeRef(id,name,subject)`, `FigureRef(kind,caption,systemSymbol)`, `SolutionStep(index,title,detail,math?,figure?)`, `ChoiceOption(label,text,isCorrect,explanation)`, `BoardElement(kind: .title/.text/.formula/.bullet/.highlight/.divider/.answer, content)`, `TutorCheckpoint(prompt,options,answerIndex,explanation)`, `TutorSegment(narration,board,checkpoint?)`, `RubricDimension(name,score,maxScore,comment)`, `SentenceAnnotation(original,comment,suggestion?,severity: .praise/.suggestion/.error)`, `WordScore(word,score)`, `RichBlock(kind: .text/.math/.image/.code/.suggestion/.action, content, auxiliary?)`, `DictationEntry(text,reading,meaning)`.
Helper: `DBJSON.encode/decode` (used internally by models).

## 4. SwiftData models (`Models/`) — read/write via `@Query` / `modelContext`

All have `id`, sensible defaults, and ergonomic accessors (`.subject`, `.grade`, `.steps`, etc.). Key ones:
- `LearnerProfile` — `nickname, grade, stage, subjects:[Subject], editions, onboardingComplete, isMinor, learnModeEnabled, preferredRoute, streakDays, problemsSolved`.
- `ProblemRecord` — `subject, source, recognizedText, imageData, steps:[SolutionStep], choices, finalAnswer, approach, knowledgePoints, route, savedToMistakes`.
- `MistakeItem` — `subject, questionText, imageData, studentAnswer, correctAnswer, errorReason, errorType, mastery, knowledgePointIDs, steps, reviewCount, nextReviewAt, createdAt`.
- `KnowledgePointEntity` — `id:String, name, subject, grade, summary, parentIDs, relatedIDs, chapter`.
- `MasteryRecord` — `knowledgePointID, subject, score(0…1), attempts, correctCount, consecutiveExplains, .state`.
- `EssayRecord` — `subject, title, promptText, originalText, overallComment, score, maxScore, examType, rubric, annotations, polishedText, highScoreExpressions`.
- `PracticeSession` (+ `PracticeAttempt` via `.attempts`) — `subject, title, kindRaw, targetKnowledgePointIDs, totalCount, correctCount, estMinutes, completed, .progress`.
- `WordDeck` (+ `WordCard` via `.cards`) — deck: `name, subject, grade, unit, .dueCount`; card: `headword, phonetic, definition, examples, easeFactor, intervalDays, repetitions, dueDate, mastery`.
- `DictationList` (`entries:[DictationEntry]`, `language`) + `DictationResult`.
- `CourseEntity` (`title, author, dynasty, subject, grade, summary, durationSec, isUGC, reviewVerified, generationStatusRaw, segments:[TutorSegment], knowledgePointIDs`) + `LessonProgress`.
- `DocumentEntity` (`title, fileType, pageCount, parsedText, summary, keyPoints, outline`).
- `Conversation` (+ `ChatMessageEntity` via `.messages`/`.sortedMessages`) — message: `role, text, blocks:[RichBlock], route`.
- `StudyPlan, StudyReminder, ActivityLog, StudyStreak, ParentControls`.

To persist: `@Environment(\.modelContext) var context` → `context.insert(...)`, `try? context.save()`. To read: `@Query(...) var items: [Model]`.

## 5. Intelligence (`Services/Intelligence/`)

Get it: `@Environment(\.intelligence) private var intelligence` → `any IntelligenceService`.
Methods (all `async throws` unless noted; DTOs in §3 / IntelligenceDTOs.swift):
```swift
intelligence.solve(SolveRequest) -> SolvedProblem
intelligence.gradeEssay(EssayGradeRequest) -> EssayFeedback
intelligence.gradeArithmetic(ArithmeticGradeRequest) -> GradedArithmetic   // really computes!
intelligence.similarProblems(SimilarRequest) -> [GeneratedProblem]
intelligence.explainKnowledgePoint(ExplainRequest) -> KnowledgeExplanation  // 背景/内容/价值 sections
intelligence.summarizeDocument(DocSummarizeRequest) -> DocumentSummary
intelligence.answerAboutDocument(DocQARequest) -> DocAnswer
intelligence.generateLesson(LessonRequest) -> GeneratedLesson
intelligence.gradeDictation(DictationGradeRequest) -> DictationGrading       // really diffs!
intelligence.scorePronunciation(PronunciationRequest) -> PronunciationScore
intelligence.tutorSession(TutorRequest) -> AsyncThrowingStream<TutorEvent, Error>   // .segment / .done
intelligence.chat(ChatRequest) -> AsyncThrowingStream<ChatChunk, Error>            // delta + final blocks
```
Request DTOs have sensible defaults; e.g. `SolveRequest(recognizedText:subject:grade:mode:learnMode:)`. Every response carries a `.route: IntelligenceRoute` → show a `DBRouteBadge(response.route)`.

Other services:
- `@Environment(\.ocr) var ocr: OCRService` → `recognizeText(in: Data) async -> String`, `recognizeLines`, `recognizeArithmeticItems(in:) async -> [ArithmeticItem]`. With no real image, fall back to sample/typed text.
- `@Environment(TTSService.self) var tts` (injected) → `tts.speak(_ text, language:"zh-CN", rate:)`, `tts.stop()`, `tts.isSpeaking`. (For English use `"en-US"`.)
- `SpeechRecognitionCoordinator()` (`@Observable`, create as `@State`): `startListening()`, `stopListening(simulated:) -> String`, `isListening`. Use for hold-to-talk; returns a deterministic transcript.
- `SRSScheduler.update(SRSState, grade: ReviewGrade) -> SRSState` for vocabulary/mistake review. `ReviewGrade`: again/hard/good/easy.
- `StudyPlanner.weakest([WeakPoint], limit:)`, `.estimatedMinutes(forTargets:)`.
- `HapticEngine.play(.success/.warning/.error/.light/.selection)`.
- `NotificationService()` → `requestAuthorization()`, `scheduleDaily(...)`.

## 6. Content catalog (`Services/Catalog/ContentCatalog.swift`)

`ContentCatalog.poems: [CatalogPoem]` (七步诗, 夏日绝句, 水调歌头, 出塞, 早发白帝城, 静夜思), `.courses`, `.englishUnit: [CatalogWord]`, `.dictationChinese/.dictationEnglish: [DictationEntry]`, `.knowledgePoints: [CatalogKnowledgePoint]`, `.sampleProblems`, `.sampleArithmetic: [ArithmeticItem]`, `.sampleEssay: String`. The DB is seeded from these on first run, so `@Query` already returns rich data.

## 7. Navigation (`App/AppRouter.swift`)

Get it: `@Environment(AppRouter.self) private var router`.
- Detect width: `@Environment(\.horizontalSizeClass) var sizeClass`; `let isRegular = sizeClass != .compact`.
- Push: `router.navigate(.tool(.dictation), regular: isRegular)` etc. `Route`: `.tool(ToolKind)`, `.mistakeDetail(UUID)`, `.course(UUID)`, `.knowledgePoint(String)`, `.conversation(UUID)`, `.wordDeck(UUID)`, `.dictation(UUID)`, `.document(UUID)`, `.reports`.
- Present a sheet: `router.present(.capture(.solve))`, `.tutor(problemText:subject:grade:)`, `.parentGate(reason:)`, `.search`.
- `router.openTool(_ ToolKind, regular:)` routes solve/grade to camera sheets and others to `.tool` push.
- **Do not** build your own NavigationStack at the screen root — the shell provides it. Just set `.navigationTitle(...)` and return content. Detail/route views you provide WILL be embedded in a stack.

## 8. What to deliver & how it gets wired

Build the **view type(s) named in your task** with the **exact init** specified, set `.navigationTitle`, handle all states, add previews. The integrator wires your view into `AppDestinations` (the one shared seam) — you do not touch navigation. If your feature needs to be launched from a tool tile, it maps from `.tool(<yourToolKind>)`; from a sidebar section it maps from `AppSection`. Name views clearly (e.g. `DictationView`, `MistakeNotebookView`, `EssayGradingView`).

Keep view models as `@Observable @MainActor final class <Feature>Model` with an `init` taking the services it needs (or read services from `@Environment` in the view and pass into an async method). Persist results to SwiftData via `modelContext`.
