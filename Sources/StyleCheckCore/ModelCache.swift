import Foundation

/// Finds a model that was already downloaded into a Hugging Face cache, so the
/// app never asks to download a model that is already on the Mac (for example,
/// one downloaded by an earlier build of Style Check, or by Python tools).
///
/// Cache layout (shared by the Swift and Python Hugging Face clients):
///
///     <root>/models--<org>--<name>/
///         refs/main                 → text file holding a revision hash
///         snapshots/<revision>/     → config.json, *.safetensors, tokenizer files
public enum ModelCache {

    /// Returns a complete snapshot folder for `repoID` (e.g. "mlx-community/Qwen3-4B-4bit"),
    /// searching each cache root in order. The `main` revision is preferred.
    public static func findSnapshot(repoID: String, in roots: [URL]) -> URL? {
        let folderName = "models--" + repoID.replacingOccurrences(of: "/", with: "--")
        let fm = FileManager.default

        for root in roots {
            let repoDir = root.appendingPathComponent(folderName, isDirectory: true)
            let snapshots = repoDir.appendingPathComponent("snapshots", isDirectory: true)
            guard let revisions = try? fm.contentsOfDirectory(atPath: snapshots.path) else { continue }

            var candidates: [String] = []
            let mainRef = repoDir.appendingPathComponent("refs/main")
            if let main = try? String(contentsOf: mainRef, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines), revisions.contains(main)
            {
                candidates.append(main)
            }
            // Then any other revision, newest first.
            let others = revisions.filter { !candidates.contains($0) && !$0.hasPrefix(".") }
                .sorted { modificationDate(snapshots.appendingPathComponent($0)) > modificationDate(snapshots.appendingPathComponent($1)) }
            candidates += others

            for revision in candidates {
                let dir = snapshots.appendingPathComponent(revision, isDirectory: true)
                if isComplete(dir) { return dir }
            }
        }
        return nil
    }

    /// A model folder is usable when it has config.json, a tokenizer, and every
    /// weight file it needs (all shards listed in model.safetensors.index.json).
    public static func isComplete(_ dir: URL) -> Bool {
        let fm = FileManager.default
        func nonEmpty(_ name: String) -> Bool {
            // stat() follows symlinks (snapshot files link into blobs/), so a link
            // whose download never finished counts as missing.
            var info = stat()
            let path = dir.appendingPathComponent(name).path
            guard stat(path, &info) == 0 else { return false }
            return (info.st_mode & S_IFMT) == S_IFREG && info.st_size > 0
        }

        guard nonEmpty("config.json") else { return false }
        guard nonEmpty("tokenizer.json") || nonEmpty("tokenizer_config.json") else { return false }

        let indexURL = dir.appendingPathComponent("model.safetensors.index.json")
        if let data = try? Data(contentsOf: indexURL),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let weightMap = json["weight_map"] as? [String: String]
        {
            let shards = Set(weightMap.values)
            return !shards.isEmpty && shards.allSatisfy(nonEmpty)
        }
        guard let files = try? fm.contentsOfDirectory(atPath: dir.path) else { return false }
        let weights = files.filter { $0.hasSuffix(".safetensors") }
        return !weights.isEmpty && weights.allSatisfy(nonEmpty)
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? .distantPast
    }
}
