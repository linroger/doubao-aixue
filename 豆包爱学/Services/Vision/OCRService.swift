//
//  OCRService.swift
//  豆包爱学
//
//  On-device text recognition (Vision) with a graceful fallback. Used by the
//  solve, grading, translation, and document flows. When no real image is
//  supplied (e.g. simulator demo) callers fall back to sample/typed text.
//

import Foundation
import Vision
import ImageIO

public nonisolated struct OCRService: Sendable {
    public init() {}

    public var isAvailable: Bool { true }

    /// Recognize lines of text in image data using on-device Vision.
    public func recognizeLines(in imageData: Data) async -> [String] {
        guard let cgImage = Self.makeCGImage(from: imageData) else { return [] }
        return await withCheckedContinuation { (continuation: CheckedContinuation<[String], Never>) in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do { try handler.perform([request]) }
            catch { continuation.resume(returning: []) }
        }
    }

    /// Recognize text and join into a single block.
    public func recognizeText(in imageData: Data) async -> String {
        await recognizeLines(in: imageData).joined(separator: "\n")
    }

    /// Parse arithmetic items (one per line) from a graded worksheet image.
    public func recognizeArithmeticItems(in imageData: Data) async -> [ArithmeticItem] {
        let lines = await recognizeLines(in: imageData)
        return Self.parseArithmeticLines(lines)
    }

    /// Split recognized lines like "12 + 7 = 19" into expression + student answer.
    public static func parseArithmeticLines(_ lines: [String]) -> [ArithmeticItem] {
        lines.compactMap { line in
            let parts = line.components(separatedBy: "=")
            guard parts.count == 2 else { return nil }
            let expr = parts[0].trimmingCharacters(in: .whitespaces)
            let ans = parts[1].trimmingCharacters(in: .whitespaces)
            guard !expr.isEmpty else { return nil }
            return ArithmeticItem(expression: expr, studentAnswer: ans)
        }
    }

    private static func makeCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

// MARK: - Environment

import SwiftUI

private struct OCRServiceKey: EnvironmentKey {
    static let defaultValue = OCRService()
}
public extension EnvironmentValues {
    var ocr: OCRService {
        get { self[OCRServiceKey.self] }
        set { self[OCRServiceKey.self] = newValue }
    }
}
