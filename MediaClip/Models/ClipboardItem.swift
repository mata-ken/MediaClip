import Foundation

final class ClipboardItem: Identifiable, Codable, ObservableObject {
    let id: UUID
    let contentType: ContentType
    let createdAt: Date
    var textContent: String?
    var imageFileName: String?
    var mediaFilePath: String?
    var thumbnailFileName: String?
    @Published var isPinned: Bool

    enum CodingKeys: String, CodingKey {
        case id, contentType, createdAt, textContent, imageFileName, mediaFilePath, thumbnailFileName, isPinned
    }

    init(
        contentType: ContentType,
        textContent: String? = nil,
        imageFileName: String? = nil,
        mediaFilePath: String? = nil,
        thumbnailFileName: String? = nil,
        isPinned: Bool = false
    ) {
        self.id = UUID()
        self.contentType = contentType
        self.createdAt = Date()
        self.textContent = textContent
        self.imageFileName = imageFileName
        self.mediaFilePath = mediaFilePath
        self.thumbnailFileName = thumbnailFileName
        self.isPinned = isPinned
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        contentType = try container.decode(ContentType.self, forKey: .contentType)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        textContent = try container.decodeIfPresent(String.self, forKey: .textContent)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        mediaFilePath = try container.decodeIfPresent(String.self, forKey: .mediaFilePath)
        thumbnailFileName = try container.decodeIfPresent(String.self, forKey: .thumbnailFileName)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(textContent, forKey: .textContent)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try container.encodeIfPresent(mediaFilePath, forKey: .mediaFilePath)
        try container.encodeIfPresent(thumbnailFileName, forKey: .thumbnailFileName)
        try container.encode(isPinned, forKey: .isPinned)
    }

    var previewText: String {
        switch contentType {
        case .plainText, .richText:
            return textContent ?? ""
        case .image:
            return "Image"
        case .video:
            return "Video"
        }
    }
}
