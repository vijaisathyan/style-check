import StyleCheckCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var models: ModelManager
    @EnvironmentObject private var library: LibraryModel
    @EnvironmentObject private var chat: ChatModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            Group {
                if needsSetup {
                    SetupView()
                } else {
                    ChatView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .status) {
                    ModelStatusPill()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        chat.clear()
                    } label: {
                        Label("New Chat", systemImage: "square.and.pencil")
                    }
                    .help("Start a new chat (⌘N)")
                    .disabled(chat.messages.isEmpty)
                }
            }
        }
        .fileImporter(
            isPresented: $library.isShowingImporter,
            allowedContentTypes: DocumentImporter.supportedTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result { library.importFiles(urls) }
        }
        .alert(
            "Couldn't add style guide",
            isPresented: Binding(
                get: { library.importError != nil },
                set: { if !$0 { library.importError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(library.importError ?? "")
        }
    }

    private var needsSetup: Bool {
        switch models.status {
        case .notInstalled, .downloading: true
        case .failed: !models.isInstalled(models.selectedModel)
        default: false
        }
    }
}

/// Small status indicator in the toolbar.
struct ModelStatusPill: View {
    @EnvironmentObject private var models: ModelManager

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(models.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Image(systemName: "wifi.slash")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .help("Runs entirely on this Mac. No internet needed.")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .help(helpText)
    }

    private var color: Color {
        switch models.status {
        case .ready: .green
        case .installed: .gray
        case .loading, .downloading: .orange
        case .notInstalled: .gray
        case .failed: .red
        }
    }

    private var helpText: String {
        switch models.status {
        case .installed:
            "The model is unloaded to save memory. It loads again in a few seconds when you ask something."
        case .failed(let message): message
        default: models.statusText
        }
    }
}
