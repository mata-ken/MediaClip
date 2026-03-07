import Foundation
import AppKit
import Combine

final class ClipboardMonitor: ObservableObject {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var selfChangeMarker = false

    static let sourceMarkerType = NSPasteboard.PasteboardType("com.mediaclip.source")

    func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func markSelfChange() {
        selfChangeMarker = true
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if selfChangeMarker {
            selfChangeMarker = false
            return
        }

        // Check excluded apps
        let settings = UserSettings.shared
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleID = frontApp.bundleIdentifier,
           settings.excludedAppBundleIDs.contains(bundleID) {
            return
        }

        if let item = detectAndCreateItem(from: pasteboard) {
            // Handle duplicates
            if settings.handleDuplicates {
                if let existing = findDuplicate(for: item) {
                    StorageManager.shared.deleteClipboardItem(existing)
                }
            }

            StorageManager.shared.addClipboardItem(item)
        }
    }

    private func findDuplicate(for newItem: ClipboardItem) -> ClipboardItem? {
        let items = StorageManager.shared.clipboardItems
        switch newItem.contentType {
        case .plainText, .richText:
            guard let newText = newItem.textContent else { return nil }
            return items.first { $0.contentType == newItem.contentType && $0.textContent == newText }
        default:
            return nil
        }
    }

    private func detectAndCreateItem(from pasteboard: NSPasteboard) -> ClipboardItem? {
        let settings = UserSettings.shared

        // Priority: fileURL -> image -> richText -> plainText

        // Check for file URLs (video/image files)
        if settings.supportFilenames || settings.supportImages {
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
               let url = urls.first {
                let videoExtensions = ["mov", "mp4", "m4v", "avi", "mkv"]
                if settings.supportImages && videoExtensions.contains(url.pathExtension.lowercased()) {
                    if let path = StorageManager.shared.saveVideoFile(from: url) {
                        var thumbName: String?
                        if let thumbData = ThumbnailGenerator.generateVideoThumbnail(from: URL(fileURLWithPath: path)) {
                            thumbName = StorageManager.shared.saveThumbnailData(thumbData)
                        }
                        return ClipboardItem(
                            contentType: .video,
                            mediaFilePath: path,
                            thumbnailFileName: thumbName
                        )
                    }
                }

                let imageExtensions = ["png", "jpg", "jpeg", "tiff", "gif", "bmp", "heic"]
                if settings.supportImages && imageExtensions.contains(url.pathExtension.lowercased()) {
                    if let data = try? Data(contentsOf: url) {
                        let imageName = StorageManager.shared.saveImageData(data)
                        var thumbName: String?
                        if let thumbData = ThumbnailGenerator.generateImageThumbnail(from: data) {
                            thumbName = StorageManager.shared.saveThumbnailData(thumbData)
                        }
                        return ClipboardItem(
                            contentType: .image,
                            imageFileName: imageName,
                            thumbnailFileName: thumbName
                        )
                    }
                }
            }
        }

        // Check for image data (screenshots)
        if settings.supportImages && settings.saveScreenshots {
            let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
            for imageType in imageTypes {
                if let data = pasteboard.data(forType: imageType) {
                    let imageName = StorageManager.shared.saveImageData(data)
                    var thumbName: String?
                    if let thumbData = ThumbnailGenerator.generateImageThumbnail(from: data) {
                        thumbName = StorageManager.shared.saveThumbnailData(thumbData)
                    }
                    return ClipboardItem(
                        contentType: .image,
                        imageFileName: imageName,
                        thumbnailFileName: thumbName
                    )
                }
            }
        }

        // Rich text
        if settings.supportRichText {
            if let rtfData = pasteboard.data(forType: .rtf),
               let attrStr = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                let text = attrStr.string
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return ClipboardItem(contentType: .richText, textContent: text)
                }
            }
        }

        // Plain text
        if settings.supportPlainText {
            if let text = pasteboard.string(forType: .string),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ClipboardItem(contentType: .plainText, textContent: text)
            }
        }

        return nil
    }
}
