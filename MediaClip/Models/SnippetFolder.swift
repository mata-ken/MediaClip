import Foundation

final class SnippetFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    var sortOrder: Int

    init(name: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
    }
}
