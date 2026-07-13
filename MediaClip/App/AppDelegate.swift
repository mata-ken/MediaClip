import AppKit
import SwiftUI
import Carbon
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let clipboardMonitor = ClipboardMonitor()
    private let screenshotWatcher = ScreenshotWatcher()
    private var snippetEditorWindow: NSWindow?
    private var searchWindow: NSWindow?
    private var previousApp: NSRunningApplication?
    private var settingsCancellables = Set<AnyCancellable>()
    /// Text awaiting snippet registration via the folder-picker popup
    private var pendingSnippetText: String?

    enum MenuKind {
        case full
        case historyOnly
        case snippetsOnly
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusBarIcon()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Request accessibility (needed for CGEvent paste / selected-text capture)
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        clipboardMonitor.startMonitoring()
        registerAllHotKeys()
        updateScreenshotWatcher()

        // Track the previously active app (non-MediaClip)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // Watch for settings changes
        UserSettings.shared.$statusBarIconName
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusBarIcon()
                }
            }
            .store(in: &settingsCancellables)

        UserSettings.shared.$watchScreenshotFiles
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateScreenshotWatcher()
                }
            }
            .store(in: &settingsCancellables)

        // Startup update check (GitHub Releases, honoring interval setting)
        UpdateChecker.autoCheckIfNeeded()
    }

    /// Re-register all global hotkeys (called after shortcut settings change)
    static func reloadHotKeys() {
        DispatchQueue.main.async {
            (NSApp.delegate as? AppDelegate)?.registerAllHotKeys()
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

    // MARK: - Global Hotkeys

    func registerAllHotKeys() {
        let manager = HotKeyManager.shared
        manager.unregisterAll()

        let settings = UserSettings.shared

        // Main menu (history + snippets)
        manager.register(
            keyCode: settings.mainShortcutKeyCode,
            modifiers: settings.mainShortcutModifiers
        ) { [weak self] in
            self?.triggerMenu(.full)
        }

        // History-only menu
        if settings.historyShortcutEnabled {
            manager.register(
                keyCode: settings.historyShortcutKeyCode,
                modifiers: settings.historyShortcutModifiers
            ) { [weak self] in
                self?.triggerMenu(.historyOnly)
            }
        }

        // Snippets-only menu
        if settings.snippetsShortcutEnabled {
            manager.register(
                keyCode: settings.snippetsShortcutKeyCode,
                modifiers: settings.snippetsShortcutModifiers
            ) { [weak self] in
                self?.triggerMenu(.snippetsOnly)
            }
        }

        // Quick snippet registration (selected text -> folder picker)
        if settings.quickSnippetShortcutEnabled {
            manager.register(
                keyCode: settings.quickSnippetShortcutKeyCode,
                modifiers: settings.quickSnippetShortcutModifiers
            ) { [weak self] in
                self?.quickSnippetCapture()
            }
        }

        // Per-folder snippet hotkeys
        for folder in StorageManager.shared.folders {
            if let keyCode = folder.hotKeyCode, let modifiers = folder.hotKeyModifiers {
                let folderID = folder.id
                manager.register(keyCode: keyCode, modifiers: modifiers) { [weak self] in
                    self?.popupFolderMenu(folderID: folderID)
                }
            }
        }
    }

    /// Called from hotkey - show menu at mouse cursor position
    func triggerMenu(_ kind: MenuKind = .full) {
        let menu = NSMenu()
        buildMenu(into: menu, kind: kind)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        buildMenu(into: menu, kind: .full)
    }

    // MARK: - Menu Building

    private func buildMenu(into menu: NSMenu, kind: MenuKind) {
        let settings = UserSettings.shared
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        ]

        if kind != .snippetsOnly {
            addHistorySection(to: menu, settings: settings, headerAttrs: headerAttrs)
        }

        if kind != .historyOnly {
            if kind == .full {
                menu.addItem(NSMenuItem.separator())
            }
            addSnippetSection(to: menu, settings: settings, headerAttrs: headerAttrs)
        }

        menu.addItem(NSMenuItem.separator())

        // アクション
        let searchItem = NSMenuItem(title: "検索...", action: #selector(openSearchWindow), keyEquivalent: "f")
        searchItem.target = self
        menu.addItem(searchItem)

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

    private func addHistorySection(
        to menu: NSMenu,
        settings: UserSettings,
        headerAttrs: [NSAttributedString.Key: Any]
    ) {
        // 履歴ヘッダー
        let historyHeader = NSMenuItem(title: "履歴", action: nil, keyEquivalent: "")
        historyHeader.attributedTitle = NSAttributedString(string: "履歴", attributes: headerAttrs)
        historyHeader.isEnabled = false
        menu.addItem(historyHeader)

        let allItems = StorageManager.shared.clipboardItems
        let textItems = allItems.filter {
            $0.contentType == .plainText || $0.contentType == .richText
                || $0.contentType == .url || $0.contentType == .file
        }
        let mediaItems = allItems.filter {
            $0.contentType == .image || $0.contentType == .video || $0.contentType == .pdf
        }

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
            addSectionItems(textItems, to: menu, settings: settings, assignNumericKeys: true)
        }

        // メディア
        let mediaHeader = NSMenuItem(title: "画像・メディア", action: nil, keyEquivalent: "")
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
            addSectionItems(mediaItems, to: menu, settings: settings, assignNumericKeys: false)
        }
    }

    /// Add items honoring the inline count setting (first N inline, remainder paged)
    private func addSectionItems(
        _ items: [ClipboardItem],
        to menu: NSMenu,
        settings: UserSettings,
        assignNumericKeys: Bool
    ) {
        let inlineCount = min(max(settings.inlineItemCount, 0), items.count)

        for i in 0..<inlineCount {
            let menuItem = createHistoryMenuItem(
                for: items[i],
                index: i,
                assignNumericKey: assignNumericKeys,
                settings: settings
            )
            menu.addItem(menuItem)
        }

        if inlineCount < items.count {
            addPagedItems(
                Array(items[inlineCount...]),
                startIndex: inlineCount,
                to: menu,
                folderSize: settings.folderItemCount,
                settings: settings,
                assignNumericKeys: assignNumericKeys
            )
        }
    }

    private func addSnippetSection(
        to menu: NSMenu,
        settings: UserSettings,
        headerAttrs: [NSAttributedString.Key: Any]
    ) {
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
                var folderTitle = folder.name
                if let keyCode = folder.hotKeyCode, let modifiers = folder.hotKeyModifiers {
                    folderTitle += "  (\(UserSettings.displayString(keyCode: keyCode, modifiers: modifiers)))"
                }
                let folderItem = NSMenuItem(title: folderTitle, action: nil, keyEquivalent: "")
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
    }

    private func addPagedItems(
        _ items: [ClipboardItem],
        startIndex: Int,
        to menu: NSMenu,
        folderSize: Int,
        settings: UserSettings,
        assignNumericKeys: Bool
    ) {
        for pageStart in stride(from: 0, to: items.count, by: folderSize) {
            let pageEnd = min(pageStart + folderSize, items.count)
            let pageItem = NSMenuItem(
                title: "\(startIndex + pageStart + 1) - \(startIndex + pageEnd)",
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
                let menuItem = createHistoryMenuItem(
                    for: clipItem,
                    index: startIndex + i,
                    assignNumericKey: assignNumericKeys,
                    settings: settings
                )
                submenu.addItem(menuItem)
            }
            pageItem.submenu = submenu
            menu.addItem(pageItem)
        }
    }

    private func createHistoryMenuItem(
        for clipItem: ClipboardItem,
        index: Int,
        assignNumericKey: Bool,
        settings: UserSettings
    ) -> NSMenuItem {
        let menuItem = NSMenuItem()
        menuItem.target = self
        menuItem.action = #selector(pasteHistoryAction(_:))
        menuItem.representedObject = clipItem

        // 数字キー(1-9,0)による即選択
        if assignNumericKey && settings.numericKeySelection && index < 10 {
            menuItem.keyEquivalent = String((index + 1) % 10)
            menuItem.keyEquivalentModifierMask = []
        }

        let maxChars = settings.menuCharacterCount

        switch clipItem.contentType {
        case .plainText, .richText, .url, .file:
            let text = clipItem.previewText
            let firstLine = text.components(separatedBy: .newlines).first ?? text
            // Normalize whitespace (tabs, multiple spaces -> single space)
            let normalized = firstLine
                .replacingOccurrences(of: "\t", with: " ")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            let truncated = String(normalized.prefix(maxChars))
            var displayText = truncated + (normalized.count > maxChars ? "..." : "")

            if clipItem.contentType == .file {
                displayText = "(File) " + displayText
            }

            let prefix = settings.showNumbering ? "\(index + 1). " : ""
            let title = prefix + truncateToPixelWidth(displayText, maxWidth: 220)

            menuItem.title = title

            if settings.showTooltips {
                menuItem.toolTip = String(text.prefix(500))
            }

            if settings.showIconInMenu && clipItem.contentType == .url {
                menuItem.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
            }

            // Color code preview
            if settings.showColorCodePreview, let content = clipItem.textContent {
                let colorHexPattern = content.trimmingCharacters(in: .whitespacesAndNewlines)
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
            // OCR済みテキストをツールチップに表示
            if settings.showTooltips, let ocr = clipItem.ocrText, !ocr.isEmpty {
                menuItem.toolTip = String(ocr.prefix(500))
            }

        case .video:
            let label = settings.showNumbering ? "\(index + 1)." : ""
            menuItem.attributedTitle = buildMediaTitle(
                label: label,
                thumbnailFileName: clipItem.thumbnailFileName,
                fallbackIcon: "film",
                settings: settings
            )
            menuItem.title = label

        case .pdf:
            let name = clipItem.textContent ?? "PDF"
            let prefix = settings.showNumbering ? "\(index + 1). " : ""
            menuItem.title = prefix + "(PDF) " + truncateToPixelWidth(name, maxWidth: 200)
            if settings.showIconInMenu {
                menuItem.image = NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: nil)
            }
        }

        if clipItem.isPinned {
            if let attributed = menuItem.attributedTitle {
                let pinned = NSMutableAttributedString(string: "📌 ")
                pinned.append(attributed)
                menuItem.attributedTitle = pinned
            } else {
                menuItem.title = "📌 " + menuItem.title
            }
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
        let flags = (NSApp.currentEvent?.modifierFlags ?? []).intersection(.deviceIndependentFlagsMask)

        // 修飾キーアクション（優先度: ピン留め > 削除 > スニペット登録 > プレーンペースト）
        if let pinFlag = settings.pinModifier.flag, flags.contains(pinFlag) {
            StorageManager.shared.togglePin(item)
            HUDNotifier.show(item.isPinned ? "📌 ピン留めしました" : "ピン留めを解除しました")
            return
        }
        if let deleteFlag = settings.deleteModifier.flag, flags.contains(deleteFlag) {
            StorageManager.shared.deleteClipboardItem(item)
            HUDNotifier.show("🗑 履歴から削除しました")
            return
        }
        if let snippetFlag = settings.snippetModifier.flag, flags.contains(snippetFlag),
           let text = item.textContent,
           item.contentType == .plainText || item.contentType == .richText || item.contentType == .url {
            promptSnippetRegistration(text: text)
            return
        }
        let forcePlain = settings.plainTextModifier.flag.map { flags.contains($0) } ?? false

        performPaste {
            PasteService.setClipboard(item: item, monitor: self.clipboardMonitor, forcePlainText: forcePlain)
        }

        if settings.sortByLastUsed {
            StorageManager.shared.moveToTop(item)
        }
        if settings.deleteAfterPaste {
            StorageManager.shared.deleteClipboardItem(item)
        }
    }

    @objc private func pasteSnippetAction(_ sender: NSMenuItem) {
        guard let snippet = sender.representedObject as? Snippet else { return }
        performPaste {
            PasteService.setClipboardText(snippet.content, monitor: self.clipboardMonitor)
        }
    }

    private func performPaste(setClipboard: @escaping () -> Void) {
        if UserSettings.shared.pasteAfterSelection {
            pasteWithAppActivation(setClipboard: setClipboard)
        } else {
            setClipboard()
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

    // MARK: - Quick Snippet Registration (C1/C2)

    /// Capture the selected text in the frontmost app and offer folder-picker registration
    func quickSnippetCapture() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            return
        }

        SelectedTextService.captureSelectedText(monitor: clipboardMonitor) { [weak self] text in
            guard let self else { return }
            if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.promptSnippetRegistration(text: text)
            } else if let clipText = StorageManager.shared.clipboardItems
                .first(where: { $0.contentType == .plainText || $0.contentType == .richText })?
                .textContent {
                // Fallback: latest clipboard text
                self.promptSnippetRegistration(text: clipText, sourceLabel: "クリップボードの最新テキスト")
            } else {
                HUDNotifier.show("選択テキストが見つかりません")
            }
        }
    }

    /// Show a folder-picker popup at the cursor to register `text` as a snippet
    func promptSnippetRegistration(text: String, sourceLabel: String? = nil) {
        pendingSnippetText = text

        let menu = NSMenu()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = String((trimmed.components(separatedBy: .newlines).first ?? trimmed).prefix(24))
        let headerTitle: String
        if let sourceLabel {
            headerTitle = "スニペットに登録 (\(sourceLabel)): \(preview)…"
        } else {
            headerTitle = "スニペットに登録: \(preview)…"
        }
        let header = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        for folder in StorageManager.shared.folders {
            let item = NSMenuItem(title: folder.name, action: #selector(registerPendingSnippet(_:)), keyEquivalent: "")
            item.target = self
            item.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
            item.representedObject = folder
            menu.addItem(item)
        }

        let noFolder = NSMenuItem(title: "未分類", action: #selector(registerPendingSnippet(_:)), keyEquivalent: "")
        noFolder.target = self
        noFolder.image = NSImage(systemSymbolName: "tray", accessibilityDescription: nil)
        menu.addItem(noFolder)

        menu.addItem(.separator())
        let newFolder = NSMenuItem(
            title: "新規フォルダを作成して登録...",
            action: #selector(registerPendingSnippetInNewFolder(_:)),
            keyEquivalent: ""
        )
        newFolder.target = self
        newFolder.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)
        menu.addItem(newFolder)

        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func registerPendingSnippet(_ sender: NSMenuItem) {
        guard let text = pendingSnippetText else { return }
        let folder = sender.representedObject as? SnippetFolder
        registerSnippet(text: text, folderID: folder?.id)
    }

    @objc private func registerPendingSnippetInNewFolder(_ sender: NSMenuItem) {
        guard let text = pendingSnippetText else { return }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "新しいフォルダ"
        alert.informativeText = "スニペットを登録するフォルダ名を入力してください"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.placeholderString = "フォルダ名"
        alert.accessoryView = field
        alert.addButton(withTitle: "作成して登録")
        alert.addButton(withTitle: "キャンセル")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let folder = SnippetFolder(name: name, sortOrder: StorageManager.shared.folders.count)
        StorageManager.shared.addFolder(folder)
        registerSnippet(text: text, folderID: folder.id)
    }

    private func registerSnippet(text: String, folderID: UUID?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? "スニペット"
        let title = String(firstLine.prefix(30))
        let snippet = Snippet(
            title: title.isEmpty ? "スニペット" : title,
            content: text,
            folderID: folderID,
            sortOrder: StorageManager.shared.snippetsForFolder(folderID).count
        )
        StorageManager.shared.addSnippet(snippet)
        pendingSnippetText = nil
        HUDNotifier.show("✅ スニペットに登録しました")
    }

    // MARK: - Folder Hotkey Popup

    private func popupFolderMenu(folderID: UUID) {
        guard let folder = StorageManager.shared.folders.first(where: { $0.id == folderID }) else { return }
        let menu = NSMenu()
        let header = NSMenuItem(title: folder.name, action: nil, keyEquivalent: "")
        header.attributedTitle = NSAttributedString(
            string: folder.name,
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]
        )
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let snippets = StorageManager.shared.snippetsForFolder(folder.id).filter { !$0.content.isEmpty }
        if snippets.isEmpty {
            let emptyItem = NSMenuItem(title: "(空)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, snippet) in snippets.enumerated() {
                let item = NSMenuItem(
                    title: snippet.title,
                    action: #selector(pasteSnippetAction(_:)),
                    keyEquivalent: ""
                )
                if UserSettings.shared.numericKeySelection && index < 10 {
                    item.keyEquivalent = String((index + 1) % 10)
                    item.keyEquivalentModifierMask = []
                }
                item.target = self
                item.representedObject = snippet
                menu.addItem(item)
            }
        }

        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: - Screenshot Watcher

    private func updateScreenshotWatcher() {
        if UserSettings.shared.watchScreenshotFiles {
            screenshotWatcher.onScreenshot = { [weak self] url in
                guard let self, let data = try? Data(contentsOf: url) else { return }
                self.clipboardMonitor.ingestImageData(data)
            }
            screenshotWatcher.start()
        } else {
            screenshotWatcher.stop()
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
        window.setContentSize(NSSize(width: 640, height: 420))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        snippetEditorWindow = window
    }

    @objc func openSearchWindow() {
        if let window = searchWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SearchWindowView(
            onPasteItem: { [weak self] item in
                self?.pasteFromSearch { monitor in
                    PasteService.setClipboard(item: item, monitor: monitor)
                }
            },
            onPasteSnippet: { [weak self] snippet in
                self?.pasteFromSearch { monitor in
                    PasteService.setClipboardText(snippet.content, monitor: monitor)
                }
            }
        )
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "検索"
        window.setContentSize(NSSize(width: 480, height: 400))
        window.styleMask = [.titled, .closable, .resizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        searchWindow = window
    }

    private func pasteFromSearch(setClipboard: @escaping (ClipboardMonitor) -> Void) {
        searchWindow?.orderOut(nil)
        performPaste { [weak self] in
            guard let self else { return }
            setClipboard(self.clipboardMonitor)
        }
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
