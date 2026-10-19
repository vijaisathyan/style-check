import XCTest

@testable import StyleCheckCore

final class SearchTests: XCTestCase {

    private func builtInIndex() -> SearchIndex {
        SearchIndex(guides: [(BuiltInGuide.guide(isEnabled: true), BuiltInGuide.chunks)])
    }

    func testBuiltInGuideParses() {
        let chunks = BuiltInGuide.chunks
        XCTAssertGreaterThan(chunks.count, 30)
        XCTAssertEqual(chunks.first?.heading, "Serial comma")
    }

    func testOxfordCommaFindsSerialComma() {
        let results = builtInIndex().search("Should I use the Oxford comma?")
        XCTAssertEqual(results.first?.chunk.heading, "Serial comma")
    }

    func testEmDashSymbolQuery() {
        let results = builtInIndex().search("spaces around — ?")
        XCTAssertEqual(results.first?.chunk.heading, "Em dashes")
    }

    func testPageRanges() {
        let results = builtInIndex().search("how to write page ranges like 101-108")
        XCTAssertTrue(results.contains { $0.chunk.heading == "Inclusive numbers (page ranges)" })
    }

    func testThatWhich() {
        let results = builtInIndex().search("that vs which")
        XCTAssertTrue(results.prefix(2).contains {
            $0.chunk.heading == "Restrictive and nonrestrictive clauses (that vs. which)"
        })
    }

    func testGuideFilter() {
        let other = StyleGuide(title: "Other")
        let index = SearchIndex(guides: [
            (BuiltInGuide.guide(isEnabled: true), BuiltInGuide.chunks),
            (other, [GuideChunk(id: 0, text: "Serial comma: house style omits it.")]),
        ])
        let results = index.search("serial comma", guides: [other.id])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.guideTitle, "Other")
    }
}

final class ChunkerTests: XCTestCase {

    func testJoinsHyphenatedLineBreaks() {
        let text = "The manuscript was exam-\nined carefully by the editors."
        let chunks = Chunker.chunk(sections: [TextSection(text: text)])
        XCTAssertTrue(chunks.first?.text.contains("examined") == true)
    }

    func testSplitsLongText() {
        let sentence = "This sentence has exactly eight words in it. "
        let text = String(repeating: sentence, count: 100)
        let chunks = Chunker.chunk(sections: [TextSection(text: text, location: "p. 3")])
        XCTAssertGreaterThan(chunks.count, 3)
        XCTAssertTrue(chunks.allSatisfy { Chunker.wordCount($0.text) <= 270 })
        XCTAssertEqual(chunks.first?.location, "p. 3")
    }

    func testSplitsTextWithoutSentenceBreaks() {
        let text = String(repeating: "word ", count: 600)
        let chunks = Chunker.chunk(sections: [TextSection(text: text)])
        XCTAssertGreaterThanOrEqual(chunks.count, 3)
        XCTAssertTrue(chunks.allSatisfy { Chunker.wordCount($0.text) <= 200 })
    }

    func testDetectsHeadings() {
        let text = "Intro text ends here.\n\nCapitalization\nCapitalize proper nouns in all cases and contexts that matter."
        let chunks = Chunker.chunk(sections: [TextSection(text: text)], targetWords: 5, maxWords: 50)
        XCTAssertTrue(chunks.contains { $0.heading == "Capitalization" })
    }
}

final class PromptTests: XCTestCase {

    func testCleanAnswerRemovesThinking() {
        XCTAssertEqual(PromptBuilder.cleanAnswer("<think>hmm</think>\nYes."), "Yes.")
        XCTAssertEqual(PromptBuilder.cleanAnswer("<think>still going"), "")
    }

    func testShortFollowUpBorrowsPreviousQuestion() {
        let q = PromptBuilder.searchQuery(question: "and in titles?", previousQuestion: "hyphen rules")
        XCTAssertTrue(q.contains("hyphen"))
    }
}

