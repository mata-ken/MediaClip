import SwiftUI

/// Represents either a folder or a snippet in the sidebar tree
enum SidebarItem: Hashable {
    case folder(UUID)
    case snippet(UUID)
}

struct SnippetManagerView: View {
    @ObservedObject private var storage = StorageManager.shared
    @State private var selection: SidebarItem?
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var editingContent = ""
    @State private var editingTitle = ""
    @State private var expandedFolders: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar (like Clipy)
            toolbar

            Divider()

            // Main content: sidebar + editor
            HSplitView {
                sidebarView
                    .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)

                editorView
                    .frame(minWidth: 300)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .alert("新しいフォルダ", isPresented: $showNewFolderAlert) {
            TextField("フォルダ名", text: $newFolderName)
            Button("作成") {
                if !newFolderName.isEmpty {
                    let folder = SnippetFolder(name: newFolderName, sortOrder: storage.folders.count)
                    storage.addFolder(folder)
                    newFolderName = ""
                }
            }
            Button("キャンセル", role: .cancel) {
                newFolderName = ""
            }
        }
        .onAppear {
            // Expand all folders by default
            expandedFolders = Set(storage.folders.map(\.id))
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 2) {
            toolbarButton("スニペット追加", systemImage: "doc.badge.plus") {
                addSnippet()
            }

            toolbarButton("フォルダ追加", systemImage: "folder.badge.plus") {
                showNewFolderAlert = true
            }

            toolbarButton("削除", systemImage: "minus.square") {
                deleteSelected()
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func toolbarButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 10))
            }
            .frame(width: 70, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    // MARK: - Sidebar (tree view with folders and snippets)

    private var sidebarView: some View {
        List(selection: $selection) {
            ForEach(storage.folders) { folder in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedFolders.contains(folder.id) },
                        set: { isExpanded in
                            if isExpanded {
                                expandedFolders.insert(folder.id)
                            } else {
                                expandedFolders.remove(folder.id)
                            }
                        }
                    )
                ) {
                    let snippets = storage.snippetsForFolder(folder.id)
                    ForEach(snippets) { snippet in
                        Label(snippet.title, systemImage: "doc.text")
                            .tag(SidebarItem.snippet(snippet.id))
                    }
                } label: {
                    Label(folder.name, systemImage: "folder")
                        .tag(SidebarItem.folder(folder.id))
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: selection) { _, newValue in
            loadSelection(newValue)
        }
    }

    // MARK: - Editor (right panel)

    private var editorView: some View {
        VStack(spacing: 0) {
            switch selection {
            case .folder(let folderID):
                folderDetailView(folderID: folderID)
            case .snippet(let snippetID):
                snippetDetailView(snippetID: snippetID)
            case nil:
                emptyDetailView
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func folderDetailView(folderID: UUID) -> some View {
        VStack {
            Spacer()
            if let folder = storage.folders.first(where: { $0.id == folderID }) {
                Label(folder.name, systemImage: "folder")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("スニペット数: \(storage.snippetsForFolder(folderID).count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func snippetDetailView(snippetID: UUID) -> some View {
        VStack(spacing: 0) {
            if storage.snippets.first(where: { $0.id == snippetID }) != nil {
                TextEditor(text: $editingContent)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .onChange(of: editingContent) { _, newValue in
                        saveCurrentSnippet()
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyDetailView: some View {
        VStack {
            Spacer()
            Text("スニペットまたはフォルダを選択してください")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func addSnippet() {
        // Add to currently selected folder, or no folder
        var folderID: UUID?
        if case .folder(let id) = selection {
            folderID = id
        } else if case .snippet(let snippetID) = selection,
                  let snippet = storage.snippets.first(where: { $0.id == snippetID }) {
            folderID = snippet.folderID
        }

        // If there's already an empty "新しいスニペット" in this folder, select it instead
        let existingEmpty = storage.snippetsForFolder(folderID).first {
            $0.title == "新しいスニペット" && $0.content.isEmpty
        }
        if let existing = existingEmpty {
            if let folderID {
                expandedFolders.insert(folderID)
            }
            selection = .snippet(existing.id)
            return
        }

        let snippet = Snippet(
            title: "新しいスニペット",
            content: "",
            folderID: folderID,
            sortOrder: storage.snippets.count
        )
        storage.addSnippet(snippet)

        if let folderID {
            expandedFolders.insert(folderID)
        }
        selection = .snippet(snippet.id)
    }

    private func deleteSelected() {
        guard let selection else { return }
        switch selection {
        case .folder(let folderID):
            if let folder = storage.folders.first(where: { $0.id == folderID }) {
                storage.deleteFolder(folder)
            }
            self.selection = nil
        case .snippet(let snippetID):
            if let snippet = storage.snippets.first(where: { $0.id == snippetID }) {
                storage.deleteSnippet(snippet)
            }
            self.selection = nil
        }
    }

    private func loadSelection(_ item: SidebarItem?) {
        guard let item else { return }
        if case .snippet(let snippetID) = item,
           let snippet = storage.snippets.first(where: { $0.id == snippetID }) {
            editingTitle = snippet.title
            editingContent = snippet.content
        }
    }

    private func saveCurrentSnippet() {
        if case .snippet(let snippetID) = selection,
           let snippet = storage.snippets.first(where: { $0.id == snippetID }) {
            snippet.content = editingContent
            storage.updateSnippet(snippet)
        }
    }
}
