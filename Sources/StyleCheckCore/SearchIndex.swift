import Foundation

/// Keyword search (BM25) over style-guide passages.
///
/// BM25 needs no extra model, uses almost no memory, and works well for
/// style questions, which tend to use the same terms the guides use
/// ("serial comma", "en dash", "possessive"). A small synonym table covers
/// the common cases where people and guides use different words.
public struct SearchIndex: Sendable {

    struct Entry: Sendable {
        let guideID: UUID
        let guideTitle: String
        let chunk: GuideChunk
        let termFrequencies: [String: Int]
        let length: Int
    }

    private var entries: [Entry] = []
    private var documentFrequency: [String: Int] = [:]
    private var averageLength: Double = 1

    private let k1 = 1.2
    private let b = 0.75

    public init() {}

    public init(guides: [(StyleGuide, [GuideChunk])]) {
        for (guide, chunks) in guides {
            for chunk in chunks {
                add(guide: guide, chunk: chunk)
            }
        }
        finalize()
    }

    public var isEmpty: Bool { entries.isEmpty }
    public var count: Int { entries.count }

    private mutating func add(guide: StyleGuide, chunk: GuideChunk) {
        var tf: [String: Int] = [:]
        var tokens = Tokenizer.terms(in: chunk.text)
        // Headings say what a passage is about; count them twice.
        if let heading = chunk.heading {
            let headingTerms = Tokenizer.terms(in: heading)
            tokens += headingTerms + headingTerms
        }
        for token in tokens { tf[token, default: 0] += 1 }
        for term in tf.keys { documentFrequency[term, default: 0] += 1 }
        entries.append(
            Entry(
                guideID: guide.id, guideTitle: guide.title, chunk: chunk,
                termFrequencies: tf, length: max(tokens.count, 1)))
    }

    private mutating func finalize() {
        guard !entries.isEmpty else { return }
        averageLength = Double(entries.reduce(0) { $0 + $1.length }) / Double(entries.count)
    }

    /// Finds the best passages for a question.
    /// - Parameters:
    ///   - query: the user's question (and optionally the previous one, for follow-ups)
    ///   - limit: maximum passages to return
    ///   - guides: restrict to these guide IDs (nil = all indexed guides)
    ///   - perGuideLimit: cap per guide so one long guide can't crowd out the rest
    public func search(
        _ query: String, limit: Int = 4, guides: Set<UUID>? = nil, perGuideLimit: Int = 3
    ) -> [Excerpt] {
        let queryTerms = Set(Tokenizer.queryTerms(in: query))
        guard !queryTerms.isEmpty, !entries.isEmpty else { return [] }

        let n = Double(entries.count)
        var idf: [String: Double] = [:]
        for term in queryTerms {
            let df = Double(documentFrequency[term] ?? 0)
            guard df > 0 else { continue }
            idf[term] = log(1 + (n - df + 0.5) / (df + 0.5))
        }
        guard !idf.isEmpty else { return [] }

        var scored: [(Entry, Double)] = []
        for entry in entries {
            if let guides, !guides.contains(entry.guideID) { continue }
            var score = 0.0
            var matched = 0
            for (term, weight) in idf {
                guard let f = entry.termFrequencies[term] else { continue }
                matched += 1
                let tf = Double(f)
                let norm = 1 - b + b * Double(entry.length) / averageLength
                score += weight * (tf * (k1 + 1)) / (tf + k1 * norm)
            }
            guard score > 0 else { continue }
            // Reward passages that cover more of the question.
            score *= 1 + 0.15 * Double(matched - 1)
            scored.append((entry, score))
        }

        scored.sort { $0.1 > $1.1 }
        var perGuide: [UUID: Int] = [:]
        var results: [Excerpt] = []
        for (entry, score) in scored {
            if perGuide[entry.guideID, default: 0] >= perGuideLimit { continue }
            perGuide[entry.guideID, default: 0] += 1
            results.append(
                Excerpt(
                    guideID: entry.guideID, guideTitle: entry.guideTitle,
                    chunk: entry.chunk, score: score))
            if results.count == limit { break }
        }
        // Drop weak tail results (less than a quarter of the best score).
        if let top = results.first?.score {
            results = results.filter { $0.score >= top * 0.25 }
        }
        return results
    }
}

/// Turns text into search terms.
public enum Tokenizer {

