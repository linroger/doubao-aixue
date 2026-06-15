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
                    question: "计算：\(a) + \(b) = ?",
                    answer: "\(answer)",
                    steps: [SolutionStep(index: 1, title: "相加", detail: "把两个数相加。", math: "\(a)+\(b)=\(answer)")],
                    difficulty: min(5, i + 1), knowledgePointID: knowledgePointID)
            } else {
                return GeneratedProblem(
                    question: "请仿照例题，完成第 \(i + 1) 道同类练习。",
                    answer: "见解析", difficulty: min(5, i + 1), knowledgePointID: knowledgePointID)
            }
        }
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
