import Foundation

enum ContentType: String, Codable, CaseIterable {
    case plainText
    case richText
    case image
    case video
    case url
    case pdf
    case file

    var displayName: String {
        switch self {
        case .plainText: return "Text"
        case .richText: return "Rich Text"
        case .image: return "Image"
        case .video: return "Video"
        case .url: return "URL"
        case .pdf: return "PDF"
        case .file: return "File"
        }
    }

    var systemImage: String {
        switch self {
        case .plainText: return "doc.text"
        case .richText: return "doc.richtext"
        case .image: return "photo"
        case .video: return "film"
        case .url: return "link"
        case .pdf: return "doc.richtext.fill"
        case .file: return "doc"
        }
    }
}
