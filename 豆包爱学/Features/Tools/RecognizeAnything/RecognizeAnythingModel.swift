//
//  RecognizeAnythingModel.swift
//  豆包爱学 — Features/Tools/RecognizeAnything
//
//  The @Observable view model behind 识万物 (F25). It drives a single
//  `ViewState<RecognitionResult>` through the standard empty/loading/loaded/error
//  lifecycle, so the view stays declarative.
//
//  Flow: image/sample → on-device Vision/OCR recognition (RecognizeAnythingEngine)
//  → kid-friendly 讲解 + 延伸问题 enrichment via the IntelligenceService
//  (`explainKnowledgePoint`, with a deterministic offline fallback so it works
//  on every platform without a network).
//

import SwiftUI

@MainActor
@Observable
final class RecognizeAnythingModel {
    /// The recognizing source, surfaced in the loading banner.
    var source: RASource = .sample
    var state: ViewState<RecognitionResult> = .idle

    private let engine = RecognizeAnythingEngine()

    /// The image we recognized, kept so a vision-capable model can ground its 讲解
    /// in the real picture (not just the recognized name). nil for the sample run.
    private var sourceImageData: Data?

    var hasResult: Bool { state.value != nil }

    // MARK: Entry points

    /// Recognize the subject in image data (camera / 相册 / 文件).
    func recognize(imageData: Data, source: RASource,
                   intelligence: any IntelligenceService, grade: GradeLevel) async {
        self.source = source
        self.sourceImageData = imageData
        state = .loading
        let result = await engine.recognize(imageData: imageData)
        await enrichAndPublish(result, intelligence: intelligence, grade: grade)
    }

    /// Run the deterministic 示例 (向日葵) so the flow is demoable everywhere.
    func runSample(intelligence: any IntelligenceService, grade: GradeLevel) async {
        source = .sample
        sourceImageData = nil
        state = .loading
        let result = RecognizeAnythingEngine.sampleResult()
        await enrichAndPublish(result, intelligence: intelligence, grade: grade)
    }

    func reset() {
        state = .idle
        source = .sample
        sourceImageData = nil
    }

    // MARK: Enrichment

    /// Fill in the kid-friendly 讲解 + 延伸问题, then publish to `.loaded`. The
    /// IntelligenceService is the primary source; a category-aware local writer
    /// guarantees a polished result even fully offline.
    private func enrichAndPublish(_ base: RecognitionResult,
                                  intelligence: any IntelligenceService,
                                  grade: GradeLevel) async {
        var result = base

        // Local, deterministic kid-friendly copy (always available).
        let local = RAExplanationWriter.write(for: result, grade: grade)
        result.explanation = local.explanation
        result.funFact = local.funFact
        result.relatedTopics = local.relatedTopics

        // Best-effort enrichment through the AI seam — pull a couple of
        // extension questions to mix in. Never fails the flow.
        if let enriched = try? await intelligence.explainKnowledgePoint(
            ExplainRequest(knowledgePoint: result.name,
                           subject: result.category.subject,
                           grade: grade,
                           imageData: sourceImageData)
        ) {
            // Prefer the AI's extension questions when present, keep our topical
            // chips first so the result stays focused on the recognized thing.
            let merged = (result.relatedTopics + enriched.extensionQuestions)
            result.relatedTopics = RAExplanationWriter.dedupe(merged, limit: 6)
            if result.explanation.isEmpty, let first = enriched.sections.first {
                result.explanation = first.body
            }
        }

        state = .loaded(result)
    }
}

// MARK: - Kid-friendly explanation writer

