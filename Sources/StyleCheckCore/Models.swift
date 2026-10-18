import Foundation

/// A block of raw text pulled out of a document, before chunking.
/// For a PDF this is usually one page; for other files it's the whole text.
public struct TextSection: Sendable {
    public var text: String
    /// Where this text came from inside the document, e.g. "p. 12".
    public var location: String?

    public init(text: String, location: String? = nil) {
        self.text = text
        self.location = location
    }
}

/// A small searchable passage of a style guide (roughly 150–250 words).
public struct GuideChunk: Codable, Hashable, Identifiable, Sendable {
    public var id: Int
    /// Nearest heading above the passage, when one could be detected.
    public var heading: String?
    /// Page or other location label, e.g. "p. 12".
    public var location: String?
    public var text: String

    public init(id: Int, heading: String? = nil, location: String? = nil, text: String) {
        self.id = id
        self.heading = heading
        self.location = location
        self.text = text
    }
}

/// A style guide the user has added (or the built-in reference).
public struct StyleGuide: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var sourceFileName: String?
    public var isBuiltIn: Bool
    /// Whether this guide is searched when answering questions.
    public var isEnabled: Bool
    public var addedAt: Date
    public var chunkCount: Int
    public var wordCount: Int

    public init(
        id: UUID = UUID(), title: String, sourceFileName: String? = nil,
        isBuiltIn: Bool = false, isEnabled: Bool = true, addedAt: Date = Date(),
        chunkCount: Int = 0, wordCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.sourceFileName = sourceFileName
        self.isBuiltIn = isBuiltIn
        self.isEnabled = isEnabled
        self.addedAt = addedAt
        self.chunkCount = chunkCount
        self.wordCount = wordCount
    }
}

/// A passage returned by search, ready to show the model and the user.
public struct Excerpt: Hashable, Identifiable, Sendable {
    public var id: String { "\(guideID.uuidString)-\(chunk.id)" }
    public let guideID: UUID
    public let guideTitle: String
    public let chunk: GuideChunk
    public let score: Double

    public init(guideID: UUID, guideTitle: String, chunk: GuideChunk, score: Double) {
        self.guideID = guideID
        self.guideTitle = guideTitle
        self.chunk = chunk
        self.score = score
    }

    /// Label used in citations, e.g. "GPO Style Manual, p. 201".
    public var citation: String {
        if let location = chunk.location, !location.isEmpty {
            return "\(guideTitle), \(location)"
        }
        return guideTitle
    }
}
