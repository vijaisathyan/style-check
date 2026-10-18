import Foundation

/// Splits document text into small passages that fit comfortably in the
/// model's context. Headings are detected loosely and used as labels only;
/// heading text is also kept in the passage so a wrong guess loses nothing.
public enum Chunker {

    public static func chunk(
        sections: [TextSection],
        targetWords: Int = 170,
        maxWords: Int = 260
    ) -> [GuideChunk] {
        var chunks: [GuideChunk] = []
        var heading: String?

        for section in sections {
            var buffer = ""
            var bufferWords = 0
            var bufferHeading = heading

            func flush(force: Bool) {
                let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    buffer = ""
                    bufferWords = 0
                    return
                }
                // Avoid tiny fragments unless we're at the end of a section.
                if !force && bufferWords < 25 { return }
                chunks.append(
                    GuideChunk(
                        id: chunks.count, heading: bufferHeading,
                        location: section.location, text: trimmed))
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
                    if !buffer.hasSuffix("\n\n") && !buffer.isEmpty { buffer += "\n\n" }
                    previousLine = line
                    continue
                }

                if let detected = headingText(line, previous: previousLine, next: nextLine) {
                    // A new heading starts a new passage when the current one is substantial.
                    if bufferWords >= 40 { flush(force: true) }
                    heading = detected
                    if bufferWords == 0 { bufferHeading = detected }
                }

                append(line: line, to: &buffer)
                bufferWords += wordCount(line)
                previousLine = line

                if bufferWords >= targetWords {
                    if let cut = sentenceCut(in: buffer, minWords: targetWords / 2) {
                        let head = String(buffer[..<cut])
                        let tail = String(buffer[cut...])
                        buffer = head
                        bufferWords = wordCount(head)
                        flush(force: true)
                        buffer = tail.trimmingCharacters(in: .whitespaces)
                        bufferWords = wordCount(buffer)
                    } else if bufferWords >= maxWords {
                        flush(force: true)
                    }
                }
            }
            flush(force: true)
        }
        return chunks
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

    /// Index just after the last sentence end that leaves at least `minWords` before it.
    static func sentenceCut(in text: String, minWords: Int) -> String.Index? {
        var best: String.Index?
        var idx = text.startIndex
        var words = 0
        var previousWasSpace = true
        while idx < text.endIndex {
            let c = text[idx]
            let isSpace = c == " " || c == "\n"
            if !isSpace && previousWasSpace { words += 1 }
            previousWasSpace = isSpace
            if c == "." || c == "?" || c == "!" {
                let next = text.index(after: idx)
                if next == text.endIndex || text[next] == " " || text[next] == "\n" {
                    if words >= minWords { best = next }
                }
            }
            idx = text.index(after: idx)
        }
        return best
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
