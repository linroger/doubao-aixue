//
//  RecognizeAnythingSupport.swift
//  豆包爱学 — Features/Tools/RecognizeAnything
//
//  Supporting value types and the on-device recognition engine for 识万物
//  (F25). Everything here is pure / Sendable so it can run off the main actor
//  (Vision requests, classification) and degrade gracefully on the simulator or
//  when no real image is supplied.
//
//  Vision (`VNClassifyImageRequest` + `VNRecognizeAnimalsRequest`) provides the
//  general image labels; the OCR service provides a text path (English words /
//  math expressions). A small built-in English→Chinese lookup turns Vision's
//  English taxonomy labels into kid-friendly Chinese, and the labels are mapped
//  to a friendly subject-aware category. The IntelligenceService then turns the
//  identification into the 讲解 + 延伸问题.
//
//  Names are RA-scoped (RecognizeAnything…) so they never collide with the OCR /
//  translation helpers compiled into the same module.
//

import SwiftUI
import Vision
import ImageIO
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Category

/// A friendly bucket the recognized subject falls into. Drives the chip color,
/// icon, and which Subject we ask 豆包老师 about.
nonisolated enum RACategory: String, Sendable, CaseIterable, Hashable {
    case plant          // 植物
    case animal         // 动物
    case food           // 食物
    case landmark       // 地标/建筑
    case object         // 物品
    case word           // 英文单词
    case math           // 数学算式
    case scene          // 场景/风景
    case unknown        // 暂不确定

    var displayName: String {
        switch self {
        case .plant: "植物"
        case .animal: "动物"
        case .food: "食物"
        case .landmark: "地标建筑"
        case .object: "物品"
        case .word: "英文单词"
        case .math: "数学算式"
        case .scene: "风景场景"
        case .unknown: "待识别"
        }
    }

    var symbolName: String {
        switch self {
        case .plant: "leaf.fill"
        case .animal: "pawprint.fill"
        case .food: "fork.knife"
        case .landmark: "building.columns.fill"
        case .object: "shippingbox.fill"
        case .word: "textformat.abc"
        case .math: "function"
        case .scene: "photo.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    @MainActor var tint: Color {
        switch self {
        case .plant: DBSubjectColor.color(for: .biology)
        case .animal: DBSubjectColor.color(for: .science)
        case .food: .dbAccent
        case .landmark: DBSubjectColor.color(for: .history)
        case .object: DBSubjectColor.color(for: .general)
        case .word: DBSubjectColor.color(for: .english)
        case .math: DBSubjectColor.color(for: .math)
        case .scene: DBSubjectColor.color(for: .geography)
        case .unknown: .dbTextSecondary
        }
    }

    /// Which subject 豆包老师 should reason about for this category.
    var subject: Subject {
        switch self {
        case .plant, .animal: .biology
        case .food, .object, .scene: .science
        case .landmark: .geography
        case .word: .english
        case .math: .math
        case .unknown: .general
        }
    }
}

// MARK: - Result

/// A single Vision/OCR identification plus everything the UI needs to render the
/// result card. `explanation` / `relatedTopics` are filled in afterwards by the
/// IntelligenceService.
nonisolated struct RecognitionResult: Sendable, Hashable, Identifiable {
    let id = UUID()
    var name: String                 // 识别名称 (Chinese where possible)
    var originalLabel: String        // raw Vision/source label (for accessibility / debugging)
    var category: RACategory
    var confidence: Double           // 0...1
    var alternativeNames: [String]   // runner-up labels, Chinese
    var explanation: String          // kid-friendly 讲解
    var funFact: String?             // 小知识
    var relatedTopics: [String]      // 相关知识点 / 延伸问题 chips

    init(name: String, originalLabel: String, category: RACategory, confidence: Double,
         alternativeNames: [String] = [], explanation: String = "",
         funFact: String? = nil, relatedTopics: [String] = []) {
        self.name = name
        self.originalLabel = originalLabel
        self.category = category
        self.confidence = confidence
        self.alternativeNames = alternativeNames
        self.explanation = explanation
        self.funFact = funFact
        self.relatedTopics = relatedTopics
    }

    var confidencePercent: Int { Int((confidence * 100).rounded()) }

    var confidenceLabel: String {
        switch confidence {
        case 0.75...: "很有把握"
        case 0.5..<0.75: "比较确定"
        case 0.25..<0.5: "可能是"
        default: "不太确定"
        }
    }
}

// MARK: - Source mode (for the recognizing banner & sample)

nonisolated enum RASource: Sendable, Hashable {
    case camera, photo, file, sample
}

// MARK: - Recognition engine

/// On-device recognizer. Combines Vision general classification + animal
/// detection with an OCR text path, then maps to a friendly `RecognitionResult`
/// (without the AI 讲解, which the model fills in separately).
nonisolated struct RecognizeAnythingEngine: Sendable {
    let ocr: OCRService

    init(ocr: OCRService = OCRService()) { self.ocr = ocr }

    /// Recognize the dominant subject in image data. Always returns *something*
    /// (falls back to `.unknown` with a helpful name) so the flow never dead-ends.
    func recognize(imageData: Data) async -> RecognitionResult {
        // 1) Text path first — if the image is clearly a word / math expression,
        //    that reading is far more useful than a generic "paper" label.
        let recognizedText = await ocr.recognizeText(in: imageData)
        if let textResult = Self.interpretText(recognizedText) {
            return textResult
        }

        // 2) Animal detector (cat/dog) — high-precision, takes priority over the
        //    generic classifier when it fires.
        if let animal = await Self.detectAnimal(in: imageData) {
            return animal
        }

        // 3) General image classification.
        let labels = await Self.classify(imageData: imageData)
        if let best = labels.first {
            let mapped = LabelTranslator.map(best.identifier)
            let alts = labels.dropFirst().prefix(2).map { LabelTranslator.map($0.identifier).chinese }
            return RecognitionResult(
                name: mapped.chinese,
                originalLabel: best.identifier,
                category: mapped.category,
                confidence: Double(best.confidence),
                alternativeNames: Array(alts)
            )
        }

        // 4) Nothing recognized — graceful fallback.
        return Self.unknownResult()
    }

    /// Build a sample result for the "试试示例" flow (no image needed, fully
    /// deterministic so it works on every platform / offline).
    static func sampleResult() -> RecognitionResult {
        RecognitionResult(
            name: "向日葵",
            originalLabel: "sunflower",
            category: .plant,
            confidence: 0.94,
            alternativeNames: ["菊科植物", "花朵"]
        )
    }

    static func unknownResult() -> RecognitionResult {
        RecognitionResult(
            name: "这个东西",
            originalLabel: "unknown",
            category: .unknown,
            confidence: 0.2,
            alternativeNames: []
        )
    }

    // MARK: Text interpretation (word / math)

    /// If the recognized text looks like an English word or a math expression,
    /// turn it into a result; otherwise return nil so the visual path runs.
    static func interpretText(_ raw: String) -> RecognitionResult? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 40 else { return nil }

        // Math expression: contains operators/equals and mostly math characters.
        if Self.looksLikeMath(text) {
            return RecognitionResult(
                name: text,
                originalLabel: text,
                category: .math,
                confidence: 0.9
            )
        }

        // A single English word (letters only, no spaces) → vocabulary lens.
        let lettersOnly = text.unicodeScalars.allSatisfy {
            CharacterSet.letters.contains($0) || $0 == "-" || $0 == "'"
        }
        if lettersOnly, !text.contains(" "), text.count >= 2,
           text.unicodeScalars.allSatisfy({ $0.isASCII }) {
            return RecognitionResult(
                name: text.lowercased(),
                originalLabel: text,
                category: .word,
                confidence: 0.88
            )
        }
        return nil
    }

    static func looksLikeMath(_ text: String) -> Bool {
        let hasOperator = text.contains(where: { "+-×÷*/=".contains($0) })
        let hasDigit = text.contains(where: { $0.isNumber })
        guard hasOperator, hasDigit else { return false }
        // Reject if it's mostly letters (e.g. "a + b is..." prose).
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        return letters <= 3
    }

    // MARK: Vision

    static func classify(imageData: Data) async -> [(identifier: String, confidence: Float)] {
        guard let cgImage = makeCGImage(from: imageData) else { return [] }
        return await withCheckedContinuation { (continuation: CheckedContinuation<[(String, Float)], Never>) in
            let request = VNClassifyImageRequest { request, _ in
                let observations = request.results as? [VNClassificationObservation] ?? []
                let top = observations
                    .filter { $0.hasMinimumRecall(0.1, forPrecision: 0.5) }
                    .prefix(6)
                    .map { ($0.identifier, $0.confidence) }
                continuation.resume(returning: Array(top))
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do { try handler.perform([request]) }
            catch { continuation.resume(returning: []) }
        }
    }

    static func detectAnimal(in imageData: Data) async -> RecognitionResult? {
        guard let cgImage = makeCGImage(from: imageData) else { return nil }
        return await withCheckedContinuation { (continuation: CheckedContinuation<RecognitionResult?, Never>) in
            let request = VNRecognizeAnimalsRequest { request, _ in
                let observations = request.results as? [VNRecognizedObjectObservation] ?? []
                guard let best = observations.max(by: { $0.confidence < $1.confidence }),
                      let label = best.labels.first else {
                    continuation.resume(returning: nil); return
                }
                let mapped = LabelTranslator.map(label.identifier)
                continuation.resume(returning: RecognitionResult(
                    name: mapped.chinese,
                    originalLabel: label.identifier,
                    category: .animal,
                    confidence: Double(best.confidence)
                ))
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do { try handler.perform([request]) }
            catch { continuation.resume(returning: nil) }
        }
    }

    static func makeCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

// MARK: - Label translation

/// Maps Vision's English taxonomy identifiers to a friendly Chinese name and a
/// category. Vision identifiers are lowercase, often hierarchical
/// (e.g. "plant", "fruit", "domestic_cat"). We look up the most specific token
/// we know, classify by keyword, and always degrade to a readable fallback.
nonisolated enum LabelTranslator {
    struct Mapped: Sendable, Hashable {
        var chinese: String
        var category: RACategory
    }

    static func map(_ identifier: String) -> Mapped {
        let key = identifier.lowercased()
        let tokens = key.split(whereSeparator: { $0 == "_" || $0 == " " || $0 == "-" }).map(String.init)

        // Most-specific token first.
        for token in tokens.reversed() {
            if let known = dictionary[token] {
                return known
            }
        }
        // Whole-identifier exact match.
        if let known = dictionary[key] {
            return known
        }
        // Keyword-based category inference + a humanized name.
        let category = inferCategory(tokens: tokens, key: key)
        return Mapped(chinese: humanize(identifier), category: category)
    }

    static func inferCategory(tokens: [String], key: String) -> RACategory {
        let plantWords: Set<String> = ["plant", "flower", "tree", "leaf", "grass", "fruit", "vegetable", "flora", "bloom"]
        let animalWords: Set<String> = ["animal", "mammal", "bird", "fish", "insect", "reptile", "fauna", "pet"]
        let foodWords: Set<String> = ["food", "dish", "meal", "snack", "dessert", "bread", "drink", "beverage", "cuisine"]
        let landmarkWords: Set<String> = ["building", "architecture", "tower", "bridge", "monument", "structure", "temple", "church"]
        let sceneWords: Set<String> = ["landscape", "mountain", "sky", "beach", "outdoor", "nature", "scenery", "sunset", "cloud"]

        let set = Set(tokens)
        if !set.isDisjoint(with: plantWords) { return .plant }
        if !set.isDisjoint(with: animalWords) { return .animal }
        if !set.isDisjoint(with: foodWords) { return .food }
        if !set.isDisjoint(with: landmarkWords) { return .landmark }
        if !set.isDisjoint(with: sceneWords) { return .scene }
        return .object
    }

    /// Turn an identifier like "domestic_cat" into "Domestic cat" for display
    /// when we have no Chinese mapping.
    static func humanize(_ identifier: String) -> String {
        let spaced = identifier.replacingOccurrences(of: "_", with: " ")
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }

    /// Compact built-in lookup covering the most common K12-relevant labels.
    static let dictionary: [String: Mapped] = [
        // Plants / flowers / fruit
        "plant": .init(chinese: "植物", category: .plant),
        "flower": .init(chinese: "花朵", category: .plant),
        "rose": .init(chinese: "玫瑰", category: .plant),
        "sunflower": .init(chinese: "向日葵", category: .plant),
        "tulip": .init(chinese: "郁金香", category: .plant),
        "tree": .init(chinese: "树", category: .plant),
        "bamboo": .init(chinese: "竹子", category: .plant),
        "leaf": .init(chinese: "叶子", category: .plant),
        "grass": .init(chinese: "草", category: .plant),
        "cactus": .init(chinese: "仙人掌", category: .plant),
        "mushroom": .init(chinese: "蘑菇", category: .plant),
        "fruit": .init(chinese: "水果", category: .food),
        "apple": .init(chinese: "苹果", category: .food),
        "banana": .init(chinese: "香蕉", category: .food),
        "orange": .init(chinese: "橙子", category: .food),
        "strawberry": .init(chinese: "草莓", category: .food),
        "grape": .init(chinese: "葡萄", category: .food),
        "watermelon": .init(chinese: "西瓜", category: .food),
        // Animals
        "animal": .init(chinese: "动物", category: .animal),
        "cat": .init(chinese: "猫", category: .animal),
        "domestic cat": .init(chinese: "猫", category: .animal),
        "kitten": .init(chinese: "小猫", category: .animal),
        "dog": .init(chinese: "狗", category: .animal),
        "puppy": .init(chinese: "小狗", category: .animal),
        "bird": .init(chinese: "鸟", category: .animal),
        "fish": .init(chinese: "鱼", category: .animal),
        "horse": .init(chinese: "马", category: .animal),
        "rabbit": .init(chinese: "兔子", category: .animal),
        "panda": .init(chinese: "熊猫", category: .animal),
        "bear": .init(chinese: "熊", category: .animal),
        "elephant": .init(chinese: "大象", category: .animal),
        "tiger": .init(chinese: "老虎", category: .animal),
        "lion": .init(chinese: "狮子", category: .animal),
        "butterfly": .init(chinese: "蝴蝶", category: .animal),
        "bee": .init(chinese: "蜜蜂", category: .animal),
        "insect": .init(chinese: "昆虫", category: .animal),
        // Food / dishes
        "food": .init(chinese: "食物", category: .food),
        "bread": .init(chinese: "面包", category: .food),
        "cake": .init(chinese: "蛋糕", category: .food),
        "rice": .init(chinese: "米饭", category: .food),
        "noodle": .init(chinese: "面条", category: .food),
        "pizza": .init(chinese: "披萨", category: .food),
        "egg": .init(chinese: "鸡蛋", category: .food),
        "milk": .init(chinese: "牛奶", category: .food),
        // Landmarks / buildings
        "building": .init(chinese: "建筑物", category: .landmark),
        "architecture": .init(chinese: "建筑", category: .landmark),
        "tower": .init(chinese: "塔", category: .landmark),
        "bridge": .init(chinese: "桥", category: .landmark),
        "temple": .init(chinese: "庙宇", category: .landmark),
        "house": .init(chinese: "房屋", category: .landmark),
        // Objects
        "book": .init(chinese: "书", category: .object),
        "pen": .init(chinese: "笔", category: .object),
        "pencil": .init(chinese: "铅笔", category: .object),
        "clock": .init(chinese: "时钟", category: .object),
        "chair": .init(chinese: "椅子", category: .object),
        "table": .init(chinese: "桌子", category: .object),
        "cup": .init(chinese: "杯子", category: .object),
        "bottle": .init(chinese: "瓶子", category: .object),
        "ball": .init(chinese: "球", category: .object),
        "toy": .init(chinese: "玩具", category: .object),
        "computer": .init(chinese: "电脑", category: .object),
        "phone": .init(chinese: "手机", category: .object),
        "car": .init(chinese: "汽车", category: .object),
        "bicycle": .init(chinese: "自行车", category: .object),
        "umbrella": .init(chinese: "雨伞", category: .object),
        // Scenes
        "landscape": .init(chinese: "风景", category: .scene),
        "mountain": .init(chinese: "山", category: .scene),
        "sky": .init(chinese: "天空", category: .scene),
        "cloud": .init(chinese: "云", category: .scene),
        "beach": .init(chinese: "海滩", category: .scene),
        "sunset": .init(chinese: "日落", category: .scene),
        "sea": .init(chinese: "大海", category: .scene),
        "river": .init(chinese: "河流", category: .scene),
        "flower garden": .init(chinese: "花园", category: .scene),
    ]
}

// MARK: - Platform image input

extension Data {
    /// Load image bytes from a security-scoped file URL (file importer). Scoped
    /// to RecognizeAnything to avoid colliding with the reading-scoped helper.
    static func recognizeImage(from url: URL) -> Data? {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }
}

#if canImport(UIKit) && os(iOS)
/// A camera capture sheet wrapping `UIImagePickerController` (iOS only). Falls
/// back to the photo library on devices/simulators without a camera. RA-scoped
/// to avoid colliding with the reading camera picker compiled in the same module.
struct RecognizeCameraPicker: UIViewControllerRepresentable {
    var onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: RecognizeCameraPicker
        init(_ parent: RecognizeCameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.85) {
                parent.onCapture(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
