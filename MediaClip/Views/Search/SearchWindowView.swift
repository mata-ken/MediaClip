import SwiftUI
import AppKit

/// Incremental search across clipboard history (incl. image OCR text) and snippets.
/// Click a row (or press Return for the top hit) to paste it.
struct SearchWindowView: View {
    @ObservedObject private var storage = StorageManager.shared
    @State private var query = ""
    @FocusState private var searchFieldFocused: Bool

    var onPasteItem: (ClipboardItem) -> Void
    var onPasteSnippet: (Snippet) -> Void

    private var filteredItems: [ClipboardItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return Array(storage.clipboardItems.prefix(30)) }
        return storage.clipboardItems.filter { item in
            (item.textContent?.lowercased().contains(q) ?? false)
                || (item.ocrText?.lowercased().contains(q) ?? false)
                || item.previewText.lowercased().contains(q)
        }
    }

    private var filteredSnippets: [Snippet] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return storage.snippets.filter {
            $0.title.lowercased().contains(q) || $0.content.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("履歴・スニペットを検索（画像はOCRテキストも対象）", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFieldFocused)
                .padding(10)
                .onSubmit {
                    if let first = filteredItems.first {
                        onPasteItem(first)
                    } else if let snippet = filteredSnippets.first {
                        onPasteSnippet(snippet)
                    }
                }

            Divider()

            List {
                Section("履歴 (\(filteredItems.count))") {
                    ForEach(filteredItems) { item in
                        Button {
                            onPasteItem(item)
                        } label: {
                            historyRow(item)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !filteredSnippets.isEmpty {
                    Section("スニペット (\(filteredSnippets.count))") {
                        ForEach(filteredSnippets) { snippet in
                            Button {
                                onPasteSnippet(snippet)
                            } label: {
                                snippetRow(snippet)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(minWidth: 420, minHeight: 320)
        .onAppear {
            searchFieldFocused = true
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func historyRow(_ item: ClipboardItem) -> some View {
        HStack(spacing: 8) {
            if item.contentType == .image || item.contentType == .video,
               let thumbName = item.thumbnailFileName,
               let data = storage.loadThumbnailData(fileName: thumbName),
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: item.contentType.systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(rowTitle(for: item))
                    .font(.system(size: 12))
                    .lineLimit(2)
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if item.isPinned {
                Text("📌")
            }
        }
        .contentShape(Rectangle())
    }

    private func rowTitle(for item: ClipboardItem) -> String {
        switch item.contentType {
        case .image:
            if let ocr = item.ocrText, !ocr.isEmpty {
                return "🖼 " + String(ocr.replacingOccurrences(of: "\n", with: " ").prefix(80))
            }
            return "🖼 画像"
        case .video:
            return "🎬 動画"
        default:
            return String(item.previewText.prefix(120))
        }
    }

    @ViewBuilder
    private func snippetRow(_ snippet: Snippet) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(snippet.content.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
