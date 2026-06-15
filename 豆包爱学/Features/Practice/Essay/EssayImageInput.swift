//
//  EssayImageInput.swift
//  豆包爱学 — Features/Practice/Essay
//
//  Platform-guarded page capture for 作文批改 (拍照识别). iOS exposes a camera
//  sheet (UIImagePickerController); both platforms can pick from Photos, and macOS
//  additionally imports a file. Each path yields raw `Data` for the OCR service —
//  no view here recognises text, they just hand image bytes to the caller.
//
//  Names are essay-scoped (Essay…) so they never collide with the口算 worksheet
//  helpers compiled into the same module.
//

import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit

/// A camera capture sheet wrapping `UIImagePickerController` (iOS only). Falls
/// back to the photo library on devices/simulators without a camera.
struct EssayCameraPicker: UIViewControllerRepresentable {
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
        let parent: EssayCameraPicker
        init(_ parent: EssayCameraPicker) { self.parent = parent }

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

extension Data {
    /// Load image bytes from a security-scoped file URL (macOS file importer).
    static func essayImage(from url: URL) -> Data? {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }
}

extension String {
    /// Read a plain-text essay from a security-scoped file URL. Returns `nil` for
    /// non-text files so the caller can fall through to the OCR (image) path.
    static func essayText(from url: URL) -> String? {
        guard ["txt", "text", "md"].contains(url.pathExtension.lowercased()) else { return nil }
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
