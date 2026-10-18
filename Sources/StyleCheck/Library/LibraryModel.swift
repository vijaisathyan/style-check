import Foundation
import StyleCheckCore
import SwiftUI

/// The user's style guides plus the search index over them.
@MainActor
final class LibraryModel: ObservableObject {

    struct ImportJob: Identifiable, Equatable {
        let id = UUID()
        let fileName: String
        var progress: Double = 0
    }

    @Published private(set) var guides: [StyleGuide] = []
    @Published private(set) var importJobs: [ImportJob] = []
    @Published var importError: String?
    @Published var isShowingImporter = false

    private var store: LibraryStore?
    private var index = SearchIndex()

    private let builtInEnabledKey = "builtInGuideEnabled"

    init() {
        do {
            store = try LibraryStore(directory: LibraryStore.defaultDirectory())
        } catch {
            importError = "Couldn't open the style guide library: \(error.localizedDescription)"
        }
        reload()
    }

    var enabledGuides: [StyleGuide] { guides.filter(\.isEnabled) }

    var libraryFolder: URL { LibraryStore.defaultDirectory() }

    // MARK: - Search

    func search(_ query: String, limit: Int = 4) -> [Excerpt] {
        let enabled = Set(enabledGuides.map(\.id))
        guard !enabled.isEmpty else { return [] }
        return index.search(query, limit: limit, guides: enabled)
    }

    // MARK: - Editing

    func setEnabled(_ enabled: Bool, guide: StyleGuide) {
        if guide.isBuiltIn {
            UserDefaults.standard.set(enabled, forKey: builtInEnabledKey)
        } else {
            try? store?.setEnabled(enabled, for: guide.id)
        }
        reload(rebuildIndex: false)
    }

    func rename(_ guide: StyleGuide, to title: String) {
        guard !guide.isBuiltIn else { return }
        try? store?.rename(id: guide.id, to: title)
        reload()  // titles appear in citations, so re-index
    }

    func remove(_ guide: StyleGuide) {
        guard !guide.isBuiltIn else { return }
        try? store?.removeGuide(id: guide.id)
        reload()
    }

    func importFiles(_ urls: [URL]) {
        for url in urls {
            Task { await importFile(url) }
        }
    }

    private func importFile(_ url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let job = ImportJob(fileName: url.lastPathComponent)
        let jobID = job.id
        importJobs.append(job)
        defer { importJobs.removeAll { $0.id == jobID } }

        do {
            let sections = try await DocumentImporter.sections(from: url) { [weak self] p in
                guard let self, let i = self.importJobs.firstIndex(where: { $0.id == jobID }) else { return }
                self.importJobs[i].progress = p
            }
            let chunks = await Task.detached(priority: .userInitiated) {
                Chunker.chunk(sections: sections)
            }.value
            guard let store else { return }
            try store.addGuide(
                title: DocumentImporter.title(for: url), sourceFileName: url.lastPathComponent,
                chunks: chunks)
            reload()
        } catch {
            importError = error.localizedDescription
        }
    }

    // MARK: - Private

    private func reload(rebuildIndex: Bool = true) {
        let builtInEnabled = UserDefaults.standard.object(forKey: builtInEnabledKey) as? Bool ?? true
        let builtIn = BuiltInGuide.guide(isEnabled: builtInEnabled)
        let userGuides = store?.guides ?? []
        guides = [builtIn] + userGuides
        guard rebuildIndex else { return }

        var pairs: [(StyleGuide, [GuideChunk])] = [(builtIn, BuiltInGuide.chunks)]
        for guide in userGuides {
            pairs.append((guide, store?.chunks(for: guide.id) ?? []))
        }
        index = SearchIndex(guides: pairs)
    }
}
