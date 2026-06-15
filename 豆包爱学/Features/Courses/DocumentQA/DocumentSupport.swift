//
//  DocumentSupport.swift
//  豆包爱学 — Features/Courses/DocumentQA
//
//  Value helpers for 文档问答: a cross-platform document parser (PDFKit + plain
//  text), a bundled 示例文档 builder sourced from the offline ContentCatalog, and
//  small presentation helpers (icon / label per file type). Kept free of UI so
//  it stays trivially testable; SwiftUI-returning helpers live in the views.
//

import Foundation
import PDFKit

// MARK: - Parsed document value

/// A pure snapshot produced by parsing an imported file or building the sample.
/// Sendable so it can cross the import callback / Task boundary safely.
nonisolated struct ParsedDocument: Sendable, Hashable {
    var title: String
    var fileType: String
    var pageCount: Int
    var text: String
}

// MARK: - Parse error

/// A friendly, Chinese-first document-parse failure. `ExpressibleByStringLiteral`
/// so parser code can `return .failure("…")` directly, while still being a real
/// `Error` (required for `Result`'s failure type) whose `message` the UI shows.
nonisolated struct DocumentParseError: Error, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    init(stringLiteral value: String) { self.message = value }
    var description: String { message }
    var localizedDescription: String { message }
}

// MARK: - Parser

/// Cross-platform extraction of readable text from an imported file URL. PDFKit
/// is available on both iOS 26 and macOS 26, so no platform guards are needed.
nonisolated enum DocumentParser {

    /// Parse the file at `url`, returning the extracted text or a friendly,
    /// Chinese-first failure message.
    static func parse(url: URL) -> Result<ParsedDocument, DocumentParseError> {
        // Security-scoped access is required for files chosen via the importer.
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let title = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.lowercased()

        if ext == "pdf" {
            guard let pdf = PDFDocument(url: url) else {
                return .failure("无法读取这份 PDF，换一份文件试试吧。")
            }
            var pieces: [String] = []
            for index in 0..<pdf.pageCount {
                if let page = pdf.page(at: index), let content = page.string {
                    pieces.append(content)
                }
            }
            let text = pieces.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return .failure("这份 PDF 似乎是扫描件，暂时无法提取文字。")
            }
            return .success(ParsedDocument(
                title: title.isEmpty ? "未命名文档" : title,
                fileType: "pdf",
                pageCount: max(1, pdf.pageCount),
                text: text
            ))
        }

        // Plain / UTF-8 text.
        let raw: String?
        if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
            raw = utf8
        } else {
            raw = try? String(contentsOf: url, encoding: .utf16)
        }
        guard let content = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            return .failure("无法读取这份文本文件，换一份试试吧。")
        }
        return .success(ParsedDocument(
            title: title.isEmpty ? "未命名文档" : title,
            fileType: "txt",
            pageCount: 1,
            text: content
        ))
    }

    /// A rich, offline 示例文档 assembled from the bundled poetry catalog so the
    /// learner can try summary + Q&A without importing anything.
    static func sampleDocument() -> ParsedDocument {
        let poems = ContentCatalog.poems
        var lines: [String] = ["《中华经典古诗词赏析》"]
        lines.append("本文档精选数首经典古诗词，附上译文与赏析，帮助同学们理解诗词大意、体会作者情感。")
        for poem in poems.prefix(4) {
            lines.append("")
            lines.append("【\(poem.title)】（\(poem.dynasty) · \(poem.author)）")
            lines.append("原文：\(poem.original.replacingOccurrences(of: "\n", with: " "))")
            lines.append("译文：\(poem.translation)")
            lines.append("赏析：\(poem.appreciation)")
        }
        let text = lines.joined(separator: "\n")
        return ParsedDocument(
            title: "中华经典古诗词赏析（示例）",
            fileType: "txt",
            pageCount: max(1, poems.prefix(4).count),
            text: text
        )
    }
}

// MARK: - Presentation helpers

nonisolated enum DocumentPresentation {
    static func symbol(forFileType fileType: String) -> String {
        switch fileType.lowercased() {
        case "pdf": "doc.richtext.fill"
        default: "doc.text.fill"
        }
    }

    static func typeLabel(forFileType fileType: String) -> String {
        switch fileType.lowercased() {
        case "pdf": "PDF"
        case "txt", "text": "文本"
        default: fileType.uppercased()
        }
    }

    /// Split parsed document text into readable paragraphs for selectable display.
    static func paragraphs(in text: String) -> [String] {
        text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
