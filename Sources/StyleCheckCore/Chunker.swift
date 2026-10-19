import Foundation

/// Splits document text into small passages that fit comfortably in the
/// model's context. Headings are detected loosely and used as labels only;
/// heading text is also kept in the passage so a wrong guess loses nothing.
public enum Chunker {

    /// - Parameters:
    ///   - targetWords: a passage is closed once adding the next sentence would pass this
    ///   - maxWords: longest run of text kept together when there are no sentence breaks
    public static func chunk(
        sections: [TextSection],
        targetWords: Int = 170,
        maxWords: Int = 260
    ) -> [GuideChunk] {
        var chunks: [GuideChunk] = []
        var heading: String?
        let minimumWords = 25  // avoid tiny fragments in the middle of a section

        for section in sections {
            var buffer = ""
            var bufferWords = 0
            var bufferHeading = heading

            func flush() {
                let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    chunks.append(
                        GuideChunk(
                            id: chunks.count, heading: bufferHeading,
                            location: section.location, text: trimmed))
                }
                buffer = ""
                bufferWords = 0
                bufferHeading = heading
            }

            let lines = normalize(section.text).components(separatedBy: "\n")
            var previousLine = ""

            for (index, rawLine) in lines.enumerated() {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                let nextLine = index + 1 < lines.count
                    ? lines[index + 1].trimmingCharacters(in: .whitespaces) : ""

                if line.isEmpty {
                    if !buffer.isEmpty && !buffer.hasSuffix("\n\n") { buffer += "\n\n" }
                    previousLine = line
                    continue
                }

                if let detected = headingText(line, previous: previousLine, next: nextLine) {
                    // A new heading starts a new passage when the current one is substantial.
                    if bufferWords >= 40 { flush() }
                    heading = detected
                    if bufferWords == 0 { bufferHeading = detected }
                }

                // Long lines (a whole Word paragraph, say) are added a sentence at a time.
                for piece in pieces(of: line, maxWords: min(targetWords, maxWords)) {
                    let words = wordCount(piece)
                    if bufferWords >= minimumWords && bufferWords + words > targetWords {
                        flush()
                    }
                    append(line: piece, to: &buffer)
                    bufferWords += words
                }
                previousLine = line
            }
            flush()
        }
        return chunks
    }

    /// Splits a line into sentences, and any sentence longer than `maxWords`
    /// into runs of at most `maxWords` words.
    static func pieces(of line: String, maxWords: Int) -> [String] {
        guard wordCount(line) > 30 else { return [line] }
        var sentences: [String] = []
        var current = ""
        let characters = Array(line)
        for (i, c) in characters.enumerated() {
            current.append(c)
            guard c == "." || c == "?" || c == "!" else { continue }
            // A sentence ends at . ? ! followed by a space and a capital, digit, or opening mark.
            guard i + 2 < characters.count, characters[i + 1] == " " else { continue }
            let next = characters[i + 2]
            if next.isUppercase || next.isNumber || "“\"‘'([".contains(next) {
                sentences.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { sentences.append(rest) }

        var result: [String] = []
        for sentence in sentences {
            let words = sentence.split(separator: " ")
            if words.count <= maxWords {
                result.append(sentence)
            } else {
                var start = 0
                while start < words.count {
                    let end = min(start + maxWords, words.count)
                    result.append(words[start..<end].joined(separator: " "))
                    start = end
                }
            }
        }
        return result
    }

    // MARK: - Helpers

    static func normalize(_ text: String) -> String {
        var t = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n\n")
            .replacingOccurrences(of: "\u{000C}", with: "\n\n")
        // Collapse runs of spaces and tabs.
        t = t.replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
        return t
    }

    /// Joins a line onto the buffer, undoing end-of-line hyphenation from PDFs.
    static func append(line: String, to buffer: inout String) {
        if buffer.isEmpty || buffer.hasSuffix("\n\n") {
            buffer += line
            return
        }
        if buffer.hasSuffix("-"), let first = line.first, first.isLowercase {
            let beforeHyphen = buffer.dropLast().last
            if let c = beforeHyphen, c.isLetter {
                buffer.removeLast()
                buffer += line
                return
            }
        }
        buffer += " " + line
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).count
    }

    /// Returns cleaned heading text when the line looks like a heading.
    static func headingText(_ line: String, previous: String, next: String) -> String? {
        // Markdown headings.
        if line.hasPrefix("#") {
            let cleaned = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
            return cleaned.isEmpty ? nil : cleaned
        }
        let words = line.split(separator: " ")
        guard (1...10).contains(words.count), line.count <= 60 else { return nil }
        guard let first = line.first, first.isUppercase || first.isNumber else { return nil }
        if let last = line.last, ".,;:!?\"”'’)".contains(last) { return nil }

        let letters = line.filter { $0.isLetter }.count
        guard letters >= 3, Double(letters) / Double(line.count) > 0.55 else { return nil }

        // Only trust it when it stands apart from the surrounding prose:
        // after a blank line or the end of a sentence, and not mid-paragraph.
        let previousEndsSentence = previous.isEmpty
            || previous.hasSuffix(".") || previous.hasSuffix(":")
            || previous.hasSuffix("?") || previous.hasSuffix("!")
        guard previousEndsSentence else { return nil }
        guard next.isEmpty || next.count > line.count else { return nil }
        return line
    }
}
