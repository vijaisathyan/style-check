import Foundation

/// Saves the user's style guides on disk.
///
/// Layout (inside ~/Library/Application Support/StyleCheck/Library):
///   guides.json            list of guides and their settings
///   chunks/<id>.json       the searchable passages of each guide
///
/// Original files are not copied; only extracted text is kept.
public final class LibraryStore {

    public let directory: URL
    private var chunksDirectory: URL { directory.appendingPathComponent("chunks", isDirectory: true) }
    private var guidesFile: URL { directory.appendingPathComponent("guides.json") }

    public private(set) var guides: [StyleGuide] = []

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: chunksDirectory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: guidesFile) {
            guides = (try? JSONDecoder.library.decode([StyleGuide].self, from: data)) ?? []
        }
    }

    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("StyleCheck/Library", isDirectory: true)
    }

    // MARK: Guides

    @discardableResult
    public func addGuide(title: String, sourceFileName: String?, chunks: [GuideChunk]) throws -> StyleGuide {
        let words = chunks.reduce(0) { $0 + Chunker.wordCount($1.text) }
        let guide = StyleGuide(
            title: title, sourceFileName: sourceFileName,
            chunkCount: chunks.count, wordCount: words)
        let data = try JSONEncoder.library.encode(chunks)
        try data.write(to: chunkFile(for: guide.id), options: .atomic)
        guides.append(guide)
        try save()
        return guide
    }

    public func removeGuide(id: UUID) throws {
        guides.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: chunkFile(for: id))
        try save()
    }

    public func setEnabled(_ enabled: Bool, for id: UUID) throws {
        guard let i = guides.firstIndex(where: { $0.id == id }) else { return }
        guides[i].isEnabled = enabled
        try save()
    }

    public func rename(id: UUID, to title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = guides.firstIndex(where: { $0.id == id }) else { return }
        guides[i].title = trimmed
        try save()
    }

    public func chunks(for id: UUID) -> [GuideChunk] {
        guard let data = try? Data(contentsOf: chunkFile(for: id)) else { return [] }
        return (try? JSONDecoder.library.decode([GuideChunk].self, from: data)) ?? []
    }

    // MARK: Private

    private func chunkFile(for id: UUID) -> URL {
        chunksDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private func save() throws {
        let data = try JSONEncoder.library.encode(guides)
        try data.write(to: guidesFile, options: .atomic)
    }
}

extension JSONEncoder {
    static var library: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var library: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