    static let stopWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "been", "but", "by", "can", "could",
        "do", "does", "did", "for", "from", "had", "has", "have", "how", "i", "if", "in",
        "into", "is", "it", "its", "me", "my", "of", "on", "or", "our", "should", "so",
        "than", "the", "then", "there", "this",
        "to", "was", "we", "were", "what", "when", "where",
        "why", "will", "with", "would", "you", "your", "use", "used", "using", "write",
        "written", "writing", "correct", "right", "wrong", "way", "per", "according",
        "chicago", "cmos", "style", "guide", "manual", "rule", "rules", "please", "tell",
        "explain", "any", "about", "also", "just", "need", "want", "know", "sentence",
    ]

    /// Words that people use differently from the guides.
    /// Keys are already-stemmed query terms; values are terms to add.
    static let synonyms: [String: [String]] = [
        "oxford": ["serial"], "harvard": ["serial"],
        "emdash": ["em", "dash"], "endash": ["en", "dash"],
        "dashe": ["dash"],
        "capital": ["capitalization", "capitalize"],
        "capitalize": ["capitalization"], "capitalized": ["capitalization"],
        "uppercase": ["capitalization", "capitalize"],
        "lowercase": ["capitalization", "lowercase"],
        "titlecase": ["headline", "capitalization"],
        "apostrophe": ["possessive"], "possessive": ["apostrophe"],
        "number": ["numeral"], "numeral": ["number"], "digit": ["numeral"],
        "percent": ["percentage"], "percentage": ["percent"],
        "ellipse": ["ellipsis"], "dot": ["ellipsis"],
        "quote": ["quotation"], "quotation": ["quote"],
        "hyphenate": ["hyphen", "compound"], "hyphen": ["hyphenation", "compound"],
        "compound": ["hyphen"],
        "citation": ["note", "bibliography", "cite"], "cite": ["citation", "note"],
        "footnote": ["note"], "endnote": ["note"],
        "reference": ["bibliography", "citation"],
        "italic": ["italics", "italicize"], "italicize": ["italics"],
        "they": ["singular", "pronoun"], "pronoun": ["they"],
        "date": ["dates"], "year": ["dates"], "time": ["times"],
        "abbreviation": ["acronym", "initialism"], "acronym": ["abbreviation"],
        "heading": ["headline"], "title": ["headline", "titles"],
    ]

    public static func terms(in text: String) -> [String] {
        var words: [String] = []
        var current = ""
        for scalar in expandSymbols(text).lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else if scalar == "'" || scalar == "’" {
                continue  // "author's" → "authors"
            } else {
                if !current.isEmpty { words.append(current) }
                current = ""
            }
        }
        if !current.isEmpty { words.append(current) }
        return words.compactMap { word in
            guard word.count >= 2 || word.first?.isNumber == true else { return nil }
            guard !stopWords.contains(word) else { return nil }
            return stem(word)
        }
    }

    /// Like `terms`, but also adds synonyms.
    public static func queryTerms(in text: String) -> [String] {
        var raw = text.lowercased()
        // Join phrases people commonly write as one idea.
        for (phrase, joined) in [
            ("em dash", "emdash"), ("em-dash", "emdash"), ("en dash", "endash"),
            ("en-dash", "endash"), ("title case", "titlecase"), ("sentence case", "titlecase"),
        ] {
            raw = raw.replacingOccurrences(of: phrase, with: joined + " " + phrase)
        }
        var result = terms(in: raw)
        for term in result {
            if let extra = synonyms[term] { result += extra.map(stem) }
        }
        return result
    }

    /// Replace punctuation marks people ask about with their names.
    static func expandSymbols(_ text: String) -> String {
        var t = text
        let names: [(String, String)] = [
            ("—", " em dash "), ("–", " en dash "), ("…", " ellipsis "),
            ("%", " percent "), ("&", " ampersand "), (";", " ; "), ("§", " section "),
        ]
        for (symbol, name) in names { t = t.replacingOccurrences(of: symbol, with: name) }
        t = t.replacingOccurrences(of: " ; ", with: " semicolon ")
        return t
    }

    /// Very light English stemming so "commas"/"comma", "hyphenated"/"hyphenate" match.
    public static func stem(_ word: String) -> String {
        var w = word
        if w.count > 4 && w.hasSuffix("ies") {
            w = String(w.dropLast(3)) + "y"
        } else if w.count > 4 && (w.hasSuffix("ches") || w.hasSuffix("shes") || w.hasSuffix("xes")) {
            w = String(w.dropLast(2))
        } else if w.count > 3 && w.hasSuffix("s") && !w.hasSuffix("ss") && !w.hasSuffix("us")
            && !w.hasSuffix("is")
        {
            w = String(w.dropLast())
        }
        if w.count > 6 && w.hasSuffix("ing") {
            w = String(w.dropLast(3))
        } else if w.count > 6 && w.hasSuffix("ed") {
            w = String(w.dropLast(1))  // "hyphenated" → "hyphenate"
        }
        return w
    }
}
