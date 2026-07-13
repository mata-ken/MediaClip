import Foundation
import AppKit
import Vision

/// On-device text recognition for image history items (makes them searchable)
enum OCRService {
    static let maxTextLength = 10_000

    static func recognizeText(in data: Data, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            guard let image = NSImage(data: data),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let request = VNRecognizeTextRequest { request, _ in
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
                DispatchQueue.main.async {
                    completion(text.isEmpty ? nil : String(text.prefix(maxTextLength)))
                }
            }
            request.recognitionLevel = .accurate
            request.automaticallyDetectsLanguage = true
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage)
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}
