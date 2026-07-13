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

    /// Capture the ENTIRE content of the focused text field (for rescuing dictated / directly-typed text).
    /// Strategy: AX value of the focused element → AX selected text → Select-All + Cmd+C fallback.
    static func captureFocusedFieldText(monitor: ClipboardMonitor, completion: @escaping (String?) -> Void) {
        if let value = axFocusedValue(), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completion(value)
            return
        }
        if let sel = axSelectedText(), !sel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completion(sel)
            return
        }
        selectAllCopyFallback(monitor: monitor, completion: completion)
    }

    // MARK: - AX API

    /// Full value (kAXValue) of the focused UI element — the whole field's text.
    private static func axFocusedValue() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return nil
        }
        // swiftlint:disable:next force_cast
        let element = focused as! AXUIElement
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let text = valueRef as? String else {
            return nil
        }
        return text
    }

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

    // MARK: - Cmd+C fallback (restores the user's clipboard afterwards)

    private static func cmdCFallback(monitor: ClipboardMonitor, completion: @escaping (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        let savedCount = pasteboard.changeCount
        let snapshot = snapshotPasteboard(pasteboard)

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
                let selection = pasteboard.string(forType: .string)
                // Restore the user's original clipboard (the ⌘C is invisible to them)
                monitor.markSelfChange()
                restorePasteboard(snapshot, to: pasteboard)
                completion(selection)
            } else {
                // Nothing was copied (no selection) - disarm the marker
                monitor.unmarkSelfChange()
                completion(nil)
            }
        }
    }

    /// Deep-copy the current pasteboard so it can be restored later.
    private static func snapshotPasteboard(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        var saved: [NSPasteboardItem] = []
        for item in pasteboard.pasteboardItems ?? [] {
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            if !copy.types.isEmpty {
                saved.append(copy)
            }
        }
        return saved
    }

    private static func restorePasteboard(_ items: [NSPasteboardItem], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    // MARK: - Select-All + Copy fallback (for fields with no AX value, e.g. some web editors)

    /// Posts ⌘A then ⌘C and reads the result. Leaves the text on the clipboard on purpose
    /// (the caller wants it captured), so we do NOT restore the previous clipboard here.
    private static func selectAllCopyFallback(monitor: ClipboardMonitor, completion: @escaping (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        let savedCount = pasteboard.changeCount
        let source = CGEventSource(stateID: .combinedSessionState)

        post(virtualKey: 0x00, source: source) // A  (⌘A select all)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            post(virtualKey: 0x08, source: source) // C  (⌘C copy)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if pasteboard.changeCount != savedCount {
                    completion(pasteboard.string(forType: .string))
                } else {
                    completion(nil)
                }
            }
        }
    }

    private static func post(virtualKey: CGKeyCode, source: CGEventSource?) {
        if let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
           let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) {
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }
}
