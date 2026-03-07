import Foundation
import AppKit
import Combine

final class StorageManager: ObservableObject {
    static let shared = StorageManager()
    static var maxHistoryCount: Int {
        UserSettings.shared.maxHistoryCount
    }

    let baseDirectory: URL
    let mediaDirectory: URL
    let imagesDirectory: URL
    let thumbnailsDirectory: URL

    @Published var clipboardItems: [ClipboardItem] = []
    @Published var snippets: [Snippet] = []
    @Published var folders: [SnippetFolder] = []

    private let historyFile: URL
    private let snippetsFile: URL
    private let foldersFile: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseDirectory = appSupport.appendingPathComponent("MediaClip", isDirectory: true)
        mediaDirectory = baseDirectory.appendingPathComponent("media", isDirectory: true)
        imagesDirectory = baseDirectory.appendingPathComponent("images", isDirectory: true)
        thumbnailsDirectory = baseDirectory.appendingPathComponent("thumbnails", isDirectory: true)

        historyFile = baseDirectory.appendingPathComponent("history.json")
        snippetsFile = baseDirectory.appendingPathComponent("snippets.json")
        foldersFile = baseDirectory.appendingPathComponent("folders.json")

        let fm = FileManager.default
        try? fm.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try? fm.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        try? fm.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try? fm.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        loadAll()
    }

    // MARK: - Clipboard Items

    func addClipboardItem(_ item: ClipboardItem) {
        clipboardItems.insert(item, at: 0)
        enforceHistoryLimit()
        saveHistory()
    }

    func deleteClipboardItem(_ item: ClipboardItem) {
        if let imageFile = item.imageFileName {
            try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(imageFile))
        }
        if let thumbFile = item.thumbnailFileName {
            try? FileManager.default.removeItem(at: thumbnailsDirectory.appendingPathComponent(thumbFile))
        }
        if let path = item.mediaFilePath {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
        }
        clipboardItems.removeAll { $0.id == item.id }
        saveHistory()
    }

    func clearUnpinnedItems() {
        let unpinned = clipboardItems.filter { !$0.isPinned }
        for item in unpinned {
            if let imageFile = item.imageFileName {
                try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(imageFile))
            }
            if let thumbFile = item.thumbnailFileName {
                try? FileManager.default.removeItem(at: thumbnailsDirectory.appendingPathComponent(thumbFile))
            }
            if let path = item.mediaFilePath {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
            }
        }
        clipboardItems.removeAll { !$0.isPinned }
        saveHistory()
    }

    func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
        saveHistory()
    }

    func saveImageData(_ data: Data) -> String {
        let fileName = "\(UUID().uuidString).png"
        let url = imagesDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)
        return fileName
    }

    func saveThumbnailData(_ data: Data) -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let url = thumbnailsDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)
        return fileName
    }

    func loadImageData(fileName: String) -> Data? {
        try? Data(contentsOf: imagesDirectory.appendingPathComponent(fileName))
    }

    func loadThumbnailData(fileName: String) -> Data? {
        try? Data(contentsOf: thumbnailsDirectory.appendingPathComponent(fileName))
    }

    func saveVideoFile(from sourceURL: URL) -> String? {
        let fileName = "\(UUID().uuidString).\(sourceURL.pathExtension)"
        let destURL = mediaDirectory.appendingPathComponent(fileName)

        // Simple dedup by file size
        if let sourceSize = try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int,
           let existing = findExistingVideo(size: sourceSize) {
            return existing
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return destURL.path
        } catch {
            return nil
        }
    }

    // MARK: - Snippets

    func addSnippet(_ snippet: Snippet) {
        snippets.append(snippet)
        saveSnippets()
    }

    func updateSnippet(_ snippet: Snippet) {
        saveSnippets()
    }

    func deleteSnippet(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        saveSnippets()
    }

    func snippetsForFolder(_ folderID: UUID?) -> [Snippet] {
        snippets.filter { $0.folderID == folderID }.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Folders

    func addFolder(_ folder: SnippetFolder) {
        folders.append(folder)
        saveFolders()
    }

    func deleteFolder(_ folder: SnippetFolder) {
        // Delete all snippets in folder
        snippets.removeAll { $0.folderID == folder.id }
        folders.removeAll { $0.id == folder.id }
        saveFolders()
        saveSnippets()
    }

    // MARK: - Storage Info

    var storageUsage: String {
        var totalSize: Int64 = 0
        let dirs = [mediaDirectory, imagesDirectory, thumbnailsDirectory]
        for dir in dirs {
            if let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
                while let url = enumerator.nextObject() as? URL {
                    if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += Int64(size)
                    }
                }
            }
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }

    // MARK: - Private

    private func enforceHistoryLimit() {
        let unpinned = clipboardItems.filter { !$0.isPinned }
        if unpinned.count > Self.maxHistoryCount {
            let excess = Array(unpinned.dropFirst(Self.maxHistoryCount))
            for item in excess {
                deleteClipboardItem(item)
            }
        }
    }

    private func findExistingVideo(size: Int) -> String? {
        guard let files = try? FileManager.default.contentsOfDirectory(at: mediaDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return nil
        }
        for file in files {
            if let fileSize = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, fileSize == size {
                return file.path
            }
        }
        return nil
    }

    private func loadAll() {
        clipboardItems = load(from: historyFile) ?? []
        snippets = load(from: snippetsFile) ?? []
        folders = load(from: foldersFile) ?? []
    }

    private func saveHistory() {
        save(clipboardItems, to: historyFile)
    }

    private func saveSnippets() {
        save(snippets, to: snippetsFile)
    }

    private func saveFolders() {
        save(folders, to: foldersFile)
    }

    private func save<T: Encodable>(_ items: [T], to url: URL) {
        if let data = try? encoder.encode(items) {
            try? data.write(to: url)
        }
    }

    private func load<T: Decodable>(from url: URL) -> [T]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode([T].self, from: data)
    }
}
