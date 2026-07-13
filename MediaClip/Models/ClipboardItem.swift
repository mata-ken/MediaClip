import Foundation

final class ClipboardItem: Identifiable, Codable, ObservableObject {
    let id: UUID
    let contentType: ContentType
    let createdAt: Date
    var textContent: String?
    var imageFileName: String?
    var mediaFilePath: String?
    var thumbnailFileName: String?
    /// RTF data file name (for rich text format preservation)
    var rtfFileName: String?
    /// PDF data file name
    var pdfFileName: String?
    /// File paths for .file type (original locations, not copied)
    var filePaths: [String]?
    /// OCR-recognized text for image items (searchable)
    var ocrText: String?
    /// SHA256 hash of content for duplicate detection
    var contentHash: String?
    @Published var isPinned: Bool

    enum CodingKeys: String, CodingKey {
        case id, contentType, createdAt, textContent, imageFileName, mediaFilePath, thumbnailFileName, isPinned
        case rtfFileName, pdfFileName, filePaths, ocrText, contentHash
    }

    init(
        contentType: ContentType,
        textContent: String? = nil,
        imageFileName: String? = nil,
        mediaFilePath: String? = nil,
        thumbnailFileName: String? = nil,
        rtfFileName: String? = nil,
        pdfFileName: String? = nil,
        filePaths: [String]? = nil,
        contentHash: String? = nil,
        isPinned: Bool = false
    ) {
        self.id = UUID()
        self.contentType = contentType
        self.createdAt = Date()
        self.textContent = textContent
        self.imageFileName = imageFileName
        self.mediaFilePath = mediaFilePath
        self.thumbnailFileName = thumbnailFileName
        self.rtfFileName = rtfFileName
        self.pdfFileName = pdfFileName
        self.filePaths = filePaths
        self.contentHash = contentHash
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
        rtfFileName = try container.decodeIfPresent(String.self, forKey: .rtfFileName)
        pdfFileName = try container.decodeIfPresent(String.self, forKey: .pdfFileName)
        filePaths = try container.decodeIfPresent([String].self, forKey: .filePaths)
        ocrText = try container.decodeIfPresent(String.self, forKey: .ocrText)
        contentHash = try container.decodeIfPresent(String.self, forKey: .contentHash)
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
        try container.encodeIfPresent(rtfFileName, forKey: .rtfFileName)
        try container.encodeIfPresent(pdfFileName, forKey: .pdfFileName)
        try container.encodeIfPresent(filePaths, forKey: .filePaths)
        try container.encodeIfPresent(ocrText, forKey: .ocrText)
        try container.encodeIfPresent(contentHash, forKey: .contentHash)
        try container.encode(isPinned, forKey: .isPinned)
    }

    var previewText: String {
        switch contentType {
        case .plainText, .richText, .url:
            return textContent ?? ""
        case .image:
            return "Image"
        case .video:
            return "Video"
        case .pdf:
            return "PDF"
        case .file:
            let names = (filePaths ?? []).map { URL(fileURLWithPath: $0).lastPathComponent }
            return names.joined(separator: ", ")
        }
    }
}
