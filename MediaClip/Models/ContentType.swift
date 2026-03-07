import Foundation

enum ContentType: String, Codable, CaseIterable {
    case plainText
    case richText
    case image
    case video

    var displayName: String {
        switch self {
        case .plainText: return "Text"
        case .richText: return "Rich Text"
        case .image: return "Image"
        case .video: return "Video"
        }
    }

    var systemImage: String {
        switch self {
        case .plainText: return "doc.text"
        case .richText: return "doc.richtext"
        case .image: return "photo"
        case .video: return "film"
        }
    }
}
