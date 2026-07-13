import Foundation
import AppKit

/// Lightweight update check against GitHub Releases (no Sparkle, no telemetry)
enum UpdateChecker {
    static let repoPage = "https://github.com/mata-ken/MediaClip"
    private static let latestReleaseAPI = "https://api.github.com/repos/mata-ken/MediaClip/releases/latest"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    enum CheckResult {
        case upToDate(current: String)
        case updateAvailable(current: String, latest: String, url: String)
        case failed(String)
    }

    static func check(completion: @escaping (CheckResult) -> Void) {
        guard let url = URL(string: latestReleaseAPI) else {
            completion(.failed("URLが不正です"))
            return
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                UserSettings.shared.lastUpdateCheckAt = Date().timeIntervalSince1970

                if let error {
                    completion(.failed(error.localizedDescription))
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String else {
                    completion(.failed("リリース情報を取得できませんでした"))
                    return
                }
                let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                let current = currentVersion
                let htmlURL = (json["html_url"] as? String) ?? repoPage + "/releases"
                if isNewer(latest, than: current) {
                    completion(.updateAvailable(current: current, latest: latest, url: htmlURL))
                } else {
                    completion(.upToDate(current: current))
                }
            }
        }.resume()
    }

    /// Semver-ish comparison: "1.2.0" > "1.1.9"
    static func isNewer(_ a: String, than b: String) -> Bool {
        let av = a.split(separator: ".").map { Int($0) ?? 0 }
        let bv = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(av.count, bv.count) {
            let x = i < av.count ? av[i] : 0
            let y = i < bv.count ? bv[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Startup auto-check honoring the user's interval setting
    static func autoCheckIfNeeded() {
        let settings = UserSettings.shared
        guard settings.autoCheckUpdates else { return }
        let elapsed = Date().timeIntervalSince1970 - settings.lastUpdateCheckAt
        guard elapsed >= Double(settings.updateCheckInterval) else { return }

        check { result in
            if case .updateAvailable(let current, let latest, let url) = result {
                presentUpdateAlert(current: current, latest: latest, url: url)
            }
        }
    }

    static func presentUpdateAlert(current: String, latest: String, url: String) {
        let alert = NSAlert()
        alert.messageText = "新しいバージョンがあります"
        alert.informativeText = "MediaClip v\(latest) が公開されています（現在: v\(current)）"
        alert.addButton(withTitle: "ダウンロードページを開く")
        alert.addButton(withTitle: "後で")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, let pageURL = URL(string: url) {
            NSWorkspace.shared.open(pageURL)
        }
    }
}