/// Deterministic, category-aware Chinese copy generator. Produces a warm "大姐姐"
/// 讲解, a 小知识, and a set of 相关知识点 / 延伸问题 chips for any recognition —
/// so the result card is always rich, even with no model and no network.
nonisolated enum RAExplanationWriter {
    struct Output: Sendable {
        var explanation: String
        var funFact: String?
        var relatedTopics: [String]
    }

    static func write(for result: RecognitionResult, grade: GradeLevel) -> Output {
        let name = result.name
        switch result.category {
        case .plant:
            return Output(
                explanation: "这是「\(name)」，属于植物。植物会进行光合作用——用阳光、水和空气里的二氧化碳，制造自己需要的养分，同时放出氧气。仔细看看它的根、茎、叶和花，每一部分都有自己的小任务哦。",
                funFact: "你知道吗？很多植物的叶子之所以是绿色的，是因为里面有一种叫「叶绿素」的小帮手。",
                relatedTopics: ["光合作用是什么？", "植物的根有什么用？", "为什么叶子是绿色的？", "种子是怎么发芽的？"]
            )
        case .animal:
            return Output(
                explanation: "这是「\(name)」，是一种动物。动物需要吃东西获得能量，会呼吸、会运动，还能感知周围的世界。不同的动物有不同的本领，想一想：它住在哪里？吃什么？怎么保护自己呢？",
                funFact: "动物可以分成有脊柱的「脊椎动物」和没有脊柱的「无脊椎动物」两大类。",
                relatedTopics: ["它是哺乳动物吗？", "它吃什么？", "它怎么保护自己？", "它生活在什么环境里？"]
            )
        case .food:
            return Output(
                explanation: "这是「\(name)」，可以吃。食物为我们的身体提供能量和营养，比如长身体需要的蛋白质、补充体力的碳水化合物，还有让身体更健康的维生素。均衡饮食，才能长得又高又壮。",
                funFact: "我们吃下的食物，要先在嘴里被牙齿嚼碎，再到胃和小肠里被慢慢消化吸收。",
                relatedTopics: ["它含有什么营养？", "它是怎么生长/制作的？", "为什么要均衡饮食？", "食物是怎么被消化的？"]
            )
        case .landmark:
            return Output(
                explanation: "这看起来像「\(name)」，是一座建筑。人们建造房屋和地标，既为了居住、生活，也为了纪念重要的事。观察它的形状、材料和高度，你能想象工程师们是怎么把它一点点造起来的吗？",
                funFact: "很多古老的建筑历经几百上千年还屹立不倒，靠的是聪明的结构设计，比如拱形和三角形。",
                relatedTopics: ["它是用什么材料建的？", "为什么三角形结构很稳？", "它有多高？", "古人是怎么盖房子的？"]
            )
        case .object:
            return Output(
                explanation: "这是「\(name)」，是一件物品。每样东西都有它的用途，也都是用某种材料做成的，比如木头、塑料、金属或玻璃。想一想：它是用来做什么的？是谁发明了它呢？",
                funFact: "同样一件物品，用不同材料做出来，重量、手感和结实程度都会不一样哦。",
                relatedTopics: ["它是用什么材料做的？", "它有什么用途？", "它是怎么被发明的？", "还有别的东西能代替它吗？"]
            )
        case .word:
            return Output(
                explanation: "这是一个英文单词「\(name)」。学英语单词时，可以一起记住它的拼写、读音和意思，再用它造一个简单的句子，这样就记得更牢啦。试着大声读一读吧！",
                funFact: "把单词放进句子里记，比单独背一个词更容易记住。",
                relatedTopics: ["这个单词怎么读？", "用它造一个句子", "它有没有近义词？", "它的复数/过去式是什么？"]
            )
        case .math:
            return Output(
                explanation: "这看起来是一道算式「\(name)」。做这类题目，先看清运算符号，记住「先乘除、后加减，有括号先算括号」的顺序，再一步一步算下去，就不容易出错啦。",
                funFact: "在数学里，运算是有先后顺序的，这个顺序叫「运算优先级」。",
                relatedTopics: ["运算顺序是什么？", "请豆包老师讲讲思路", "再出一道同类题", "怎么验算更稳妥？"]
            )
        case .scene:
            return Output(
                explanation: "这是一幅「\(name)」的画面，属于自然风景。大自然里有山川、河流、天空和云朵，它们都在不停地变化。看看画面里的天气和光线，你能猜到这是一天中的什么时候吗？",
                funFact: "云有很多种类，形状和高度不同，往往预示着不同的天气。",
                relatedTopics: ["云是怎么形成的？", "为什么天空是蓝色的？", "什么是水循环？", "山是怎么形成的？"]
            )
        case .unknown:
            return Output(
                explanation: "我还没完全看清这是什么呢。换个角度、靠近一点、让光线更亮一些，再拍一张试试看？如果是文字或算式，记得把它拍清楚、拍正哦。",
                funFact: nil,
                relatedTopics: ["换个角度再拍", "问问豆包老师", "试试示例图"]
            )
        }
    }

    /// Order-preserving de-duplication with a cap.
    static func dedupe(_ items: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for item in items {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            out.append(trimmed)
            if out.count >= limit { break }
        }
        return out
    }
}
