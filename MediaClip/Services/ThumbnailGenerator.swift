import Foundation
import AppKit
import AVFoundation

enum ThumbnailGenerator {
    static let maxThumbnailSize: CGFloat = 200

    static func generateImageThumbnail(from data: Data) -> Data? {
        guard let image = NSImage(data: data) else { return nil }

        let originalSize = image.size
        let scale = min(maxThumbnailSize / originalSize.width, maxThumbnailSize / originalSize.height, 1.0)
        let newSize = NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        thumbnail.unlockFocus()

        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else { return nil }

        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    }

    static func generateVideoThumbnail(from url: URL) -> Data? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxThumbnailSize * 2, height: maxThumbnailSize * 2)

        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

            guard let tiffData = image.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData) else { return nil }

            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
        } catch {
            print("Failed to generate video thumbnail: \(error)")
            return nil
        }
    }
}
