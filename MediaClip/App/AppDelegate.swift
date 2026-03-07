import AppKit
import SwiftUI
import Carbon
import Combine

// File-scope C callback for Carbon hotkey
private func carbonHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        delegate.triggerMenu()
    }
    return noErr
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let clipboardMonitor = ClipboardMonitor()
    private var snippetEditorWindow: NSWindow?
    private var previousApp: NSRunningApplication?
    private var hotKeyRef: EventHotKeyRef?
    private var settingsCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusBarIcon()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Request accessibility (needed for CGEvent paste, not for hotkey)
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        clipboardMonitor.startMonitoring()
        registerGlobalHotKey()

        // Track the previously active app (non-MediaClip)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // Watch for status bar icon changes
        settingsCancellable = UserSettings.shared.$statusBarIconName
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusBarIcon()
                }
            }
    }

    private func updateStatusBarIcon() {
        if let button = statusItem.button {
            let iconName = UserSettings.shared.statusBarIconName
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "MediaClip")
        }
    }

    @objc private func activeAppChanged(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = app
        }
    }

    // MARK: - Global Hotkey (Carbon)

    private func registerGlobalHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyHandler,
            1,
            &eventType,
            selfPtr,
            nil
        )

        let settings = UserSettings.shared
        let hotKeyID = EventHotKeyID(signature: OSType(0x4D434C50), id: 1)
        let status = RegisterEventHotKey(
            settings.mainShortcutKeyCode,
            settings.mainShortcutModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            print("Failed to register hotkey: \(status)")
        }
    }

    /// Called from hotkey - show menu at mouse cursor position
    func triggerMenu() {
        let menu = NSMenu()
        buildMenu(into: menu)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        buildMenu(into: menu)
    }

    // MARK: - Menu Building

    private func buildMenu(into menu: NSMenu) {
        let settings = UserSettings.shared
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        ]

        // 履歴ヘッダー
        let historyHeader = NSMenuItem(title: "履歴", action: nil, keyEquivalent: "")
        historyHeader.attributedTitle = NSAttributedString(string: "履歴", attributes: headerAttrs)
        historyHeader.isEnabled = false
        menu.addItem(historyHeader)

        let allItems = StorageManager.shared.clipboardItems
        let textItems = allItems.filter { $0.contentType == .plainText || $0.contentType == .richText }
        let mediaItems = allItems.filter { $0.contentType == .image || $0.contentType == .video }
        let folderSize = settings.folderItemCount

        // テキスト
        let textHeader = NSMenuItem(title: "テキスト", action: nil, keyEquivalent: "")
        if settings.showIconInMenu {
            textHeader.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        }
        textHeader.isEnabled = false
        menu.addItem(textHeader)

        if textItems.isEmpty {
            let emptyItem = NSMenuItem(title: "  テキスト履歴がありません", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            addPagedItems(textItems, to: menu, folderSize: folderSize, settings: settings)
        }

        // 画像
        let mediaHeader = NSMenuItem(title: "画像", action: nil, keyEquivalent: "")
        if settings.showIconInMenu {
            mediaHeader.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: nil)
        }
        mediaHeader.isEnabled = false
        menu.addItem(mediaHeader)

        if mediaItems.isEmpty {
            let emptyItem = NSMenuItem(title: "  画像履歴がありません", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            addPagedItems(mediaItems, to: menu, folderSize: folderSize, settings: settings)
        }

        menu.addItem(NSMenuItem.separator())

        // スニペットヘッダー
        let snippetHeader = NSMenuItem(title: "スニペット", action: nil, keyEquivalent: "")
        snippetHeader.attributedTitle = NSAttributedString(string: "スニペット", attributes: headerAttrs)
        snippetHeader.isEnabled = false
        menu.addItem(snippetHeader)

        let folders = StorageManager.shared.folders
        let unfolderedSnippets = StorageManager.shared.snippetsForFolder(nil).filter { !$0.content.isEmpty }

        if folders.isEmpty && unfolderedSnippets.isEmpty {
            let emptyItem = NSMenuItem(title: "  スニペットがありません", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for folder in folders {
                let folderItem = NSMenuItem(title: folder.name, action: nil, keyEquivalent: "")
                if settings.showIconInMenu {
                    folderItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
                }

                let submenu = NSMenu()
                let snippets = StorageManager.shared.snippetsForFolder(folder.id).filter { !$0.content.isEmpty }
                if snippets.isEmpty {
                    let emptyItem = NSMenuItem(title: "(空)", action: nil, keyEquivalent: "")
                    emptyItem.isEnabled = false
                    submenu.addItem(emptyItem)
                } else {
                    for snippet in snippets {
                        let item = NSMenuItem(
                            title: snippet.title,
                            action: #selector(pasteSnippetAction(_:)),
                            keyEquivalent: ""
                        )
                        item.target = self
                        item.representedObject = snippet
                        submenu.addItem(item)
                    }
                }
                folderItem.submenu = submenu
                menu.addItem(folderItem)
            }

            for snippet in unfolderedSnippets {
                let item = NSMenuItem(
                    title: snippet.title,
                    action: #selector(pasteSnippetAction(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = snippet
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // アクション
        let clearItem = NSMenuItem(title: "履歴をクリア", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        let editSnippetsItem = NSMenuItem(title: "スニペットを編集...", action: #selector(openSnippetEditor), keyEquivalent: "")
        editSnippetsItem.target = self
        menu.addItem(editSnippetsItem)

        let settingsItem = NSMenuItem(title: "環境設定...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "MediaClip を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func addPagedItems(_ items: [ClipboardItem], to menu: NSMenu, folderSize: Int, settings: UserSettings) {
        for pageStart in stride(from: 0, to: items.count, by: folderSize) {
            let pageEnd = min(pageStart + folderSize, items.count)
            let pageItem = NSMenuItem(
                title: "\(pageStart + 1) - \(pageEnd)",
                action: nil,
                keyEquivalent: ""
            )
            if settings.showIconInMenu {
                pageItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
            }

            let submenu = NSMenu()
            submenu.minimumWidth = 250
            for i in pageStart..<pageEnd {
                let clipItem = items[i]
                let menuItem = createHistoryMenuItem(for: clipItem, index: i)
                submenu.addItem(menuItem)
            }
            pageItem.submenu = submenu
            menu.addItem(pageItem)
        }
    }

    private func createHistoryMenuItem(for clipItem: ClipboardItem, index: Int) -> NSMenuItem {
        let settings = UserSettings.shared
        let menuItem = NSMenuItem()
        menuItem.target = self
        menuItem.action = #selector(pasteHistoryAction(_:))
        menuItem.representedObject = clipItem

        let maxChars = settings.menuCharacterCount

        switch clipItem.contentType {
        case .plainText, .richText:
            let text = clipItem.textContent ?? ""
            let firstLine = text.components(separatedBy: .newlines).first ?? text
            // Normalize whitespace (tabs, multiple spaces -> single space)
            let normalized = firstLine
                .replacingOccurrences(of: "\t", with: " ")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            let truncated = String(normalized.prefix(maxChars))
            let displayText = truncated + (normalized.count > maxChars ? "..." : "")

            let prefix = settings.showNumbering ? "\(index + 1). " : ""
            let title = prefix + truncateToPixelWidth(displayText, maxWidth: 220)

            menuItem.title = title

            if settings.showTooltips {
                menuItem.toolTip = String(text.prefix(500))
            }

            // Color code preview
            if settings.showColorCodePreview {
                let colorHexPattern = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if let color = colorFromHex(colorHexPattern) {
                    let colorImage = createColorSwatch(color: color, size: NSSize(width: 16, height: 16))
                    menuItem.image = colorImage
                }
            }

        case .image:
            let label = settings.showNumbering ? "\(index + 1)." : ""
            menuItem.attributedTitle = buildMediaTitle(
                label: label,
                thumbnailFileName: clipItem.thumbnailFileName,
                fallbackIcon: "photo",
                settings: settings
            )
            menuItem.title = label

        case .video:
            let label = settings.showNumbering ? "\(index + 1)." : ""
            menuItem.attributedTitle = buildMediaTitle(
                label: label,
                thumbnailFileName: clipItem.thumbnailFileName,
                fallbackIcon: "film",
                settings: settings
            )
            menuItem.title = label
        }

        if clipItem.isPinned {
            menuItem.title = "📌 " + menuItem.title
        }

        return menuItem
    }

    private func resizeImage(_ image: NSImage, to maxSize: NSSize) -> NSImage {
        let originalSize = image.size
        guard originalSize.width > 0 && originalSize.height > 0 else { return image }

        let widthRatio = maxSize.width / originalSize.width
        let heightRatio = maxSize.height / originalSize.height
        let scale = min(widthRatio, heightRatio, 1.0)

        let newSize = NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1.0)
        resized.unlockFocus()
        return resized
    }

    private func buildMediaTitle(
        label: String,
        thumbnailFileName: String?,
        fallbackIcon: String,
        settings: UserSettings
    ) -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 0)
        let result = NSMutableAttributedString(string: label + "  ", attributes: [.font: font])

        if settings.showImagePreview,
           let thumbName = thumbnailFileName,
           let data = StorageManager.shared.loadThumbnailData(fileName: thumbName),
           let image = NSImage(data: data) {
            let previewSize = NSSize(
                width: CGFloat(settings.imagePreviewWidth),
                height: CGFloat(settings.imagePreviewHeight)
            )
            let resized = resizeImage(image, to: previewSize)

            let attachment = NSTextAttachment()
            attachment.image = resized
            let imageHeight = resized.size.height
            attachment.bounds = CGRect(
                x: 0,
                y: (font.capHeight - imageHeight) / 2,
                width: resized.size.width,
                height: imageHeight
            )
            result.append(NSAttributedString(attachment: attachment))
        } else if settings.showIconInMenu {
            if let icon = NSImage(systemSymbolName: fallbackIcon, accessibilityDescription: nil) {
                let attachment = NSTextAttachment()
                attachment.image = icon
                let iconSize: CGFloat = 14
                attachment.bounds = CGRect(
                    x: 0,
                    y: (font.capHeight - iconSize) / 2,
                    width: iconSize,
                    height: iconSize
                )
                result.append(NSAttributedString(attachment: attachment))
            }
        }

        return result
    }

    private func truncateToPixelWidth(_ text: String, maxWidth: CGFloat) -> String {
        let font = NSFont.menuFont(ofSize: 0)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let fullWidth = (text as NSString).size(withAttributes: attrs).width
        guard fullWidth > maxWidth else { return text }

        // Binary search for the right truncation point
        var low = 0
        var high = text.count
        while low < high {
            let mid = (low + high + 1) / 2
            let sub = String(text.prefix(mid)) + "..."
            let w = (sub as NSString).size(withAttributes: attrs).width
            if w <= maxWidth {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return String(text.prefix(low)) + "..."
    }

    private func colorFromHex(_ hex: String) -> NSColor? {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard str.hasPrefix("#") else { return nil }
        str.removeFirst()
        guard str.count == 6 || str.count == 3 else { return nil }
        guard str.allSatisfy({ $0.isHexDigit }) else { return nil }

        if str.count == 3 {
            str = str.map { "\($0)\($0)" }.joined()
        }

        guard let val = UInt64(str, radix: 16) else { return nil }
        let r = CGFloat((val >> 16) & 0xFF) / 255.0
        let g = CGFloat((val >> 8) & 0xFF) / 255.0
        let b = CGFloat(val & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    private func createColorSwatch(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        NSColor.gray.setStroke()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).stroke()
        image.unlockFocus()
        return image
    }

    // MARK: - Paste Actions

    @objc private func pasteHistoryAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else { return }
        let settings = UserSettings.shared

        if settings.pasteAfterSelection {
            pasteWithAppActivation {
                PasteService.setClipboard(item: item, monitor: self.clipboardMonitor)
            }
            if settings.deleteAfterPaste {
                StorageManager.shared.deleteClipboardItem(item)
            }
        } else {
            PasteService.setClipboard(item: item, monitor: clipboardMonitor)
            if settings.deleteAfterPaste {
                StorageManager.shared.deleteClipboardItem(item)
            }
        }
    }

    @objc private func pasteSnippetAction(_ sender: NSMenuItem) {
        guard let snippet = sender.representedObject as? Snippet else { return }
        let settings = UserSettings.shared

        if settings.pasteAfterSelection {
            pasteWithAppActivation {
                PasteService.setClipboardText(snippet.content, monitor: self.clipboardMonitor)
            }
        } else {
            PasteService.setClipboardText(snippet.content, monitor: clipboardMonitor)
        }
    }

    private func pasteWithAppActivation(setClipboard: @escaping () -> Void) {
        // Check accessibility permission
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            return
        }

        setClipboard()
        self.previousApp?.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            PasteService.simulateCmdV()
        }
    }

    // MARK: - Other Actions

    @objc private func clearHistory() {
        StorageManager.shared.clearUnpinnedItems()
    }

    @objc private func openSnippetEditor() {
        if let window = snippetEditorWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SnippetManagerView()
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "スニペット編集"
        window.setContentSize(NSSize(width: 600, height: 400))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        snippetEditorWindow = window
    }

    @objc private func openSettings() {
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
