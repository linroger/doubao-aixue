//
//  WorkbookImageInput.swift
//  豆包爱学 — Features/Workbook
//
//  Platform-guarded page capture for 作业批改. Three acquisition paths, exactly as
//  the product asks: take a photo with the camera (iOS, UIImagePickerController),
//  pick a previously-taken photo (Photos), or upload a file (file importer — the
//  primary path on macOS). Each yields raw JPEG/PNG `Data` for the OCR pre-pass and
//  the vision model. No view here grades anything — they only hand image bytes back.
//
//  Names are Workbook-scoped (Workbook…) so they never collide with the 口算 /
//  作文 / 识万物 image helpers compiled into the same module.
//

import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit

/// A camera capture sheet wrapping `UIImagePickerController` (iOS only). Defaults to
/// the camera; gracefully falls back to the photo library on devices/simulators
/// without a camera so the flow never dead-ends.
struct WorkbookCameraPicker: UIViewControllerRepresentable {
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
        let parent: WorkbookCameraPicker
        init(_ parent: WorkbookCameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = WorkbookImagePrep.normalizedJPEG(from: image) {
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

// MARK: - Image preparation

/// Downscales + re-encodes a captured image so uploads stay small (vision APIs and
/// SwiftData external storage both prefer a bounded payload). Pure, no UI.
enum WorkbookImagePrep {
    /// Cap the long edge so a full-resolution camera shot doesn't bloat the request.
    static let maxDimension: CGFloat = 1600

    #if canImport(UIKit)
    static func normalizedJPEG(from image: UIImage, quality: CGFloat = 0.8) -> Data? {
        let resized = resize(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality)
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
    #endif

    #if os(macOS)
    static func normalizedJPEG(from data: Data, quality: CGFloat = 0.8) -> Data? {
        guard let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return data }
        let props: [NSBitmapImageRep.PropertyKey: Any] = [.compressionFactor: quality]
        return rep.representation(using: .jpeg, properties: props) ?? data
    }
    #endif
}

// MARK: - File / display helpers

extension Data {
    /// Load image bytes from a security-scoped file URL (file importer / open panel).
    static func workbookImage(from url: URL) -> Data? {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }
}

extension Image {
    /// Build a SwiftUI `Image` from raw bytes, platform-guarded. Returns nil for
    /// undecodable data so callers can hide the preview gracefully.
    static func fromWorkbookData(_ data: Data) -> Image? {
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
