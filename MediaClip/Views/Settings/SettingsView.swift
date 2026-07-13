import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("一般", systemImage: "gear") }

            MenuSettingsTab()
                .tabItem { Label("メニュー", systemImage: "list.bullet") }

            FormatSettingsTab()
                .tabItem { Label("対応形式", systemImage: "doc.badge.gearshape") }

            ExcludedAppsSettingsTab()
                .tabItem { Label("除外アプリ", systemImage: "xmark.app") }

            ShortcutSettingsTab()
                .tabItem { Label("ショートカット", systemImage: "keyboard") }

            UpdateSettingsTab()
                .tabItem { Label("アップデート", systemImage: "arrow.triangle.2.circlepath") }

            BetaSettingsTab()
                .tabItem { Label("ベータ", systemImage: "flask") }
        }
        .frame(width: 540, height: 440)
    }
}

// MARK: - 一般 (General)

struct GeneralSettingsTab: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("ログイン時に起動", isOn: $settings.launchAtLogin)
            }

            Section {
                Toggle("メニュー項目選択後に自動ペースト (Cmd+V)", isOn: $settings.pasteAfterSelection)
            }

            Section {
                HStack {
                    Text("履歴の保存件数")
                    Spacer()
                    Picker("", selection: $settings.maxHistoryCount) {
                        Text("10").tag(10)
                        Text("20").tag(20)
                        Text("30").tag(30)
                        Text("50").tag(50)
                        Text("100").tag(100)
                    }
                    .frame(width: 100)
                }

                Toggle("ペーストしたアイテムを先頭に並べ替え", isOn: $settings.sortByLastUsed)
            }

            Section("ステータスバーアイコン") {
                Picker("アイコン", selection: $settings.statusBarIconName) {
                    ForEach(UserSettings.statusBarIconOptions, id: \.symbol) { option in
                        Label(option.name, systemImage: option.symbol)
                            .tag(option.symbol)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("権限") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("アクセシビリティ")
                        Text("他のアプリへのペースト・選択テキスト取得に必要")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if AXIsProcessTrusted() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("許可済み")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Button("アクセスを許可") {
                            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
                            AXIsProcessTrustedWithOptions(options)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal)
    }
}

// MARK: - メニュー (Menu)

struct MenuSettingsTab: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        Form {
            Section("表示設定") {
                HStack {
                    Text("インライン表示数")
                    Spacer()
                    Picker("", selection: $settings.inlineItemCount) {
                        Text("0 (すべてフォルダ)").tag(0)
                        Text("5").tag(5)
                        Text("10").tag(10)
                        Text("15").tag(15)
                        Text("20").tag(20)
                    }
                    .frame(width: 180)
                }

                HStack {
                    Text("フォルダ内の表示数")
                    Spacer()
                    Picker("", selection: $settings.folderItemCount) {
                        Text("5").tag(5)
                        Text("10").tag(10)
                        Text("15").tag(15)
                        Text("20").tag(20)
                    }
                    .frame(width: 100)
                }

                HStack {
                    Text("メニュー表示文字数")
                    Spacer()
                    Picker("", selection: $settings.menuCharacterCount) {
                        Text("20").tag(20)
                        Text("30").tag(30)
                        Text("40").tag(40)
                        Text("50").tag(50)
                        Text("70").tag(70)
                        Text("100").tag(100)
                    }
                    .frame(width: 100)
                }
            }

            Section("動作") {
                Toggle("同じ内容の重複を排除", isOn: $settings.handleDuplicates)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("数字キー (1-9, 0) で選択", isOn: $settings.numericKeySelection)
                    Text("メニュー表示中に数字キーを押すと、テキスト履歴の先頭10件を直接選択できます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("メニュー外観") {
                Toggle("番号を表示", isOn: $settings.showNumbering)
                Toggle("アイコンを表示", isOn: $settings.showIconInMenu)
                Toggle("ツールチップを表示", isOn: $settings.showTooltips)
                Toggle("カラーコードのプレビュー表示", isOn: $settings.showColorCodePreview)
            }

            Section("画像プレビュー") {
                Toggle("メニューに画像プレビューを表示", isOn: $settings.showImagePreview)

                if settings.showImagePreview {
                    HStack {
                        Text("サイズ")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("幅", value: $settings.imagePreviewWidth, format: .number)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                            Text("x")
                            TextField("高さ", value: $settings.imagePreviewHeight, format: .number)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                            Text("px")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal)
    }
}

// MARK: - 対応形式 (Supported Formats)

struct FormatSettingsTab: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        Form {
            Section("クリップボード監視する形式") {
                Toggle("プレーンテキスト", isOn: $settings.supportPlainText)
                Toggle("リッチテキスト (RTF)", isOn: $settings.supportRichText)
                Toggle("PDF", isOn: $settings.supportPDF)
                Toggle("ファイル", isOn: $settings.supportFilenames)
                Toggle("URL", isOn: $settings.supportURL)
                Toggle("画像・動画", isOn: $settings.supportImages)
            }

            Section("セキュリティ") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("機密データを無視", isOn: $settings.ignoreConcealedTypes)
                    Text("パスワードマネージャ (1Password 等) がコピーする機密データを履歴に保存しません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("チェックを外した形式はクリップボード履歴に保存されません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal)
    }
}

// MARK: - 除外アプリ (Excluded Apps)

struct ExcludedAppsSettingsTab: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var showAppPicker = false

    var body: some View {
        VStack(spacing: 0) {
            Text("以下のアプリからのコピーは履歴に保存されません")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 12)

            List {
                ForEach(settings.excludedAppBundleIDs, id: \.self) { bundleID in
                    HStack {
                        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(appNameFromBundleID(bundleID))
                        } else {
                            Image(systemName: "app")
                                .frame(width: 20, height: 20)
                            Text(bundleID)
                        }
                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    settings.excludedAppBundleIDs.remove(atOffsets: indexSet)
                }
            }
            .listStyle(.bordered)
            .frame(minHeight: 200)

            HStack {
                Button(action: { showAppPicker = true }) {
                    Image(systemName: "plus")
                }
                Button(action: removeSelectedApp) {
                    Image(systemName: "minus")
                }
                Spacer()
            }
            .padding(8)
        }
        .padding(.horizontal)
        .fileImporter(
            isPresented: $showAppPicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                if let bundle = Bundle(url: url), let id = bundle.bundleIdentifier {
                    if !settings.excludedAppBundleIDs.contains(id) {
                        settings.excludedAppBundleIDs.append(id)
                    }
                }
            }
        }
    }

    private func removeSelectedApp() {
        if !settings.excludedAppBundleIDs.isEmpty {
            settings.excludedAppBundleIDs.removeLast()
        }
    }

    private func appNameFromBundleID(_ bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleID
    }
}

