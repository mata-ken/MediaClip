import Foundation
import AppKit

/// Watches for newly saved screenshot files via Spotlight metadata
/// and reports them so they can be added to clipboard history.
final class ScreenshotWatcher {
    private var query: NSMetadataQuery?
    private var seenPaths = Set<String>()

    /// Called on the main queue with the URL of a newly saved screenshot
    var onScreenshot: ((URL) -> Void)?

    func start() {
        guard query == nil else { return }

        let q = NSMetadataQuery()
        q.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
        q.searchScopes = [NSMetadataQueryUserHomeScope]

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(initialGatherComplete(_:)),
            name: .NSMetadataQueryDidFinishGathering,
            object: q
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryUpdated(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: q
        )
        q.start()
        query = q
    }

    func stop() {
        guard let q = query else { return }
        q.stop()
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: q)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: q)
        query = nil
        seenPaths.removeAll()
    }

    @objc private func initialGatherComplete(_ note: Notification) {
        // Mark pre-existing screenshots as seen so only new ones are captured
        guard let q = query else { return }
        q.disableUpdates()
        defer { q.enableUpdates() }
        for i in 0..<q.resultCount {
            if let item = q.result(at: i) as? NSMetadataItem,
               let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
                seenPaths.insert(path)
            }
        }
    }

    @objc private func queryUpdated(_ note: Notification) {
        guard let q = query else { return }
        q.disableUpdates()
        defer { q.enableUpdates() }

        for i in 0..<q.resultCount {
            guard let item = q.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  !seenPaths.contains(path) else { continue }
            seenPaths.insert(path)

            let url = URL(fileURLWithPath: path)
            // Small delay so the screenshot file is fully written
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.onScreenshot?(url)
            }
        }
    }
}
