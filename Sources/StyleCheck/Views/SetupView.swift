import AppKit
import SwiftUI

/// First run: pick and download a model once. After this the app is offline.
struct SetupView: View {
    @EnvironmentObject private var models: ModelManager

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(Color.accentColor)
                    Text("One-time setup")
                        .font(.title2.weight(.semibold))
                    Text("Style Check runs a free, open-source language model entirely on this Mac. Download it once; after that no internet connection is needed.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 480)
                }

                VStack(spacing: 8) {
                    ForEach(ModelCatalog.all) { model in
                        ModelChoiceRow(model: model, isSelected: model.id == models.selectedModelID) {
                            models.selectedModelID = model.id
                        }
                    }
                }
                .frame(maxWidth: 520)
                .disabled(isDownloading)

                switch models.status {
                case .downloading(let progress):
                    VStack(spacing: 6) {
                        ProgressView(value: progress)
                            .frame(maxWidth: 360)
                        Text("Downloading \(models.selectedModel.name)… \(Int(progress * 100))%")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("You can keep using your Mac. This happens only once.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                default:
                    VStack(spacing: 10) {
                        Button {
                            Task { await models.download() }
                        } label: {
                            Text("Download \(models.selectedModel.name) (\(models.selectedModel.downloadSize))")
                                .frame(minWidth: 260)
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)

                        Button("I already have an MLX model folder…") { pickFolder() }
                            .buttonStyle(.link)
                            .font(.callout)
                    }
                }

                if case .failed(let message) = models.status {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: 480)
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
    }

    private var isDownloading: Bool {
        if case .downloading = models.status { return true }
        return false
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder containing config.json and .safetensors files"
        if panel.runModal() == .OK, let url = panel.url {
            models.useExistingFolder(url)
        }
    }
}

struct ModelChoiceRow: View {
    let model: LocalModel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(model.name).font(.headline)
                        if model == ModelCatalog.recommended {
                            Text("Recommended")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        }
                    }
                    Text(model.summary).font(.callout).foregroundStyle(.secondary)
                    Text("\(model.downloadSize) · \(model.license)")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.07) : Color(nsColor: .controlBackgroundColor)))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}
