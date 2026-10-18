import Foundation
import MLXLMCommon
import StyleCheckCore
import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }

    let id = UUID()
    let role: Role
    var text: String
    var excerpts: [Excerpt] = []
    var isStreaming = false
    var error: String?
}

/// The conversation and the question-answer loop.
@MainActor
final class ChatModel: ObservableObject {

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isGenerating = false
    @Published var draft = ""

    private var generationTask: Task<Void, Never>?

    func clear() {
        stop()
        messages.removeAll()
        draft = ""
    }

    func stop() {
        generationTask?.cancel()
        generationTask = nil
    }

    func send(_ text: String? = nil, library: LibraryModel, models: ModelManager) {
        let question = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isGenerating else { return }
        draft = ""

        // Earlier finished exchanges, for follow-up questions.
        var turns: [PromptBuilder.Turn] = []
        var pendingQuestion: String?
        for message in messages {
            switch message.role {
            case .user: pendingQuestion = message.text
            case .assistant:
                if let q = pendingQuestion, message.error == nil, !message.text.isEmpty {
                    turns.append(.init(question: q, answer: message.text))
                }
                pendingQuestion = nil
            }
        }
        let previousQuestion = messages.last(where: { $0.role == .user })?.text

        let query = PromptBuilder.searchQuery(question: question, previousQuestion: previousQuestion)
        let excerpts = library.search(query)

        messages.append(ChatMessage(role: .user, text: question))
        messages.append(ChatMessage(role: .assistant, text: "", excerpts: excerpts, isStreaming: true))
        let answerID = messages[messages.count - 1].id
        isGenerating = true

        var chat: [Chat.Message] = []
        for turn in PromptBuilder.history(from: turns) {
            chat.append(.user(turn.question))
            chat.append(.assistant(turn.answer))
        }
        chat.append(.user(PromptBuilder.userMessage(question: question, excerpts: excerpts)))
        let finalChat = chat

        generationTask = Task { [weak self] in
            guard let self else { return }
            var raw = ""
            do {
                let stream = try await models.streamAnswer(
                    system: PromptBuilder.systemPrompt, messages: finalChat)
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    raw += chunk
                    self.update(answerID) { $0.text = PromptBuilder.cleanAnswer(raw) }
                }
            } catch is CancellationError {
                // Stopped by the user; keep what was written so far.
            } catch {
                self.update(answerID) { $0.error = error.localizedDescription }
            }
            self.update(answerID) {
                $0.isStreaming = false
                if $0.text.isEmpty && $0.error == nil && Task.isCancelled {
                    $0.text = "_Stopped._"
                }
            }
            self.isGenerating = false
            self.generationTask = nil
            models.scheduleIdleUnload()
        }
    }

    private func update(_ id: UUID, _ change: (inout ChatMessage) -> Void) {
        guard let i = messages.firstIndex(where: { $0.id == id }) else { return }
        change(&messages[i])
    }
}
