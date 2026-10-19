import Foundation
import HuggingFace
import MLX
import MLXLLM
import MLXLMCommon
import StyleCheckCore
import SwiftUI
import Tokenizers

/// Downloads, loads, and runs the local language model.
///
/// Memory strategy for an 8 GB Mac:
/// - one 4-bit model of at most ~2.3 GB is loaded at a time;
/// - MLX's buffer cache is capped so freed memory goes back to macOS;
/// - every question starts a fresh session (no ever-growing KV cache);
/// - the model is unloaded after a few idle minutes and reloads in seconds.
@MainActor
final class ModelManager: ObservableObject {

    enum Status: Equatable {
        case notInstalled
        case downloading(Double)
        case installed  // on disk, not in memory
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var status: Status = .notInstalled
    @Published var selectedModelID: String {
        didSet {
            guard oldValue != selectedModelID else { return }
            UserDefaults.standard.set(selectedModelID, forKey: Keys.selectedModel)
            unload()
            refreshStatus()
        }
    }
    @Published var unloadWhenIdle: Bool {
        didSet { UserDefaults.standard.set(unloadWhenIdle, forKey: Keys.unloadWhenIdle) }
    }
    @Published var idleMinutes: Int {
        didSet { UserDefaults.standard.set(idleMinutes, forKey: Keys.idleMinutes) }
    }
    @Published var answerLength: AnswerLength {
        didSet { UserDefaults.standard.set(answerLength.rawValue, forKey: Keys.answerLength) }
    }

    var selectedModel: LocalModel { ModelCatalog.model(id: selectedModelID) }

    private var container: ModelContainer?
    private var loadTask: Task<ModelContainer, Error>?
    private var idleTask: Task<Void, Never>?

    private enum Keys {
        static let selectedModel = "selectedModel"
        static let unloadWhenIdle = "unloadWhenIdle"
        static let idleMinutes = "idleMinutes"
        static let answerLength = "answerLength"
    }

    init() {
        let defaults = UserDefaults.standard
        let savedChoice = defaults.string(forKey: Keys.selectedModel)
        selectedModelID = savedChoice ?? ModelCatalog.recommended.id
        unloadWhenIdle = defaults.object(forKey: Keys.unloadWhenIdle) as? Bool ?? true
        idleMinutes = defaults.object(forKey: Keys.idleMinutes) as? Int ?? 10
        answerLength = AnswerLength(rawValue: defaults.string(forKey: Keys.answerLength) ?? "") ?? .normal
        // Return freed GPU buffers to the system quickly instead of hoarding them.
        Memory.cacheLimit = 64 * 1024 * 1024
        // First launch: if the recommended model isn't on this Mac but another
        // supported model already is, start with that one instead of asking to download.
        if savedChoice == nil, !isInstalled(selectedModel),
            let available = ModelCatalog.all.first(where: { isInstalled($0) })
        {
            selectedModelID = available.id
        }
        refreshStatus()
    }

    // MARK: - Installation

    /// Where a model's files are on disk, if it is installed.
    /// Checks the folder recorded at download time first, then looks for a copy
    /// already in the shared Hugging Face cache (from an earlier build of the
    /// app, another app, or Python tools) and remembers it.
    func directory(for model: LocalModel) -> URL? {
        if let path = UserDefaults.standard.string(forKey: "modelDirectory.\(model.id)") {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if ModelCache.isComplete(url) { return url }
        }
        if let found = ModelCache.findSnapshot(repoID: model.id, in: Self.cacheRoots) {
            setDirectory(found, for: model)
            return found
        }
        return nil
    }

    /// Hugging Face cache folders to search, in order: the location the
    /// downloader uses (honors HF_HUB_CACHE / HF_HOME), then the standard
    /// home-folder and Library locations.
    static var cacheRoots: [URL] {
        var roots: [URL] = []
        if let configured = CacheLocationProvider.environment.resolve() { roots.append(configured) }
        let home = FileManager.default.homeDirectoryForCurrentUser
        roots.append(home.appendingPathComponent(".cache/huggingface/hub", isDirectory: true))
        if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            roots.append(caches.appendingPathComponent("huggingface/hub", isDirectory: true))
        }
        var seen = Set<String>()
        return roots.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    func isInstalled(_ model: LocalModel) -> Bool { directory(for: model) != nil }

