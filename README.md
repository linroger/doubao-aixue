<div align="center">

# 豆包爱学 · Doubao Ai Xue

### A native iOS + macOS K‑12 AI study companion

**On‑device‑first intelligence · provider‑agnostic AI · one universal SwiftUI codebase**

[简体中文](README.zh-CN.md) · English

</div>

---

> A native, Apple‑platform reimagining of a K‑12 AI study app — **better integrated, more
> intuitive, and enhanced with on‑device intelligence.** It runs fully **offline** out of the
> box (a deterministic mock engine backs every feature), and can be upgraded to real cloud or
> on‑device models without touching a single feature view.

## Highlights

- **One codebase, three form factors.** `TabView` on iPhone, `NavigationSplitView` on iPad &
  Mac — the same feature views, idiomatic on each platform. True multi‑pane study sessions on
  large screens.
- **Works offline, today.** A fully functional `MockIntelligenceService` ships by default:
  deterministic, demoable, no network or entitlements required. The app **never** hard‑depends
  on a backend.
- **Bring your own AI.** Optionally route to on‑device Apple Foundation Models, or to a cloud
  provider of your choice (豆包 / 通义千问 / 智谱 GLM / Kimi / DeepSeek / MiniMax / Claude /
  Gemini / OpenAI). Keys live in the Keychain; every AI feature flows through one abstraction.
- **Pedagogy, not answer‑dumping.** A "Learn Mode" (attempt‑first, graduated Socratic hints,
  parent‑gated full reveal) runs through Solve, Essay, and the Tutor.
- **Local‑first, sync‑ready.** SwiftData is the source of truth; every model is
  CloudKit‑compatible, so cross‑device sync can be switched on without a schema migration.

## Features

The app implements **70+ features** across the full K‑12 study workflow.

### 📸 Solve & grade
- **拍照搜题 / Photo solve** — capture or import a problem → calibrate → OCR (printed,
  handwriting, formulas) → editable recognized question.
- **框选单题 / 整页批改** — crop a single problem, or detect every problem on a page with
  per‑item ✓/✗.
- **结构化解答 / Structured solution** — 思路 · 步骤 · 答案 · 知识点, with accessible LaTeX‑ish
  math rendering and diagrams.
- **实时扫题 / Live scan** — VisionKit live‑text capture on iOS, graceful fallback to photo
  solve elsewhere.
- **作业批改 / Workbook grading** — photograph, pick from album, or import a file; the AI grades
  **every** question into a subject‑agnostic `GradedWorkbook` (math / 语文 / English / any),
  shown as a score summary plus per‑question ✓/✗/◐ cards (student vs. correct answer, 错因,
  explanation, 知识点 chips, steps, rubric). Multimodal vision on capable models, OCR‑text on
  others, deterministic offline engine as a universal fallback. **批改历史** re‑renders any past
  grading identically and offline.

### 🧑‍🏫 Tutor & companion
- **豆包老师 / Dynamic‑blackboard tutor** — voice‑first, streamed board + narration, hold‑to‑talk
  "是否听懂了" comprehension loop, interruptible follow‑ups, grade‑level tiered explanation.
- **AI 伙伴 / Companion** — 知识问答 open‑domain Q&A, 成长挚友 (safety‑gated), 识万物
  recognize‑anything lens, intent dispatch to specialized skills, resumable conversation history.
- **Voice & rate** — dialect/accent picker (普通话 / 粤语 / 台湾国语 / English) + speed slider.

### ✍️ Practice
- **作文批改 / Essay grading** — overall + per‑sentence feedback, score, 升格 suggestions,
  read‑aloud, a rubric radar chart, coach‑not‑write.