// MARK: - ショートカット (Shortcuts)

struct ShortcutSettingsTab: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        Form {
            Section("グローバルショートカット") {
                HStack {
                    Text("メインメニュー（履歴＋スニペット）")
                    Spacer()
                    ShortcutRecorderField(
                        keyCode: $settings.mainShortcutKeyCode,
                        modifiers: $settings.mainShortcutModifiers,
                        onChange: { AppDelegate.reloadHotKeys() }
                    )
                    .frame(width: 130, height: 24)
                }

                shortcutToggleRow(
                    "履歴のみ表示",
                    enabled: $settings.historyShortcutEnabled,
                    keyCode: $settings.historyShortcutKeyCode,
                    modifiers: $settings.historyShortcutModifiers
                )

                shortcutToggleRow(
                    "スニペットのみ表示",
                    enabled: $settings.snippetsShortcutEnabled,
                    keyCode: $settings.snippetsShortcutKeyCode,
                    modifiers: $settings.snippetsShortcutModifiers
                )

                shortcutToggleRow(
                    "クイックスニペット登録（選択テキスト）",
                    enabled: $settings.quickSnippetShortcutEnabled,
                    keyCode: $settings.quickSnippetShortcutKeyCode,
                    modifiers: $settings.quickSnippetShortcutModifiers
                )

                shortcutToggleRow(
                    "入力欄の内容を履歴に取り込む（音声入力の救済）",
                    enabled: $settings.captureFieldShortcutEnabled,
                    keyCode: $settings.captureFieldShortcutKeyCode,
                    modifiers: $settings.captureFieldShortcutModifiers
                )
            }

