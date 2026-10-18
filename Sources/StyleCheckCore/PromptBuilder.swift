import Foundation

/// Builds what the language model sees. Kept small on purpose: a 3–4B model
/// on an 8 GB Mac does best with short, explicit instructions and a few
/// relevant passages rather than whole documents.
public enum PromptBuilder {

    public static let systemPrompt = """
        You are Style Check, a careful copyeditor's assistant for academic and literary journals. \
        You answer questions about grammar, punctuation, usage, citations, and house style. \
        Unless the user names another guide, follow Chicago style conventions.

        How to answer:
        1. Base your answer on the EXCERPTS in the user's message. After a point that comes from an excerpt, \
        cite it in square brackets using the label shown for that excerpt, for example [Chicago Quick Reference]. \
        Only cite labels that appear in the excerpts.
        2. If the excerpts do not cover the question, begin with "The loaded guides don't cover this directly." \
        Then give your best general answer and say it is general guidance.
        3. If two guides disagree, say which guide recommends what.
        4. If the user gives a sentence or passage to check, show the corrected version first, \
        then list each change with a one-line reason. If nothing needs to change, say so.
        5. Be brief: a direct answer, the rule behind it, and one short example. Use bullets when listing several points.
        6. Never invent section numbers, page numbers, or quotations.
        """

    public struct Turn: Sendable {
        public var question: String
        public var answer: String
        public init(question: String, answer: String) {
            self.question = question
            self.answer = answer
        }
    }

    /// The message sent for a new question, with the retrieved passages attached.
    public static func userMessage(question: String, excerpts: [Excerpt], maxExcerptWords: Int = 900) -> String {
        guard !excerpts.isEmpty else {
            return """
                EXCERPTS: none found in the loaded guides.

                QUESTION: \(question)
                """
        }
        var parts: [String] = []
        var used = 0
        for (index, excerpt) in excerpts.enumerated() {
            let words = excerpt.chunk.text.split(separator: " ")
            let remaining = maxExcerptWords - used
            guard remaining > 40 else { break }
            let text = words.count > remaining
                ? words.prefix(remaining).joined(separator: " ") + " …"
                : excerpt.chunk.text
            used += min(words.count, remaining)
            var header = "[\(excerpt.citation)]"
            if let heading = excerpt.chunk.heading { header += " — \(heading)" }
            parts.append("Excerpt \(index + 1) \(header)\n\(text)")
        }
        return """
            EXCERPTS:
            \(parts.joined(separator: "\n\n"))

            QUESTION: \(question)
            """
    }

    /// Text used to search the guides. Short follow-ups ("what about in titles?")
    /// borrow the previous question so the search has something to go on.
    public static func searchQuery(question: String, previousQuestion: String?) -> String {
        let words = question.split(separator: " ").count
        if words < 8, let previousQuestion { return question + " " + previousQuestion }
        return question
    }

    /// Recent history to keep follow-ups coherent without letting memory use grow.
    /// Answers are trimmed so the context stays small.
    public static func history(from turns: [Turn], keep: Int = 2, maxAnswerCharacters: Int = 700) -> [Turn] {
        turns.suffix(keep).map { turn in
            var answer = turn.answer
            if answer.count > maxAnswerCharacters {
                answer = String(answer.prefix(maxAnswerCharacters)) + " …"
            }
            return Turn(question: turn.question, answer: answer)
        }
    }

    /// Removes any reasoning block a model may emit before its answer.
    public static func cleanAnswer(_ text: String) -> String {
        var t = text
        while let start = t.range(of: "<think>") {
            if let end = t.range(of: "</think>", range: start.upperBound..<t.endIndex) {
                t.removeSubrange(start.lowerBound..<end.upperBound)
            } else {
                // Still thinking (streaming): hide everything after <think>.
                t.removeSubrange(start.lowerBound..<t.endIndex)
            }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
