import StyleCheckCore
import SwiftUI
import UniformTypeIdentifiers

/// Left column: the style guides the assistant can consult.
struct SidebarView: View {
    @EnvironmentObject private var library: LibraryModel
    @State private var isDropTargeted = false
    @State private var renaming: StyleGuide?
    @State private var renameText = ""

    var body: some View {
        List {
            Section {
                ForEach(library.guides) { guide in
                    GuideRow(guide: guide)
                        .contextMenu {
                            if !guide.isBuiltIn {
                                Button("Rename…") {
                                    renameText = guide.title
                                    renaming = guide
                                }
                                Button("Remove", role: .destructive) { library.remove(guide) }
                            }
                        }
                }
                ForEach(library.importJobs) { job in
                    HStack(spacing: 8) {
                        ProgressView(value: job.progress)
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                        Text("Reading \(job.fileName)…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Style Guides")
            } footer: {
                Text("Checked guides are searched for every question.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button {
                    library.isShowingImporter = true
                } label: {
                    Label("Add Style Guide…", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .help("PDF, Word, RTF, HTML, Markdown, or text (⌘O)")
                Text("or drop files here")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .background(Color.accentColor.opacity(0.08))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            library.importFiles(urls.filter(\.isFileURL))
            return true
        } isTargeted: { isDropTargeted = $0 }
        .sheet(item: $renaming) { guide in
            RenameSheet(title: $renameText) {
                library.rename(guide, to: renameText)
                renaming = nil
            } onCancel: {
                renaming = nil
            }
        }
    }
}

private struct GuideRow: View {
    @EnvironmentObject private var library: LibraryModel
    let guide: StyleGuide

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Toggle(
                "",
                isOn: Binding(
                    get: { guide.isEnabled },
                    set: { library.setEnabled($0, guide: guide) })
            )
            .toggleStyle(.checkbox)
            .labelsHidden()
            .help(guide.isEnabled ? "Used when answering" : "Not used")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(guide.title)
                        .lineLimit(2)
                    if guide.isBuiltIn {
                        Image(systemName: "checkmark.seal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("Built in: common Chicago-style conventions, written for this app")
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .opacity(guide.isEnabled ? 1 : 0.55)
    }

    private var subtitle: String {
        if guide.isBuiltIn { return "Built in · \(guide.chunkCount) topics" }
        let words = guide.wordCount >= 1000
            ? "\(guide.wordCount / 1000)k words" : "\(guide.wordCount) words"
        return words
    }
}

private struct RenameSheet: View {
    @Binding var title: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rename Style Guide").font(.headline)
            Text("This name is shown in answers when the guide is cited.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("Name", text: $title)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onSave)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Save", action: onSave).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
