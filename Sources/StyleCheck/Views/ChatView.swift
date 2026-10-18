import StyleCheckCore
import SwiftUI

/// The main panel: ask a question, get an answer with the passages it used.
struct ChatView: View {
    @EnvironmentObject private var models: ModelManager
    @EnvironmentObject private var library: LibraryModel
    @EnvironmentObject private var chat: ChatModel

    var body: some View {
        VStack(spacing: 0) {
            if chat.messages.isEmpty {
                EmptyChatView { example in
                    chat.send(example, library: library, models: models)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(chat.messages) { message in
                                MessageView(message: message)
                                    .id(message.id)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 20)
                        .frame(maxWidth: 820)
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: chat.messages.last?.text) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    .onChange(of: chat.messages.count) {
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
            }
            Divider()
            Composer()
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Empty state

private struct EmptyChatView: View {
    let onPick: (String) -> Void

    private let examples = [
        "Should I use a serial comma in “red, white and blue”?",
        "Check this: “The data shows that 5 participants, who were students, left early.”",
        "When do I spell out numbers versus using numerals?",
        "How should I capitalize “a history of the world in ten chapters” as a title?",
        "Em dash or en dash in “pages 45-67”?",
        "How do I cite a journal article in a footnote?",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 30)
                Image(systemName: "text.badge.checkmark")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Color.accentColor)
                VStack(spacing: 6) {
                    Text("Ask about grammar, punctuation, or style")
                        .font(.title2.weight(.semibold))
                    Text("Paste a sentence to check, or ask how a rule works. Answers cite the guides in the sidebar.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
                    ForEach(examples, id: \.self) { example in
                        Button {
                            onPick(example)
                        } label: {
                            Text(example)
                                .font(.callout)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(nsColor: .controlBackgroundColor)))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color.primary.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 620)
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Messages

private struct MessageView: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 80)
                Text(message.text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(0.14)))
            }
        case .assistant:
            AnswerView(message: message)
        }
    }
}

private struct AnswerView: View {
    let message: ChatMessage
    @State private var showSources = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = message.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            } else if message.text.isEmpty && message.isStreaming {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(message.excerpts.isEmpty ? "Thinking…" : "Reading \(message.excerpts.count) passages…")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(markdown(message.text))
                    .textSelection(.enabled)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !message.isStreaming {
                HStack(spacing: 14) {
                    if !message.excerpts.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { showSources.toggle() }
                        } label: {
                            Label(
                                showSources ? "Hide sources" : "Sources (\(message.excerpts.count))",
                                systemImage: "book")
                        }
                    } else if message.error == nil {
                        Label("No matching passage in your guides", systemImage: "book.closed")
                            .foregroundStyle(.secondary)
                    }
                    if !message.text.isEmpty {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.text, forType: .string)
                            copied = true
                            Task {
                                try? await Task.sleep(for: .seconds(1.5))
                                copied = false
                            }
                        } label: {
                            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if showSources {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(message.excerpts) { excerpt in
                        SourceCard(excerpt: excerpt)
                    }
                }
            }
        }
        .padding(.trailing, 40)
    }

    private func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

private struct SourceCard: View {
    let excerpt: Excerpt
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(excerpt.citation).font(.caption.weight(.semibold))
                if let heading = excerpt.chunk.heading {
                    Text("· \(heading)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
            }
            Text(excerpt.chunk.text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(expanded ? nil : 4)
                .textSelection(.enabled)
            Button(expanded ? "Show less" : "Show more") { expanded.toggle() }
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

// MARK: - Composer

private struct Composer: View {
    @EnvironmentObject private var models: ModelManager
    @EnvironmentObject private var library: LibraryModel
    @EnvironmentObject private var chat: ChatModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask a question or paste a sentence to check…", text: $chat.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...8)
                .focused($focused)
                .onSubmit(send)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(focused ? 0.25 : 0.1)))

            if chat.isGenerating {
                Button {
                    chat.stop()
                } label: {
                    Image(systemName: "stop.circle.fill").font(.system(size: 26))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Stop")
                .keyboardShortcut(".", modifiers: .command)
            } else {
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 26))
                }
                .buttonStyle(.plain)
                .foregroundStyle(canSend ? Color.accentColor : Color.secondary.opacity(0.5))
                .disabled(!canSend)
                .help("Send (Return). Option-Return for a new line.")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity)
        .onAppear { focused = true }
    }

    private var canSend: Bool {
        !chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard canSend else { return }
        chat.send(library: library, models: models)
    }
}