- **口算批改 / 口算练习** — batch arithmetic grading and grade‑adaptive drills.
- **靶向练习 / Targeted practice** — knowledge‑graph‑driven daily weak‑point training.
- **听写 / Dictation** — TTS reads, you write, OCR auto‑checks.
- **背单词 / Vocabulary SRS** — spaced‑repetition decks, cards, and quizzes.
- **英语口语 / Oral** — scenario role‑play with correction + pronunciation scoring.
- **课文翻译 · 文言文 / Translation & Classical Chinese** — passage OCR → bilingual + gloss +
  read‑aloud; classical‑poem study, recite check, and "talk to the poet".
- **模拟测验 / Timed exam** — pick subject / count / duration → live countdown → auto‑graded
  report with per‑question review and 加入错题本.

### 📚 Knowledge & courses
- **错题本 / Mistake notebook** — collect, classify, and review wrong questions; 组卷 / export;
  bulk 加入题库.
- **错因分析 + 知识图谱 / Knowledge graph** — weak‑point mapping with targeted drill launch.
- **知识点讲解 2.0** — 背景 → 内容 → 价值 explanations tied to a personal knowledge graph.
- **题库 / Question bank** — save wrong (or any) questions for review; filter by subject / star,
  reveal answers, 让豆包老师讲. A **forgetting‑curve review loop** (again / hard / good / easy →
  mastery + next‑review) and a **今日复习** due filter.
- **智能出题 / AI question generation** — turn banked questions into 同类练习, then re‑bank the
  generated items for even more review.
- **豆包课堂 · 定制课程 / Courses** — interactive AI lessons with timestamp quizzes; on‑demand
  lesson generation.
- **文档/PDF 问答 / Document Q&A** — import → summary/outline + chat Q&A.

### 📊 Insight & motivation
- **答题足迹 / Contribution heatmap** — a GitHub‑style daily heatmap that counts **every**
  answered, graded, or practiced question per calendar day (5‑level green growth scale,
  calendar‑week columns, scroll‑anchored to today, month + weekday labels, accessibility per
  cell). A central `ActivityRecorder` funnels every learning surface into one consistent record,
  so the heatmap, **streak**, and reports never disagree. Surfaced in 个人中心, 今日, and 学习报告.
- **学习报告 / Reports** — time, mastery, and trend charts with 薄弱点预警.
- **今日 / Today** — a single‑glance daily planner: goal ring + streak, targeted practice, due
  mistakes & vocabulary, continue‑learning, a 7‑day time chart — all deep‑linked.
- **成就墙 / Achievements** — XP / level ring, streak heat‑strip, tiered badge wall with persisted
  unlock dates — derived live from real history.

### 🧩 Shell & platform
- 4‑tab adaptive navigation (首页 / 学习 / 工具 / 我的) · onboarding + grade wizard · Sign in
  with Apple + guest · 个人中心 · 工具 hub with search · empty/loading/error/offline state system.
- **家长模式 / Parent mode** — verification gate, answer hiding, controls, report.
- **Unified search**, **App Intents / Siri / Spotlight**, **macOS menus & shortcuts**
  (拍照解题 ⌘N, 批改 ⇧⌘G, 今日练习 ⌘T, 问豆包 ⌘L, 搜索 ⌘F, sections ⌘1–⌘9), 科学计算器 +
  公式库, and a 专注 · 番茄钟 focus timer.

## Architecture

A clean, layered SwiftUI architecture. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full
blueprint.

```
App        DoubaoAiXueApp · RootView · AppShell · AppRouter (typed routes)
Features   Home · Solve · Tutor · Practice · Knowledge · Courses · Companion
           · Reports · Workbook · QuestionBank · Exam · Tools · Profile · …
Services   IntelligenceService (Mock | FoundationModels | Cloud) · OCR/Vision
           · Speech (ASR + TTS) · SRS · ContentCatalog · Planner · ActivityRecorder
Data       SwiftData @Model entities · ModelContainerFactory · SampleData
Design     DBTheme tokens · DB* components · Liquid Glass · MathText · ViewState
```

