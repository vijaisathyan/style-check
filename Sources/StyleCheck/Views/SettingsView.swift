import AppKit
import SwiftUI

/// Style Check ▸ Settings… (⌘,)
struct SettingsView: View {
    @EnvironmentObject private var models: ModelManager
    @EnvironmentObject private var library: LibraryModel

    var body: some View {
        Form {
            Section("Model") {
                Picker("Model", selection: $models.selectedModelID) {
                    ForEach(ModelCatalog.all) { model in
                        Text(models.isInstalled(model) ? model.name : "\(model.name) (not downloaded)")
                            .tag(model.id)
                    }
                }
                if !models.isInstalled(models.selectedModel) {
                    Button("Download \(models.selectedModel.name) (\(models.selectedModel.downloadSize))") {
                        Task { await models.download() }
                    }
                }
                Picker("Answer length", selection: $models.answerLength) {
                    ForEach(AnswerLength.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("Free memory when idle", isOn: $models.unloadWhenIdle)
                if models.unloadWhenIdle {
                    Stepper("After \(models.idleMinutes) minutes", value: $models.idleMinutes, in: 1...60)
                }
                Button("Free memory now") { models.unload() }
                    .disabled(models.status != .ready)
            } header: {
                Text("Memory")
            } footer: {
                Text("The model uses about 2–3 GB while loaded. Unloading keeps your Mac responsive; the next question reloads it in a few seconds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Library") {
                LabeledContent("Style guides", value: "\(library.guides.count)")
                Button("Show Library in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([library.libraryFolder])
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(.vertical, 8)
    }
}
