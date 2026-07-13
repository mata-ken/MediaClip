import Foundation
import AppKit
import Combine
import CryptoKit

final class ClipboardMonitor: ObservableObject {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var selfChangeMarker = false

    static let sourceMarkerType = NSPasteboard.PasteboardType("com.mediaclip.source")

    /// Pasteboard marker types that indicate transient data (never record)
    private static let transientTypes: Set<String> = [
        "org.nspasteboard.TransientType",
        "de.petermaurer.TransientPasteboardType",
        "com.typeit4me.clipping",
        "Pasteboard generator type",
    ]

    /// Pasteboard marker types for confidential data (password managers)
    private static let concealedTypes: Set<String> = [
        "org.nspasteboard.ConcealedType",
        "com.agilebits.onepassword",
    ]

    /// Universal Clipboard (Handoff) marker - file URLs from other devices are unusable
    private static let remoteClipboardType = "com.apple.is-remote-clipboard"

    private static let videoExtensions: Set<String> = ["mov", "mp4", "m4v", "avi", "mkv"]
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "tiff", "gif", "bmp", "heic", "webp"]

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

    func unmarkSelfChange() {
        selfChangeMarker = false
    }

    /// Add image data to history directly (e.g. from the screenshot file watcher)
    func ingestImageData(_ data: Data) {
        addImageItem(data: data)
    }

    // MARK: - Polling

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

        processPasteboard(pasteboard, settings: settings)
    }

    // MARK: - Detection

    private func processPasteboard(_ pasteboard: NSPasteboard, settings: UserSettings) {
        let rawTypes = Set((pasteboard.types ?? []).map(\.rawValue))

        // Security: never record transient data; skip concealed (password manager) data if enabled
        if !rawTypes.isDisjoint(with: Self.transientTypes) { return }
        if settings.ignoreConcealedTypes && !rawTypes.isDisjoint(with: Self.concealedTypes) { return }

        let isRemoteClipboard = rawTypes.contains(Self.remoteClipboardType)

        // Priority: fileURL -> image data -> PDF data -> URL -> richText -> plainText

        // 1. File URLs (image/video/pdf/general files) - unreliable for Universal Clipboard
        if !isRemoteClipboard,
           let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           !urls.isEmpty, urls.allSatisfy({ $0.isFileURL }) {
            if handleFileURLs(urls, settings: settings) { return }
        }

        // 2. Raw image data (e.g. clipboard screenshots, copied bitmap)
        if settings.supportImages && settings.saveScreenshots {
            for imageType in [NSPasteboard.PasteboardType.png, .tiff] {
                if let data = pasteboard.data(forType: imageType) {
                    addImageItem(data: data)
                    return
                }
            }
        }

        // 3. PDF data
        if settings.supportPDF, let data = pasteboard.data(forType: .pdf) {
            let hash = Self.sha256(data)
            dedupOrInsert(hash: hash) {
                let name = StorageManager.shared.savePDFData(data)
                return ClipboardItem(contentType: .pdf, pdfFileName: name, contentHash: hash)
            }
            return
        }

        // 4. Web URL
        if settings.supportURL, let urlString = webURLString(from: pasteboard) {
            let hash = Self.sha256("url:" + urlString)
            dedupOrInsert(hash: hash, textFallback: urlString, textType: .url) {
                ClipboardItem(contentType: .url, textContent: urlString, contentHash: hash)
            }
            return
        }

        // 5. Rich text (preserve RTF data for format-keeping paste)
        if settings.supportRichText {
            var rtfData = pasteboard.data(forType: .rtf)
            if rtfData == nil,
               let rtfdData = pasteboard.data(forType: .rtfd),
               let attr = NSAttributedString(rtfd: rtfdData, documentAttributes: nil) {
                rtfData = attr.rtf(from: NSRange(location: 0, length: attr.length), documentAttributes: [:])
            }
            if let rtfData,
               let attrStr = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                let text = attrStr.string
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let hash = Self.sha256("rtf:" + text)
                    dedupOrInsert(hash: hash, textFallback: text, textType: .richText) {
                        let rtfName = StorageManager.shared.saveRTFData(rtfData)
                        return ClipboardItem(contentType: .richText, textContent: text, rtfFileName: rtfName, contentHash: hash)
                    }
                    return
                }
            }
        }

        // 6. Plain text
        if settings.supportPlainText,
           let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let hash = Self.sha256("text:" + text)
            dedupOrInsert(hash: hash, textFallback: text, textType: .plainText) {
                ClipboardItem(contentType: .plainText, textContent: text, contentHash: hash)
            }
        }
    }

    /// Handle copied file URLs. Returns true if the pasteboard content was consumed.
    private func handleFileURLs(_ urls: [URL], settings: UserSettings) -> Bool {
        if urls.count == 1 {
            let url = urls[0]
            let ext = url.pathExtension.lowercased()

            // Video file
            if settings.supportImages && Self.videoExtensions.contains(ext) {
                if let path = StorageManager.shared.saveVideoFile(from: url) {
                    let hash = Self.sha256("video:" + path)
                    dedupOrInsert(hash: hash) {
                        var thumbName: String?
                        if let thumbData = ThumbnailGenerator.generateVideoThumbnail(from: URL(fileURLWithPath: path)) {
                            thumbName = StorageManager.shared.saveThumbnailData(thumbData)
                        }
                        return ClipboardItem(
                            contentType: .video,
                            mediaFilePath: path,
                            thumbnailFileName: thumbName,
                            contentHash: hash
                        )
                    }
                    return true
                }
            }

            // Image file
            if settings.supportImages && Self.imageExtensions.contains(ext) {
                if let data = try? Data(contentsOf: url) {
                    addImageItem(data: data)
                    return true
                }
            }

            // PDF file
            if settings.supportPDF && ext == "pdf" {
                if let data = try? Data(contentsOf: url) {
                    let hash = Self.sha256(data)
                    dedupOrInsert(hash: hash) {
                        let name = StorageManager.shared.savePDFData(data)
                        return ClipboardItem(
                            contentType: .pdf,
                            textContent: url.lastPathComponent,
                            pdfFileName: name,
                            contentHash: hash
                        )
                    }
                    return true
                }
            }
        }

        // General files (single or multiple) - store paths only, no copy
        if settings.supportFilenames {
            let paths = urls.map(\.path)
            let hash = Self.sha256("files:" + paths.joined(separator: "\n"))
            dedupOrInsert(hash: hash) {
                ClipboardItem(contentType: .file, filePaths: paths, contentHash: hash)
            }
            return true
        }

        return false
    }

    private func addImageItem(data: Data) {
        let hash = Self.sha256(data)
        dedupOrInsert(hash: hash) {
            let imageName = StorageManager.shared.saveImageData(data)
            var thumbName: String?
            if let thumbData = ThumbnailGenerator.generateImageThumbnail(from: data) {
                thumbName = StorageManager.shared.saveThumbnailData(thumbData)
            }
            return ClipboardItem(
                contentType: .image,
                imageFileName: imageName,
                thumbnailFileName: thumbName,
                contentHash: hash
            )
        }
    }

    /// Extract a web URL string if the pasteboard holds one (public.url or a bare URL string)
    private func webURLString(from pasteboard: NSPasteboard) -> String? {
        if let urlString = pasteboard.string(forType: .URL),
           let url = URL(string: urlString),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return urlString
        }
        if let text = pasteboard.string(forType: .string) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.contains(where: { $0.isWhitespace || $0.isNewline }),
                  trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://"),
                  URL(string: trimmed) != nil else { return nil }
            return trimmed
        }
        return nil
    }

    // MARK: - Dedup

    /// Insert a new item, or move the existing duplicate to the top instead.
    /// `create` is only executed (and its file side-effects only happen) when the content is new.
    private func dedupOrInsert(
        hash: String,
        textFallback: String? = nil,
        textType: ContentType? = nil,
        create: () -> ClipboardItem?
    ) {
        let storage = StorageManager.shared
        if UserSettings.shared.handleDuplicates {
            if let existing = storage.itemWithHash(hash) {
                storage.moveToTop(existing)
                return
            }
            // Legacy items saved before hashes were introduced
            if let text = textFallback, let type = textType,
               let existing = storage.clipboardItems.first(where: {
                   $0.contentHash == nil && $0.contentType == type && $0.textContent == text
               }) {
                existing.contentHash = hash
                storage.moveToTop(existing)
                return
            }
        }
        if let item = create() {
            StorageManager.shared.addClipboardItem(item)
        }
    }

    // MARK: - Hash

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256(_ string: String) -> String {
        sha256(Data(string.utf8))
    }
}
