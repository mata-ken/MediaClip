import AppKit
import ApplicationServices

/// Captures the currently selected text in the frontmost app.
/// Strategy: Accessibility API first, Cmd+C simulation as fallback.
enum SelectedTextService {
    static func captureSelectedText(monitor: ClipboardMonitor, completion: @escaping (String?) -> Void) {
        if let text = axSelectedText(), !text.isEmpty {
            completion(text)
            return
        }
        cmdCFallback(monitor: monitor, completion: completion)
    }

    // MARK: - AX API

    private static func axSelectedText() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return nil
        }
        // swiftlint:disable:next force_cast
        let element = focused as! AXUIElement
        var selectedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedRef) == .success,
              let text = selectedRef as? String else {
            return nil
        }
        return text
    }

    // MARK: - Cmd+C fallback (preserves clipboard pollution via self-change marker)

    private static func cmdCFallback(monitor: ClipboardMonitor, completion: @escaping (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        let savedCount = pasteboard.changeCount

        // Ignore the copy we are about to trigger so it doesn't enter history
        monitor.markSelfChange()

        let source = CGEventSource(stateID: .combinedSessionState)
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true), // C
           let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false) {
            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if pasteboard.changeCount != savedCount {
                completion(pasteboard.string(forType: .string))
            } else {
                // Nothing was copied (no selection) - disarm the marker
                monitor.unmarkSelfChange()
                completion(nil)
            }
        }
    }
}
