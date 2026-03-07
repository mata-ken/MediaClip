import Foundation
import AppKit
import Combine
import ServiceManagement

final class UserSettings: ObservableObject {
    static let shared = UserSettings()

    private let defaults = UserDefaults.standard

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

    // MARK: - 除外アプリ (Excluded Apps)

    @Published var excludedAppBundleIDs: [String] {
        didSet { defaults.set(excludedAppBundleIDs, forKey: "excludedAppBundleIDs") }
    }

    // MARK: - ショートカット (Shortcuts)

    @Published var mainShortcutKeyCode: UInt32 {
        didSet { defaults.set(mainShortcutKeyCode, forKey: "mainShortcutKeyCode") }
    }

    @Published var mainShortcutModifiers: UInt32 {
        didSet { defaults.set(mainShortcutModifiers, forKey: "mainShortcutModifiers") }
    }

    // MARK: - アップデート (Update)

    @Published var autoCheckUpdates: Bool {
        didSet { defaults.set(autoCheckUpdates, forKey: "autoCheckUpdates") }
    }

    @Published var updateCheckInterval: Int {
        didSet { defaults.set(updateCheckInterval, forKey: "updateCheckInterval") }
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
            "showIconInMenu": true,
            "showImagePreview": true,
            "imagePreviewWidth": 100,
            "imagePreviewHeight": 32,
            "showTooltips": true,
            "showColorCodePreview": false,
            "supportPlainText": true,
            "supportRichText": true,
            "supportPDF": false,
            "supportFilenames": true,
            "supportURL": true,
            "supportImages": true,
            "autoCheckUpdates": true,
            "updateCheckInterval": 86400,
            "pasteAsPlainText": false,
            "deleteAfterPaste": false,
            "saveScreenshots": true,
            "mainShortcutKeyCode": 9,    // kVK_ANSI_V
            "mainShortcutModifiers": 0x0100 | 0x0200, // cmdKey | shiftKey
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

        excludedAppBundleIDs = defaults.stringArray(forKey: "excludedAppBundleIDs") ?? []

        mainShortcutKeyCode = UInt32(defaults.integer(forKey: "mainShortcutKeyCode"))
        mainShortcutModifiers = UInt32(defaults.integer(forKey: "mainShortcutModifiers"))

        autoCheckUpdates = defaults.bool(forKey: "autoCheckUpdates")
        updateCheckInterval = defaults.integer(forKey: "updateCheckInterval")

        pasteAsPlainText = defaults.bool(forKey: "pasteAsPlainText")
        deleteAfterPaste = defaults.bool(forKey: "deleteAfterPaste")
        saveScreenshots = defaults.bool(forKey: "saveScreenshots")
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
        var parts: [String] = []
        if mainShortcutModifiers & 0x0100 != 0 { parts.append("Cmd") }
        if mainShortcutModifiers & 0x0200 != 0 { parts.append("Shift") }
        if mainShortcutModifiers & 0x0800 != 0 { parts.append("Option") }
        if mainShortcutModifiers & 0x1000 != 0 { parts.append("Control") }

        let keyName = keyCodeToString(mainShortcutKeyCode)
        parts.append(keyName)
        return parts.joined(separator: " + ")
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        let map: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
            38: "J", 40: "K", 45: "N", 46: "M",
        ]
        return map[keyCode] ?? "Key(\(keyCode))"
    }
}
