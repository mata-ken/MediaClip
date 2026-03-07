import Foundation
import AppKit

enum PasteService {
    /// Set clipboard content for a history item (does NOT paste)
    static func setClipboard(item: ClipboardItem, monitor: ClipboardMonitor) {
        let pasteboard = NSPasteboard.general
        monitor.markSelfChange()
        pasteboard.clearContents()

        switch item.contentType {
        case .plainText, .richText:
            if let text = item.textContent {
                pasteboard.writeObjects([text as NSString])
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
        }
    }

    /// Set clipboard content for a snippet (does NOT paste)
    static func setClipboardText(_ text: String, monitor: ClipboardMonitor) {
        let pasteboard = NSPasteboard.general
        monitor.markSelfChange()
        pasteboard.clearContents()
        pasteboard.writeObjects([text as NSString])
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