            Section {
                Text("フィールドをクリックしてキーを押すと変更できます（Escでキャンセル・修飾キー必須）。\nスニペットフォルダごとのホットキーは「スニペット編集」画面で設定できます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal)
        .onChange(of: settings.historyShortcutEnabled) { _, _ in AppDelegate.reloadHotKeys() }
        .onChange(of: settings.snippetsShortcutEnabled) { _, _ in AppDelegate.reloadHotKeys() }
        .onChange(of: settings.quickSnippetShortcutEnabled) { _, _ in AppDelegate.reloadHotKeys() }
        .onChange(of: settings.captureFieldShortcutEnabled) { _, _ in AppDelegate.reloadHotKeys() }
    }

    @ViewBuilder
    private func shortcutToggleRow(
        _ label: String,
        enabled: Binding<Bool>,
        keyCode: Binding<UInt32>,
        modifiers: Binding<UInt32>
    ) -> some View {
        HStack {
            Toggle(label, isOn: enabled)
            Spacer()
            if enabled.wrappedValue {
                ShortcutRecorderField(
                    keyCode: keyCode,
                    modifiers: modifiers,
                    onChange: { AppDelegate.reloadHotKeys() }
                )
                .frame(width: 130, height: 24)
            }
        }
    }
}

// MARK: - アップデート (Update)

struct UpdateSettingsTab: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var checking = false
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle("自動的にアップデートを確認", isOn: $settings.autoCheckUpdates)

                if settings.autoCheckUpdates {
                    HStack {
                        Text("確認頻度")
                        Spacer()
                        Picker("", selection: $settings.updateCheckInterval) {
                            Text("毎日").tag(86400)
                            Text("毎週").tag(604800)
                            Text("毎月").tag(2592000)
                        }
                        .frame(width: 120)
                    }
                }
            }

            Section {
                HStack {
                    Text("現在のバージョン")
                    Spacer()
                    Text(UpdateChecker.currentVersion)
                        .foregroundStyle(.secondary)
                }

                if settings.lastUpdateCheckAt > 0 {
                    HStack {
                        Text("最終確認")
                        Spacer()
                        Text(Date(timeIntervalSince1970: settings.lastUpdateCheckAt)
                            .formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Button(checking ? "確認中..." : "アップデートを確認") {
                        checking = true
                        statusMessage = nil
                        UpdateChecker.check { result in
                            checking = false
                            switch result {
                            case .upToDate(let current):
                                statusMessage = "最新版です (v\(current))"
                            case .updateAvailable(let current, let latest, let url):
                                statusMessage = "新しいバージョン v\(latest) があります"
                                UpdateChecker.presentUpdateAlert(current: current, latest: latest, url: url)
                            case .failed(let message):
                                statusMessage = "確認失敗: \(message)"
                            }
                        }
                    }
                    .disabled(checking)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal)
    }
}

// MARK: - ベータ機能 (Beta)

struct BetaSettingsTab: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        Form {
            Section("修飾キー + クリックのアクション（履歴アイテム）") {
                modifierPicker("プレーンテキストでペースト", selection: $settings.plainTextModifierRaw)
                modifierPicker("履歴から削除", selection: $settings.deleteModifierRaw)
                modifierPicker("ピン留め / 解除", selection: $settings.pinModifierRaw)
                modifierPicker("スニペットに登録", selection: $settings.snippetModifierRaw)
                Text("修飾キーを押しながら履歴アイテムを選択すると、ペーストの代わりに上記アクションを実行します")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("実験的機能") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("常にプレーンテキストとしてペースト", isOn: $settings.pasteAsPlainText)
                    Text("リッチテキストの書式を除去してペーストします")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("ペースト後に履歴から削除", isOn: $settings.deleteAfterPaste)
                    Text("ペーストしたアイテムを自動的に履歴から削除します")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("クリップボードの画像を自動保存", isOn: $settings.saveScreenshots)
                    Text("コピーされた画像（スクリーンショット等）をクリップボード履歴に保存します")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("スクリーンショットのファイル保存を監視", isOn: $settings.watchScreenshotFiles)
                    Text("ファイルとして保存されたスクリーンショットも履歴に取り込みます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("画像の文字認識 (OCR)", isOn: $settings.enableOCR)
                    Text("画像内のテキストを認識して検索できるようにします（オンデバイス処理）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func modifierPicker(_ label: String, selection: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Picker("", selection: selection) {
                ForEach(ModifierChoice.allCases) { choice in
                    Text(choice.displayName).tag(choice.rawValue)
                }
            }
            .frame(width: 140)
        }
    }
}
