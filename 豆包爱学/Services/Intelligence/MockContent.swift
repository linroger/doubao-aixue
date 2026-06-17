//
//  MockContent.swift
//  豆包爱学
//
//  Deterministic content generators for MockIntelligenceService. Pure,
//  nonisolated helpers — no randomness, derived from input for stability.
//

import Foundation

public nonisolated enum MockContent {

    // MARK: Subject inference

    static func inferSubject(from text: String) -> Subject {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let asciiLetters = text.unicodeScalars.filter { ("a"..."z").contains(Character($0)) || ("A"..."Z").contains(Character($0)) }
        if !letters.isEmpty, Double(asciiLetters.count) / Double(letters.count) > 0.6 { return .english }
        if text.contains(where: { "+-×÷=".contains($0) }) || text.range(of: "[0-9]", options: .regularExpression) != nil {
            return .math
        }
        if text.contains("化学") || text.contains("元素") { return .chemistry }
        if text.contains("物理") || text.contains("力") { return .physics }
        return .chinese
    }

    // MARK: Choices

    static func parseChoices(from text: String) -> [ChoiceOption]? {
        let labels = ["A", "B", "C", "D"]
        var found: [ChoiceOption] = []
        for (i, label) in labels.enumerated() {
            for sep in [".", "、", "．", ")", "）"] {
                if let range = text.range(of: "\(label)\(sep)") {
                    let after = text[range.upperBound...].prefix(24)
                    found.append(ChoiceOption(label: label, text: String(after).trimmingCharacters(in: .whitespaces),
                                              isCorrect: i == 0,
                                              explanation: i == 0 ? "符合题意，正确。" : "与题意不符或存在概念错误。"))
                    break
                }
            }
        }
        return found.count >= 2 ? found : nil
    }

    // MARK: Knowledge points

    static func knowledgePoints(for subject: Subject) -> [KnowledgeRef] {
        switch subject {
        case .math: [KnowledgeRef(name: "方程与等量关系", subject: .math), KnowledgeRef(name: "数形结合", subject: .math)]
        case .physics: [KnowledgeRef(name: "受力分析", subject: .physics)]
        case .chemistry: [KnowledgeRef(name: "化学方程式", subject: .chemistry)]
        case .english: [KnowledgeRef(name: "时态与语法", subject: .english)]
        case .chinese: [KnowledgeRef(name: "阅读理解", subject: .chinese)]
        default: [KnowledgeRef(name: "核心概念", subject: subject)]
        }
    }

    // MARK: Generic solution

    static func approach(for subject: Subject) -> String {
        switch subject {
        case .math: "先理解已知与所求，建立等量关系，再一步步求解。"
        case .physics: "先做受力/情景分析，选定规律，再代入求解。"
        case .chemistry: "先判断反应类型，写出方程式并配平，再按比例计算。"
        case .english: "先抓住句子结构与时态，再结合语境理解含义。"
        case .chinese: "先通读把握大意，再回到原文定位关键句作答。"
        default: "先理解题意，再分步推理得到结论。"
        }
    }

    static func genericSteps(for subject: Subject, text: String) -> [SolutionStep] {
        [
            SolutionStep(index: 1, title: "理解题意", detail: "提取关键信息：\(text.prefix(26))…，明确要解决什么。"),
            SolutionStep(index: 2, title: "建立思路", detail: approach(for: subject),
                         math: subject.isSTEM ? formula(for: subject) : nil),
            SolutionStep(index: 3, title: "分步求解", detail: "按思路逐步推进，注意每一步的依据。"),
            SolutionStep(index: 4, title: "归纳总结", detail: "回顾用到的知识点，想想这类题的通法。"),
        ]
    }

    static func genericAnswer(for subject: Subject) -> String {
        subject.isSTEM ? "x = 2（示例答案）" : "见解析（要点已在步骤中给出）"
    }

    static func formula(for subject: Subject) -> String {
        switch subject {
        case .math: "ax + b = 0 \\Rightarrow x = -\\frac{b}{a}"
        case .physics: "F = ma"
        case .chemistry: "2H_2 + O_2 \\rightarrow 2H_2O"
        default: "S = \\frac{1}{2}bh"
        }
    }

    // MARK: Similar problems

    static func similar(subject: Subject, count: Int, knowledgePointID: String) -> [GeneratedProblem] {
        (0..<count).map { i in
            let a = (i + 2) * 3, b = (i + 1) * 4
            if subject == .math {
                let answer = a + b
                return GeneratedProblem(
                    subject: subject,
                    question: "计算：\(a) + \(b) = ?",
                    answer: "\(answer)",
                    steps: [SolutionStep(index: 1, title: "相加", detail: "把两个数相加。", math: "\(a)+\(b)=\(answer)")],
                    difficulty: min(5, i + 1), knowledgePointID: knowledgePointID)
            } else {
                // A deterministic single-choice item with a REAL checkable answer
                // (A–D), so non-math drills are actually winnable offline and the
                // recap shows a genuine explanation instead of "见解析".
                let item = nonMathChoiceBank(for: subject)[i % max(1, nonMathChoiceBank(for: subject).count)]
                let labels = ["A", "B", "C", "D"]
                let answerLabel = labels[item.correct]
                return GeneratedProblem(
                    subject: subject,
                    question: item.q + "\n" + item.choices.joined(separator: "\n") + "\n（请填写正确选项的字母）",
                    answer: answerLabel,
                    steps: [SolutionStep(index: 1, title: "解析",
                                         detail: "正确答案是 \(answerLabel)。\(approach(for: subject))")],
                    difficulty: min(5, i + 1), knowledgePointID: knowledgePointID)
            }
        }
    }

    /// Deterministic, subject-aware single-choice items used by the offline /
    /// on-device drill generator so every subject is genuinely answerable.
    private static func nonMathChoiceBank(for subject: Subject) -> [(q: String, choices: [String], correct: Int)] {
        switch subject {
        case .chinese:
            return [("下列词语书写完全正确的一项是：",
                     ["A. 一丝不苟", "B. 再接再励", "C. 不径而走", "D. 走头无路"], 0),
                    ("「春风又绿江南岸」中「绿」字的妙处在于：",
                     ["A. 用作动词，写出春风使江南变绿的动态", "B. 单纯写颜色", "C. 只为押韵", "D. 没有特别含义"], 0)]
        case .english:
            return [("Choose the correct form: She ___ to school every day.",
                     ["A. go", "B. goes", "C. going", "D. gone"], 1),
                    ("Choose the correct word: I have ___ apple.",
                     ["A. a", "B. an", "C. the", "D. /"], 1)]
        case .physics:
            return [("一个静止在水平桌面上的物体，受到的合力是：",
                     ["A. 重力", "B. 支持力", "C. 零", "D. 摩擦力"], 2)]
        case .chemistry:
            return [("下列变化属于化学变化的是：",
                     ["A. 冰融化成水", "B. 铁生锈", "C. 水蒸发", "D. 玻璃破碎"], 1)]
        default:
            return [("关于「\(subject.displayName)」核心概念，正确的一项是：",
                     ["A. 正确选项", "B. 干扰项一", "C. 干扰项二", "D. 干扰项三"], 0)]
        }
    }

    // MARK: Workbook grading (作业批改)

    /// Grade a workbook from its OCR pre-pass. Real arithmetic is genuinely
    /// checked; everything else falls back to a rich, deterministic sample so the
    /// feature is fully demoable offline and on every platform.
    static func gradeWorkbook(recognizedText: String, subjectHint: Subject?, grade: GradeLevel) -> GradedWorkbook {
        let lines = recognizedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let arithmetic = OCRService.parseArithmeticLines(lines)
        if !arithmetic.isEmpty {
            let questions = arithmetic.enumerated().map { idx, item in
                gradeArithmeticQuestion(index: idx + 1, item: item)
            }
            let correct = questions.filter { $0.verdict == .correct }.count
            let comment = correct == questions.count
                ? "全部做对了，计算又快又准，真棒！继续保持这种细心。"
                : "一共 \(questions.count) 题，做对 \(correct) 题。错的几道大多是计算或进位的小失误，订正一遍就能掌握。"
            return GradedWorkbook(
                title: "口算作业 · \(grade.displayName)",
                grade: grade,
                detectedSubjects: [.math],
                questions: questions,
                overallComment: comment,
                encouragement: correct == questions.count ? "满分啦，给你点个大大的赞！" : "错题不可怕，订正完就是你的了～",
                route: .mock)
        }
        // Nothing recognized → let the caller surface the empty state ("没识别到题目")
        // rather than a misleading demo.
        guard !lines.isEmpty else {
            return GradedWorkbook(title: "作业批改", grade: grade, detectedSubjects: [],
                                  questions: [], overallComment: "", encouragement: "", route: .mock)
        }
        // OCR found text but the offline engine can only auto-grade 口算. Surface the
        // recognized questions as 待确认 with an honest, actionable nudge to enable
        // cloud AI — never fake a grade.
        let subj = subjectHint ?? inferSubject(from: lines.joined(separator: "\n"))
        let questions = lines.prefix(12).enumerated().map { idx, line in
            GradedQuestion(
                number: "\(idx + 1)", type: .other, subject: subj,
                questionText: line, verdict: .ungradable,
                explanation: "离线模式只能自动批改口算题。在「设置 → AI 模型」开启云端模型后，我就能逐题批改这道题啦。")
        }
        return GradedWorkbook(
            title: "作业识别（离线）", grade: grade, detectedSubjects: [subj],
            questions: Array(questions),
            overallComment: "已识别到 \(questions.count) 道题目。离线模式暂时只能批改口算；开启 AI 模型后可获得逐题批改与讲解。",
            encouragement: "开启 AI 模型，我能帮你把每道题都批改好～", route: .mock)
    }

    private static func gradeArithmeticQuestion(index: Int, item: ArithmeticItem) -> GradedQuestion {
        let kp = [KnowledgeRef(name: "四则运算", subject: .math)]
        let exprClean = item.expression.replacingOccurrences(of: "=", with: "")
        let questionText = item.expression.contains("=") ? item.expression : item.expression + " ="
        guard let value = ArithmeticEvaluator.evaluate(exprClean) else {
            return GradedQuestion(
                number: "\(index)", type: .calculation, subject: .math,
                questionText: questionText, studentAnswer: item.studentAnswer,
                correctAnswer: "—", verdict: .ungradable,
                explanation: "这道算式没有看清楚，建议把作业拍清楚、拍正一点再批改。",
                knowledgePoints: kp)
        }
        let correct = ArithmeticEvaluator.format(value)
        let studentTrimmed = item.studentAnswer.trimmingCharacters(in: .whitespaces)
        if studentTrimmed.isEmpty {
            return GradedQuestion(
                number: "\(index)", type: .calculation, subject: .math,
                questionText: questionText, studentAnswer: "", correctAnswer: correct,
                verdict: .unattempted,
                explanation: "这道题还没有作答哦。正确答案是 \(correct)，试着自己算一遍吧。",
                errorType: .careless, knowledgePoints: kp,
                steps: [SolutionStep(index: 1, title: "按运算顺序计算", detail: "先乘除后加减，有括号先算括号。", math: "\(exprClean) = \(correct)")])
        }
        let studentVal = ArithmeticEvaluator.evaluate(studentTrimmed)
        let isCorrect = studentVal.map { abs($0 - value) < 0.0001 } ?? (studentTrimmed == correct)
        return GradedQuestion(
            number: "\(index)", type: .calculation, subject: .math,
            questionText: questionText, studentAnswer: item.studentAnswer, correctAnswer: correct,
            verdict: isCorrect ? .correct : .incorrect,
            explanation: isCorrect
                ? "计算正确，很细心！"
                : "正确答案是 \(correct)。再检查一下运算顺序和进位/借位，慢一点会更稳。",
            errorType: isCorrect ? nil : .calculation,
            knowledgePoints: kp,
            steps: isCorrect ? [] : [SolutionStep(index: 1, title: "正确算法", detail: "按运算顺序一步步算。", math: "\(exprClean) = \(correct)")])
    }

    /// A rich, multi-subject demo result that exercises every part of the schema —
    /// used when there's nothing to OCR (sample / unsupported capture).
    static func sampleGradedWorkbook(subjectHint: Subject?, grade: GradeLevel) -> GradedWorkbook {
        let questions: [GradedQuestion] = [
            GradedQuestion(
                number: "1", type: .calculation, subject: .math,
                questionText: "25 \\times 4 =", studentAnswer: "100", correctAnswer: "100",
                verdict: .correct, explanation: "计算正确，乘法口诀用得很熟练！",
                knowledgePoints: [KnowledgeRef(name: "两位数乘法", subject: .math)]),
            GradedQuestion(
                number: "2", type: .calculation, subject: .math,
                questionText: "36 + 48 =", studentAnswer: "74", correctAnswer: "84",
                verdict: .incorrect,
                explanation: "个位 6+8=14，要向十位进 1。正确答案是 84，注意进位别漏掉。",
                errorType: .calculation,
                knowledgePoints: [KnowledgeRef(name: "进位加法", subject: .math)],
                steps: [SolutionStep(index: 1, title: "对齐数位", detail: "个位加个位，十位加十位。"),
                        SolutionStep(index: 2, title: "处理进位", detail: "6+8=14，写4进1。", math: "36 + 48 = 84")]),
            GradedQuestion(
                number: "3", type: .fillInBlank, subject: .chinese,
                questionText: "《静夜思》：举头望明月，低头思______。",
                studentAnswer: "故乡", correctAnswer: "故乡",
                verdict: .correct, explanation: "默写正确，古诗记得很牢！",
                knowledgePoints: [KnowledgeRef(name: "古诗默写", subject: .chinese)]),
            GradedQuestion(
                number: "4", type: .multipleChoice, subject: .english,
                questionText: "She ___ to school every day.  A. go  B. goes  C. going",
                studentAnswer: "A", correctAnswer: "B",
                verdict: .incorrect,
                explanation: "主语 She 是第三人称单数，动词要加 -s，所以选 B. goes。",
                errorType: .concept,
                knowledgePoints: [KnowledgeRef(name: "一般现在时第三人称单数", subject: .english)]),
            GradedQuestion(
                number: "5", type: .shortAnswer, subject: .chinese,
                questionText: "用「先……再……最后……」写一句话，描述你的早晨。",
                studentAnswer: "我先刷牙，再吃饭，去上学。", correctAnswer: "（开放题，言之有序即可）",
                verdict: .partial,
                explanation: "句子顺序清楚，很好！只差最后一个关联词，可以改成「……最后去上学」让结构更完整。",
                errorType: .method,
                knowledgePoints: [KnowledgeRef(name: "关联词造句", subject: .chinese)],
                rubric: [RubricDimension(name: "条理", score: 4, maxScore: 5, comment: "顺序清楚"),
                         RubricDimension(name: "完整", score: 3, maxScore: 5, comment: "缺少「最后」"),
                         RubricDimension(name: "用词", score: 4, maxScore: 5, comment: "用词准确")],
                teacherComment: "再补上「最后」就满分啦，加油！"),
        ]
        return GradedWorkbook(
            title: "作业批改示例 · \(grade.displayName)",
            grade: grade,
            detectedSubjects: [.math, .chinese, .english],
            questions: questions,
            overallComment: "这页作业一共 5 题，做对 2 题、部分正确 1 题、错 2 题。错题集中在「进位加法」和「动词第三人称单数」，把这两个知识点复习一下就更稳了。",
            encouragement: "做得不错，订正完错题，你会更厉害！",
            route: .mock)
    }

    // MARK: Text utilities

    static func sentences(in text: String) -> [String] {
        let separators = CharacterSet(charactersIn: "。！？.!?\n")
        return text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func polish(_ text: String) -> String {
        let s = sentences(in: text)
        guard !s.isEmpty else { return text }
        var out = s
        out[0] = out[0] + "（开头点题，引人入胜）"
        if out.count > 1 { out[out.count - 1] = out[out.count - 1] + "（结尾升华，呼应开头）" }
        return out.joined(separator: "。") + "。"
    }

    static func overlap(_ a: String, _ b: String) -> Int {
        let sa = Set(a), sb = Set(b)
        return sa.intersection(sb).count
    }

    // MARK: Lesson

    static func lessonSegments(topic: String, subject: Subject) -> [TutorSegment] {
        [
            TutorSegment(narration: "今天我们来学习《\(topic)》。先看一段情景，感受它的背景。",
                         board: [BoardElement(kind: .title, content: topic)]),
            TutorSegment(narration: "我们逐句来理解它的含义和写作手法。",
                         board: [BoardElement(kind: .bullet, content: "逐句精讲"),
                                 BoardElement(kind: .text, content: "关键词与意象")]),
            TutorSegment(narration: "做一道小练习检验一下。",
                         board: [BoardElement(kind: .bullet, content: "互动习题")],
                         checkpoint: TutorCheckpoint(prompt: "这首作品表达了怎样的情感？",
                                                     options: ["思乡", "喜悦", "愤怒"], answerIndex: 0,
                                                     explanation: "结合背景可知，作者借景抒发思念之情。")),
            TutorSegment(narration: "最后我们一起背诵并总结要点。",
                         board: [BoardElement(kind: .answer, content: "理解记忆，事半功倍")]),
        ]
    }

    // MARK: Chat

    static func chatReply(to userText: String, kind: ConversationKind) -> String {
        if userText.isEmpty {
            return "你好呀！我是你的学习搭子豆包。有什么题目或问题都可以问我，我会一步一步陪你想清楚～"
        }
        switch kind {
        case .companion:
            return "我在听呢。学习有时候确实会累，先深呼吸一下。\(userText.prefix(12))…这件事，我们可以一起慢慢面对。你愿意多和我说说吗？"
        case .tutor, .knowledge:
            return "好问题！关于「\(userText.prefix(16))」，我们先弄清它在问什么，再一步步分析。核心要点有三个，我先讲第一个，你跟上了随时打断我提问。"
        }
    }

    static func streamFragments(_ text: String) -> [String] {
        // Split into small chunks for a streaming feel.
        var result: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if "，。！？、,.!? ".contains(ch) || current.count >= 6 {
                result.append(current); current = ""
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    static func chatBlocks(for userText: String, fullText: String, kind: ConversationKind) -> [RichBlock] {
        var blocks: [RichBlock] = [RichBlock(kind: .text, content: fullText)]
        if kind != .companion {
            blocks.append(RichBlock(kind: .suggestion, content: "讲一讲这道题", auxiliary: "tutor"))
            blocks.append(RichBlock(kind: .suggestion, content: "出几道相似题", auxiliary: "similar"))
            blocks.append(RichBlock(kind: .suggestion, content: "加入错题本", auxiliary: "mistake"))
        }
        return blocks
    }
}
