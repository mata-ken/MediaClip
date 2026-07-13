import Foundation

/// Clipy-compatible snippet XML import/export.
/// Format: <folders> > <folder> > <title> + <snippets> > <snippet> > <title>/<content>
enum SnippetXMLService {
    struct ImportedFolder {
        let title: String
        let snippets: [(title: String, content: String)]
    }

    enum XMLError: LocalizedError {
        case invalidFormat

        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "XMLの形式が正しくありません（Clipy形式の <folders> ルート要素が必要です）"
            }
        }
    }

    // MARK: - Export

    static func exportXML(folders: [SnippetFolder], snippetsForFolder: (UUID?) -> [Snippet]) -> Data {
        let root = XMLElement(name: "folders")
        let doc = XMLDocument(rootElement: root)
        doc.version = "1.0"
        doc.characterEncoding = "UTF-8"

        func addFolder(title: String, snippets: [Snippet]) {
            let folderEl = XMLElement(name: "folder")
            folderEl.addChild(XMLElement(name: "title", stringValue: title))
            let snippetsEl = XMLElement(name: "snippets")
            for snippet in snippets {
                let snippetEl = XMLElement(name: "snippet")
                snippetEl.addChild(XMLElement(name: "title", stringValue: snippet.title))
                snippetEl.addChild(XMLElement(name: "content", stringValue: snippet.content))
                snippetsEl.addChild(snippetEl)
            }
            folderEl.addChild(snippetsEl)
            root.addChild(folderEl)
        }

        for folder in folders {
            addFolder(title: folder.name, snippets: snippetsForFolder(folder.id))
        }
        // Clipy has no "unfoldered" concept; wrap them in a pseudo folder
        let unfoldered = snippetsForFolder(nil)
        if !unfoldered.isEmpty {
            addFolder(title: "未分類", snippets: unfoldered)
        }

        return doc.xmlData(options: .nodePrettyPrint)
    }

    // MARK: - Import

    static func importXML(data: Data) throws -> [ImportedFolder] {
        let doc = try XMLDocument(data: data)
        guard let root = doc.rootElement(), root.name == "folders" else {
            throw XMLError.invalidFormat
        }

        var result: [ImportedFolder] = []
        for folderEl in root.elements(forName: "folder") {
            let title = folderEl.elements(forName: "title").first?.stringValue ?? "untitled folder"
            var snippets: [(title: String, content: String)] = []
            if let snippetsEl = folderEl.elements(forName: "snippets").first {
                for snippetEl in snippetsEl.elements(forName: "snippet") {
                    let snippetTitle = snippetEl.elements(forName: "title").first?.stringValue ?? "untitled snippet"
                    let content = snippetEl.elements(forName: "content").first?.stringValue ?? ""
                    snippets.append((title: snippetTitle, content: content))
                }
            }
            result.append(ImportedFolder(title: title, snippets: snippets))
        }
        return result
    }
}