final class ModelCacheTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// Builds <root>/models--org--name/{blobs,refs/main,snapshots/<rev>/…} like the HF cache,
    /// with snapshot files as symlinks into blobs/.
    @discardableResult
    private func makeSnapshot(
        repo: String = "org/name", revision: String = "abc123", files: [String: String],
        danglingLinks: [String] = [], writeMainRef: Bool = true
    ) throws -> URL {
        let fm = FileManager.default
        let repoDir = root.appendingPathComponent("models--" + repo.replacingOccurrences(of: "/", with: "--"))
        let blobs = repoDir.appendingPathComponent("blobs")
        let snapshot = repoDir.appendingPathComponent("snapshots/\(revision)")
        try fm.createDirectory(at: blobs, withIntermediateDirectories: true)
        try fm.createDirectory(at: snapshot, withIntermediateDirectories: true)
        for (name, contents) in files {
            let blob = blobs.appendingPathComponent(UUID().uuidString)
            try contents.write(to: blob, atomically: true, encoding: .utf8)
            try fm.createSymbolicLink(at: snapshot.appendingPathComponent(name), withDestinationURL: blob)
        }
        for name in danglingLinks {
            try fm.createSymbolicLink(
                at: snapshot.appendingPathComponent(name),
                withDestinationURL: blobs.appendingPathComponent("missing-\(UUID().uuidString)"))
        }
        if writeMainRef {
            try fm.createDirectory(at: repoDir.appendingPathComponent("refs"), withIntermediateDirectories: true)
            try revision.write(to: repoDir.appendingPathComponent("refs/main"), atomically: true, encoding: .utf8)
        }
        return snapshot
    }

    func testFindsCompleteSingleFileModel() throws {
        let snapshot = try makeSnapshot(files: [
            "config.json": "{}", "tokenizer.json": "{}", "model.safetensors": "weights",
        ])
        let found = ModelCache.findSnapshot(repoID: "org/name", in: [root])
        XCTAssertEqual(found?.standardizedFileURL.path, snapshot.standardizedFileURL.path)
    }

    func testFindsCompleteShardedModel() throws {
        let index = #"{"weight_map": {"a": "model-00001-of-00002.safetensors", "b": "model-00002-of-00002.safetensors"}}"#
        try makeSnapshot(files: [
            "config.json": "{}", "tokenizer.json": "{}", "model.safetensors.index.json": index,
            "model-00001-of-00002.safetensors": "w1", "model-00002-of-00002.safetensors": "w2",
        ])
        XCTAssertNotNil(ModelCache.findSnapshot(repoID: "org/name", in: [root]))
    }

    func testRejectsModelWithMissingShard() throws {
        let index = #"{"weight_map": {"a": "model-00001-of-00002.safetensors", "b": "model-00002-of-00002.safetensors"}}"#
        try makeSnapshot(files: [
            "config.json": "{}", "tokenizer.json": "{}", "model.safetensors.index.json": index,
            "model-00001-of-00002.safetensors": "w1",
        ])
        XCTAssertNil(ModelCache.findSnapshot(repoID: "org/name", in: [root]))
    }

    func testRejectsInterruptedDownload() throws {
        // The weights link exists but its blob never finished downloading.
        try makeSnapshot(
            files: ["config.json": "{}", "tokenizer.json": "{}"],
            danglingLinks: ["model.safetensors"])
        XCTAssertNil(ModelCache.findSnapshot(repoID: "org/name", in: [root]))
    }

    func testSkipsRootsWithoutTheModel() throws {
        let empty = root.appendingPathComponent("empty-cache")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        try makeSnapshot(files: ["config.json": "{}", "tokenizer.json": "{}", "model.safetensors": "w"])
        XCTAssertNotNil(ModelCache.findSnapshot(repoID: "org/name", in: [empty, root]))
        XCTAssertNil(ModelCache.findSnapshot(repoID: "other/model", in: [empty, root]))
    }

    func testFindsSnapshotWithoutMainRef() throws {
        try makeSnapshot(
            files: ["config.json": "{}", "tokenizer.json": "{}", "model.safetensors": "w"],
            writeMainRef: false)
        XCTAssertNotNil(ModelCache.findSnapshot(repoID: "org/name", in: [root]))
    }
}