- **Provider‑abstracted AI.** Every model call goes through the `IntelligenceService` protocol,
  injected via `\.intelligence`. Three implementations: `MockIntelligenceService` (default,
  offline, deterministic), `FoundationModelsService` (on‑device Apple Intelligence when
  available), and a multi‑provider `CloudIntelligenceService`. DTOs crossing the boundary are
  pure `Sendable` value types; features map them to SwiftData models for persistence.
- **Single navigation source of truth.** `AppRouter` (`@Observable`, `@MainActor`) with typed
  `Route`s; cross‑feature deep links resolve through it, never via direct view references.
- **Concurrency.** `MainActor` default isolation, Swift 6 strict concurrency; heavy work is
  `async` / `Sendable`.
- **Build model.** A single app target with a synchronized file group — any file under
  `豆包爱学/` is compiled automatically (no `.pbxproj` edits to add sources).

**Tech:** Swift 6 · SwiftUI · SwiftData · Observation · Swift Charts · Vision/VisionKit ·
Speech/AVFoundation · PencilKit · App Intents · (optional) FoundationModels.

## Requirements

- **Xcode 26** or newer
- **iOS 26** (iPhone + iPad) · **macOS 26** (Apple silicon)

## Build & run

```bash
# Clone
git clone https://github.com/linroger/doubao-aixue.git
cd doubao-aixue

# Open in Xcode (scheme: 豆包爱学) and run on a simulator or your Mac
open 豆包爱学.xcodeproj

# …or build from the command line:
./init.sh            # build macOS (default)
./init.sh ios        # build for the iOS Simulator
```

The app launches straight into a richly seeded demo (sample profile, mistakes, decks, courses,
a knowledge graph, and ~12 weeks of activity) and is fully usable **offline** against the mock
engine — no API key required.

### Enabling real AI (optional)

Open **Settings → 多模型 / AI provider**, pick a provider, and paste an API key (stored in the
Keychain). Every AI feature — Solve, Tutor, Workbook grading, Essay, Companion, Document Q&A,
question generation — then routes to your chosen model, with automatic fallback to on‑device /
offline when a request can't be served. Vision‑capable models additionally power image‑based
Solve and Workbook grading.

## Releasing the macOS app (.dmg)

```bash
./scripts/package_dmg.sh          # → dist/豆包爱学.dmg (Release, ad‑hoc signed, locally runnable)
```

This builds the Release configuration, ad‑hoc signs the app, and wraps it in a drag‑to‑install
disk image. The DMG is **ad‑hoc signed, not notarized**, so on first launch use
**right‑click → Open** (macOS remembers the choice). See [`RELEASE.md`](RELEASE.md) for the
notarization path (requires a paid Apple Developer account).

## Project layout

| Path | What's there |
|---|---|
| `豆包爱学/` | All Swift source (auto‑compiled synchronized group) |
| `豆包爱学/App` · `…/Features` · `…/Services` · `…/Models` · `…/DesignSystem` | Layered architecture |
| `scripts/package_dmg.sh` · `notarize.sh` | macOS release tooling |
| `lesson_content/` · `scripts/generate_lesson_catalog.py` | Bundled lesson catalog + generator |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) · [`RELEASE.md`](RELEASE.md) · `RESEARCH.md` · `PLAN.md` | Design docs |
| `feature_list.json` | Traceable feature backlog (each marked passing) |

## Privacy

By default the app processes everything **on device** (mock or Apple Foundation Models) and
stores data locally in SwiftData. Cloud AI is strictly opt‑in: nothing leaves the device until
you add a provider key, and keys are stored in the system Keychain.

## License

This is a personal, educational reimplementation built for learning and demonstration. "豆包爱学"
and related names are trademarks of their respective owners; this project is not affiliated with
or endorsed by ByteDance.

---

<div align="center"><sub>Built with SwiftUI for iOS 26 + macOS 26.</sub></div>
