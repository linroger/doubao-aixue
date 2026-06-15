# 豆包爱学 (Doubao Ai Xue) — Definitive Product Research Report

> **Authoritative research input for a native iOS + macOS (SwiftUI, iOS/macOS 26) reimagining.**
> Target app: **豆包爱学 (Doubao Ai Xue / "Doubao Loves Learning")** — ByteDance's K12 AI study app, formerly **河马爱学 (Hippo Ai Xue)**, powered by the **豆包 (Doubao)** large model.
> This document consolidates seven structured research dossiers covering the photo-solve engine, subject practice tools, content/courses/knowledge graph, the AI companion layer, the app shell, the technical/AI architecture, and the competitive landscape. Where a claim is **confirmed** by sources it is stated plainly; **inferred** items (category norms, reasonable synthesis) are marked inline.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Product History & Positioning](#2-product-history--positioning)
3. [Information Architecture & Navigation](#3-information-architecture--navigation)
4. [Feature Inventory](#4-feature-inventory)
   - 4.1 [Photo Problem-Solving & Q&A Engine](#41-photo-problem-solving--qa-engine-拍照答疑拍照搜题拍照解题)
   - 4.2 [AI Companion: Chat, Voice, Multimodal, Agents](#42-ai-companion-chat-voice-multimodal-agents-planning)
   - 4.3 [Subject Practice & Assessment Tools](#43-subject-specific-practice--assessment-tools)
   - 4.4 [Content Library, Courses & Knowledge Graph](#44-content-library-courses--knowledge-graph)
   - 4.5 [App Shell: Onboarding, Account, Membership, Parent](#45-app-shell-onboarding-account-membership-parent)
5. [UI/UX Patterns & Visual Design Language](#5-uiux-patterns--visual-design-language)
6. [Technical & AI Architecture (Observed)](#6-technical--ai-architecture-observed)
7. [Competitive Landscape](#7-competitive-landscape)
8. [Opportunities to Surpass on Apple Platforms](#8-opportunities-to-surpass-on-apple-platforms)
9. [Consolidated Feature Backlog](#9-consolidated-feature-backlog)
10. [Sources](#10-sources)

---

## 1. Executive Summary

**豆包爱学** is ByteDance's free, ad-free, K12-focused AI study app, built end-to-end on the **豆包 (Doubao/Seed) multimodal large model** served via **火山引擎 (Volcano Engine)**. It targets primary, junior-high, and senior-high (小学 → 高中) students, their parents, and self-learners in the Chinese market (with practical reach claimed up to 大学/研究生). It is rated **4.8★ from ~360k ratings**, ranks **#9 in Education** on the China App Store, ships at ~254 MB on iOS 13+, and supports **iPhone, iPad (landscape), Mac (Apple silicon M1+), and Apple Vision Pro**.

**Core value loop.** The app's defining philosophy — repeated across reviews — is a deliberate shift **FROM** the old "search-and-show-the-answer" paradigm (作业帮/小猿搜题) **TO** "guide-the-student-to-think." It behaves like a patient 1-on-1 tutor:

```
   ┌──────────────┐    ┌───────────────┐    ┌──────────────┐    ┌──────────────┐
   │ CAPTURE      │ →  │ UNDERSTAND    │ →  │ TEACH        │ →  │ CONSOLIDATE  │
   │ 拍照/语音/    │    │ OCR+识别       │    │ 豆包老师      │    │ 错题本+知识图谱│
   │ 文字/手写     │    │ 结构化解析      │    │ 动态板书+语音  │    │ 举一反三+靶向 │
   └──────────────┘    └───────────────┘    └──────────────┘    └──────┬───────┘
          ▲                                                            │
          └──────────────── daily 5–10 min targeted practice ◄─────────┘
```

1. **Capture** a problem (photo of printed/handwritten work, single question or whole page, or via text/voice/handwriting).
2. **Understand** it via multimodal OCR (~98.3% recognition accuracy; ~99.1% math-step accuracy claimed).
3. **Teach** it through the flagship **豆包老师** AI teacher — a voice-first tutor that draws a **动态板书 (dynamic blackboard)** synchronized to spoken explanation, checks comprehension ("是否听懂了?"), adapts depth to grade level, and supports interruption/追问.
4. **Consolidate** via an auto-collected **错题本 (mistake notebook)**, a **personal 知识图谱 (knowledge graph)** that pinpoints weak points, **举一反三** auto-generated similar problems, and a **daily 5–10 minute targeted (靶向) practice** push — which feeds back into capture.

Surrounding this spine: full-subject **作业批改/作文批改** grading, **课文翻译**, **古诗文/文言文** support, **英语口语/听写/背单词**, **豆包课堂** (immersive AI video lessons built on the **Seedance** video model), document/PDF Q&A, a **成长挚友** emotional companion, and a lightweight **家长端** with weekly 学情周报 and parent-verification anti-cheat gating. Monetization is **indirect** (no in-app paywall or VIP wall; revenue flows through the broader Doubao/Douyin ecosystem and ByteDance "AI伴学机" hardware).

**Why it matters for the Apple rebuild.** The single most important architectural fact is that 豆包爱学 is **entirely cloud-dependent** — every capability is a thin client over Volcano Engine with **no meaningful offline mode**. A native iOS/macOS 26 app can win decisively on **(a)** on-device privacy and offline capability (Apple Foundation Models, VisionKit, Speech/SpeechAnalyzer, PencilKit), **(b)** deep Apple-system integration competitors cannot replicate (App Intents, Live Activities, widgets, SharePlay, Continuity/Handoff, Family Controls), and **(c)** a "tutor not cheat-engine" pedagogy and parental trust posture aligned with Chinese minors'-data regulation.

---

## 2. Product History & Positioning

### Timeline

| Date | Event |
|---|---|
| **Early 2024** | Launches as **河马爱学 (Hippo Ai Xue)**, built by **大力教育 (Dali Education)**'s "**ZERO**" AI-education team — ByteDance's re-entry into K12 after the 2021 "双减" retreat. Targets photo-solve and homework grading. |
| **May 2024** | At the Volcano Engine 原动力 conference, ByteDance renames its **云雀 (Skylark)** foundation model to **豆包大模型 (Doubao)**. |
| **Sept 2024** | **河马爱学 → 豆包爱学 rebrand.** The 大力教育/ZERO team is folded into the Doubao product line; the app becomes the **first product to carry the "豆包" brand name**. |
| **Sept 2025** | **豆包老师 (AI Teacher 1.0)** launches: real-time voice + dynamic blackboard + tiered guidance, deliberately **avatar-free**. |
| **Jan 2026** | **AI Teacher 2.0**: strategic shift from "讲题" (explain the problem) to "讲知识" (teach the knowledge); the feature is also promoted into the main 豆包 app (v2.0). |
| **~May 2026** | **豆包课堂** dedicated tab launches: "沉浸式AI视频课" built on ByteDance's **Seedance** video-generation model; first batch = 11 classical-Chinese poetry/文言文 courses. |

### Identity & Provenance

- **Publisher (China App Store):** 上海仁静信息技术有限公司 (Shanghai Renjing Information Technology) / 大力教育.
- **Bundle id:** `com.aitutor.hippo` — the "hippo" preserving its 河马 origin.
- **Brand language:** the soft, rounded, warm **豆包 mascot** with a "sisterly" (温柔的大姐姐) companion voice — distinct from the more neutral adult 豆包 app.

### Place in the Doubao Ecosystem

豆包爱学 is the **dedicated K12 "study" vertical** in ByteDance's AI "family bucket," sitting alongside:

- **豆包 (general assistant app):** the flagship, whose real-time **打电话 (voice call, sub-2s natural replies)** and one-way **视频通话 (camera-as-eyes)** define the interaction bar 豆包爱学 inherits. The 豆包老师 feature was later merged "up" into this app.
- **扣子 (Coze):** agent-building platform.
- **Gauth (overseas sibling):** the global homework solver (~200M users) — the closest competitive reference (see §7).
- **AI伴学机 hardware:** "AI study companion" devices that share the Doubao account and provide indirect monetization.

**Positioning statement.** A free, multimodal, **pedagogy-first** AI tutor for Chinese K12 — "全能助手" (all-purpose assistant) + "贴心朋友" (warm companion) — that teaches understanding rather than dispensing answers, while relieving parents of homework-checking burden ("母慈子笑").

---

## 3. Information Architecture & Navigation

The app is **deliberately flat and shallow** (most value ≤ 2 taps deep), child-friendly, **ad-free**, and **free of paywall surfaces**. Primary navigation is a confirmed **4-tab bottom bar**, with the camera/拍照答疑 as the hero action. The AI companion is the app's **spine** (hub-and-spoke: one LLM brain, many entry points), not a single tab.

### Confirmed Top-Level Tabs

| Tab | Chinese | Role |
|---|---|---|
| **Home** | 首页 | Hero 拍照答疑/拍一拍 camera entry, recommended content, recent activity, quick-entry tool cards. |
| **Study** | 学习 | Learning materials & courses, incl. **豆包课堂** immersive AI video lessons. |
| **Tools** | 工具 | Grid of all utilities: 拍题答疑, 作业批改, 作文批改, 错题本, 听写, 背单词, 口语跟读, 课文翻译, 知识专家, 创作大师, 古诗文. |
| **Profile** | 我的 | History, favorites, downloads, 错题本 access, grade/subject settings, 学习报告, account, settings, parent controls. |

### ASCII Navigation Tree

```
豆包爱学
│
├─ ① 首页 (Home)  ◄── default
│   ├─ 🎥 HERO: 拍照答疑 / 拍一拍 (camera)  ──┐
│   │     ├─ mode: 拍题 (solve)              │   the universal input funnel
│   │     └─ mode: 批改 (grade)              │   (also accepts album / PDF / voice / 手写)
│   ├─ Recommended content carousels         │
│   ├─ Recent / 继续学习 row                  │
│   └─ Quick-entry tool cards ───────────────┘ (deep-link into 工具 flows)
│
├─ ② 学习 (Study)
│   ├─ 豆包课堂 (immersive AI video lessons)
│   │     ├─ 精品课程 (PGC grid)
│   │     └─ 我的课程 / 定制课程 (UGC, on-demand generation)
│   ├─ 学习资料 / courses / 微课
│   └─ 教材同步 browse (学段 → 年级 → 版本 → 章节 → 知识点)
│
├─ ③ 工具 (Tools — feature 宫格)
│   ├─ 答疑:  拍题答疑 · 知识专家(知识问答)
│   ├─ 批改:  作业批改 · 口算批改 · 作文批改
│   ├─ 记忆:  听写 · 背单词 · 错题本
│   ├─ 表达:  英语口语/跟读 · 课文翻译
│   └─ 拓展:  古诗文/文言文 · 创作大师 · 文档/PDF问答 · 识万物
│
└─ ④ 我的 (Profile)
    ├─ Profile header (avatar, grade badge, streak/打卡, stats)
    ├─ 历史记录 / 收藏 / 下载
    ├─ 错题本 (cross-cutting)
    ├─ 学习报告 / 学情周报 (mastery heatmap, weak-point warning)
    ├─ 年级/学科/教材版本 settings (re-personalize)
    ├─ 家长验证 / 家长模式 (ID gate, 隐藏答案, 时间管理)
    └─ 设置 / 账号

CROSS-CUTTING OVERLAYS (launched from anywhere):
  • 豆包老师 full-screen session (voice + 动态板书 + 字幕 + 追问)
  • 成长挚友 companion chat (softer theme)
  • Parent-verification modal (gates 拍照搜题 / 作文生成)
  • Auth sheet (抖音/字节一键登录 · 手机 · 邮箱)

GLOBAL CONTEXT (set at onboarding, conditions everything):
  学段 + 年级 + 学科 + 教材版本/地区
```

### First-Run Flow

`Install → splash → (login or skip) → 学段 select (小学/初中/高中/大学 — NO "working professional") → 年级 → 学科 preferences → optional 教材版本/地区 → contextual permissions (camera/mic/photos/notifications) → personalized 首页.`

### Adaptive Mapping for the Apple Rebuild

- **iPhone:** `TabView` (Solve/Tutor · Study · Tools · Plan · Me) with the **camera as a center quick-action**.
- **iPad/Mac:** `NavigationSplitView` (history/subjects sidebar · content · detail) enabling **true multi-pane study sessions** (problem | whiteboard | chat) the current app only partially supports.

---

## 4. Feature Inventory

Organized by domain. Every feature from all seven dossiers is preserved; overlaps are **deduplicated** (e.g., 错题本, 举一反三, 知识图谱, document Q&A, 豆包课堂, parent gating appeared in multiple dossiers and are consolidated to their primary home with cross-references). Each carries a **priority** tag (P0 = core/highest-frequency, P1 = important, P2 = enhancement).

---

### 4.1 Photo Problem-Solving & Q&A Engine (拍照答疑/拍照搜题/拍照解题)

> The highest-value, highest-frequency surface — the app's universal input funnel.

#### F1. Camera Capture & Problem Scan — 拍照搜题 / 拍题答疑 · **P0**
- **What:** Primary entry point. Large camera button opens a live viewfinder; user shoots a printed/handwritten problem. Capture screen forks into **拍题 (solve)** and **批改 (grade)** modes, plus album upload. Copy: "一键拍照获取详细解析." Covers 小学→高中, all subjects.
- **Flow:** Open app → tap camera → live viewfinder with capture-frame guide → align → shutter → auto-crop preview → confirm → process → solution.
- **UI:** Full-screen viewfinder; bottom mode tabs (拍题 | 批改); center shutter; album thumbnail bottom-left; torch toggle; rectangular capture-guide overlay; minimal chrome.
- **States:** empty · capturing · low-light (suggest torch) · blurry/too-far (retake prompt) · permission-denied · processing.
- **Data:** `CaptureSession { id, sourceImage, mode: solve|grade, capturedAt, deviceOrientation }`.

#### F2. Auto-Deskew & Image Calibration — 画面校准 / 自动修正 · **P1**
- **What:** Confirmed "画面校准机制" auto-corrects tilted/skewed photos before recognition. Reduces retake friction (praised by reviewers).
- **Flow:** Shutter → detect document edges/perspective → auto-rotate/de-skew → corrected preview → user confirms or adjusts corners.
- **UI:** Detected-quadrilateral overlay; draggable corner handles; rotate; recapture/confirm.
- **States:** auto-detect-success · auto-detect-fail (manual corners) · corrected.
- **Data:** `ImageCorrection { sourceImage, detectedQuad[4], correctedImage, rotationDegrees }`.

#### F3. Single-Problem Crop / Region Selection — 框选单题 / 圈选题目 · **P0**
- **What:** When a page has multiple questions, user isolates one to solve (solve flow is one-question-at-a-time).
- **Flow:** Capture page → drag adjustable box around one question → confirm → solve only that.
- **UI:** Resizable crop rectangle; magnifier loupe near edges; "solve this" confirm.
- **States:** single-question (auto-fit box) · multi-question (prompt select) · reselect.
- **Data:** `RegionSelection { captureSessionId, cropRect, selectedQuestionImage }`.

#### F4. Multi-Problem Detection (Grade Mode) — 多题识别 / 整页批改 · **P0**
- **What:** In 批改 mode, recognizes an entire worksheet at once, segmenting and grading each item (口算题, 练习册, exercises). "全学科批改"; whole-试卷 recognition confirmed.
- **Flow:** Switch to 批改 → shoot whole worksheet → segment all → mark each ✓/✗ → tap flagged item for analysis (规律, 解题思路).
- **UI:** ✓ (green)/✗ (red) overlay on each detected region atop the photo; tappable regions; summary count (e.g. 8/10); list view below.
- **States:** all-correct · has-errors · partial-recognition (some unread) · low-confidence flagged.
- **Data:** `GradedPage { captureSessionId, items:[{ region, recognizedText, studentAnswer, correctAnswer, isCorrect, confidence }], correctCount, totalCount }`.

#### F5. Multimodal OCR (printed + handwriting + formulas) — 题目识别 · **P0**
- **What:** Multimodal Doubao model recognizes printed text, handwriting, math (LaTeX-level), physics, chemistry equations. ~98.3% accuracy. Known weak spots: underlined text, ellipsis (……).
- **Flow:** Image → OCR + layout analysis → recognized question rendered back as editable text/LaTeX for confirmation **before** solving.
- **UI:** Recognized-question card with inline-rendered math; "edit/修改" affordance; auto-detected subject chip.
- **States:** recognizing · recognized (editable) · low-confidence (highlight uncertain tokens) · unsupported-content.
- **Data:** `Recognition { image, recognizedLatex/text, subject, confidence, uncertainTokens[], editable }`.

#### F6. Step-by-Step Structured Solution — 思路·步骤·答案·知识点 · **P0**
- **What:** Core output: 思路 (approach) → 分步骤解析 (steps) → 答案 (answer) → 知识点 (tagged knowledge points). For multiple-choice, explains **every** option. Builds understanding, not just answers.
- **Flow:** After recognition → sections returned → action row (相似题 / 看视频讲解 / 加入错题本 / 追问).
- **UI:** Scrollable, collapsible sections; numbered steps; final answer in a boxed/highlighted card; tappable knowledge-point chips; **pinch-to-zoom** on the whole solution.
- **States:** loading (streaming) · complete · expandable · zoomed.
- **Data:** `Solution { recognitionId, approach, steps:[{index,text,math,figureRef}], finalAnswer, knowledgePoints:[{id,name}], confidence }`.

#### F7. LaTeX / Math & Diagram Rendering — 公式渲染 / 图示 · **P0**
- **What:** Inline math (fractions, exponents, integrals), chemistry equations, and figures (geometry auxiliary lines, area decompositions, physics free-body, illustrations) rendered within solutions and on the blackboard.
- **UI:** Inline typeset formulas; embedded diagrams; interleaved illustrations; all zoomable.
- **States:** render-success · render-fallback (raw on failure) · figure-loading.
- **Data:** `Renderable { latex, figureAssets:[{type:diagram|illustration,data}] }`.

#### F8. 举一反三 — Auto-Generated Similar Practice — 举一反三 / 相似题 · **P0**
- **What:** After solving, generates analogous problems so the student moves "从会做这道题到会做这类题." (Also surfaced via the AI companion and the practice tools — consolidated here.)
- **Flow:** Tap 举一反三/相似题 → N analogous problems on the same knowledge point → attempt → feedback/solution.
- **UI:** "相似题" button; generated cards with difficulty tags; attempt → check → reveal-solution.
- **States:** generating · ready · attempting · answered.
- **Data:** `SimilarProblem { sourceProblemId, knowledgePointId, generatedQuestion, answer, difficulty }`.

#### F9. Confidence / Accuracy & Recognition-Failure Handling — 准确率 / 置信度 · **P1**
- **What:** Handle low-confidence recognition (let user edit transcribed question), known OCR weaknesses, retake prompts — breaking the wrong-OCR → wrong-answer cascade. *(Quality surface; exact confidence-UI inferred.)*
- **UI:** Editable recognized-question field; "looks wrong? edit/retake" banner; subject-mismatch correction chip.
- **States:** high-confidence (auto-proceed) · low-confidence (prompt edit) · recognition-failed · wrong-subject.
- **Data:** `RecognitionQuality { confidence, uncertainSpans[], userCorrected }`.

#### F10. Subject Auto-Detection & Coverage Routing — 学科识别 / 全学科覆盖 · **P0**
- **What:** Detects subject and routes to the right solver/formatter. Coverage: 数学 (incl. 口算 +/−/×/÷), 物理, 化学, 语文 (comprehension, 作文), 英语 (grammar/vocab/tense, 作文), 科学/生物 — 小学→高中.
- **UI:** Subject chip on recognized-question card; subject filter in history/错题本; subject-specific layouts.
- **States:** auto-detected · user-overridden · ambiguous.
- **Data:** `SubjectRouting { detectedSubject, confidence, gradeBand, solverProfile }`.

#### F11. Solve History & Per-Problem Conversation Thread — 搜题历史 / 题目对话记录 · **P1**
- **What:** Each solved problem persists with image, solution, and follow-up conversation; resumable. *(Inferred from chat-anchored model + 错题本 persistence.)*
- **Flow:** History → pick past problem → re-view / resume 追问 / save to 错题本 / generate 相似题.
- **UI:** History list with thumbnails + recognized question + subject + date.
- **States:** empty · populated · searchable · filtered.
- **Data:** `ProblemThread { problemId, image, recognition, solution, followUps[], savedToMistakeBook, createdAt }`.

> Cross-references: **F8 举一反三**, **F12 错题本**, **F13 知识图谱**, **F14 daily targeted practice**, and **F15 video lessons** are all reachable directly from a solve result.

#### F12. Save to AI Mistake Notebook — 错题本 / 错题收录 · **P0**  *(canonical home; see also §4.3 F38, §4.4 F46)*
- **What:** Wrong/difficult problems auto-collected (or saved one-tap). "错题收录，AI 分析错因并推荐必练题." Organizable, exportable/printable.
- **Flow:** Graded ✗ or solved problem → auto-added / tap 收藏 → categorized by subject & knowledge point → revisit, re-practice, print.
- **UI:** "加入错题本" action; list grouped by subject/chapter/knowledge point; entries show original image, recognized question, correct solution, error reason; export/print.
- **States:** empty · populated · filtered · exported.
- **Data:** `MistakeEntry { problemImage, recognizedQuestion, studentAnswer, correctSolution, errorReason, subject, knowledgePointIds, createdAt, masteryStatus }`.

#### F13. Error-Cause Analysis & Knowledge-Graph Weak-Point Mapping — 错因分析 / 知识图谱 · **P1**  *(see also §4.4 F44)*
- **What:** AI analyzes **why** the student erred and maps mistakes to a personal 知识图谱 to pinpoint 薄弱环节.
- **UI:** Knowledge-graph/weakness visualization; per-point mastery indicators; per-mistake error reason.
- **States:** insufficient-data · graph-built · weak-areas-highlighted.
- **Data:** `KnowledgeGraphNode { knowledgePointId, masteryScore, linkedMistakes[], subject }`.

#### F14. Daily Targeted Practice Push — 靶向练习 / 每日必练 · **P1**  *(see also §4.4 F45)*
- **What:** Based on the weakness graph, pushes a 5–10 min daily targeted set. "系统会每日推送5-10分钟的靶向练习."
- **UI:** Daily-practice home card; timed mini-set; progress ring; results feed back into the graph.
- **States:** available · in-progress · completed · streak.
- **Data:** `PracticeSession { date, targetKnowledgePoints[], problems[], durationEstimate, result }`.

#### F15. 真人讲解视频 / Immersive AI Video Lessons attached to problems — 豆包课堂 · **P1**  *(canonical home §4.4 F42)*
- **What:** Video explanations tied to problems/topics. 河马爱学 heritage = real-teacher video; current product leans on 豆包课堂 immersive AI video. A given problem/knowledge point can offer a richer video walkthrough.
- **UI:** Video player with chapters tied to steps; related-topic course entry; immersive full-screen.
- **States:** available · unavailable-for-this-problem · buffering · playing · completed.
- **Data:** `VideoLesson { topicId/problemId, videoUrl, chapters[], durationSeconds, type:aiCourse|teacherVideo }`.

#### F16. Album Upload & Document/PDF Q&A — 相册上传 / 文档·PDF问答 · **P1**  *(see also §4.4 F47)*
- **What:** Upload images from album, plus documents for reading and Q&A. Ask about a screenshot, scanned worksheet, or PDF.
- **Flow:** Tap album/upload → pick image or doc/PDF → ingest → ask questions / solve within it.
- **UI:** Album picker; file picker; uploaded-doc viewer with Q&A chat panel; point-at-region-and-ask.
- **States:** uploading · parsing · ready-for-qa · unsupported-format · large-file-warning.
- **Data:** `UploadedSource { type:image|pdf|doc, fileRef, parsedContent, pageCount }`.

#### F17. Open-Ended / Encyclopedic Q&A (same solve UX) — 扩展性问答 / 百科答疑 · **P1**
- **What:** Handles open questions ("如果地球突然停止自转会怎样？") with the **same** decompose → illustrate → explain structure; a curiosity/encyclopedia tutor. "百科知识随问随答."
- **UI:** Text/voice input; same structured/illustrated card + blackboard; suggested follow-ups.
- **States:** answering · answered · follow-up-suggested.
- **Data:** `OpenQuery { questionText/voice, answerStructure, illustrations[], followUps[] }`.

---

### 4.2 AI Companion: Chat, Voice, Multimodal, Agents, Planning

> The connective tissue — one Doubao brain, many surfaces. Hub-and-spoke architecture.

#### F18. 豆包老师 — Voice-First Dynamic-Blackboard Tutor — 豆包老师 / AI老师 分步讲解 · **P0**
- **What:** Flagship conversational tutor. Decomposes a problem into sub-steps and teaches one at a time ("边做讲解，一步一步带着用户解题") rather than dumping the answer. Three confirmed pillars: **语音实时互动 (real-time voice)**, **动态板书演示 (dynamic blackboard — draws as it talks)**, **分层引导讲解 (tiered guided explanation)**. Prioritizes audio + visual board + key-point extraction over walls of text; tapping the voice bar reveals 字幕. Warm "温柔的大姐姐声线." Covers all K12 subjects + 生活百科.
- **Flow:** From a solution/拍题/错题 → tap "讲一讲"/AI老师 → teacher speaks while drawing → pauses at key steps to ask comprehension → student responds (voice/type) → continues → ends with extension question.
- **UI:** Animated blackboard canvas (primary surface) syncing strokes/figures to TTS; persistent voice/waveform bar (tap → expand transcript); persona avatar; pace/pause controls.
- **States:** speaking+drawing · paused (awaiting answer) · awaiting-voice-input · replaying-step · finished · interrupted.
- **Data:** `TutorSession { problemId, segments:[{narration, boardOps:[strokes/figures], checkpointQuestion?}], voicePersona, dialect, pace, transcript }`.

#### F19. Real-Time Voice Interaction & Comprehension Checks — 语音实时互动 / 是否听懂了 · **P0**
- **What:** Tutor speaks each step in a lively "讲解员" style, naming formulas/theorems used. At checkpoints asks aloud "是否听懂了?"; student **holds the voice button** to answer before continuing — a genuine spoken dialogue loop. Mirrors parent 豆包's sub-2s, noise-robust call UX.
- **Flow:** Narrate step → ask "是否听懂了?" → student holds mic, says "听懂了"/"没懂"/follow-up → ASR transcribes → advance or re-explain → loop.
- **UI:** Prominent hold-to-talk mic; live waveform; tappable voice chips → 字幕; replay any spoken step; speaker/voice-style indicator.
- **States:** tap-to-talk · transcribing · success · error (didn't catch) · offline (text-only).
- **Data:** `VoiceTurn { audioIn, transcript, intent[understood|confused|followup], confidence }`; `TutorVoice { text, audioOut, voiceStyleId, durationMs }`.

#### F20. Interactive Follow-Up / Interruptible Q&A — 追问 / 即时打断提问 · **P0**
- **What:** Student can interrupt at any time and ask follow-ups; AI re-explains. v5.1.2 added **pause** + **typed-reply** alternative to voice.
- **Flow:** During/after explanation → hold voice button (or type) → ask "why this step?" → tutor pauses, answers contextually, resumes/re-teaches.
- **UI:** Hold-to-talk button; checkpoint prompt bubbles; typed-reply keyboard; conversation thread anchored to the problem.
- **States:** listening · thinking · responding · resumed · mic-denied · typed-input.
- **Data:** `FollowUp { tutorSessionId, turns:[{role, text/voice, atStep}], mode:voice|text }`.

#### F21. Grade-Level / Tiered Explanation Adaptation — 分层引导 / 按年级调整 · **P0/P1**
- **What:** Adapts strategy and depth to grade. Confirmed example: 鸡兔同笼 solved with the intuitive **抬腿法** for grade 3 vs. **一元一次方程** for grade 7. Student can request a level ("用初一所学知识去解答").
- **UI:** Grade/学段 selector in profile; per-explanation "explain simpler/deeper" toggle; method-name badges (抬腿法 / 一元一次方程).
- **States:** default-for-grade · simplified · advanced.
- **Data:** `ExplanationConfig { gradeLevel, methodVariant, vocabularyLevel }`.

#### F22. Multi-Dialect / Multi-Language & Adjustable Pace — 方言讲解 / 语速调整 · **P2**
- **What:** Voice supports Mandarin, **东北话**, **粤语**, and English; adjustable speaking pace.
- **UI:** Dialect/language picker; speed slider (~0.75x–1.5x).
- **States:** default-voice · alt-dialect · faster/slower.
- **Data:** `VoiceConfig { dialect, language, rate }`.

#### F23. 知识问答 — Open-Domain Interactive Q&A — 知识问答 / 知识专家 · **P0/P1**
- **What:** Dialogue-based general + academic knowledge ("百科知识随问随答"). The general 豆包 chat brain scoped to a learning-safe context; multimodal (voice, handwriting, image).
- **UI:** Chat thread with rich cards (text/math/images/links), suggested follow-up chips, voice I/O, history sidebar.
- **States:** empty (example chips) · streaming · answered · error · offline (cached readable).
- **Data:** `Conversation { topicTag, messages[{role, richContent}], linkedKnowledgePointIds[] }`.

#### F24. 成长挚友 — Emotional Companion / Virtual Friend — 成长挚友 / 专属虚拟朋友 · **P1/P2**
- **What:** 24/7 emotional-support persona: "学习遇到烦心事…快去和豆包聊一聊，它是你专属的虚拟朋友." Warmer mode distinct from task tutoring; persona memory. **Sensitive for minors — heavy safety/compliance constraints.**
- **UI:** Softer chat theme; persona avatar; warm tone; voice option; mood-aware prompts.
- **States:** active · safety-filtered · offline (limited canned support).
- **Data:** `CompanionThread { turns[], moodTags, personaMemory }` — privacy-sensitive.

#### F25. 识万物 — Recognize-Anything Multimodal Lens — 识万物 · **P1**
- **What:** Camera-based "recognize everything" beyond textbook problems — point at object/plant/diagram/scene, get a conversational explanation. Mirrors parent 豆包's camera-as-eyes 视频通话.
- **Flow:** Open 识万物 → point camera → identify + explain → follow-ups → save to history.
- **UI:** Live viewfinder with recognition overlay; capture; result card (name + explanation + "ask more"); optional live video mode.
- **States:** camera prompt · recognizing · labeled result · error · offline (disabled).
- **Data:** `RecognitionEvent { image/videoFrame, detectedEntities[], explanationThread }`.

#### F26. Multimodal Input Pipeline (photo/text/voice/handwriting) — 多模态输入 · **P0**
- **What:** Unified input layer feeding all AI surfaces. Photo (full-page/single-question), typed text, voice, **手写识别 (handwriting)**. ~98.3% photo accuracy; ~99.1% math-step accuracy.
- **UI:** Unified composer with mode switcher (camera/text/voice/pencil); crop & multi-region select; editable OCR result; handwriting canvas; voice waveform.
- **States:** choose mode · OCR/ASR · recognized & editable · low-confidence (manual edit) · offline (text/pencil only).
- **Data:** `InputArtifact { type, rawAsset, recognizedText, confidence, regions[] }`.

#### F27. AI Orchestration / Cross-Feature Actions — AI串联：讲解、批改、出题、规划 · **P0**
- **What:** The companion is the hub dispatching natural-language intents to specialized skills: "explain this" (深度讲解, added 2024/06), "grade my work" (作业批改 + 错因), "make similar problems" (举一反三), "recognize this" (识万物), "build me a lesson" (豆包课堂 custom), "plan my practice" (daily drills).
- **UI:** Intent suggestion chips, slash-style quick actions, inline result cards that deep-link into the dedicated feature, seamless hand-off back to chat.
- **States:** action chips · dispatching · inline result · clarify intent · queue (offline).
- **Data:** `Intent { type, params } → Skill invocation → result entity linked back into Conversation`.

#### F28. Conversation Session & History / Continuity — 学习历史记录 / 接续学习 · **P0**
- **What:** All AI interactions persisted and history-aware: "依托学习历史记录实现课程内容的接续学习." Tutor recalls prior context, weak points, grade across sessions.
- **UI:** History sidebar grouped by subject/date; resumable session cards; search; per-session summary; cross-links to 错题/courses.
- **States:** empty · resumable threads · sync-conflict resolution · offline (locally cached).
- **Data:** `Session { id, subject, gradeContext, startedAt, summary, messages[], linkedEntities[] }` — user-scoped, syncable.

#### F29. Voice/Video Call Interaction Paradigm (from parent 豆包) — 打电话 / 视频通话 · **P1**
- **What:** Inherited interaction bar: real-time **打电话** (natural, sub-2s, noise-robust, lifelike timbre) + one-way **视频通话** (camera-as-eyes). In learning context = live spoken tutoring call + camera-based scene tutoring (basis for 识万物 / live problem walk-through).
- **UI:** Call screen with mic/camera toggles, live waveform, interrupt-to-speak, transcript toggle; camera viewfinder for live tutoring.
- **States:** tap-to-call · connecting · live · reconnect · offline (unavailable).
- **Data:** `CallSession { audioStream, optional videoFrames, transcript, durationMs }` — convertible to saved Session.

#### F30. Streaks / Motivation & Reminders — 打卡 / 学习提醒 / 激励 · **P2**
- **What:** Study reminders, completion encouragement, streak-style continuity, weekly 学情周报 cadence. *(Inferred from daily-practice push + 成长挚友 encouragement + parent report cadence.)*
- **UI:** Reminder notifications; streak counter; completion celebration; weekly digest.
- **States:** set-reminder-time · streak-update · notification-permission · offline (local reminders).
- **Data:** `ReminderSchedule { time, cadence }`; `StreakRecord { current, longest }`; `WeeklyReport`.

---

### 4.3 Subject-Specific Practice & Assessment Tools

> Turns the tutor from a one-shot answer engine into a closed learning loop (batch → learn → drill → consolidate).

#### F31. Chinese & English Essay Grading — 作文批改 · **P0**
- **What:** The most mature, heavily-marketed pillar. Photograph (OCR) or type a 语文/英语 essay; Doubao returns multi-dimensional feedback that **always praises strengths first** (综合点评 on 结构/审题/立意/用词), then **sentence-level** annotations (分句点评 flagging weak phrasing, spelling, grammar, logic), then revision/润色 suggestions, then a **polished/upgraded reference essay (升格作文)**, and **reads aloud where & why it changed things**. On "请给出评分" produces a rubric-referenced score (中考/高考). **Claimed 0.89 correlation with human-teacher scoring.** Closes the loop with a same-type 练手题. For English: 高分表达, 优秀范文参考, 易错提示.
- **Flow:** Tap 作文批改 → choose 语文/英语 + grade/exam type → photograph (multi-page OCR) or paste text + prompt → 综合点评 card + scrollable 分句点评 → "请给出评分" for rubric breakdown → 升格作文 with diff highlights → play voice explanation → accept same-type practice.
- **UI:** Camera+OCR capture; collapsible cards (Overall, Sentence-by-sentence, Score with rubric bars, Polished essay with colored diff, Audio-explain play); side-by-side original vs rewritten; "practice this type" CTA. **Parent-verification gate before full model essay.**
- **States:** capture/paste · OCR+grading spinner · feedback+score+rewrite · low-confidence OCR (re-shoot/correct) · illegible/off-topic warning · offline (queued, needs network).
- **Data:** `Essay { id, subject, gradeLevel, examType, promptText, sourceImages[], ocrText }`; `Feedback { overallComment, score{value,max,rubricDimensions[]}, sentenceAnnotations[], polishedEssay, revisionAudioUrl, strengths[], highScoreExpressions[] }`.

#### F32. Arithmetic / Mental-Math Batch Grading — 口算批改 · **P0**
- **What:** Original launch feature (河马爱学 era). Photograph a page of 口算/计算 → recognize each → auto-check → red ✓/✗ → explain error cause → auto-collect to 错题本. ~99.1% math step accuracy. Relieves parents ("母慈子笑").
- **Flow:** Tap 口算/作业批改 → photograph whole page → segment + recognize each problem & child's answer → ✓/✗ overlay → tap wrong item for 错因 + steps → auto-add to 错题本 → optionally generate 错题试卷 or 举一反三.
- **UI:** Full-page photo with per-problem bounding boxes + ✓/✗; summary bar (correct/total, accuracy %); tap-to-expand error sheet; "add to notebook" / "generate paper" buttons.
- **States:** take-photo · grading · annotated+summary · ambiguous handwriting (confirm) · blurry (re-shoot) · offline (needs network).
- **Data:** `Worksheet { id, subject:math, gradeLevel, image }`; `ProblemResult { bbox, recognizedExpression, studentAnswer, correctAnswer, isCorrect, errorType, solutionSteps[] }`.

#### F33. Math / Arithmetic Drill & 举一反三 Practice — 口算练习 / 数学练习 · **P0**
- **What:** Beyond grading, generates targeted practice with grade-adaptive strategies (鸡兔同笼: 抬腿法 grade 3 vs 一元一次方程 grade 7). Builds 错题试卷 from mistakes; daily targeted pushes. *(Inferred: timed mental-math drill mode; sources confirm generation, not a stopwatch.)*
- **Flow:** From wrong item/topic/knowledge point → 举一反三/练一练 → N similar problems at right difficulty → answer (type/photo) → check & explain → mastery updates; persistent misses re-queued.
- **UI:** Problem cards; answer input or photo capture; instant check + explanation; difficulty selector; "assemble into paper"; progress ring.
- **States:** pick-topic · generating · drill set · topic-too-broad (clarify) · offline (cached sets, deferred grading).
- **Data:** `PracticeSet { id, sourceType, gradeLevel, difficulty, problems[{stem,answer,solutionSteps,strategyTag}] }`.

#### F34. Dictation (AI reads, student writes, auto-check) — 听写 · **P1**
- **What:** Doubao reads words/phrases aloud **one-by-one** so the student writes them — Chinese 字词 and English words. Currently delivered through the conversational tutor / parent-assist flow rather than a dedicated engine. *(Inferred: custom lists, speed/interval control, repeat, OCR auto-grading.)*
- **Flow:** Ask Doubao to 报听写 for a unit/课文 or pasted list → reads each word → child writes → photograph → OCR check → mark ✓/✗ → wrong words to 错题本.
- **UI:** List source picker (textbook unit / custom / from 错题本); playback controls (speed slider, gap, repeat, next/prev); word counter; photograph-to-check with per-word ✓/✗; re-test-wrong button.
- **States:** choose list · playing · paused · checking (OCR) · per-word results · handwriting unrecognized (manual) · offline (cached TTS playable, OCR deferred).
- **Data:** `DictationList { id, language, words[{text, pinyinOrPhonetic, audioUrl, meaning}] }`; `DictationSession {...}`; `DictationResult { perWord[{word, writtenOcr, isCorrect}], score, wrongWords[] }`.

#### F35. Vocabulary Memorization / Word Cards — 背单词 / 单词卡 · **P1**
- **What:** Currently **embedded** in the conversational tutor / 课文翻译 (Doubao explains words, pronunciation, 拼读, example sentences) — **not** a standalone SRS deck. *(Inferred/opportunity: textbook-synced lists, swipeable cards, spaced-repetition scheduling, self-rated recall, quiz modes — a clear gap.)*
- **Flow (confirmed):** Ask about a word/unit → meaning, phonetics, examples, usage tips; tap unknown words in 课文翻译 for instant glossing. **(Inferred deck):** select textbook+grade+unit → word deck → flip cards → self-rate (会/模糊/不会) → SRS reschedule → quiz → dashboard.
- **UI:** Inline glossing in chat/translation; (inferred) card stack with audio, flip animation, recall self-rating, daily review queue, mastery bar, quiz modes.
- **States:** pick unit · learning · review-due · complete · word-not-in-dictionary · offline (cached decks).
- **Data:** `WordList { textbookEdition, grade, unit, words[{headword, phonetic, definition, examples[], audioUrl}] }`; `WordCardState { wordId, easeFactor, intervalDays, dueDate, recallHistory[] }`.

#### F36. English Conversational Speaking / Oral Coaching — 英语口语 / 口语陪练 · **P0**
- **What:** Real-time spoken-English via a call/voice mode. Live subtitles, in-line error correction + correct-expression suggestions, situational role-play (e.g., shopping where Doubao plays shopkeeper), switchable avatars/voices, selectable scenarios. *(Inferred: explicit numeric pronunciation scoring — accuracy/fluency/completeness 0–100 per sentence — NOT clearly surfaced today; an opportunity.)*
- **Flow:** Enter 口语/通话 → choose scenario + avatar/voice → tap voice button, speak → live subtitles + instant correction inline → continue turns. *(Inferred 跟读评测:* listen to model → record → per-word/phoneme scoring with color-coded results + sentence score.*)*
- **UI:** Call-mode screen with animated avatar, live subtitle area, mic button, scenario chips, voice/character picker; correction bubbles (wrong→right); (inferred) waveform + color-coded pronunciation heat + score gauge.
- **States:** choose scenario · listening/recording · processing (ASR+correction) · corrected feedback · no-speech/mic-denied · offline (needs network).
- **Data:** `OralSession { scenario, avatar, voice }`; `Turn { studentAudioUrl, asrText, correctionsApplied[], modelReply }`; *(inferred)* `PronScore { accuracy, fluency, completeness, perWord[], overall }`.

#### F37. Textbook Passage Translation & Read-Aloud — 课文翻译 · **P1**
- **What:** Beloved feature. Recognizes a photographed English (or classical Chinese) textbook passage, translates it, reads it aloud — bridging reading, listening, vocabulary (tap words for glossing).
- **Flow:** Tap 课文翻译 → photograph page → recognized text + translation, sentence-aligned → play native read-aloud (adjustable speed) → tap any word for meaning/拼读/examples.
- **UI:** Photo capture; bilingual aligned view (toggle / side-by-side); play/pause + speed; tappable words; save to materials/word list.
- **States:** capture · OCR+translate · bilingual+audio · low-confidence OCR (editable) · unreadable · offline (needs network; cached audio replayable).
- **Data:** `Passage { id, subject, grade, images[], ocrText, sentences[{src, translation, audioUrl}] }`; `Glossary { words[{headword, meaning, phonetic}] }`.

#### F38. Wrong-Question Notebook & Custom Error Papers — 错题本 / 错题试卷 · **P0**  *(consolidated with §4.1 F12, §4.4 F46)*
- **What:** Cross-cutting backbone. Wrong items from 口算批改, 作业批改, dictation, drills, essay practice auto-collect into a per-subject 错题本 with original, correct answer, error cause, knowledge-point tags. Multi-dimensional classification (subject / error-type tag / **forgetting-curve (遗忘曲线) timeline**). Students assemble custom **错题试卷 (组卷)** for re-testing and **一键打印**. Mastered items graduate; persistent ones re-queue.
- **UI:** Subject-tabbed, filterable list; entries show original + correct + 错因 + tags; multi-select to build paper; mastery badges; daily-push card; landscape on iPad (v5.2.8).
- **States:** empty · populated · paper-completed · offline (viewable, sync later).
- **Data:** `WrongQuestion { id, subject, sourceType, stem/image, studentAnswer, correctAnswer, errorTypeTags[], knowledgePointIds[], masteryState(new|reviewing|mastered), reviewSchedule[], addedAt }`; `ErrorPaper { questionIds[], createdAt, results, printURL }`.

#### F39. Knowledge Mastery Heatmap & Adaptive Practice Push — 知识点掌握度热力图 / 靶向练习 · **P1**  *(see also §4.4 F44/F45)*
- **What:** Tracks per-knowledge-point mastery as a **热力图** built from grading + practice; generates a personal graph to pinpoint weak areas; pushes daily 靶向 practice. Real-time mastery underpins adaptive difficulty; parent-visible.
- **UI:** Heatmap grid / knowledge-graph by subject & grade; weak-point list; daily-practice card; trend charts; parent-view toggle.
- **States:** insufficient-data · heatmap populated · improvement trend · offline (last-synced).
- **Data:** `KnowledgePoint { id, subject, grade, name, parentGraphNode }`; `Mastery { knowledgePointId, score(0–1), lastUpdated, history[] }`.

#### F40. Parent-Assist & Anti-Cheat Verification — 家长验证 / 家长辅助 · **P1**  *(see also §4.5 F54)*
- **What:** Writing assistance + full model-essay reveal gated behind **parent verification** (prevents copy-paste cheating); dictation/review support parent-assist. Tools **coach** rather than do the homework.
- **Flow:** Student requests full 范文/writing help → parent-verification prompt → on verify, full content unlocks; else only 思路/guidance shown.
- **UI:** Verification modal (code/gesture); guidance-only vs full-content states; parent-mode toggles.
- **States:** locked (guidance only) · verifying · unlocked · failed (retry).
- **Data:** `ParentVerification { method, verifiedAt, scopeUnlocked[] }`; `FeatureGate { featureId, requiresParent }`.

#### F41. Classical Chinese Poetry & Prose — 古诗文 / 文言文 · **P1/P2**
- **What:** Comprehensive 古诗文 support **two ways**: (a) **conversational** — translate poems/文言文, give 赏析, **断句** sentence-parsing (builds 语感), structural/趣味 translation mnemonics, summarize **古今异义字** with sources, and **dialogue with historical figures** (李白, 诸葛亮, 孙悟空); (b) **豆包课堂** immersive AI video micro-lessons for 古诗文. Strong 背诵 aid by explaining meaning. *(Inferred: recitation-check via ASR diffing against canonical text with per-character highlight.)*
- **Flow:** Pick/photograph poem → translation + 赏析 + key 字词 (含古今异义) + author/出处 → 断句 practice + mnemonics → optionally chat with the poet → or watch 豆包课堂 lesson → recite.
- **UI:** Poem detail page (original + translation + 注释 + 赏析 + author card); 断句 exercise; mnemonic breakdown; 豆包课堂 player; "talk to 李白" entry; (inferred) recite-and-check recorder.
- **States:** choose poem · analysis/video load · full study page · not recognized · offline (downloaded videos + cached text).
- **Data:** `ClassicalText { id, title, dynasty, author, type(诗/词/文言文), original, translation, annotations[], appreciation, source, grade }`; `AncientWord { char, ancientMeaning, modernMeaning, source }`.

> **Also in the Tools hub:** **创作大师** (creation master — story/image generation) — a generative-creativity utility surfaced as a tool tile.

---

### 4.4 Content Library, Courses & Knowledge Graph

> Not a download-everything resource library — an AI-generated, on-demand knowledge engine. The closed loop: explanation → wrong question → graph → weak-point alert → micro-course + practice → report.

#### F42. 豆包课堂 — Immersive AI Video Lessons — 豆包课堂 · **P0**  *(canonical home; cross-ref §4.1 F15)*
- **What:** Dedicated bottom-nav tab of "沉浸式AI视频课" generated with ByteDance's **Seedance** model (~May 2026). Each lesson follows **"AI情景短片 + 知识点精讲"**: a cinematic AI-generated short reconstructs the historical scene (e.g., Cao Zhi's life for 《七步诗》), then 豆包老师 does line-by-line 知识点 breakdown with 动态板书, interleaving **互动习题** at key nodes, with real-time interruptible Q&A ("边看边学，随时提问"), ending on a narrative video reveal. **~10-minute** lessons blend 文字/图片/板书/视频/互动题. First batch = **11 classical-Chinese poetry/文言文 courses** (《夏日绝句》《七步诗》《水调歌头》《出塞》《早发白帝城》…). Split into **精品课程 (PGC)** and **我的课程 (UGC)**. Vetted by **三重审核 (AI filter + expert review + historical-accuracy validation)**. Completely free, no ads, no time limit.
- **Flow:** Tap 豆包课堂 → browse 精品课程 grid → tap a course → watch AI情景短片 opener → line-by-line walk with 动态板书 → interactive quiz pops at a key node → answer/ask free-form (voice/keyboard) → pauses, AI responds, resumes → narrative conclusion → bookmark / continue / generate custom.
- **UI:** Bottom tab; course-grid of large video-thumbnail cards (title, dynasty/author, duration badge, grade tag); 我的课程 shelf; in-lesson full-bleed player with persistent ask/interrupt (mic+text), inline quiz cards at timestamps, blackboard annotations, transcript/board-notes pane, speed control, chapter markers.
- **States:** empty (我的课程 prompt) · loading (Seedance buffering + skeleton) · playable · video-load failure · generation-state ("生成中…").
- **Data:** `Course { id, title, author, dynasty, subject, gradeBand, durationSec, thumbnailURL, type(PGC|UGC), reviewStatus, knowledgePointIds[] }`; `Lesson segments[{type:openerVideo|explanation|quiz|conclusionVideo, startTime, boardNotes, mediaURL}]`; `QuizNode { prompt, options, answer, knowledgePointId }`.

#### F43. Custom / User-Generated Courses — 我的课程 / 定制课程 · **P1**
- **What:** UGC counterpart to 精品课程 — request a personalized AI video lesson on any topic; generated via the same Seedance + AI-teacher pipeline. Turns 豆包课堂 into an **on-demand video-lesson generator**.
- **Flow:** 我的课程 / 定制课程 button → enter/pick topic + grade → submit → "生成中" → new lesson appears → watch.
- **UI:** 我的课程 shelf; creation entry (FAB/top button) with topic input, grade/version selector, generate button; generation-progress card; personal-flagged result card.
- **States:** empty (encourages first) · generating · ready · failed (retry) · offline (blocked/queued).
- **Data:** `Course (type=UGC, requesterUserId, sourcePrompt, generationStatus(pending|generating|ready|failed), createdAt)`.

#### F44. Knowledge-Point Explanation (AI Teacher 2.0) & Personal Knowledge Graph — 知识点讲解 / 专属知识图谱 · **P0**  *(consolidated with §4.1 F13)*
- **What:** AI Teacher **2.0** (Jan 2026) shifted from "讲题" to "讲知识": decomposes any problem into underlying 知识点, structures explanations (e.g., 文言文 as **背景→内容→价值**), uses **图文结合** multimodal output, ends with **延伸提问**. From accumulated 错题 + answering history it builds a **per-student 知识图谱** mapping mastered vs. weak points and concept interconnections ("形成全面的知识网络"), precisely locating 薄弱环节. The structural backbone connecting wrong-question data → knowledge points → recommended courses/practice. Cited ~99.1% math step accuracy.
- **Flow (explanation):** Ask (photo/text/voice) or tap a knowledge point → AI identifies 知识点 → structured multimodal explanation with 板书 → 延伸提问/checkpoints → free follow-ups → save to 错题本. **(Graph):** problems/mistakes tag to points → graph builds/updates → open mastery view → tap weak node → drill into explanation, micro-course, targeted practice.
- **UI:** Chat-style explanation with rich blocks (dynamic blackboard, inline images, highlighted terms, collapsible steps, 延伸提问 chips, voice playback, "收藏到错题本"); knowledge-point breadcrumb. **Graph:** node-link/hierarchical tree colored/sized by mastery, weak nodes highlighted, tap-to-expand to prerequisites, per-node panel (mastery %, recent errors, linked 错题, 讲解/练习 actions), subject/grade filter, mind-map (思维导图) layout.
- **States:** empty ("do problems to build your map") · loading (streaming explanation / graph computing) · interactive graph · low-confidence (retake) · offline (last-synced snapshot).
- **Data:** `KnowledgePoint { id, name, subject, gradeBand, parentIds[], relatedIds[] }`; `Explanation { knowledgePointIds[], steps[], boardAssets[], extensionQuestions[], modality }`; `Mastery { knowledgePointId, score, attempts, lastErrorAt, status(weak|developing|mastered) }`.

#### F45. Targeted Daily Practice / Weak-Point Training — 靶向练习 / 专项练习 · **P1**  *(consolidated with §4.1 F14, §4.3 F39)*
- **What:** Graph-driven daily **5–10 min** 靶向练习 on weak points + 必练题 after error analysis. Difficulty adapts: 3 consecutive correct same-type → introduce **变式题** to prevent boredom; struggling concepts trigger remediation.
- **Flow:** App/notification → "今日靶向练习" card → complete 5–10 min set → AI grades & explains → mastery updates feed graph → next day re-targets.
- **UI:** Daily-practice card (est. minutes + target points); question runner (handwriting/typing, auto-grading, per-question explanation); progress ring; streak.
- **States:** all-caught-up · generating · completed (mastery delta) · grading failure · offline (cached only).
- **Data:** `PracticeSet { date, targetKnowledgePointIds[], items[], estMinutes }`; `PracticeAttempt { itemId, correct, timeSpent, knowledgePointId }`.

#### F46. Wrong-Question Notebook (content-library view) — 错题本 · **P0**  *(consolidated — see §4.1 F12, §4.3 F38)*
- **What:** Same backbone, viewed as a content/review surface: auto-collects, classifies multi-dimensionally, follows **Ebbinghaus forgetting curve** for review scheduling, generates 必练题, supports 举一反三 同类题/变式题 and **一键组卷与打印**.
- *(Full data model under F38.)*

#### F47. Document / File Reading & Q&A — 文档/PDF 阅读问答 · **P1**  *(consolidated with §4.1 F16)*
- **What:** Inherited from the Doubao model: upload/photograph study materials in varied formats ("精准识别多个学习场景下不同来源与格式的学习资料"). Auto-summarizes core content, extracts key points, structures outlines, answers questions, supports selecting a passage to **解释/翻译/搜索/"问问豆包."** Broader Doubao supports **PDF/Word/Excel/PPT/TXT, up to 200 files / 100MB each** (study-app limits likely tighter); leverages Seed **256K long-context**. Ultra-long-doc parsing is VIP-flagged in the broader ecosystem.
- **Flow:** Camera/upload → choose photo or file → parse (1–3 min) → summary + key points + outline → ask questions → select text/region for 解释/翻译/搜索 → for essays, grade & polish full text.
- **UI:** Upload/camera entry + file picker; parsing progress ("解析中 1–3分钟"); document viewer + chat Q&A split pane; selectable text context menu (解释/翻译/问问豆包); summary/key-points/outline cards; (essays) scored annotation overlay + 全文润色.
- **States:** upload prompt · parsing · doc+summary+chat ready · unsupported/parse-fail/too-large · offline (blocked).
- **Data:** `Document { id, fileType, sourceURL, pageCount, parsedText, summary, keyPoints[], outline[] }`; `DocQuery { question, answer, citedSpans[] }`; `EssayReview { score, annotations[], polishedText }`.

#### F48. Learning Reports & Analytics — 学习报告 / 学情周报 · **P1**  *(see also §4.5 F53)*
- **What:** Aggregates activity into student/parent reports: **每日讲题时长**, **知识点掌握率**, 学习进度, 成绩报告, 学习建议. Includes a **薄弱点预警** system: when a knowledge point remains unclear after **3 consecutive explanations**, auto-pushes **微课视频 + 专项练习**. Daily/weekly summaries; auto-pushed weekly to parents.
- **Flow:** Open 学习报告 (or parent mode) → daily/weekly dashboard (time, mastery %, trends) → flagged weak points → tap → jump to micro-course + practice → review suggestions.
- **UI:** Dashboard with time-spent chart, mastery gauges per subject/point, trend lines, weak-point alert cards (CTA to course/practice), suggestion list; parent-mode toggle; shareable weekly card; export/share.
- **States:** insufficient-data · chart skeletons · populated · analytics-fetch failure · offline (last-synced).
- **Data:** `Report { period, totalTutoringMinutes, masteryBySubject[], masteryByKnowledgePoint[], weakPointAlerts[{knowledgePointId, missCount, pushedCourseId, pushedPracticeId}], suggestions[] }`.

#### F49. Textbook Sync & Subject Question Bank — 教材同步 / 全学科题库 · **P1**
- **What:** Full-subject question bank 小学→高中 ("覆盖小学到高中全学科") with **multiple textbook editions (人教版/北师大版 etc.)** so content aligns to grade + edition. Knowledge points organized by subject/grade and (per category norm) mapped to textbook chapters, enabling 教材同步 selection of 年级 + 版本 + 章节. *(Confirmed: multi-edition + full-subject bank; chapter-level browse UI inferred.)*
- **Flow:** First run/settings → select 学段 + 年级 + 教材版本 → content filtered → browse subject → chapter → knowledge point → aligned explanations, micro-courses, practice.
- **UI:** Grade/edition picker (学段→年级→版本); subject tabs; chapter/knowledge-point outline; edition-aligned content cards; change-edition setting.
- **States:** edition-unset (prompt) · catalog fetch · edition-aligned browse · catalog unavailable · offline (cached catalog).
- **Data:** `UserProfile { gradeBand, grade, textbookEditions{subject:edition} }`; `TextbookChapter { subject, edition, grade, chapterId, knowledgePointIds[] }`.

#### F50. Knowledge Q&A (general) — 知识问答 / 知识专家 · **P1**  *(consolidated with §4.2 F23)*
- **What:** Dialogue-based general + academic knowledge ("知识专家", 互动问答) — the general-knowledge complement to structured 知识点讲解. Multimodal (voice, handwriting, image gen).
- *(See F23 for UI/flow/data.)*

---

### 4.5 App Shell: Onboarding, Account, Membership, Parent

#### F51. Bottom Tab Bar (4-tab primary navigation) — 首页/学习/工具/我的 · **P0**
- **What:** Persistent 4-destination bottom bar (confirmed). 首页 (Home), 学习 (Study), 工具 (Tools), 我的 (Profile). Home default; camera/答疑 most prominent.
- **UI:** Standard iOS bottom `TabView`, 4 icon+label items, rounded friendly iconography.
- **States:** fresh install → onboarding first · skeleton on Home · populated · per-tab retry · offline (cached recents + banner).
- **Data:** `AppTab enum {home, study, tools, profile}`; selectedTab persisted; per-tab nav stack.

#### F52. First-Run Onboarding & Grade Selection — 首次启动引导与年级选择 · **P0**
- **What:** Collects 学段 (小学/初中/高中/大学 — explicitly NO "working professional"), subject preferences, likely 教材版本/地区 — the personalization baseline. Permissions requested contextually.
- **UI:** Sequential wizard with large grade chips, 学段 segmented control, multi-select subject tiles, progress dots, mascot guide. Skippable where possible.
- **States:** defaults · saving spinner · confirmation→Home · save-failed (retry) · offline (store local, sync later).
- **Data:** `UserProfile { grade, stage, subjects[], textbookEdition, region }`; `OnboardingState { completed, step }`.

#### F53. Account / Login System — 账号登录系统 · **P0**
- **What:** **抖音/字节一键登录 (SSO)** + 手机号 (SMS) + 邮箱; sign-up ~10s. Ties grade/subject prefs, history, favorites, 错题本, reports across the Doubao ecosystem + hardware. Some browsing pre-login; auth for personalized/sensitive features. **Real-name implications for minors.**
- **UI:** Bottom-sheet/full-screen auth with prominent Douyin/ByteDance button, phone field + code, agreement checkbox. No ads.
- **States:** guest mode · auth spinner · profile hydrated · code-expired/network · offline (block login).
- **Data:** `Account { userId, authProvider, phone?, email?, bytedanceId? }`; Session token; guest vs authed.

#### F54. Personal Center (我的) — 我的（个人中心） · **P0**
- **What:** Aggregates profile/avatar, grade & subject settings (editable to re-personalize), history, favorites, downloads, 错题本 access, progress & 成绩报告, study-plan adjustments, Settings. The place to change grade/subject post-onboarding.
- **UI:** Profile header card (avatar, nickname, grade badge) → stats row (streak/打卡, problems solved) → grouped list rows with icons → settings at bottom.
- **States:** prompt to set grade/log in · stats skeleton · full center · retry rows · offline (cached records, editable locally).
- **Data:** `ProfileSummary { avatar, nickname, grade, stats }`; lists: history[], favorites[], downloads[].

#### F55. Learning Reports & Progress (家长-facing) — 学情周报与学习进度报告 · **P1**  *(consolidated with §4.4 F48)*
- **What:** In-app progress, mastery tracking, 成绩报告 with suggestions; **auto-pushed 学情周报** so parents follow remotely. Adaptive system evaluates ability, tracks mastery in real time.
- *(Full data model under F48.)*

#### F56. Parent Verification & Controls — 家长验证与家长模式 · **P1**  *(consolidated with §4.3 F40)*
- **What:** Sensitive flows (拍照搜题, 作文生成) can require **parent ID-card-number verification**; parental controls can **hide solution steps** (隐藏答案/只看思路) to prevent answer-copying. With weekly reports, forms a lightweight 家长端 within the same app. Ties to compliance (guardian consent, anti-addiction, minors mode).
- **UI:** Verification modal (ID input + agreement); "隐藏解题步骤/只看思路" toggle under 我的; reassuring copy.
- **States:** not-verified · verifying · unlocked · verification-failed · offline (blocked).
- **Data:** `GuardianAccount { linkedChild, restrictions{}, consentRecord }`; `ParentControls { hideSteps, gatedFeatures[] }`; `UsageReport { timeSpent, subjectsStudied, mistakesResolved }`.

#### F57. Membership / Monetization Posture (No Paywall) — 会员/付费策略 · **P2**
- **What:** Distinctive: **简洁、无广告、无会员按钮**, immediate feature access, no marketing friction. App Store lists free with no surfaced IAP. Monetization **indirect** — broader Doubao/Douyin ecosystem + **AI伴学机** hardware. The broader Doubao platform monetizes via tiered premium (reported 68/128/…/up to 500 RMB/month) gating ultra-long-doc parsing, pro image gen, faster/larger models — everyday study stays free. *(Inferred: future quota limits possible; no confirmed in-app paywall.)*
- **UI:** **Absence** of paywall/VIP badges/upgrade banners is itself a design statement; utility-first layout. Soft "try again later" if quotas exist (vs. buy prompt).
- **States:** n/a (no paywall states).
- **Data:** Entitlements minimal/absent; ecosystem account links to hardware/Doubao subs externally.

#### F58. Tools Hub (工具) — 工具中心（功能宫格） · **P0**
- **What:** Aggregation tab presenting all utilities as a grid: 拍题答疑, 作业批改, 作文批改, 错题本, 听写, 背单词, 英语口语/跟读, 课文翻译, 知识专家, 创作大师, 古诗文/文言文. Central launchpad; Home quick-entries deep-link here.
- **UI:** Sectioned grid of colorful rounded icon tiles with labels, grouped by category (答疑/批改/记忆/表达/拓展); possibly search.
- **States:** all tools always present · icon placeholders · full grid · network tools dimmed offline.
- **Data:** `ToolCatalog [ToolItem { id, title, icon, category, requiresNetwork, gated }]`.

#### F59. Empty / Loading / Error / Offline States — 空/加载/错误/离线状态 · **P0**
- **What:** App-wide state handling: skeleton/shimmer loaders, friendly mascot-illustrated empty states (e.g., empty 错题本 → "no mistakes yet, keep it up"), error retry banners, offline behavior favoring cached recents/downloads while gating network-dependent AI.
- **UI:** Mascot-illustrated empties, skeleton cards, toast/banner errors, offline ribbon — consistent rounded style.
- **States:** **this feature IS the cross-cutting state system** (empty/loading/success/error/offline each defined).
- **Data:** `ViewState enum { empty, loading, loaded, error, offline }` per screen/section.

#### F60. Visual Design & Brand Language — 视觉设计与品牌语言 · **P0**
- **What:** Built around the **豆包 mascot** — soft, rounded, warm, "sisterly" companion voice. Child-friendly: rounded cards, pastel/warm accents, large friendly typography, playful colorful tool icons, encouragement baked into scoring. Distinct from the neutral adult 豆包. App icon = Doubao mark. Tablet landscape for study.
- **UI:** Rounded corners, soft shadows, pastel + warm primary accent, generous spacing, large tap targets, mascot illustrations, colorful per-tool glyphs, friendly Chinese typeface.
- **States:** design system spans all states (mascot-led empties, celebratory success microcopy).
- **Data:** `DesignTokens { cornerRadius, palette, typography scale, mascot asset set }`.

#### F61. Notifications & Reminders — 通知与提醒 · **P2**  *(see also §4.2 F30)*
- **What:** Push drives engagement + parent loop: auto-pushed weekly 学情周报, forgetting-curve **智能复习计划** reminders, 打卡 nudges, feature announcements. Permission requested contextually.
- **UI:** Standard iOS notifications; possible in-app inbox; category toggles under 我的→设置.
- **States:** none scheduled · delivered+deep-link · silent error · queued offline.
- **Data:** `NotificationPrefs { weeklyReport, reviewReminders, checkIn, announcements }`; `ReviewSchedule (forgetting curve)`.

#### F62. Cross-Platform & Device Support Shell — 多端支持 · **P1**
- **What:** Ships for iPhone, iPad (landscape added v5.2.8), Mac (M1+), Apple Vision Pro; iOS 13+; ~254 MB. Shared account syncs grade, history, 错题本, reports across devices.
- **UI:** Adaptive layouts; tablet landscape multi-pane for study/whiteboard; Mac runs the iPad build.
- **States:** sync states across devices; per-device offline with cached content.
- **Data:** Cross-device sync of `UserProfile`, history, `ErrorNotebook`, reports via account.

---

## 5. UI/UX Patterns & Visual Design Language

### Core Components & Layout Patterns

- **Camera-first / omni-input entry.** Full-screen live viewfinder with rectangular capture-guide overlay and bottom mode switcher (**拍题 | 批改**); the camera is the hero on Home and the universal funnel (also accepts album, PDF, voice, 手写).
- **Capture → preview-with-auto-crop → confirm.** Draggable corner handles + magnifier loupe for deskew and single-question isolation.
- **Recognized-question confirmation card.** Inline-rendered LaTeX + an "edit/修改" affordance **before** solving — guards against OCR-error cascades.
- **Structured, collapsible solution sheet.** 思路 / 步骤(numbered) / 答案(boxed-highlighted) / 知识点(tappable chips), pinch-to-zoom; with a consistent **action row** on every solution: `相似题(举一反三) | 看视频讲解 | 加入错题本 | 追问`.
- **Visualization-first AI-teacher overlay.** Animated **动态板书** canvas + illustrations as the **primary** surface; the text **字幕** transcript is a secondary, tappable layer behind voice chips.
- **Hold-to-talk comprehension loop.** Tutor speaks → asks "是否听懂了?" → student holds mic to answer → advance/re-explain (genuine dialogue, not one-shot TTS); typed-reply fallback.
- **Grading overlay.** ✓/✗ drawn directly atop the photographed worksheet, correct-count summary, tappable per-question detail.
- **Closed-loop card stack.** batch/grade → structured feedback cards → rewrite/explanation → **same-type practice CTA** (consistent across essay, math, error notebook).
- **Diff-style before/after view** for essay rewrite and arithmetic correction; **inline colored annotations** by feedback category.
- **Audio-explain buttons everywhere** (read revisions, words, translations) — voice-forward design.
- **Call/voice mode** with animated avatar + live subtitles + inline correction bubbles (oral practice; Duolingo/Youdao-class).
- **Interactive video player** (豆包课堂): inline quiz overlays at timestamps + persistent "ask the teacher" button; chapter markers; blackboard insets.
- **Knowledge-graph / mind-map** node-link or tree colored by mastery, tap-to-drill; **knowledge mastery 热力图**.
- **Multi-dimensional filterable 错题本 list** (subject chips, error-type tags, time, knowledge point) with multi-select **组卷** + print/PDF wizard.
- **Document viewer + chat Q&A split pane** with selectable-text context menu (解释/翻译/问问豆包).
- **Analytics dashboard** with time charts, mastery gauges/rings, trend lines, and actionable **薄弱点预警** cards; shareable weekly-report card.
- **Tools-as-grid hub:** colorful rounded icon tiles grouped by category, each a focused task flow reached via deep-link cards.
- **Wizard/stepper onboarding** with large grade chips, 学段 segmented control, multi-select subject tiles, progress dots.
- **Personal center** as a grouped list (profile header + stats row + settings rows).
- **Bottom-sheet/full-screen auth** with a prominent **Douyin/ByteDance one-tap SSO** button.
- **Modal parent-verification gate** (ID number) on sensitive features + answer-hiding toggle.
- **Intent-driven chat hub:** natural-language and chip-based quick actions that dispatch to specialized skills and return inline result cards; grade/level chips to escalate/simplify; resumable history sidebar.
- **State system:** mascot-illustrated empties, skeleton/shimmer loaders, inline retry banners, offline ribbon.

### Brand & Visual Cues

- **Mascot-driven warmth:** the soft, rounded 豆包 character + "温柔的大姐姐" voice persona across onboarding, empties, AI teacher, and companion.
- **Child-friendly system:** rounded corners, soft shadows, **pastel + warm** palette, large friendly typography, generous spacing, large tap targets, playful per-tool colors, encouragement microcopy.
- **Deliberate absence:** no ads, no VIP badges, no paywall interstitials — utility-first, friction-free.
- **Dual conversational themes:** a task-focused academic tutor vs. a warmer **成长挚友** companion.
- **Avatar-free teacher:** the AI teacher is voice + board + key-points, deliberately **no digital-human avatar** (a distinctive design stance).

### Notable Gaps / Quality Concerns (from reviews)

- OCR weak spots (underlines, ellipses); occasional grade-appropriateness mismatch; grading-accuracy complaints — all addressable in the rebuild.
- Dark-mode support unclear/weak; underinvested Dynamic Type / VoiceOver / accessibility.
- No unified in-app search across tools/history/错题本/lessons.
- Vocabulary and dictation lack dedicated SRS modules (embedded in chat only).
- Explicit numeric pronunciation scoring not clearly surfaced.

---

## 6. Technical & AI Architecture (Observed)

> **The single most important architectural fact: the product is end-to-end cloud, a thin client over Volcano Engine, with no meaningful offline capability.**

### Model & Service Stack (Doubao/Seed family on 火山引擎 / Volcano Engine 方舟/Ark)

| Layer | Model / Service | Notes |
|---|---|---|
| **Multimodal LLM backbone** | **Doubao-Seed** (formerly 云雀/Skylark) | All-modal (text/image/audio/video). **Seed-1.6 / 1.6-vision** (first vision deep-thinking; tool-calling; **256K context**; OCR, diagram/visual grounding, 3D spatial reasoning, video comprehension; adaptive **深度思考 vs 快速作答**; ~50% cheaper than 1.5-thinking-vision-pro). **Seed-1.8** (multimodal Agent, stronger tool-calling/instruction following). **Seed-2.0-lite** (first full-modal understanding, low latency/cost). |
| **OCR / Vision** | Doubao-Seed vision + ByteDance OCR services | Printed + handwriting + math (LaTeX) + figures; auto-segment multi-question; tilt/perspective correction. |
| **ASR** | **Doubao-Seed-ASR-2.0** (Dec 2025) | Seed MoE LLM architecture, 2B-param audio encoder, +20% keyword recall via context, optimized for proper nouns/homophones, visual-assisted recognition, **13+ overseas languages** incl. accurate English. |
| **TTS / Voice clone** | **Doubao-Seed-TTS 2.0** + **Doubao-Seed-ICL 2.0** (Oct 2025) | LLM-based, context-aware emotion/prosody, second-level 1:1 **voice cloning**. Powers voice teacher, dictation read-aloud, oral scoring, voice chat. |
| **Video generation** | **Seedance** | Powers 豆包课堂 immersive AI video lessons. |

### Scale & Capacity

- Doubao platform: **DAU > 100M, MAU ~170M+** (Dec 2025); **~120 trillion tokens/day** across Volcano Engine by 2026 (~1000× in two years; China #1, global top-3) → effectively **unbounded backend capacity** — but a **hard cloud dependency**, latency cost, and minors'-data compliance burden.

### Quality Metrics (cited)

- **~98.3%** photo-recognition accuracy · **~99.1%** math step-solving accuracy · **0.89** correlation between AI and human essay scoring.

### Response Modes & Rendering

- User-exposed **快速作答 (fast)** vs **深度思考 (deep thinking)** toggle on hard problems.
- **Streaming token-by-token** answer rendering with inline LaTeX/math typesetting; real-time board rendering synced to TTS.
- Inference is **stateless per call**; the app stores returned `Solution`/`Grading`/transcripts keyed to `User + Problem`. **No model weights on device.**

### Compliance Surface (Chinese minors' data)

- **PIPL**, **未成年人网络保护条例 (Minors Network Protection Regulation)**, guardian-consent rules, anti-addiction, 2026 personal-information-protection special action (minors' data, guardian consent, over-collection, face-recognition rules). Upload of children's homework photos, handwriting, audio, phone numbers to Volcano Engine is the core compliance pressure point — and the rebuild's biggest privacy opportunity.

### Core Data Entities (synthesized)

`User/Account · UserProfile(grade, stage, subjects, textbookEditions, region, isMinor, guardianId) · GuardianAccount · CaptureSession · Recognition · Solution · GradedPage/Worksheet/ProblemResult · TutorSession(boardOps, transcript, segments) · Conversation/Message/Session · KnowledgePoint · Mastery · KnowledgeGraphNode · MistakeEntry/WrongQuestion · ErrorPaper · PracticeSet/PracticeAttempt · Essay/Feedback · DictationList/Session/Result · WordList/WordCardState · OralSession/Turn/PronScore · Passage/Glossary · ClassicalText/AncientWord · Course/Lesson/QuizNode · Document/DocQuery/EssayReview · Report/WeeklyReport · NotificationPrefs/ReviewSchedule · Subscription/Entitlements(largely absent) · SyncState`.

---

## 7. Competitive Landscape

豆包爱学 competes in **two arenas**: the Chinese K12 "AI 答疑/拍搜" market, and the global AI-solver market (where ByteDance's own overseas **Gauth** is the closest sibling). The strategic gap **every** competitor shares: all are **cloud-dependent, ad/subscription-monetized, privacy-opaque, and platform-generic**.

### Chinese K12

| Competitor | 中文 | Notable features & moat |
|---|---|---|
| **Zuoyebang** | 作业帮 | **~1.9B-entry** free photo-search bank; **93%** video-explanation coverage matching original + similar problems; AI essay writing aligned to K12 progress; photo translation w/ read-aloud; parent "check-after-attempt" mode. *Lesson: depth of answer coverage + real-teacher video is table-stakes.* |
| **Xiaoyuan / Yuanfudao** | 小猿搜题 / 猿辅导 | Feb 2025 plugged **DeepSeek** reasoning into 小猿AI / 小猿搜题 / **学练机**, fused with self-built **猿力** model; reference pipeline (preprocess→segment→DL recognition→NLP correction→bank rank); invented the **"学练机" (practice-first)** category — diagnose-practice-correct loop. *Lesson: pair solver with adaptive practice + 口算 grading.* |
| **Xueersi** | 学而思 | **九章 (Jiuzhang)** large model + DeepSeek dual-core; reportedly **full marks on 高考 math**; full-subject solving/grading, CN/EN essay grading, multimodal correction, **knowledge-graph step explanation**; **T4 Pro** machine ships **58 AI tools**; 2024: **74.97M** wrong-questions corrected. *Lesson: a real knowledge graph + error-TYPE marking is the quality bar.* |
| **Youdao** | 网易有道 | **子曰** education LLM; **14B** translation model measured **#1 globally** (子曰翻译 2.0); AI sim-interpretation, photo/doc translation, transcribe→translate→dub pipeline; **虚拟人** spoken-English coach; L1–L5 AI-education rubric. *Lesson: translation quality + embodied conversational coach with pronunciation scoring is the bar.* |

### Global Solvers & Pedagogy-First

| Competitor | Notable features |
|---|---|
| **Gauth** (ByteDance, overseas) | ~200M users; Oct-2025 **"AI Live Tutor"** = real-time **voice + interactive whiteboard**; multi-model (Gauth-GPT + Gemini + GPT); 24/7 human tutors. **The closest sibling and most important reference.** Frontier UX = conversational voice + shared whiteboard. |
| **Question.AI** | ~98% accuracy; **100+ languages**; type/upload-doc/photo input; PDF solver; essay writer (subscription-gated). *Lesson: support every input modality; don't paywall basics.* |
| **Photomath** (Google) | Handwriting/diagram/graph recognition; word-problem interpretation; **animated, replayable step tutorials**; textbook solutions (Plus $9.99/mo). *Lesson: animated step-throughs + robust handwriting/graph recognition.* |
| **Khanmigo** | **Socratic** probing questions + **graduated hints** (won't dump the answer); **Writing Coach refuses to write**; pastes of 15+ words flagged for teacher review; embedded in Khan content; reviews student code; **$4/mo**. **The trust/anti-cheat benchmark.** |
| **Socratic by Google** | Free, photo-based, multi-subject; step-by-step + curated explainer resources; Google Classroom/Drive integration. *Lesson: zero-friction free entry + class/file ecosystem integration.* |
| **Quizlet** | **Magic Notes** → auto flashcards/tests/essay prompts from uploaded notes; adaptive **Learn/Test** modes; community sets. *Lesson: auto-generate study sets from any captured material + adaptive recall.* |
| **Duolingo Max** | **Video Call with Lily** (spontaneous conversation + transcripts); **Explain My Answer** (+34% grammar retention); **Roleplay**; **Birdbrain** adaptive engine; gamified streak/XP. **The engagement + conversational-practice benchmark** ($167.99/yr). |

**Strategic read:** the frontier experience is **conversational voice + shared whiteboard + Socratic pedagogy + adaptive practice + gamified retention** — and **none** of these competitors can match deep Apple-system integration or on-device privacy.

---

## 8. Opportunities to Surpass on Apple Platforms

Prioritized; each mapped to specific Apple frameworks. **The headline differentiators are (1) on-device privacy + offline, (2) OS-level integration competitors cannot replicate, and (3) a "tutor not cheat-engine" trust posture.**

### Tier 0 — Defining Differentiators (build first)

1. **On-device private AI tutor & hybrid model routing.** Run **Foundation Models** (on-device ~3B Apple Intelligence model) for intent routing, classification, Socratic hint generation, study planning, vocab/dictation grading, summarizing wrong-question patterns, and **offline Q&A**, with **Generable structured outputs** for reliable step cards/flashcards/rubric scores. Reserve heavy step-by-step solving and long-document reasoning for **Private Cloud Compute** or the cloud Doubao model, with a transparent `RoutePolicy(taskType → onDevice|pcc|cloud)` and clear **on-device vs enhanced** badges. → *"Your child's homework never leaves the device / works offline"* — the single most powerful trust message; **no cloud-only competitor can match it.** **Frameworks:** Foundation Models, Private Cloud Compute.

2. **On-device OCR & capture.** Replace server OCR/画面校准 with **VisionKit** (DataScanner / Document Scanner / Live Text), **Vision** (`VNRecognizeTextRequest`, document/perspective correction) for instant, offline, private recognition — recognize **before the shutter fires**, fix the underline/ellipsis misses, and let users long-press any equation in any app (Live Text) to send into the tutor. **Frameworks:** VisionKit, Vision, Continuity Camera.

3. **PencilKit-native handwritten math + true vector blackboard.** Let students **write** math with Apple Pencil and solve it in their own handwriting (**Math Notes**-style inline solving, variable assignment, one-tap multi-equation **graphing**, Smart Script). The AI annotates the student's **own** working to show where a step went wrong. The 豆包老师 **shared whiteboard** is **SwiftUI Canvas/Metal + PencilKit** → Gauth's whiteboard with native ink quality, zero latency, and the ability to critique handwriting. **Frameworks:** PencilKit, SwiftUI Canvas/Metal, Scribble.

4. **Interruptible bidirectional voice tutoring + on-device speech.** Use **SpeechAnalyzer / Speech** + **AVAudioEngine** for low-latency, **barge-in** (interrupt mid-explanation) ASR powering the "是否听懂了?" loop and 追问; **AVSpeechSynthesizer / Personal Voice** for natural teacher narration, dialect/style options, and dictation/translation read-aloud — all offline-capable. **Frameworks:** SpeechAnalyzer, Speech, AVAudioEngine, AVSpeechSynthesizer, Personal Voice.

5. **Anti-cheat "Learn Mode" + Study Focus (trust posture).** Default to a **Khanmigo-grade** answer-withholding, attempt-first, graduated-hint mode with **paste-detection** (flag 15+ pasted words), backed by on-device **effort logging**; pair with a parent-schedulable **Study Focus** filter. Reframes the product from "homework cheat engine" to "genuine tutor" — essential for school/parent/regulator acceptance. **Frameworks:** Focus filters, App Intents, on-device Foundation Models.

6. **Native parent mode via Screen Time / Family Controls.** Build the 家长端 on **Family Sharing + Screen Time + Family Controls (Managed Settings, Device Activity)**: study goals, downtime, **answer-gating enforcement**, private on-device weekly mastery reports, Ask-to-Buy approval — system-trusted and privacy-preserving, vs. entering an ID-card number. **Frameworks:** Family Controls, Screen Time, Family Sharing.

7. **Cross-device continuum (the "better integrated" mandate).** Snap on iPhone → continue with Pencil on iPad → write the essay on Mac — **错题本, study plans, flashcards, knowledge graph** stay in sync via **SwiftData + CloudKit** (end-to-end encrypted, local-first/offline-capable). **Handoff (NSUserActivity)**, **Universal Clipboard**, and **Continuity Camera** (scan from iPhone into the Mac app). Impossible for phone-only Chinese apps. **Frameworks:** SwiftData, CloudKit, Handoff/Continuity.

8. **Live Activities & interactive widgets (Duolingo-class retention).** Lock Screen/Dynamic Island **Live Activities** for study/Pomodoro timers, today's plan progress, and 听写/口算 session status; **WidgetKit** Home/Lock-Screen widgets for streaks, **due SRS reviews**, daily-goal rings, and "wrong-question-of-the-day," with **App Intents** Button/Toggle to start a session or mark a review done without opening the app. **Frameworks:** Live Activities, WidgetKit, App Intents.

### Tier 1 — Strong Enhancements

9. **First-class knowledge graph as a navigable hero.** Make the 知识图谱 a zoomable, explorable concept map (**Swift Charts** + custom **Canvas/Metal**) where every explanation, wrong question, and document answer **deep-links to its node** and related lessons/practice — stronger than today's siloed flows. **Frameworks:** Swift Charts, Canvas/Metal, SwiftData.

10. **OS-level reach via App Intents / Siri / Spotlight / Shortcuts.** "Hey Siri, solve this homework" / "复习错题" / "开始今天的听写" / "summarize this PDF"; a Share-Sheet extension to solve any screenshot/PDF from any app; **Spotlight-indexed** search across tools, history, 错题本, flashcards, and uploaded docs (the current app lacks unified search). **Frameworks:** App Intents, Siri, Spotlight (CoreSpotlight), Shortcuts, Share Extension.

11. **First-class on-device SRS for 背单词 + standalone dictation engine.** Replace inline glossing with a true **SwiftData**-backed spaced-repetition deck (textbook-synced lists, SM-2/Leitner, swipeable cards, spelling+choice quizzes) and a first-class **听写** engine (custom lists, speed/gap/repeat, zh/en, parent-assist, **PencilKit** handwriting + on-device OCR auto-grading). **Frameworks:** SwiftData, PencilKit, VisionKit, AVSpeechSynthesizer.

12. **Numeric pronunciation scoring for 跟读评测.** Add explicit **accuracy/fluency/completeness 0–100** per word/phoneme with color-coded heatmaps via **Speech + SoundAnalysis** on-device. **Frameworks:** Speech, SoundAnalysis.

13. **Native essay coaching with Writing Tools + concept visuals.** Embed system **Writing Tools** (proofread/rewrite/summarize) in the 作文批改 editor under a "coach, don't write" policy with rubric presets (中考/高考/IELTS) and per-dimension **radar charts**; generate concept diagrams, vocabulary picture-cards, and 古诗文 scene art via **Image Playground / Genmoji** — visuals no Chinese competitor offers natively. **Frameworks:** Writing Tools, Image Playground, Swift Charts.

14. **Offline-first content.** Pre-download 豆包课堂 lessons, document summaries, wrong-question sets, decks, and the knowledge graph via **Background Assets** for transit/exam-prep study. **Frameworks:** Background Assets.

15. **Camera Control / Action Button instant 拍题.** Bind one-press capture on supported iPhones; **Visual Intelligence** integration. **Frameworks:** Camera Control, Action Button.

16. **Native math typesetting & accessibility.** Crisp **Core Text / SwiftMath** LaTeX with full **VoiceOver**-readable formulas, **Dynamic Type**, and SF Symbols-based iconography/haptics — beating web-rendered LaTeX. **Frameworks:** Core Text/SwiftMath, Accessibility, SF Symbols.

17. **Native StoreKit 2 + Family Sharing monetization.** Generous free tier (mirroring 豆包爱学's free strategy via cheap on-device inference) with VIP reserved for cloud deep-solve / teacher video, shareable across the family. **Frameworks:** StoreKit 2, Family Sharing.

### Tier 2 — Differentiated Extras

18. **SharePlay study-together.** Synchronized FaceTime co-study: shared problem + **PencilKit** whiteboard, co-op flashcards/听写, synced group quizzes, remote parent help — a social dimension no competitor offers natively. **Frameworks:** SharePlay (GroupActivities).

19. **visionOS immersive lessons.** Present 豆包课堂 historically-reconstructed scenes and a spatial whiteboard as immersive spaces (the app already declares Vision Pro support). **Frameworks:** RealityKit, ARKit, visionOS.

20. **Provenance / trust UI.** Expose 豆包课堂's **三重审核** status and source citations as a native "verified content" badge, addressing AI-content accuracy concerns. **Frameworks:** custom UI + structured outputs.

21. **Native translation framework** for 英语 tutoring and bilingual explanations, on-device. **Frameworks:** Translation framework.

---

## 9. Consolidated Feature Backlog

A single prioritized table a product team can build from. Priority reflects build order (P0 = core spine first). "Apple-native angle" names the differentiating framework(s).

| # | Feature (中文) | Domain | Priority | Apple-Native Angle |
|---|---|---|---|---|
| 1 | Camera Capture & Problem Scan (拍照搜题/拍题答疑) | Photo-Solve | **P0** | VisionKit DataScanner live recognition; Camera Control instant 拍题 |
| 2 | Single-Problem Crop / Region Select (框选单题) | Photo-Solve | **P0** | Live in-viewfinder tap-to-select via Vision |
| 3 | Multi-Problem Grade-Page Detection (整页批改) | Photo-Solve | **P0** | Vision document detection + on-device segmentation |
| 4 | Multimodal OCR (题目识别: 印刷+手写+公式) | Photo-Solve | **P0** | VisionKit/Vision on-device OCR; fixes underline/ellipsis misses |
| 5 | Step-by-Step Structured Solution (思路·步骤·答案·知识点) | Photo-Solve | **P0** | Foundation Models + Generable step cards; Core Text math |
| 6 | LaTeX / Math & Diagram Rendering (公式渲染/图示) | Photo-Solve | **P0** | Core Text/SwiftMath, VoiceOver-accessible formulas |
| 7 | Subject Auto-Detection & Routing (全学科覆盖) | Photo-Solve | **P0** | On-device classifier via Foundation Models |
| 8 | 举一反三 Similar-Problem Generation (相似题) | Photo-Solve / Practice | **P0** | On-device generation + Generable schemas |
| 9 | 豆包老师 Voice-First Dynamic Blackboard (动态板书+语音) | AI Tutor | **P0** | SwiftUI Canvas/Metal + PencilKit board; SpeechAnalyzer; AVSpeech |
| 10 | Real-Time Voice + "是否听懂了" Loop (语音实时互动) | AI Tutor | **P0** | SpeechAnalyzer barge-in; AVSpeechSynthesizer/Personal Voice |
| 11 | Interruptible Follow-Up Q&A (追问) | AI Tutor | **P0** | On-device ASR + low-latency Foundation Models |
| 12 | Grade-Level Tiered Adaptation (分层引导) | AI Tutor | **P0/P1** | On-device learner model; Generable method variants |
| 13 | Multimodal Input Pipeline (拍/文/语/手写) | AI Tutor | **P0** | VisionKit + Vision handwriting + Speech + PencilKit |
| 14 | AI Orchestration / Cross-Feature Intents (AI串联) | AI Tutor | **P0** | App Intents skill dispatch; Foundation Models tool-calling |
| 15 | Conversation Session & History / Continuity (接续学习) | AI Tutor | **P0** | SwiftData + CloudKit; Handoff |
| 16 | 错题本 + 错因 + Knowledge-Graph Mapping (错题本/错因/知识图谱) | Practice / Knowledge | **P0** | SwiftData store; Swift Charts/Canvas graph; CloudKit sync |
| 17 | Knowledge-Point Explanation 2.0 (讲知识/背景-内容-价值) | Knowledge | **P0** | Foundation Models structured explanations + Image Playground visuals |
| 18 | 豆包课堂 Immersive AI Video Lessons | Courses | **P0** | AVKit interactive player; Background Assets offline; visionOS scenes |
| 19 | Essay Grading (作文批改: 综合/分句/升格/朗读) | Assessment | **P0** | Writing Tools "coach not write"; Swift Charts rubric radar; AVSpeech |
| 20 | Arithmetic Batch Grading (口算批改) | Assessment | **P0** | VisionKit OCR + on-device CAS check; ✓/✗ overlay |
| 21 | Math/Arithmetic Drill & Practice (举一反三/必练题) | Practice | **P0** | On-device generation; PencilKit answer input |
| 22 | English Oral Coaching (英语口语/口语陪练) | Practice | **P0** | Speech ASR; SoundAnalysis pronunciation scoring; AVSpeech avatar |
| 23 | Knowledge Q&A (知识问答/知识专家) | Knowledge | **P0/P1** | Foundation Models; Spotlight-indexed history |
| 24 | Tools Hub (工具宫格) | Shell | **P0** | NavigationSplitView (iPad/Mac) + TabView (iPhone) |
| 25 | 4-Tab Bottom Navigation (首页/学习/工具/我的) | Shell | **P0** | Adaptive TabView ↔ NavigationSplitView |
| 26 | Onboarding & Grade Selection (年级选择) | Shell | **P0** | VisionKit textbook-cover scan to auto-detect grade/edition |
| 27 | Account / Login (账号登录) | Shell | **P0** | Sign in with Apple + iCloud; optional ByteDance SSO |
| 28 | Personal Center (我的) | Shell | **P0** | SwiftData-backed profile; Swift Charts stats |
| 29 | App-Wide States (空/加载/错误/离线) | Shell | **P0** | On-device offline mode (no competitor offline) |
| 30 | Visual Design & Brand (豆包吉祥物/圆润暖色) | Shell | **P0** | Liquid Glass (iOS/macOS 26), full Dark Mode, SF Symbols, haptics |
| 31 | Anti-Cheat Learn Mode + Study Focus | Trust | **P0** | Focus filters; on-device effort log; paste-detection |
| 32 | On-Device Private Tutor & Model Routing | AI Infra | **P0** | Foundation Models + Private Cloud Compute route policy |
| 33 | Live Activities & Widgets (streaks/timers/SRS due) | Engagement | **P0** | Live Activities, WidgetKit, App Intents |
| 34 | Cross-Device Continuity & Sync | Platform | **P0** | SwiftData + CloudKit; Handoff; Continuity Camera |
| 35 | Auto-Deskew / Image Calibration (画面校准) | Photo-Solve | **P1** | Vision perspective correction (free, system-quality) |
| 36 | Confidence / Recognition-Failure Handling (置信度) | Photo-Solve | **P1** | Inline editable recognized-question; on-device confidence |
| 37 | Solve History & Per-Problem Threads (搜题历史) | Photo-Solve | **P1** | SwiftData threads; Spotlight indexing |
| 38 | Daily Targeted Practice Push (靶向练习/每日必练) | Practice / Adaptive | **P1** | Notifications + Live Activities; on-device adaptive engine |
| 39 | Knowledge Mastery Heatmap (掌握度热力图) | Progress | **P1** | Swift Charts heatmap |
| 40 | Document / PDF Reading & Q&A (文档/PDF问答) | Document | **P1** | Foundation Models on-device summarize; VisionKit capture |
| 41 | Album Upload (相册上传) | Photo-Solve | **P1** | PHPicker; Live Text long-press entry |
| 42 | Open-Ended / Encyclopedic Q&A (百科答疑) | AI Tutor | **P1** | Same structured-answer Generable pipeline |
| 43 | Dictation Engine (听写) | Practice | **P1** | AVSpeechSynthesizer read-aloud; PencilKit + on-device OCR grading |
| 44 | Vocabulary SRS Decks (背单词/单词卡) | Practice | **P1** | SwiftData SM-2 scheduling; widgets for due cards |
| 45 | Textbook Passage Translation & Read-Aloud (课文翻译) | Practice | **P1** | Translation framework; AVSpeech; Live Text |
| 46 | Classical Chinese (古诗文/文言文) | Humanities | **P1/P2** | On-device recitation-check (Speech diff); Image Playground scene art |
| 47 | Custom / UGC Courses (我的课程/定制课程) | Courses | **P1** | Cloud Seedance gen + on-device quiz scoring |
| 48 | Learning Reports & Analytics (学习报告/学情周报) | Reports | **P1** | Swift Charts; Family Sharing parent reports; Live Activities |
| 49 | Textbook Sync & Question Bank (教材同步) | Content | **P1** | VisionKit scan-to-chapter; SwiftData catalog |
| 50 | Parent Verification & Controls (家长验证/家长模式) | Parent / Safety | **P1** | Family Controls, Screen Time, Device Activity |
| 51 | Cross-Platform Device Shell (多端支持) | Platform | **P1** | One SwiftUI universal codebase; adaptive layouts; visionOS |
| 52 | 识万物 Recognize-Anything Lens (识万物) | Multimodal | **P1** | VisionKit object recognition; ARKit continuous camera |
| 53 | Voice/Video Call Tutoring (打电话/视频通话) | Voice | **P1** | SpeechAnalyzer + AVAudioEngine; ARKit live camera |
| 54 | Numeric Pronunciation Scoring (跟读评测) | Practice / Assessment | **P1** | Speech + SoundAnalysis, color-coded heatmap |
| 55 | OS-Level Search & Siri Intents (Spotlight/Shortcuts) | Platform | **P1** | App Intents, CoreSpotlight, Siri, Share Extension |
| 56 | Concept Visuals & Writing Tools (作文/概念图) | Assessment / Creativity | **P1** | Writing Tools, Image Playground, Genmoji |
| 57 | Offline Content Packs (离线下载) | Content | **P1** | Background Assets |
| 58 | StoreKit 2 + Family Sharing Membership (会员) | Monetization | **P1/P2** | StoreKit 2, Family Sharing |
| 59 | Multi-Dialect / Pace Voice (方言/语速) | AI Tutor | **P2** | AVSpeech voice/style options; Personal Voice |
| 60 | 成长挚友 Emotional Companion (成长挚友) | Companion / Wellbeing | **P1/P2** | On-device, parent-auditable memory; Communication Safety |
| 61 | Streaks / Motivation & Reminders (打卡/提醒) | Engagement | **P2** | Live Activities, WidgetKit, notifications |
| 62 | Notifications & Smart Review Reminders (智能复习计划) | System | **P2** | UserNotifications + forgetting-curve scheduling |
| 63 | Membership Posture / Free Tier (无付费墙) | Monetization | **P2** | Cheap on-device inference enables generous free tier |
| 64 | 创作大师 Creation Master (story/image) | Creativity | **P2** | Image Playground, Writing Tools |
| 65 | SharePlay Study-Together (一起学) | Social | **P2** | SharePlay/GroupActivities + shared PencilKit whiteboard |
| 66 | visionOS Immersive Lessons | Platform | **P2** | RealityKit, ARKit, visionOS immersive spaces |
| 67 | Provenance / Trust Badge (三重审核可见) | Trust | **P2** | Custom UI + structured citations |

---

## 10. Sources

Consolidated, deduplicated across all seven dossiers. (Web data was thin in places; items marked *inferred* in the inventory rely on category norms and reasoned synthesis.)

**Official / App Store & product listings**
- App Store CN listing — 豆包爱学 (id6469102455): official feature copy, version notes (豆包课堂/AI老师/拍题答疑/作业批改/写作助手/知识问答/成长挚友), 4.8★/~360k ratings, #9 Education, platforms (iPhone/iPad/Mac M1+/Vision Pro), publisher 上海仁静信息技术.
- Microsoft Store / AGICamp / Hello123 / downxia / vkxiazai feature listings.

**Feature breakdowns & evaluations**
- ai-bot.cn/doubaoaixue, ai-bot.cn/app/10466.html — feature overview, version history, OCR weak-spot feedback, 豆包课堂.
- aihub.cn/tools/study/hippolearning, aigc.cn/doubaoaixue, aiww.com/aitool/doubaoaixue — subject coverage, error-tracking, adaptive learning, writing guidance.
- 53ai.com (2025091431750) — 豆包老师 flow: 动态板书, 语音互动, 是否听懂了 hold-to-talk, 鸡兔同笼 抬腿法 vs 一元一次方程, 字幕, 识万物.
- zizhuyunxuan.com/1428.html — 3.0 camera upgrade: 拍题 vs 批改, whole-试卷 grading, free/no-VIP.
- aixq.cc/28052.html (AI星球) — essay grading praise-first/范文/audio-explain + same-type practice; 知识点掌握度热力图; noted gaps (pronunciation scoring/dictation/standalone vocab).
- openi.cn/sites/259897.html, aieva.cn/sites/1583.html, hello123.com/hippolearning — 批改相机, 错题自动收录, 知识图谱/知识网络, full-subject bank.

**News & analysis**
- Tencent News (qq.com): 20250913A09OT100 (字节的教育新答卷/豆包老师 launch), 20240918A09MYQ00 (开学季升级: 作业批改/错题试卷/English essay 高分表达/parent-verification anti-cheat/historical-figure dialogue, 98.3% accuracy, 画面校准 praise), 20260527A03AH800 (豆包课堂 Seedance/精品 vs 我的课程/七步诗), 20260318A066WF00 (deep experience: guide-don't-tell, blackboard, 追问, dialects, 举一反三, open-ended), 20250620A02FRZ00 (豆包 音视频通话).
- 100ec.cn/detail--6659669.html, frontiersonline.com (2026/05/30) — 豆包课堂 launch, AI情景短片+知识点精讲, 11 courses, 三重审核, free.
- 36kr.com: 3739607815602176 (Doubao vs Qwen; 知识点拆解/背景-内容-价值/延伸提问; AI老师 1.0→2.0 讲题→讲知识), 2937295848544898 (河马爱学→豆包爱学 rebrand, ZERO merged into Doubao), 2663887291836167 (河马爱学 launch).
- duozhi.com (2024090916584, 2025091517689), pingwest.com/w/298151, finance.sina.com.cn (incnfien4697950, incnfawq4750952, inhtcspq0783548) — rebrand, ZERO team, token scale.
- Zhihu: zhuanlan p/28333813292 (parent perspective: 综合/分句点评, 学习报告 每日讲题时长/掌握率, 薄弱点预警, 错题本 multi-dim, 99.1% math / 0.89 essay), p/1995092727579288254, p/1992297797656007219, p/1989334810129344314 (Doubao DAU 100M); question/14025731252, question/13... (grade coverage, 教材版本, 一键组卷打印).
- CSDN: blog 145267912 (Doubao English oral/grammar/essay), 147432517 (grade reach 小学→研究生, 多模态识别), m0_46168848/145887403 (voice cloning/streaming TTS).
- Sohu: a/862740688 (dictation one-word-at-a-time), a/1028181110 (豆包课堂 Seedance).
- hncj.com/wz/3904.html, hncj.com/sjrj/123779.html — 豆包 vs 豆包爱学 (confirms 首页/学习/工具/我的 tabs).

**Models / infrastructure**
- volcengine.com (docs/6360/1264663, product/tts) — Volcano Engine Doubao stack, TTS.
- ithome.com/0/947/010.htm (Seed-2.0-lite), oschina.net/news/390665 (Seed-1.8), seed.bytedance.com (Seed 1.6), technode.com (1.6-vision ~50% cost cut), github.com/ByteDance-Seed (Seed1.5-VL), zhihu p/1981419964855502084 (Seed-ASR-2.0), baai.ac.cn/view/54469 (tiered subs 68–500 RMB), finance.sina.com.cn inhtcspq0783548 (~120T tokens/day).

**Compliance**
- cac.gov.cn (2023-10/24 未成年人网络保护条例; 2026-04/02 personal-information special action), zhonglun.com/research/articles/7471.html.

**Competitors**
- Zuoyebang: mwm.ai listing, asiatechdaily.com (~1.9B bank, 93% video). Xiaoyuan/Yuanfudao: sj.qq.com/appdetail, ai-bot.cn/xiaoyuan-ai, qq.com 20250416A096GI00 (DeepSeek+猿力). Xueersi: 100tal.com/news/2936, bjnews 1750071199129754 (九章 高考 full marks), finance.sina ineekkks9461947 (T4 Pro 58 tools, 74.97M). Youdao: finance.sina ineuctzx4472182, mydrivers 1064905, geekpark 322350, iaiol.com (L1–L5). Gauth: foxdata.com, implicator.ai (200M, AI Live Tutor, multi-model). Question.AI: play.google listing, skywork.ai review. Photomath: androidcentral, sammyfans (Google acquisition). Khanmigo: khanmigo.ai/learners, reruption.com. Socratic: goodcall.com. Quizlet: play.google listing. Duolingo: investors.duolingo.com, cheapersgames medium review.
- Apple/Math Notes: macworld.com (iPadOS 18 Math Notes), apple.com/newsroom (Math Notes/Smart Script/PencilKit). Apple dev: WWDC25/286 (Foundation Models), WWDC26/339 (model options/PCC), WWDC25/244 (App Intents → Widgets/Live Activities/Siri/Spotlight), developer.apple.com/documentation/appintents, bfrearson.github.io (interactive Live Activities), techcrunch.com (SharePlay).

**Domain knowledge**
- K12 photo-solver category (作业帮/小猿搜题/Mathpix-style math OCR), ByteDance Doubao multimodal capabilities, K12 ed-tech app conventions, and Apple iOS/macOS 26 platform capabilities — used for items clearly marked *inferred/synthesized*.
