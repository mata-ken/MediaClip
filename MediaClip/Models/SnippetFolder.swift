import Foundation

final class SnippetFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    var sortOrder: Int
    /// Optional global hotkey to pop up this folder's snippets (Carbon key code / modifiers)
    var hotKeyCode: UInt32?
    var hotKeyModifiers: UInt32?

    init(name: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
    }
}
