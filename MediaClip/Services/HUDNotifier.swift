import AppKit

/// Small transient HUD overlay for lightweight feedback
/// (e.g. "✅ スニペットに登録しました") - no notification permission needed.
enum HUDNotifier {
    private static var currentPanel: NSPanel?

    static func show(_ message: String, duration: TimeInterval = 1.4) {
        DispatchQueue.main.async {
            currentPanel?.orderOut(nil)
            currentPanel = nil

            let label = NSTextField(labelWithString: message)
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textColor = .labelColor
            label.alignment = .center
            label.sizeToFit()

            let hPadding: CGFloat = 22
            let vPadding: CGFloat = 12
            let contentSize = NSSize(
                width: label.frame.width + hPadding * 2,
                height: label.frame.height + vPadding * 2
            )

            let effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentSize))
            effectView.material = .hudWindow
            effectView.state = .active
            effectView.wantsLayer = true
            effectView.layer?.cornerRadius = 12
            effectView.layer?.masksToBounds = true
            label.frame.origin = NSPoint(x: hPadding, y: vPadding)
            effectView.addSubview(label)

            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: contentSize),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .statusBar
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.ignoresMouseEvents = true
            panel.contentView = effectView

            // Show on the screen containing the mouse cursor, slightly below center
            let mouse = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
            if let screen {
                let x = screen.frame.midX - contentSize.width / 2
                let y = screen.frame.minY + screen.frame.height * 0.22
                panel.setFrame(NSRect(x: x, y: y, width: contentSize.width, height: contentSize.height), display: true)
            }

            panel.alphaValue = 1
            panel.orderFrontRegardless()
            currentPanel = panel

            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.3
                    panel.animator().alphaValue = 0
                }, completionHandler: {
                    panel.orderOut(nil)
                    if currentPanel === panel { currentPanel = nil }
                })
            }
        }
    }
}
