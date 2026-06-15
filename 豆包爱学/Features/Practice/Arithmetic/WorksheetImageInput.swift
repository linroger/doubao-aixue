//
//  WorksheetImageInput.swift
//  豆包爱学 — Features/Practice/Arithmetic
//
//  Platform-guarded image acquisition for 口算批改. iOS exposes a camera capture
//  sheet (UIImagePickerController) and a Photos picker; macOS falls back to a file
//  importer. Each path yields raw `Data` for the OCR service. No view here computes
//  arithmetic — they just hand image bytes back to the caller.
//

import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit

/// A camera capture sheet wrapping `UIImagePickerController` (iOS only).
struct WorksheetCameraPicker: UIViewControllerRepresentable {
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
        let parent: WorksheetCameraPicker
        init(_ parent: WorksheetCameraPicker) { self.parent = parent }

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

extension Image {
    /// Build a SwiftUI `Image` from raw bytes, platform-guarded. Returns nil when the
    /// data is not a decodable image so callers can hide the preview gracefully.
    static func fromWorksheetData(_ data: Data) -> Image? {
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

extension Data {
    /// Load image bytes from a security-scoped file URL (macOS file importer).
    static func worksheetImage(from url: URL) -> Data? {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }
}
