//
//  SolveScanSupport.swift
//  豆包爱学 — Features/Solve
//
//  Platform-guarded scanning + image plumbing for 拍照解题. iOS exposes a VisionKit
//  live text scanner (`DataScannerViewController`) so learners can hover over a
//  problem and tap to pick exactly the line(s) they want — the recognized text then
//  flows straight into the existing solve pipeline. macOS has no live scanner, so it
//  degrades to a Continuity Camera / file import helper that yields raw image `Data`
//  for the OCR service. Nothing here computes a solution; these views only surface
//  recognized text or image bytes back to the caller.
//

import SwiftUI
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics

#if os(iOS) && canImport(VisionKit)
import VisionKit
import UIKit

// MARK: - Live document/text scanner (iOS, VisionKit)

/// Wraps `DataScannerViewController` for live, on-device text recognition. Highlights
/// recognized text and lets the learner tap a specific item to capture just that line
/// (tap-to-pick-region), or pull every recognized line via the "全部识别" affordance in
/// the hosting view. Availability is gated by `SolveLiveScanAvailability` so the
/// caller can degrade gracefully when the device lacks the Neural Engine / camera.
@available(iOS 16.0, *)
struct SolveDataScanner: UIViewControllerRepresentable {
    /// Called when the learner taps a highlighted item — carries just that text.
    var onTapItem: (String) -> Void
    /// Called with the union of all currently-recognized lines (for "全部识别").
    var onRecognizedTextChanged: ([String]) -> Void
    /// Bound to trigger a one-shot "capture everything" from the parent toolbar.
    @Binding var captureAllToken: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        // Start scanning lazily; `try?` because start can throw if not available.
        if !context.coordinator.isScanning {
            try? controller.startScanning()
            context.coordinator.isScanning = true
        }
        // Honor a one-shot "capture all" request from the parent.
        if context.coordinator.lastCaptureToken != captureAllToken {
            context.coordinator.lastCaptureToken = captureAllToken
            context.coordinator.emitAllRecognized(from: controller)
        }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
        coordinator.isScanning = false
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: SolveDataScanner
        var isScanning = false
        var lastCaptureToken = 0
        /// The most recent full set of recognized items, tracked from the delegate
        /// callbacks (DataScannerViewController exposes no synchronous accessor).
        private var latestItems: [RecognizedItem] = []

        init(_ parent: SolveDataScanner) {
            self.parent = parent
            self.lastCaptureToken = parent.captureAllToken
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case let .text(text) = item {
                parent.onTapItem(text.transcript)
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            emit(allItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didRemove removedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            emit(allItems)
        }

        func emitAllRecognized(from controller: DataScannerViewController) {
            emit(latestItems)
        }

        private func emit(_ items: [RecognizedItem]) {
            latestItems = items
            let lines: [String] = items.compactMap { item in
                if case let .text(text) = item { return text.transcript }
                return nil
            }
            parent.onRecognizedTextChanged(lines)
        }
    }
}
#endif

// MARK: - Availability probe (cross-platform)

/// Cross-platform availability probe for the live scanner. On iOS it reflects
/// `DataScannerViewController.isSupported && .isAvailable`; everywhere else it is
/// `false` so the UI presents the import/typed fallbacks instead.
enum SolveLiveScanAvailability {
    static var isSupported: Bool {
        #if os(iOS) && canImport(VisionKit)
        if #available(iOS 16.0, *) {
            return DataScannerViewController.isSupported && DataScannerViewController.isAvailable
        }
        return false
        #else
        return false
        #endif
    }
}

// MARK: - Continuity Camera / file import (macOS)

#if os(macOS)
import AppKit

/// Imports an image on macOS, preferring Continuity Camera ("用 iPhone 拍照"/"扫描文稿")
/// when a paired device is nearby and falling back to a standard open panel. The
/// `NSOpenPanel` exposes Continuity Camera entries automatically via its accessory
/// menu on macOS 13+, so a single panel covers both paths. Returns raw image `Data`.
enum SolveContinuityCamera {
    @MainActor
    static func importImage() -> Data? {
        let panel = NSOpenPanel()
        panel.message = "选择图片，或用相机连续互通从 iPhone 拍照/扫描"
        panel.prompt = "使用"
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .pdf, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }
}
#endif

// MARK: - Cross-platform image helpers

extension Image {
    /// Build a SwiftUI `Image` from raw bytes, platform-guarded. Returns nil when the
    /// data is not a decodable image so callers can hide the preview gracefully.
    static func fromSolveScanData(_ data: Data) -> Image? {
        #if canImport(UIKit)
        guard let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
        #elseif canImport(AppKit)
        guard let ns = NSImage(data: data) else { return nil }
        return Image(nsImage: ns)
        #else
        return nil
        #endif
    }
}

/// Pure-data helpers for cropping image bytes to a normalized rectangle. Marked
/// `nonisolated` because they touch no UI state and may run off the main actor.
nonisolated enum SolveImageCrop {
    /// Crop `imageData` to the normalized rect (origin top-left, values in 0…1) and
    /// return re-encoded bytes. Returns the original data if decoding/cropping fails so
    /// the caller always has something usable for OCR.
    static func crop(_ imageData: Data, to normalized: CGRect) -> Data {
        guard let cg = makeCGImage(from: imageData) else { return imageData }
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        let clamped = normalized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !clamped.isNull, clamped.width > 0.01, clamped.height > 0.01 else { return imageData }
        let pixelRect = CGRect(
            x: (clamped.minX * w).rounded(.down),
            y: (clamped.minY * h).rounded(.down),
            width: (clamped.width * w).rounded(.down),
            height: (clamped.height * h).rounded(.down)
        )
        guard pixelRect.width >= 1, pixelRect.height >= 1,
              let cropped = cg.cropping(to: pixelRect) else { return imageData }
        return encodePNG(cropped) ?? imageData
    }

    private static func makeCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func encodePNG(_ image: CGImage) -> Data? {
        let mutable = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            mutable as CFMutableData, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutable as Data
    }
}
