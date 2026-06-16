# Lesson Content Authoring Spec

**Target schema (already exists in app — DO NOT change):**
- `Models/SharedValueTypes.swift:62` — `BoardElement { id, kind: title|text|formula|bullet|highlight|divider|answer, content }`
- `Models/SharedValueTypes.swift:72` — `TutorCheckpoint { prompt, options: [String], answerIndex: Int, explanation: String }`
- `Models/SharedValueTypes.swift:83` — `TutorSegment { id, narration, board: [BoardElement], checkpoint: TutorCheckpoint? }`
- `Models/AppEnums.swift:14` — `Subject` (11 cases); `:96` — `GradeLevel` (g1–g12)

**Every lesson file = JSON object with this exact shape:**

```json
{
  "subject": "math",
  "grade": 3,
  "topic": "两位数乘一位数",
  "objectives": ["掌握 23×4 的竖式算理", "能口算并验算"],
  "segments": [
    {
      "narration": "小明去文具店买笔记本，每本 23 元，他买 4 本，一共要付多少钱？",
      "board": [
        {"kind": "title", "content": "两位数乘一位数"},
        {"kind": "text", "content": "23 × 4 = ?"}
      ],
      "checkpoint": null
    },
    { ... },
    ...
  ]
}
```

## Mandatory rules (zero-stub)

1. **Exactly 6 segments per lesson** (no fewer, no more).
2. **At least 2 segments must contain a `checkpoint`** (formative assessment).
3. **Every checkpoint must have**: `prompt`, `options` (exactly 4 items unless subject/grade dictates 3), `answerIndex` (0-based, must point at the correct option), `explanation` (≥ 30 Chinese characters explaining why the correct option is right).
4. **Every narration ≥ 40 Chinese characters** of real teaching dialogue (no placeholders like "讲解概念", "示例" alone — write actual sentences a 豆包老师 would say).
5. **Every board element's `content` ≥ 4 characters** and contains real content (no `"..."`, no `"待补充"`, no `"示例"`).
6. **`BoardElement.kind` only**: `title` | `text` | `formula` | `bullet` | `highlight` | `divider` | `answer`.
7. **Subject/grade alignment is mandatory** — content must be age-appropriate for the specified GradeLevel per Chinese K12 curriculum. Example: g1 math = 数与运算基础 (10以内加减); g7 math = 一元一次方程; g1 chinese = 拼音+识字+看图说话; g12 physics = 电磁感应.
8. **Use simplified Chinese** (the app is zh-CN).
9. **No two lessons may have identical segment narration** (audit will fail duplicates).
10. **No lesson may reference external systems** (no "请访问...", no URLs).

## Recommended 6-segment structure

1. **Hook / 情景导入** — Real-world scenario (≤ 60 chars narration, 1-2 board elements: `title` + `text`).
2. **概念精讲** — Introduce the concept/formula with examples (~80 chars, 3-4 board elements: `text` + `formula` + `bullet`).
3. **例题演练 + Checkpoint #1** — Step-by-step demo then test understanding (~80 chars, 3-4 board + 1 checkpoint).
4. **易错点辨析** — Common mistakes & how to avoid them (~80 chars, 3 board with at least one `highlight` for warnings).
5. **举一反三 + Checkpoint #2** — Independent practice with a different problem (~80 chars, 3 board + 1 checkpoint).
6. **小结回顾** — Recap + bridge to next lesson (~60 chars, 2-3 board with `bullet` recap + `answer` final).

## Grade-by-subject validity map

| Subject | Valid grades |
|---|---|
| `chinese` | g1, g2, g3, g4, g5, g6, g7, g8, g9, g10, g11, g12 |
| `math` | g1–g12 |
| `english` | g1–g12 |
| `general` | g1–g12 |
| `science` | g1, g2, g3, g4, g5, g6 |
| `biology` | g7, g8, g9, g10, g11, g12 |
| `physics` | g8, g9, g10, g11, g12 |
| `chemistry` | g9, g10, g11, g12 |
| `history` | g7, g8, g9, g10, g11, g12 |
| `geography` | g7, g8, g9, g10, g11, g12 |
| `politics` | g7, g8, g9, g10, g11, g12 |

**Total: 87 lessons.**

## Per-cluster file naming

Each parallel agent writes ONE JSON file containing an array of their assigned lessons:
- `chinese.json` — 12 lessons (g1–g12)
- `math.json` — 12 lessons (g1–g12)
- `english.json` — 12 lessons (g1–g12)
- `general.json` — 12 lessons (g1–g12)
- `sciences.json` — 21 lessons (physics g8–g12, chemistry g9–g12, biology g7–g12, science g1–g6)
- `social.json` — 18 lessons (history g7–g12, geography g7–g12, politics g7–g12)

The file is a JSON array at top level.