import Foundation

final class Snippet: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var folderID: UUID?
    var sortOrder: Int

    init(title: String, content: String, folderID: UUID? = nil, sortOrder: Int = 0) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.folderID = folderID
        self.sortOrder = sortOrder
    }
}
