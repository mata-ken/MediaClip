import Foundation
import AppKit

enum PasteService {
    /// Set clipboard content for a history item (does NOT paste)
    static func setClipboard(item: ClipboardItem, monitor: ClipboardMonitor, forcePlainText: Bool = false) {
        let pasteboard = NSPasteboard.general
        monitor.markSelfChange()
        pasteboard.clearContents()

        let plainOnly = forcePlainText || UserSettings.shared.pasteAsPlainText

        switch item.contentType {
        case .plainText:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }

        case .richText:
            if !plainOnly,
               let rtfName = item.rtfFileName,
               let rtfData = StorageManager.shared.loadRTFData(fileName: rtfName) {
                let pbItem = NSPasteboardItem()
                pbItem.setData(rtfData, forType: .rtf)
                pbItem.setString(item.textContent ?? "", forType: .string)
                pasteboard.writeObjects([pbItem])
            } else if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }

        case .url:
            if let urlString = item.textContent {
                if plainOnly {
                    pasteboard.setString(urlString, forType: .string)
                } else {
                    let pbItem = NSPasteboardItem()
                    pbItem.setString(urlString, forType: .URL)
                    pbItem.setString(urlString, forType: .string)
                    pasteboard.writeObjects([pbItem])
                }
            }

        case .image:
            if let fileName = item.imageFileName,
               let data = StorageManager.shared.loadImageData(fileName: fileName),
               let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }

        case .video:
            if let path = item.mediaFilePath {
                let url = URL(fileURLWithPath: path) as NSURL
                pasteboard.writeObjects([url])
            }

        case .pdf:
            if let fileName = item.pdfFileName,
               let data = StorageManager.shared.loadPDFData(fileName: fileName) {
                let pbItem = NSPasteboardItem()
                pbItem.setData(data, forType: .pdf)
                pasteboard.writeObjects([pbItem])
            }

        case .file:
            let urls = (item.filePaths ?? []).map { URL(fileURLWithPath: $0) as NSURL }
            if !urls.isEmpty {
                pasteboard.writeObjects(urls)
            }
        }
    }

    /// Set clipboard content for a snippet (does NOT paste)
    static func setClipboardText(_ text: String, monitor: ClipboardMonitor) {
        let pasteboard = NSPasteboard.general
        monitor.markSelfChange()
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Simulate Cmd+V using CGEvent, with AppleScript fallback
    static func simulateCmdV() {
        // Try CGEvent first
        let source = CGEventSource(stateID: .combinedSessionState)
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        } else {
            // Fallback: AppleScript
            simulateViaAppleScript()
        }
    }

    private static func simulateViaAppleScript() {
        let source = """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
    }
}