    private func setDirectory(_ url: URL, for model: LocalModel) {
        UserDefaults.standard.set(url.path, forKey: "modelDirectory.\(model.id)")
    }

    func refreshStatus() {
        if container != nil {
            status = .ready
        } else if case .downloading = status {
            return
        } else {
            status = isInstalled(selectedModel) ? .installed : .notInstalled
        }
    }

    /// One-time download. This is the only step that needs the internet.
    func download() async {
        let model = selectedModel
        status = .downloading(0)
        do {
            let downloader: any Downloader = HubDownloader()
            let url = try await downloader.download(
                id: model.id, revision: "main",
                matching: ["*.safetensors", "*.json", "*.jinja"],
                useLatest: false
            ) { [weak self] progress in
                let fraction = progress.fractionCompleted
                Task { @MainActor in
                    guard let self, case .downloading = self.status else { return }
                    self.status = .downloading(fraction)
                }
            }
            setDirectory(url, for: model)
            status = .installed
            _ = try? await ensureLoaded()
        } catch {
            status = .failed("Download failed: \(error.localizedDescription). Check your internet connection and try again.")
        }
    }

    /// Use a model folder the user already has (for fully offline installs).
    func useExistingFolder(_ url: URL) {
        let config = url.appendingPathComponent("config.json")
        guard FileManager.default.fileExists(atPath: config.path) else {
            status = .failed("That folder doesn't look like an MLX model (no config.json).")
            return
        }
        setDirectory(url, for: selectedModel)
        unload()
        status = .installed
    }

    // MARK: - Loading

    @discardableResult
    func ensureLoaded() async throws -> ModelContainer {
        if let container { return container }
        if let loadTask { return try await loadTask.value }

        let model = selectedModel
        guard let directory = directory(for: model) else {
            status = .notInstalled
            throw StyleCheckError.modelNotInstalled
        }
        status = .loading
        let task = Task { () throws -> ModelContainer in
            let configuration = ModelConfiguration(
                directory: directory, extraEOSTokens: model.extraEOSTokens)
            // Loading from a local folder never touches the network:
            // a directory configuration skips the downloader entirely.
            return try await LLMModelFactory.shared.loadContainer(
                from: HubDownloader(),
                using: TransformersTokenizerLoader(),
                configuration: configuration)
        }
        loadTask = task
        do {
            let loaded = try await task.value
            container = loaded
            loadTask = nil
            status = .ready
            return loaded
        } catch {
            loadTask = nil
            status = .failed("Couldn't load the model: \(error.localizedDescription)")
            throw error
        }
    }

    func unload() {
        idleTask?.cancel()
        loadTask?.cancel()
        loadTask = nil
        container = nil
        Memory.clearCache()
        if case .ready = status { status = .installed }
    }

    // MARK: - Generation

    /// Streams an answer. A fresh session per question keeps memory flat.
    func streamAnswer(system: String, messages: [Chat.Message]) async throws
        -> AsyncThrowingStream<String, Error>
    {
        idleTask?.cancel()
        let container = try await ensureLoaded()
        let model = selectedModel
        let parameters = GenerateParameters(
            maxTokens: answerLength.maxTokens,
            temperature: 0.3,
            topP: 0.9,
            repetitionPenalty: 1.05)
        let session = ChatSession(
            container,
            instructions: system,
            generateParameters: parameters,
            additionalContext: model.additionalContext)
        let upstream = session.streamResponse(to: messages)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await chunk in upstream {
                        continuation.yield(chunk)
                    }
                    _ = session  // keep the session alive until generation ends
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Called after each answer; frees memory if the app sits idle.
    func scheduleIdleUnload() {
        idleTask?.cancel()
        Memory.clearCache()
        guard unloadWhenIdle else { return }
        let minutes = idleMinutes
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard !Task.isCancelled else { return }
            self?.unload()
        }
    }

    var statusText: String {
        switch status {
        case .notInstalled: "No model installed"
        case .downloading(let p): "Downloading model… \(Int(p * 100))%"
        case .installed: "\(selectedModel.name) · sleeping"
        case .loading: "Loading \(selectedModel.name)…"
        case .ready: "\(selectedModel.name) · ready"
        case .failed: "Model problem"
        }
    }
}

enum StyleCheckError: LocalizedError {
    case modelNotInstalled
    var errorDescription: String? {
        switch self {
        case .modelNotInstalled: "No language model is installed yet."
        }
    }
}
