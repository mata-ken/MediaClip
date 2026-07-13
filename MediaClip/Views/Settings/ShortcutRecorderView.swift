import SwiftUI
import AppKit

/// Click-to-record shortcut field (self-contained, no external dependencies).
/// Click -> press a key combo (at least one modifier required) -> saved. Esc cancels.
struct ShortcutRecorderField: NSViewRepresentable {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    var onChange: () -> Void = {}

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: RecorderNSView) {
        view.displayText = modifiers == 0
            ? "クリックして設定"
            : UserSettings.displayString(keyCode: keyCode, modifiers: modifiers)
        view.onCapture = { code, mods in
            keyCode = code
            modifiers = mods
            onChange()
        }
    }
}

final class RecorderNSView: NSView {
    var onCapture: ((UInt32, UInt32) -> Void)?
    var displayText: String = "" {
        didSet { needsDisplay = true }
    }
    private var isRecording = false {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 130, height: 24) }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == 53 { // Esc cancels
            isRecording = false
            window?.makeFirstResponder(nil)
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let carbon = UserSettings.carbonModifiers(from: flags)
        guard carbon != 0 else {
            NSSound.beep() // require at least one modifier
            return
        }
        isRecording = false
        window?.makeFirstResponder(nil)
        onCapture?(UInt32(event.keyCode), carbon)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Cmd-combos arrive as key equivalents - capture them too while recording
        if isRecording && event.type == .keyDown {
            keyDown(with: event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        let fillColor = isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.15)
            : NSColor.controlBackgroundColor
        fillColor.setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = isRecording ? "キーを入力..." : displayText
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let point = NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        (text as NSString).draw(at: point, withAttributes: attrs)
    }
}
