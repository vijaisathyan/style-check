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
