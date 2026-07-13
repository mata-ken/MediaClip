import Foundation
import AppKit
import Combine
import ServiceManagement

/// Modifier key choice for modifier-click actions on history items
enum ModifierChoice: String, CaseIterable, Identifiable {
    case none
    case command
    case shift
    case option
    case control

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "なし"
        case .command: return "⌘ Command"
        case .shift: return "⇧ Shift"
        case .option: return "⌥ Option"
        case .control: return "⌃ Control"
        }
    }

    var flag: NSEvent.ModifierFlags? {
        switch self {
        case .none: return nil
        case .command: return .command
        case .shift: return .shift
        case .option: return .option
        case .control: return .control
        }
    }
}

final class UserSettings: ObservableObject {
    static let shared = UserSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Carbon modifier constants
    static let carbonCmd: UInt32 = 0x0100
    static let carbonShift: UInt32 = 0x0200
    static let carbonOption: UInt32 = 0x0800
    static let carbonControl: UInt32 = 0x1000

    // MARK: - 一般 (General)

    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
                launchAtLogin = !launchAtLogin
            }
        }
    }

    @Published var pasteAfterSelection: Bool {
        didSet { defaults.set(pasteAfterSelection, forKey: "pasteAfterSelection") }
    }

    @Published var maxHistoryCount: Int {
        didSet { defaults.set(maxHistoryCount, forKey: "maxHistoryCount") }
    }

    @Published var sortByLastUsed: Bool {
        didSet { defaults.set(sortByLastUsed, forKey: "sortByLastUsed") }
    }

    @Published var statusBarIconName: String {
        didSet { defaults.set(statusBarIconName, forKey: "statusBarIconName") }
    }

    // MARK: - メニュー (Menu)

    @Published var inlineItemCount: Int {
        didSet { defaults.set(inlineItemCount, forKey: "inlineItemCount") }
    }

    @Published var folderItemCount: Int {
        didSet { defaults.set(folderItemCount, forKey: "folderItemCount") }
    }

    @Published var menuCharacterCount: Int {
        didSet { defaults.set(menuCharacterCount, forKey: "menuCharacterCount") }
    }

    @Published var handleDuplicates: Bool {
        didSet { defaults.set(handleDuplicates, forKey: "handleDuplicates") }
    }

    @Published var showNumbering: Bool {
        didSet { defaults.set(showNumbering, forKey: "showNumbering") }
    }

    @Published var numericKeySelection: Bool {
        didSet { defaults.set(numericKeySelection, forKey: "numericKeySelection") }
    }

    @Published var showIconInMenu: Bool {
        didSet { defaults.set(showIconInMenu, forKey: "showIconInMenu") }
    }

    @Published var showImagePreview: Bool {
        didSet { defaults.set(showImagePreview, forKey: "showImagePreview") }
    }

    @Published var imagePreviewWidth: Int {
        didSet { defaults.set(imagePreviewWidth, forKey: "imagePreviewWidth") }
    }

    @Published var imagePreviewHeight: Int {
        didSet { defaults.set(imagePreviewHeight, forKey: "imagePreviewHeight") }
    }

    @Published var showTooltips: Bool {
        didSet { defaults.set(showTooltips, forKey: "showTooltips") }
    }

    @Published var showColorCodePreview: Bool {
        didSet { defaults.set(showColorCodePreview, forKey: "showColorCodePreview") }
    }

    // MARK: - 対応形式 (Supported Formats)

    @Published var supportPlainText: Bool {
        didSet { defaults.set(supportPlainText, forKey: "supportPlainText") }
    }

    @Published var supportRichText: Bool {
        didSet { defaults.set(supportRichText, forKey: "supportRichText") }
    }

    @Published var supportPDF: Bool {
        didSet { defaults.set(supportPDF, forKey: "supportPDF") }
    }

    @Published var supportFilenames: Bool {
        didSet { defaults.set(supportFilenames, forKey: "supportFilenames") }
    }

    @Published var supportURL: Bool {
        didSet { defaults.set(supportURL, forKey: "supportURL") }
    }

    @Published var supportImages: Bool {
        didSet { defaults.set(supportImages, forKey: "supportImages") }
    }

    /// パスワードマネージャ等が付与する Concealed 型を無視（セキュリティ）
    @Published var ignoreConcealedTypes: Bool {
        didSet { defaults.set(ignoreConcealedTypes, forKey: "ignoreConcealedTypes") }
    }

    // MARK: - 除外アプリ (Excluded Apps)

    @Published var excludedAppBundleIDs: [String] {
        didSet { defaults.set(excludedAppBundleIDs, forKey: "excludedAppBundleIDs") }
    }

    // MARK: - ショートカット (Shortcuts)

    @Published var mainShortcutKeyCode: UInt32 {
        didSet { defaults.set(Int(mainShortcutKeyCode), forKey: "mainShortcutKeyCode") }
    }

    @Published var mainShortcutModifiers: UInt32 {
        didSet { defaults.set(Int(mainShortcutModifiers), forKey: "mainShortcutModifiers") }
    }

    @Published var historyShortcutEnabled: Bool {
        didSet { defaults.set(historyShortcutEnabled, forKey: "historyShortcutEnabled") }
    }

    @Published var historyShortcutKeyCode: UInt32 {
        didSet { defaults.set(Int(historyShortcutKeyCode), forKey: "historyShortcutKeyCode") }
    }

    @Published var historyShortcutModifiers: UInt32 {
        didSet { defaults.set(Int(historyShortcutModifiers), forKey: "historyShortcutModifiers") }
    }

    @Published var snippetsShortcutEnabled: Bool {
        didSet { defaults.set(snippetsShortcutEnabled, forKey: "snippetsShortcutEnabled") }
    }

    @Published var snippetsShortcutKeyCode: UInt32 {
        didSet { defaults.set(Int(snippetsShortcutKeyCode), forKey: "snippetsShortcutKeyCode") }
    }

    @Published var snippetsShortcutModifiers: UInt32 {
        didSet { defaults.set(Int(snippetsShortcutModifiers), forKey: "snippetsShortcutModifiers") }
    }

    @Published var quickSnippetShortcutEnabled: Bool {
        didSet { defaults.set(quickSnippetShortcutEnabled, forKey: "quickSnippetShortcutEnabled") }
    }

    @Published var quickSnippetShortcutKeyCode: UInt32 {
        didSet { defaults.set(Int(quickSnippetShortcutKeyCode), forKey: "quickSnippetShortcutKeyCode") }
    }

    @Published var quickSnippetShortcutModifiers: UInt32 {
        didSet { defaults.set(Int(quickSnippetShortcutModifiers), forKey: "quickSnippetShortcutModifiers") }
    }

    /// フォーカス中のテキスト欄の中身を履歴に取り込む（音声入力・直接入力の救済）
    @Published var captureFieldShortcutEnabled: Bool {
        didSet { defaults.set(captureFieldShortcutEnabled, forKey: "captureFieldShortcutEnabled") }
    }

    @Published var captureFieldShortcutKeyCode: UInt32 {
        didSet { defaults.set(Int(captureFieldShortcutKeyCode), forKey: "captureFieldShortcutKeyCode") }
    }

    @Published var captureFieldShortcutModifiers: UInt32 {
        didSet { defaults.set(Int(captureFieldShortcutModifiers), forKey: "captureFieldShortcutModifiers") }
    }

    // MARK: - アップデート (Update)

    @Published var autoCheckUpdates: Bool {
        didSet { defaults.set(autoCheckUpdates, forKey: "autoCheckUpdates") }
    }

    @Published var updateCheckInterval: Int {
        didSet { defaults.set(updateCheckInterval, forKey: "updateCheckInterval") }
    }

    @Published var lastUpdateCheckAt: Double {
        didSet { defaults.set(lastUpdateCheckAt, forKey: "lastUpdateCheckAt") }
    }

    // MARK: - ベータ機能 (Beta)

    @Published var pasteAsPlainText: Bool {
        didSet { defaults.set(pasteAsPlainText, forKey: "pasteAsPlainText") }
    }

    @Published var deleteAfterPaste: Bool {
        didSet { defaults.set(deleteAfterPaste, forKey: "deleteAfterPaste") }
    }

    @Published var saveScreenshots: Bool {
        didSet { defaults.set(saveScreenshots, forKey: "saveScreenshots") }
    }

    /// スクリーンショットのファイル保存を監視して履歴に取り込む
    @Published var watchScreenshotFiles: Bool {
        didSet { defaults.set(watchScreenshotFiles, forKey: "watchScreenshotFiles") }
    }

    /// 画像履歴の文字認識（検索対象化）
    @Published var enableOCR: Bool {
        didSet { defaults.set(enableOCR, forKey: "enableOCR") }
    }

    // 修飾キー + クリックで発動するアクション（履歴アイテム）
    @Published var plainTextModifierRaw: String {
        didSet { defaults.set(plainTextModifierRaw, forKey: "plainTextModifier") }
    }

    @Published var deleteModifierRaw: String {
        didSet { defaults.set(deleteModifierRaw, forKey: "deleteModifier") }
    }

    @Published var pinModifierRaw: String {
        didSet { defaults.set(pinModifierRaw, forKey: "pinModifier") }
    }

    @Published var snippetModifierRaw: String {
        didSet { defaults.set(snippetModifierRaw, forKey: "snippetModifier") }
    }

    var plainTextModifier: ModifierChoice { ModifierChoice(rawValue: plainTextModifierRaw) ?? .none }
    var deleteModifier: ModifierChoice { ModifierChoice(rawValue: deleteModifierRaw) ?? .none }
    var pinModifier: ModifierChoice { ModifierChoice(rawValue: pinModifierRaw) ?? .none }
    var snippetModifier: ModifierChoice { ModifierChoice(rawValue: snippetModifierRaw) ?? .none }

    // MARK: - Init

    private init() {
        // Register defaults
        let defaultValues: [String: Any] = [
            "pasteAfterSelection": true,
            "maxHistoryCount": 30,
            "sortByLastUsed": false,
            "statusBarIconName": "paperclip",
            "inlineItemCount": 0,
            "folderItemCount": 10,
            "menuCharacterCount": 30,
            "handleDuplicates": true,
            "showNumbering": true,
            "numericKeySelection": true,
            "showIconInMenu": true,
            "showImagePreview": true,
            "imagePreviewWidth": 100,
            "imagePreviewHeight": 32,
            "showTooltips": true,
            "showColorCodePreview": false,
            "supportPlainText": true,
            "supportRichText": true,
            "supportPDF": true,
            "supportFilenames": true,
            "supportURL": true,
            "supportImages": true,
            "ignoreConcealedTypes": true,
            "autoCheckUpdates": true,
            "updateCheckInterval": 86400,
            "lastUpdateCheckAt": 0.0,
            "pasteAsPlainText": false,
            "deleteAfterPaste": false,
            "saveScreenshots": true,
            "watchScreenshotFiles": false,
            "enableOCR": true,
            "mainShortcutKeyCode": 9,    // kVK_ANSI_V
            "mainShortcutModifiers": 0x0100 | 0x0200, // cmd | shift
            "historyShortcutEnabled": true,
            "historyShortcutKeyCode": 9, // V
            "historyShortcutModifiers": 0x0100 | 0x1000, // cmd | control
            "snippetsShortcutEnabled": true,
            "snippetsShortcutKeyCode": 11, // B
            "snippetsShortcutModifiers": 0x0100 | 0x0200, // cmd | shift
            "quickSnippetShortcutEnabled": true,
            "quickSnippetShortcutKeyCode": 1, // S
            "quickSnippetShortcutModifiers": 0x0100 | 0x0200, // cmd | shift
            "captureFieldShortcutEnabled": true,
            "captureFieldShortcutKeyCode": 8, // C
            "captureFieldShortcutModifiers": 0x0100 | 0x0200, // cmd | shift
            "plainTextModifier": ModifierChoice.shift.rawValue,
            "deleteModifier": ModifierChoice.control.rawValue,
            "pinModifier": ModifierChoice.option.rawValue,
            "snippetModifier": ModifierChoice.command.rawValue,
        ]
        defaults.register(defaults: defaultValues)

        // Load values
        launchAtLogin = SMAppService.mainApp.status == .enabled
        pasteAfterSelection = defaults.bool(forKey: "pasteAfterSelection")
        maxHistoryCount = defaults.integer(forKey: "maxHistoryCount")
        sortByLastUsed = defaults.bool(forKey: "sortByLastUsed")
        statusBarIconName = defaults.string(forKey: "statusBarIconName") ?? "paperclip"

        inlineItemCount = defaults.integer(forKey: "inlineItemCount")
        folderItemCount = defaults.integer(forKey: "folderItemCount")
        menuCharacterCount = defaults.integer(forKey: "menuCharacterCount")
        handleDuplicates = defaults.bool(forKey: "handleDuplicates")
        showNumbering = defaults.bool(forKey: "showNumbering")
        numericKeySelection = defaults.bool(forKey: "numericKeySelection")
        showIconInMenu = defaults.bool(forKey: "showIconInMenu")
        showImagePreview = defaults.bool(forKey: "showImagePreview")
        imagePreviewWidth = defaults.integer(forKey: "imagePreviewWidth")
        imagePreviewHeight = defaults.integer(forKey: "imagePreviewHeight")
        showTooltips = defaults.bool(forKey: "showTooltips")
        showColorCodePreview = defaults.bool(forKey: "showColorCodePreview")

        supportPlainText = defaults.bool(forKey: "supportPlainText")
        supportRichText = defaults.bool(forKey: "supportRichText")
        supportPDF = defaults.bool(forKey: "supportPDF")
        supportFilenames = defaults.bool(forKey: "supportFilenames")
        supportURL = defaults.bool(forKey: "supportURL")
        supportImages = defaults.bool(forKey: "supportImages")
        ignoreConcealedTypes = defaults.bool(forKey: "ignoreConcealedTypes")

        excludedAppBundleIDs = defaults.stringArray(forKey: "excludedAppBundleIDs") ?? []

        mainShortcutKeyCode = UInt32(defaults.integer(forKey: "mainShortcutKeyCode"))
        mainShortcutModifiers = UInt32(defaults.integer(forKey: "mainShortcutModifiers"))
        historyShortcutEnabled = defaults.bool(forKey: "historyShortcutEnabled")
        historyShortcutKeyCode = UInt32(defaults.integer(forKey: "historyShortcutKeyCode"))
        historyShortcutModifiers = UInt32(defaults.integer(forKey: "historyShortcutModifiers"))
        snippetsShortcutEnabled = defaults.bool(forKey: "snippetsShortcutEnabled")
        snippetsShortcutKeyCode = UInt32(defaults.integer(forKey: "snippetsShortcutKeyCode"))
        snippetsShortcutModifiers = UInt32(defaults.integer(forKey: "snippetsShortcutModifiers"))
        quickSnippetShortcutEnabled = defaults.bool(forKey: "quickSnippetShortcutEnabled")
        quickSnippetShortcutKeyCode = UInt32(defaults.integer(forKey: "quickSnippetShortcutKeyCode"))
        quickSnippetShortcutModifiers = UInt32(defaults.integer(forKey: "quickSnippetShortcutModifiers"))
        captureFieldShortcutEnabled = defaults.bool(forKey: "captureFieldShortcutEnabled")
        captureFieldShortcutKeyCode = UInt32(defaults.integer(forKey: "captureFieldShortcutKeyCode"))
        captureFieldShortcutModifiers = UInt32(defaults.integer(forKey: "captureFieldShortcutModifiers"))

        autoCheckUpdates = defaults.bool(forKey: "autoCheckUpdates")
        updateCheckInterval = defaults.integer(forKey: "updateCheckInterval")
        lastUpdateCheckAt = defaults.double(forKey: "lastUpdateCheckAt")

        pasteAsPlainText = defaults.bool(forKey: "pasteAsPlainText")
        deleteAfterPaste = defaults.bool(forKey: "deleteAfterPaste")
        saveScreenshots = defaults.bool(forKey: "saveScreenshots")
        watchScreenshotFiles = defaults.bool(forKey: "watchScreenshotFiles")
        enableOCR = defaults.bool(forKey: "enableOCR")

        plainTextModifierRaw = defaults.string(forKey: "plainTextModifier") ?? ModifierChoice.shift.rawValue
        deleteModifierRaw = defaults.string(forKey: "deleteModifier") ?? ModifierChoice.control.rawValue
        pinModifierRaw = defaults.string(forKey: "pinModifier") ?? ModifierChoice.option.rawValue
        snippetModifierRaw = defaults.string(forKey: "snippetModifier") ?? ModifierChoice.command.rawValue
    }

    // MARK: - Helpers

    /// Available status bar icon choices
    static let statusBarIconOptions: [(name: String, symbol: String)] = [
        ("クリップ", "paperclip"),
        ("クリップボード", "doc.on.clipboard"),
        ("書類", "doc.text"),
        ("スタック", "square.stack"),
    ]

    /// Human-readable shortcut string for the main hotkey
    var mainShortcutDisplayString: String {
        Self.displayString(keyCode: mainShortcutKeyCode, modifiers: mainShortcutModifiers)
    }

    /// Compact symbol representation e.g. "⌘⇧V"
    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts = ""
        if modifiers & carbonControl != 0 { parts += "⌃" }
        if modifiers & carbonOption != 0 { parts += "⌥" }
        if modifiers & carbonShift != 0 { parts += "⇧" }
        if modifiers & carbonCmd != 0 { parts += "⌘" }
        return parts + keyCodeToString(keyCode)
    }

    static func keyCodeToString(_ keyCode: UInt32) -> String {
        let map: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
            38: "J", 40: "K", 45: "N", 46: "M",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "5", 23: "6",
            26: "7", 28: "8", 25: "9", 29: "0",
            24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";",
            42: "\\", 43: ",", 44: "/", 47: ".", 50: "`",
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        return map[keyCode] ?? "Key(\(keyCode))"
    }

    /// Convert NSEvent modifier flags to Carbon modifiers
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= carbonCmd }
        if flags.contains(.shift) { carbon |= carbonShift }
        if flags.contains(.option) { carbon |= carbonOption }
        if flags.contains(.control) { carbon |= carbonControl }
        return carbon
    }
}
