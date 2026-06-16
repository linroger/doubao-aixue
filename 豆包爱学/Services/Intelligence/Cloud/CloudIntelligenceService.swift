//
//  CloudIntelligenceService.swift
//  豆包爱学 — Services/Intelligence/Cloud
//
//  The real cloud-AI provider. Implements the whole `IntelligenceService` surface
//  by prompting the user-selected model (via `CloudChatClient`) and parsing the
//  reply into feature DTOs. Every method is wrapped so any failure (no network,
//  bad key, malformed JSON) falls back to the deterministic offline service —
//  the app never breaks, it just degrades from 增强 → 端侧/离线.
//
//  Text-centric and structured tasks (solve / tutor / essay / explain / summarize
//  / docQA / similar / lesson / chat) call the model live. The deterministic
//  grading tasks (口算 / 听写 / 发音) stay on the local engine (an LLM adds little
//  and JSON reliability is low) but are re-stamped `.cloud` for a consistent badge.
//
//  `nonisolated` Sendable struct — the protocol methods are nonisolated.
//

import Foundation
import OSLog

nonisolated struct CloudIntelligenceService: IntelligenceService {
    let client: CloudChatClient
    let fallback: any IntelligenceService

    init(config: ResolvedAIConfig, fallback: any IntelligenceService) {
        self.client = CloudChatClient(config: config)
        self.fallback = fallback
    }

    var capabilities: IntelligenceCapabilities {
        let modelName = client.provider.model(withID: client.modelID)?.name ?? client.modelID
        return IntelligenceCapabilities(
            route: .cloud,
            modelName: "\(client.provider.shortName) · \(modelName)",
            supportsStreaming: true)
    }

    // MARK: - Prompt helpers

    private func gradeLabel(_ g: GradeLevel) -> String { g.displayName }
    private func subjectLabel(_ s: Subject?) -> String { s?.displayName ?? "综合" }

    /// A shared persona so every feature speaks in 豆包爱学's warm K12 voice.
    private var persona: String {
        "你是「豆包爱学」里的 AI 老师，面向中国中小学生，讲解亲切、鼓励、循序渐进，用简体中文。"
    }

    private func text(system: String, user: String, maxTokens: Int = 1400) async throws -> String {
        try await client.complete(system: system, user: user, maxTokens: maxTokens)
    }

    private func json<T: Decodable>(_ type: T.Type, system: String, user: String,
                                    maxTokens: Int = 1600) async throws -> T {
        let raw = try await client.complete(
            system: system + "\n严格只返回一个 JSON，对象/数组，不要任何解释文字，不要 Markdown 代码块。",
            user: user, maxTokens: maxTokens)
        let cleaned = Self.extractJSON(raw)
        guard let data = cleaned.data(using: .utf8) else { throw CloudAIError.decode("编码失败") }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CloudAIError.decode(String(describing: error))
        }
    }

    /// Pull the first complete JSON object/array out of a possibly fenced/explained
    /// reply. Scans from the first opener to its *matching* close, tracking string and
    /// escape state, so braces inside string values (or trailing prose / a second
    /// object) don't corrupt the extraction the way "first `{` … last `}`" would.
    static func extractJSON(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip a leading ``` / ```json fence and its trailing counterpart.
        if t.hasPrefix("```") {
            if let firstNL = t.firstIndex(of: "\n") { t = String(t[t.index(after: firstNL)...]) }
            if let fence = t.range(of: "```", options: .backwards) { t = String(t[..<fence.lowerBound]) }
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = t.firstIndex(where: { $0 == "{" || $0 == "[" }) else { return t }
        let open = t[start]
        let close: Character = open == "{" ? "}" : "]"
        var depth = 0
        var inString = false
        var escaped = false
        var i = start
        while i < t.endIndex {
            let c = t[i]
            if inString {
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inString = false }
            } else if c == "\"" {
                inString = true
            } else if c == open {
                depth += 1
            } else if c == close {
                depth -= 1
                if depth == 0 { return String(t[start...i]) }
            }
            i = t.index(after: i)
        }
        // Unbalanced — best effort from the opener to the end.
        return String(t[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Solve

    private struct SolveWire: Decodable {
        struct Step: Decodable { let title: String; let detail: String; let math: String? }
        struct Choice: Decodable { let label: String; let text: String; let isCorrect: Bool; let explanation: String? }
        let approach: String
        let steps: [Step]
        let finalAnswer: String
        let choices: [Choice]?
        let knowledgePoints: [String]?
    }

    func solve(_ request: SolveRequest) async throws -> SolvedProblem {
        do {
            let subject = request.subject ?? .general
            let sys = persona + " 你在帮学生解题。"
            let learn = request.learnMode ? "先讲思路再给步骤，引导式讲解，避免直接抄答案。" : ""
            let useVision = request.imageData != nil && client.provider.supportsVision
            let problemLine = useVision
                ? "题目在图片里（文字初识别：\(request.recognizedText.isEmpty ? "（无）" : request.recognizedText)）。请以图片为准。"
                : "题目：\(request.recognizedText)"
            let user = """
            年级：\(gradeLabel(request.grade))，学科：\(subjectLabel(request.subject))。\(learn)
            \(problemLine)
            请按以下 JSON 结构作答：
            {"approach":"解题思路","steps":[{"title":"步骤标题","detail":"讲解","math":"可选公式"}],"finalAnswer":"最终答案","choices":[{"label":"A","text":"选项","isCorrect":true,"explanation":"为什么"}],"knowledgePoints":["相关知识点"]}
            若非选择题，choices 用空数组。
            """
            let w: SolveWire
            if useVision, let image = request.imageData {
                let raw = try await client.completeVision(
                    system: sys + "\n严格只返回一个 JSON 对象，不要任何解释文字，不要 Markdown 代码块。",
                    user: user, imageData: image, maxTokens: 1600)
                let cleaned = Self.extractJSON(raw)
                guard let data = cleaned.data(using: .utf8) else { throw CloudAIError.decode("编码失败") }
                w = try JSONDecoder().decode(SolveWire.self, from: data)
            } else {
                w = try await json(SolveWire.self, system: sys, user: user)
            }
            let steps = w.steps.enumerated().map { idx, s in
                SolutionStep(index: idx + 1, title: s.title, detail: s.detail, math: s.math)
            }
            let choices = (w.choices ?? []).map {
                ChoiceOption(label: $0.label, text: $0.text, isCorrect: $0.isCorrect,
                             explanation: $0.explanation ?? "")
            }
            let kps = (w.knowledgePoints ?? []).map { KnowledgeRef(name: $0, subject: subject) }
            return SolvedProblem(subject: subject, approach: w.approach, steps: steps,
                                 finalAnswer: w.finalAnswer, choices: choices,
                                 knowledgePoints: kps, route: .cloud)
        } catch {
            var r = try await fallback.solve(request); r.route = .cloud; return r
        }
    }

    // MARK: - Workbook grading (作业批改)

    private struct WorkbookWire: Decodable {
        struct Question: Decodable {
            struct Step: Decodable { let title: String; let detail: String; let math: String? }
            struct Rubric: Decodable { let name: String; let score: Double; let maxScore: Double; let comment: String? }
            let number: String?
            let type: String?
            let subject: String?
            let questionText: String?
            let studentAnswer: String?
            let correctAnswer: String?
            let verdict: String?
            let explanation: String?
            let errorType: String?
            let knowledgePoints: [String]?
            let pointsEarned: Double?
            let pointsPossible: Double?
            let steps: [Step]?
            let rubric: [Rubric]?
            let teacherComment: String?
        }
        let title: String?
        let detectedSubjects: [String]?
        let overallComment: String?
        let encouragement: String?
        let questions: [Question]
    }

    func gradeWorkbook(_ request: WorkbookGradeRequest) async throws -> GradedWorkbook {
        do {
            let hint = request.subjectHint.map { "学科提示：\($0.displayName)。" } ?? "请自动判断每题的学科。"
            let learn = request.learnMode ? "讲解以引导和鼓励为主，指出错因并给出改正方法，不要只给答案。" : ""
            let ocr = request.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
            let ocrBlock = ocr.isEmpty ? "" : "\n以下是对图片的文字初识别（可能有误，请以图片为准）：\n\(ocr.prefix(3000))"
            let sys = persona + " 你是认真负责的作业批改老师，正在批改一页学生作业。"
            let subjectCodes = "math, physics, chemistry, biology, chinese, english, science, history, geography, politics, general"
            let typeCodes = "calculation, fillInBlank, multipleChoice, trueFalse, shortAnswer, application, proof, essay, translation, reading, dictation, matching, handwriting, other"
            let verdictCodes = "correct（正确）, incorrect（错误）, partial（部分正确）, unattempted（未作答）, ungradable（无法判定）"
            let errorCodes = "concept, method, calculation, careless, knowledgeGap, comprehension"
            let user = """
            年级：\(gradeLabel(request.grade))。\(hint)\(learn)
            请逐题批改这页作业，判断每题对错并给出讲解。客观题严格判分；主观题（作文/简答）用 rubric 评分并给出 partial。\(ocrBlock)
            严格按以下 JSON 结构作答：
            {"title":"作业标题（简短）","detectedSubjects":["subject 代码"],"overallComment":"整体评语：做得好的地方+最该改进的一点","encouragement":"一句鼓励的话","questions":[{"number":"题号","type":"题型代码","subject":"subject 代码","questionText":"题目原文（数学用 LaTeX-ish）","studentAnswer":"学生作答","correctAnswer":"正确答案","verdict":"判定代码","explanation":"为什么对/错以及如何改正","errorType":"错因代码或省略","knowledgePoints":["相关知识点"],"pointsEarned":得分或省略,"pointsPossible":满分或省略,"steps":[{"title":"步骤","detail":"讲解","math":"可选公式"}],"rubric":[{"name":"维度","score":4,"maxScore":5,"comment":"点评"}],"teacherComment":"可选的一句老师寄语"}]}
            subject 代码只能用：\(subjectCodes)。
            type 代码只能用：\(typeCodes)。
            verdict 代码只能用：\(verdictCodes)。
            errorType 代码只能用：\(errorCodes)。
            若某字段不适用就省略。只返回 JSON。
            """
            let raw: String
            if client.provider.supportsVision {
                raw = try await client.completeVision(
                    system: sys + "\n严格只返回一个 JSON 对象，不要任何解释文字，不要 Markdown 代码块。",
                    user: user, imageData: request.imageData, maxTokens: 3200)
            } else {
                // Text-only provider: grade from the OCR pre-pass.
                guard !ocr.isEmpty else { throw CloudAIError.decode("无文字可批改") }
                raw = try await client.complete(
                    system: sys + "\n严格只返回一个 JSON 对象，不要任何解释文字，不要 Markdown 代码块。",
                    user: user, maxTokens: 3000)
            }
            let cleaned = Self.extractJSON(raw)
            guard let data = cleaned.data(using: .utf8) else { throw CloudAIError.decode("编码失败") }
            let w = try JSONDecoder().decode(WorkbookWire.self, from: data)
            let assembled = Self.assembleWorkbook(w, request: request)
            // An empty result means the model returned no questions — fall back to the
            // offline grader (OCR/sample) rather than show a blank workbook.
            guard !assembled.questions.isEmpty else { throw CloudAIError.decode("模型未返回任何题目") }
            return assembled
        } catch {
            AppLog.ai.warning("作业批改云端失败，回退离线引擎：\(String(describing: error), privacy: .public)")
            var r = try await fallback.gradeWorkbook(request); r.route = .cloud; return r
        }
    }

    private static func assembleWorkbook(_ w: WorkbookWire, request: WorkbookGradeRequest) -> GradedWorkbook {
        func subject(_ code: String?) -> Subject {
            guard let code, let s = Subject(rawValue: code.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return request.subjectHint ?? .general
            }
            return s
        }
        // Trim a model-returned string; nil/blank → empty.
        func clean(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        // A non-empty trimmed value, or a fallback.
        func cleanOr(_ s: String?, _ fallback: String) -> String {
            let t = clean(s); return t.isEmpty ? fallback : t
        }
        let questions = w.questions.enumerated().map { idx, q -> GradedQuestion in
            let subj = subject(q.subject)
            let steps = (q.steps ?? []).enumerated().map { i, s in
                SolutionStep(index: i + 1, title: s.title, detail: s.detail, math: s.math)
            }
            let rubric = (q.rubric ?? []).map {
                RubricDimension(name: $0.name, score: $0.score, maxScore: $0.maxScore, comment: $0.comment ?? "")
            }
            // Drop blank knowledge-point names so the UI never renders empty chips.
            let kps = (q.knowledgePoints ?? []).compactMap { name -> KnowledgeRef? in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : KnowledgeRef(name: trimmed, subject: subj)
            }
            let errorType = q.errorType.flatMap { ErrorType(rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            return GradedQuestion(
                number: cleanOr(q.number, "\(idx + 1)"),
                type: WorkbookQuestionType.parse(q.type),
                subject: subj,
                questionText: clean(q.questionText),
                studentAnswer: clean(q.studentAnswer),
                correctAnswer: clean(q.correctAnswer),
                verdict: GradeVerdict.parse(q.verdict),
                explanation: clean(q.explanation),
                errorType: errorType,
                knowledgePoints: kps,
                pointsEarned: q.pointsEarned,
                pointsPossible: q.pointsPossible,
                steps: steps,
                rubric: rubric,
                teacherComment: q.teacherComment.map { clean($0) }.flatMap { $0.isEmpty ? nil : $0 })
        }
        let detected = (w.detectedSubjects ?? []).compactMap { Subject(rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return GradedWorkbook(
            title: cleanOr(w.title, "作业批改"),
            grade: request.grade,
            detectedSubjects: detected.isEmpty ? Array(Set(questions.map(\.subject))) : detected,
            questions: questions,
            overallComment: clean(w.overallComment),
            encouragement: cleanOr(w.encouragement, "继续加油，你做得很好！"),
            route: .cloud)
    }

    // MARK: - Essay grading

    private struct EssayWire: Decodable {
        struct Rubric: Decodable { let name: String; let score: Double; let maxScore: Double; let comment: String }
        struct Anno: Decodable { let original: String; let comment: String; let suggestion: String?; let severity: String? }
        let overallComment: String
        let score: Double
        let maxScore: Double
        let rubric: [Rubric]
        let annotations: [Anno]?
        let polishedText: String
        let highScoreExpressions: [String]?
        let strengths: [String]?
    }

    func gradeEssay(_ request: EssayGradeRequest) async throws -> EssayFeedback {
        do {
            let sys = persona + " 你是语文/英语作文批改老师，鼓励为主，指出问题并给出升格建议。"
            let user = """
            年级：\(gradeLabel(request.grade))，学科：\(subjectLabel(request.subject))，题目/要求：\(request.prompt.isEmpty ? "（自由命题）" : request.prompt)。
            学生作文：
            \(request.text)
            请按 JSON 作答：
            {"overallComment":"总评","score":42,"maxScore":50,"rubric":[{"name":"立意","score":8,"maxScore":10,"comment":"点评"}],"annotations":[{"original":"原句","comment":"点评","suggestion":"改写建议","severity":"praise|suggestion|error"}],"polishedText":"升格后的作文","highScoreExpressions":["亮点表达"],"strengths":["优点"]}
            """
            let w = try await json(EssayWire.self, system: sys, user: user, maxTokens: 2200)
            let rubric = w.rubric.map { RubricDimension(name: $0.name, score: $0.score, maxScore: $0.maxScore, comment: $0.comment) }
            let annotations = (w.annotations ?? []).map { a in
                SentenceAnnotation(original: a.original, comment: a.comment, suggestion: a.suggestion,
                                   severity: Self.severity(a.severity))
            }
            return EssayFeedback(overallComment: w.overallComment, score: w.score, maxScore: w.maxScore,
                                 rubric: rubric, annotations: annotations, polishedText: w.polishedText,
                                 highScoreExpressions: w.highScoreExpressions ?? [],
                                 strengths: w.strengths ?? [], route: .cloud)
        } catch {
            var r = try await fallback.gradeEssay(request); r.route = .cloud; return r
        }
    }

    private static func severity(_ s: String?) -> SentenceAnnotation.Severity {
        switch s?.lowercased() {
        case "praise": .praise
        case "error": .error
        default: .suggestion
        }
    }

    // MARK: - Similar problems

    private struct SimilarWire: Decodable {
        struct Problem: Decodable {
            struct Step: Decodable { let title: String; let detail: String; let math: String? }
            let question: String; let answer: String; let difficulty: Int?; let steps: [Step]?
        }
        let problems: [Problem]
    }

    func similarProblems(_ request: SimilarRequest) async throws -> [GeneratedProblem] {
        do {
            let sys = persona + " 你在出举一反三的同类练习题。"
            let kp = request.knowledgePoints.map(\.name).joined(separator: "、")
            let user = """
            学科：\(request.subject.displayName)，年级：\(gradeLabel(request.grade))，知识点：\(kp.isEmpty ? "（依据参考题）" : kp)。
            参考题：\(request.referenceText)
            请生成 \(request.count) 道难度递增的同类题，按 JSON：
            {"problems":[{"question":"题目","answer":"答案","difficulty":2,"steps":[{"title":"步骤","detail":"讲解","math":"可选"}]}]}
            """
            let w = try await json(SimilarWire.self, system: sys, user: user, maxTokens: 2000)
            return w.problems.map { p in
                let steps = (p.steps ?? []).enumerated().map { i, s in
                    SolutionStep(index: i + 1, title: s.title, detail: s.detail, math: s.math)
                }
                return GeneratedProblem(question: p.question, answer: p.answer, steps: steps,
                                        difficulty: max(1, min(5, p.difficulty ?? 2)),
                                        knowledgePointID: request.knowledgePoints.first?.id ?? "")
            }
        } catch {
            return try await fallback.similarProblems(request)
        }
    }

    // MARK: - Explain knowledge point

    private struct ExplainWire: Decodable {
        struct Section: Decodable { let heading: String; let body: String; let math: String? }
        let title: String; let sections: [Section]; let extensionQuestions: [String]?
    }

    func explainKnowledgePoint(_ request: ExplainRequest) async throws -> KnowledgeExplanation {
        do {
            let sys = persona + " 你在讲解一个知识点，分小节、由浅入深。"
            let user = """
            学科：\(request.subject.displayName)，年级：\(gradeLabel(request.grade))。
            知识点：\(request.knowledgePoint)
            请按 JSON：{"title":"标题","sections":[{"heading":"小节标题","body":"讲解","math":"可选公式"}],"extensionQuestions":["延伸思考问题"]}
            """
            let w = try await json(ExplainWire.self, system: sys, user: user)
            let sections = w.sections.map { ExplanationSection(heading: $0.heading, body: $0.body, math: $0.math) }
            return KnowledgeExplanation(title: w.title, sections: sections, board: [],
                                        extensionQuestions: w.extensionQuestions ?? [], route: .cloud)
        } catch {
            var r = try await fallback.explainKnowledgePoint(request); r.route = .cloud; return r
        }
    }

    // MARK: - Document summarize / Q&A

    private struct SummaryWire: Decodable { let summary: String; let keyPoints: [String]; let outline: [String] }

    func summarizeDocument(_ request: DocSummarizeRequest) async throws -> DocumentSummary {
        do {
            let sys = persona + " 你在帮学生快速读懂一份文档/课文。"
            let user = """
            标题：\(request.title)
            正文（节选）：
            \(String(request.text.prefix(6000)))
            请按 JSON：{"summary":"一段话总结","keyPoints":["要点"],"outline":["大纲条目"]}
            """
            let w = try await json(SummaryWire.self, system: sys, user: user)
            return DocumentSummary(summary: w.summary, keyPoints: w.keyPoints, outline: w.outline, route: .cloud)
        } catch {
            var r = try await fallback.summarizeDocument(request); r.route = .cloud; return r
        }
    }

    func answerAboutDocument(_ request: DocQARequest) async throws -> DocAnswer {
        do {
            let sys = persona + " 你只能依据给定文档内容回答，答案要准确、引用原文。"
            let user = """
            文档内容（节选）：
            \(String(request.documentText.prefix(6000)))

            问题：\(request.question)
            请用简体中文回答；若文档没有相关信息，请直说。
            """
            let answer = try await text(system: sys, user: user, maxTokens: 800)
            return DocAnswer(answer: answer, citedSpans: [], route: .cloud)
        } catch {
            var r = try await fallback.answerAboutDocument(request); r.route = .cloud; return r
        }
    }

    // MARK: - Lesson generation

    private struct LessonWire: Decodable {
        struct Segment: Decodable {
            struct Board: Decodable { let kind: String; let content: String }
            let narration: String; let board: [Board]?
        }
        let title: String; let segments: [Segment]
    }

    func generateLesson(_ request: LessonRequest) async throws -> GeneratedLesson {
        do {
            let sys = persona + " 你在为学生定制一节小课，分若干讲解片段，每段配板书要点。"
            let user = """
            学科：\(request.subject.displayName)，年级：\(gradeLabel(request.grade))，主题：\(request.topic)。
            请按 JSON：{"title":"课程标题","segments":[{"narration":"老师讲的话","board":[{"kind":"title|text|formula|bullet|highlight|answer","content":"板书内容"}]}]}
            生成 4-6 个片段。
            """
            let w = try await json(LessonWire.self, system: sys, user: user, maxTokens: 2200)
            let segments = w.segments.map { seg in
                TutorSegment(narration: seg.narration,
                             board: (seg.board ?? []).map { BoardElement(kind: Self.boardKind($0.kind), content: $0.content) })
            }
            let kps = [KnowledgeRef(name: request.topic, subject: request.subject)]
            return GeneratedLesson(title: w.title, segments: segments, knowledgePoints: kps, route: .cloud)
        } catch {
            var r = try await fallback.generateLesson(request); r.route = .cloud; return r
        }
    }

    private static func boardKind(_ s: String) -> BoardElement.Kind {
        BoardElement.Kind(rawValue: s.lowercased()) ?? .text
    }

    // MARK: - Deterministic graders (local engine, .cloud badge)

    func gradeArithmetic(_ request: ArithmeticGradeRequest) async throws -> GradedArithmetic {
        var r = try await fallback.gradeArithmetic(request); r.route = .cloud; return r
    }
    func gradeDictation(_ request: DictationGradeRequest) async throws -> DictationGrading {
        var r = try await fallback.gradeDictation(request); r.route = .cloud; return r
    }
    func scorePronunciation(_ request: PronunciationRequest) async throws -> PronunciationScore {
        var r = try await fallback.scorePronunciation(request); r.route = .cloud; return r
    }

    // MARK: - Tutor (streamed segments)

    private struct TutorWire: Decodable {
        struct Segment: Decodable {
            struct Board: Decodable { let kind: String; let content: String }
            let narration: String; let board: [Board]?
        }
        let segments: [Segment]
    }

    func tutorSession(_ request: TutorRequest) -> AsyncThrowingStream<TutorEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let sys = persona + " 你是「豆包老师」，正在用动态板书一步步讲题。"
                    let learn = request.learnMode ? "引导式，先讲思路，分小步，每步可设一个小提问。" : ""
                    let user = """
                    年级：\(gradeLabel(request.grade))，学科：\(subjectLabel(request.subject))。\(learn)
                    题目：\(request.problemText)
                    请按 JSON：{"segments":[{"narration":"老师讲的话","board":[{"kind":"title|text|formula|bullet|highlight|answer","content":"板书"}]}]}
                    生成 4-6 段。
                    """
                    let w = try await json(TutorWire.self, system: sys, user: user, maxTokens: 2200)
                    for seg in w.segments {
                        try Task.checkCancellation()
                        let board = (seg.board ?? []).map { BoardElement(kind: Self.boardKind($0.kind), content: $0.content) }
                        continuation.yield(.segment(TutorSegment(narration: seg.narration, board: board)))
                    }
                    continuation.yield(.done)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    // Fall back to the offline tutor stream.
                    do {
                        for try await event in fallback.tutorSession(request) {
                            continuation.yield(event)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Chat (streamed, simulated token deltas)

    func chat(_ request: ChatRequest) -> AsyncThrowingStream<ChatChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let reply = try await cloudChat(request)
                    // Emit in small word-ish chunks so the bubble types out smoothly.
                    let pieces = Self.streamPieces(reply)
                    for piece in pieces {
                        try Task.checkCancellation()
                        continuation.yield(ChatChunk(delta: piece, isFinal: false, route: .cloud))
                        try? await Task.sleep(nanoseconds: 18_000_000)
                    }
                    continuation.yield(ChatChunk(delta: "", isFinal: true, route: .cloud))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    do {
                        for try await chunk in fallback.chat(request) { continuation.yield(chunk) }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func cloudChat(_ request: ChatRequest) async throws -> String {
        let role: String
        switch request.kind {
        case .tutor:     role = "你是耐心的私人辅导老师，引导学生自己想明白。"
        case .companion: role = "你是温暖的学习伙伴「豆包」，可以聊学习也可以鼓励打气。"
        case .knowledge: role = "你是知识专家，回答准确、简洁、可延伸。"
        }
        let sys = persona + " " + role + " 年级：\(gradeLabel(request.context.grade))。"
        // Flatten the recent turns into a single prompt (last ~12 turns).
        let turns = request.turns.suffix(12).map { turn -> String in
            let who = turn.role == .user ? "学生" : "老师"
            return "\(who)：\(turn.text)"
        }.joined(separator: "\n")
        let user = turns + "\n老师："
        return try await client.complete(system: sys, user: user, maxTokens: 1200)
    }

    /// Split a reply into smooth streaming pieces (group CJK by a few chars,
    /// keep latin words intact).
    private static func streamPieces(_ text: String) -> [String] {
        var pieces: [String] = []
        var buffer = ""
        for ch in text {
            buffer.append(ch)
            let isBoundary = ch == " " || ch == "\n" || ch == "，" || ch == "。" || ch == "、"
            if isBoundary || buffer.count >= 3 {
                pieces.append(buffer)
                buffer = ""
            }
        }
        if !buffer.isEmpty { pieces.append(buffer) }
        return pieces.isEmpty ? [text] : pieces
    }
}
