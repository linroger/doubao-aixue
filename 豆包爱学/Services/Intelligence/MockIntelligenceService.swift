//
//  MockIntelligenceService.swift
//  豆包爱学
//
//  The default, fully-functional, deterministic, offline Intelligence provider.
//  It makes every feature demoable with no network and no entitlements. Outputs
//  are templated + derived from the input (no randomness) so they are stable.
//  Where it can compute a real answer (arithmetic, dictation diff, pronunciation
//  overlap) it does, so those features are genuinely correct.
//

import Foundation

public nonisolated struct MockIntelligenceService: IntelligenceService {
    public init() {}

    public var capabilities: IntelligenceCapabilities {
        IntelligenceCapabilities(route: .mock, modelName: "豆包爱学 · 离线引擎", supportsStreaming: true)
    }

    // Small artificial latency so streaming/spinners feel real.
    private func tick(_ ms: UInt64 = 220) async {
        try? await Task.sleep(nanoseconds: ms * 1_000_000)
    }

    // MARK: Solve

    public func solve(_ request: SolveRequest) async throws -> SolvedProblem {
        let text = request.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw IntelligenceError.emptyInput }
        await tick()
        let subject = request.subject ?? MockContent.inferSubject(from: text)

        // Real arithmetic path when the captured text is a bare expression.
        if subject == .math, let value = ArithmeticEvaluator.evaluate(text.replacingOccurrences(of: "=", with: "")) {
            let answer = ArithmeticEvaluator.format(value)
            let steps = [
                SolutionStep(index: 1, title: "审题", detail: "先看清运算顺序：先乘除、后加减，有括号先算括号。"),
                SolutionStep(index: 2, title: "计算", detail: "按顺序逐步计算。", math: "\(text) = \(answer)"),
                SolutionStep(index: 3, title: "检查", detail: "可用估算或逆运算复核，确保结果合理。"),
            ]
            return SolvedProblem(
                subject: .math, approach: "这是一道计算题，重点在运算顺序与细心。",
                steps: steps, finalAnswer: answer,
                knowledgePoints: [KnowledgeRef(name: "四则运算", subject: .math)], route: .mock)
        }

        // MCQ path.
        if let choices = MockContent.parseChoices(from: text) {
            let steps = [
                SolutionStep(index: 1, title: "理解题意", detail: "提取题干关键信息，明确在考查什么。"),
                SolutionStep(index: 2, title: "逐项分析", detail: "对每个选项判断正误并说明原因。"),
                SolutionStep(index: 3, title: "得出答案", detail: "排除错误选项，确定正确答案。"),
            ]
            let correct = choices.first(where: \.isCorrect)?.label ?? "A"
            return SolvedProblem(subject: subject, approach: "选择题要逐项排查，理解每个选项为什么对或错。",
                                 steps: steps, finalAnswer: correct, choices: choices,
                                 knowledgePoints: MockContent.knowledgePoints(for: subject), route: .mock)
        }

        // General structured solution.
        let steps = MockContent.genericSteps(for: subject, text: text)
        return SolvedProblem(
            subject: subject,
            approach: MockContent.approach(for: subject),
            steps: steps,
            finalAnswer: MockContent.genericAnswer(for: subject),
            knowledgePoints: MockContent.knowledgePoints(for: subject),
            route: .mock)
    }

    // MARK: Essay grading

    public func gradeEssay(_ request: EssayGradeRequest) async throws -> EssayFeedback {
        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw IntelligenceError.emptyInput }
        await tick(420)
        let sentences = MockContent.sentences(in: text)
        let length = text.count
        // Score grows with length & sentence variety (bounded), praising effort.
        let base = min(92, 70 + length / 40 + min(sentences.count, 8))
        let isEnglish = request.subject == .english
        let rubric: [RubricDimension] = [
            RubricDimension(name: isEnglish ? "Content" : "立意", score: Double(min(20, base / 5)), maxScore: 20, comment: "中心明确，能围绕主题展开。"),
            RubricDimension(name: isEnglish ? "Organization" : "结构", score: Double(min(20, base / 5 - 1)), maxScore: 20, comment: "层次较清晰，段落衔接可再自然。"),
            RubricDimension(name: isEnglish ? "Language" : "语言", score: Double(min(20, base / 5 - 1)), maxScore: 20, comment: "用词较准确，可增加生动表达。"),
            RubricDimension(name: isEnglish ? "Mechanics" : "书写", score: Double(min(20, base / 5)), maxScore: 20, comment: "卷面整洁，标点规范。"),
            RubricDimension(name: isEnglish ? "Insight" : "亮点", score: Double(min(20, base / 5 - 2)), maxScore: 20, comment: "有自己的思考，鼓励再深入。"),
        ]
        let annotations: [SentenceAnnotation] = sentences.prefix(4).enumerated().map { i, s in
            if i == 0 {
                return SentenceAnnotation(original: s, comment: "开头点题，很好！", severity: .praise)
            } else if i == 1 {
                return SentenceAnnotation(original: s, comment: "这句可以更具体，加入细节描写。",
                                          suggestion: s + "（可补充一个具体例子）", severity: .suggestion)
            } else {
                return SentenceAnnotation(original: s, comment: "表达清楚，注意语气连贯。", severity: .suggestion)
            }
        }
        let overall = "先表扬：你的作文中心明确、条理清楚，看得出认真思考。再建议：个别句子可以更具体生动，结尾可以呼应开头、升华主题。"
        return EssayFeedback(
            overallComment: overall,
            score: Double(base), maxScore: 100, rubric: rubric, annotations: annotations,
            polishedText: MockContent.polish(text),
            highScoreExpressions: isEnglish
                ? ["a vivid example", "more importantly", "in conclusion"]
                : ["首尾呼应", "由景及情", "画龙点睛"],
            strengths: ["中心明确", "条理清楚", "书写工整"], route: .mock)
    }

    // MARK: Arithmetic grading (real evaluation)

    public func gradeArithmetic(_ request: ArithmeticGradeRequest) async throws -> GradedArithmetic {
        await tick(320)
        let graded = request.items.map { item -> GradedArithmeticItem in
            let expr = item.expression.replacingOccurrences(of: "=", with: "")
            guard let value = ArithmeticEvaluator.evaluate(expr) else {
                return GradedArithmeticItem(expression: item.expression, studentAnswer: item.studentAnswer,
                                            correctAnswer: "—", isCorrect: false,
                                            errorType: .comprehension, explanation: "无法识别算式，请重新拍摄。")
            }
            let correct = ArithmeticEvaluator.format(value)
            let studentVal = ArithmeticEvaluator.evaluate(item.studentAnswer)
            let isCorrect = studentVal.map { abs($0 - value) < 0.0001 } ?? (item.studentAnswer.trimmingCharacters(in: .whitespaces) == correct)
            return GradedArithmeticItem(
                expression: item.expression, studentAnswer: item.studentAnswer,
                correctAnswer: correct, isCorrect: isCorrect,
                errorType: isCorrect ? nil : .calculation,
                explanation: isCorrect ? "" : "正确答案是 \(correct)。注意运算顺序与进位/借位。")
        }
        return GradedArithmetic(items: graded, route: .mock)
    }

    // MARK: Similar problems

    public func similarProblems(_ request: SimilarRequest) async throws -> [GeneratedProblem] {
        await tick(300)
        return MockContent.similar(subject: request.subject, count: max(1, request.count),
                                   knowledgePointID: request.knowledgePoints.first?.id ?? "")
    }

    // MARK: Knowledge explanation (背景→内容→价值)

    public func explainKnowledgePoint(_ request: ExplainRequest) async throws -> KnowledgeExplanation {
        await tick(360)
        let kp = request.knowledgePoint
        let sections = [
            ExplanationSection(heading: "背景", body: "「\(kp)」是\(request.subject.displayName)中的重要知识点，常出现在\(request.grade.displayName)的学习与考试中。"),
            ExplanationSection(heading: "内容", body: "它的核心是理解概念的定义、适用条件与常见变形。我们用一个例子来体会它的用法。",
                               math: MockContent.formula(for: request.subject)),
            ExplanationSection(heading: "价值", body: "掌握「\(kp)」能帮助你把一类题目串联起来，做到举一反三，而不是只会做这一道题。"),
        ]
        let board = [
            BoardElement(kind: .title, content: kp),
            BoardElement(kind: .bullet, content: "定义与条件"),
            BoardElement(kind: .formula, content: MockContent.formula(for: request.subject)),
            BoardElement(kind: .bullet, content: "典型应用"),
        ]
        return KnowledgeExplanation(title: kp, sections: sections, board: board,
                                    extensionQuestions: ["如果条件变一变，结论还成立吗？", "你能再举一个生活中的例子吗？"],
                                    route: .mock)
    }

    // MARK: Document Q&A

    public func summarizeDocument(_ request: DocSummarizeRequest) async throws -> DocumentSummary {
        await tick(500)
        let sentences = MockContent.sentences(in: request.text)
        let summary = sentences.prefix(2).joined(separator: "") .isEmpty
            ? "这份文档介绍了「\(request.title)」的主要内容。"
            : sentences.prefix(2).joined()
        let keyPoints = Array(sentences.prefix(5)).enumerated().map { "要点\($0.offset + 1)：\($0.element)" }
        let outline = ["引入", "核心内容", "要点梳理", "小结"]
        return DocumentSummary(summary: summary, keyPoints: keyPoints, outline: outline, route: .mock)
    }

    public func answerAboutDocument(_ request: DocQARequest) async throws -> DocAnswer {
        await tick(360)
        let sentences = MockContent.sentences(in: request.documentText)
        let q = request.question
        // Find the sentence with the most shared characters with the question.
        let best = sentences.max { lhs, rhs in
            MockContent.overlap(q, lhs) < MockContent.overlap(q, rhs)
        } ?? "文档中暂未找到直接相关的内容。"
        return DocAnswer(answer: "根据文档：\(best)", citedSpans: [best], route: .mock)
    }

    // MARK: Lesson generation

    public func generateLesson(_ request: LessonRequest) async throws -> GeneratedLesson {
        await tick(600)
        let segs = MockContent.lessonSegments(topic: request.topic, subject: request.subject)
        return GeneratedLesson(title: request.topic, segments: segs,
                               knowledgePoints: [KnowledgeRef(name: request.topic, subject: request.subject)], route: .mock)
    }

    // MARK: Dictation grading (real diff)

    public func gradeDictation(_ request: DictationGradeRequest) async throws -> DictationGrading {
        await tick(260)
        let count = max(request.expected.count, request.written.count)
        var results: [DictationWordResult] = []
        for i in 0..<count {
            let expected = i < request.expected.count ? request.expected[i] : ""
            let written = i < request.written.count ? request.written[i] : ""
            let correct = !expected.isEmpty &&
                expected.trimmingCharacters(in: .whitespaces) == written.trimmingCharacters(in: .whitespaces)
            results.append(DictationWordResult(expected: expected, written: written, isCorrect: correct))
        }
        return DictationGrading(results: results, route: .mock)
    }

    // MARK: Pronunciation (overlap-based)

    public func scorePronunciation(_ request: PronunciationRequest) async throws -> PronunciationScore {
        await tick(300)
        let refWords = request.referenceText.lowercased().split{ !$0.isLetter }.map(String.init)
        let saidWords = Set(request.recognizedText.lowercased().split { !$0.isLetter }.map(String.init))
        let per = refWords.map { word -> WordScore in
            let hit = saidWords.contains(word)
            return WordScore(word: word, score: hit ? 96 : 62)
        }
        let accuracy = per.isEmpty ? 80 : per.map(\.score).reduce(0, +) / Double(per.count)
        let completeness = refWords.isEmpty ? 100 : Double(refWords.filter { saidWords.contains($0) }.count) / Double(refWords.count) * 100
        let fluency = min(100, accuracy + 2)
        let overall = (accuracy + completeness + fluency) / 3
        return PronunciationScore(overall: overall, accuracy: accuracy, fluency: fluency,
                                  completeness: completeness, perWord: per, route: .mock)
    }

    // MARK: Tutor session (streamed)

    public func tutorSession(_ request: TutorRequest) -> AsyncThrowingStream<TutorEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let subject = request.subject
                let intro = TutorSegment(
                    narration: "我们一起来看这道题。别急着要答案，先想想它在考什么。",
                    board: [BoardElement(kind: .title, content: "一起解题"),
                            BoardElement(kind: .text, content: request.problemText.prefix(40).description)])
                continuation.yield(.segment(intro))
                try? await Task.sleep(nanoseconds: 600_000_000)

                let steps = MockContent.genericSteps(for: subject, text: request.problemText)
                for step in steps {
                    let seg = TutorSegment(
                        narration: "第\(step.index)步，\(step.title)。\(step.detail)",
                        board: [BoardElement(kind: .bullet, content: "\(step.index). \(step.title)")]
                            + (step.math.map { [BoardElement(kind: .formula, content: $0)] } ?? []),
                        checkpoint: step.index == steps.count
                            ? TutorCheckpoint(prompt: "到这里听懂了吗？", options: ["听懂了", "再讲一遍"], answerIndex: 0,
                                              explanation: "很好，那我们继续。")
                            : nil)
                    continuation.yield(.segment(seg))
                    try? await Task.sleep(nanoseconds: 700_000_000)
                }
                let outro = TutorSegment(
                    narration: "这类题的关键就在刚才那一步。试着自己再做一道类似的题巩固一下吧！",
                    board: [BoardElement(kind: .answer, content: MockContent.genericAnswer(for: subject))])
                continuation.yield(.segment(outro))
                continuation.yield(.done)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Chat (streamed)

    public func chat(_ request: ChatRequest) -> AsyncThrowingStream<ChatChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let userText = request.turns.last(where: { $0.role == .user })?.text ?? ""
                let reply = MockContent.chatReply(to: userText, kind: request.kind)
                // Stream by sentence-ish chunks.
                var buffer = ""
                for fragment in MockContent.streamFragments(reply) {
                    buffer += fragment
                    continuation.yield(ChatChunk(delta: fragment, isFinal: false, route: .mock))
                    try? await Task.sleep(nanoseconds: 90_000_000)
                }
                let blocks = MockContent.chatBlocks(for: userText, fullText: buffer, kind: request.kind)
                continuation.yield(ChatChunk(delta: "", isFinal: true, blocks: blocks, route: .mock))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
