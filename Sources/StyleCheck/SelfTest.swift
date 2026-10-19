import Foundation
import MLX
import StyleCheckCore

/// `StyleCheck --self-test` checks a packaged app without opening a window:
/// MLX can find its Metal shaders inside the bundle and run on the GPU, and
/// the built-in style reference loads and is searchable. Used by the release
/// build to catch packaging mistakes before a disk image ships.
enum SelfTest {

    static func runIfRequested() {
        guard CommandLine.arguments.contains("--self-test") else { return }
        var failures = 0

        func check(_ name: String, _ body: () throws -> Bool) {
            do {
                let ok = try body()
                print(ok ? "✓ \(name)" : "✗ \(name)")
                if !ok { failures += 1 }
            } catch {
                print("✗ \(name): \(error)")
                failures += 1
            }
        }

        check("MLX runs on the GPU with bundled Metal shaders") {
            let x = MLXArray([1, 2, 3, 4] as [Float])
            let y = (x * 2 + 1).sum()
            eval(y)
            return y.item(Float.self) == 24
        }

        check("Built-in Chicago reference loads") {
            BuiltInGuide.chunks.count > 30
        }

        check("Search finds the serial comma rule") {
            let index = SearchIndex(guides: [(BuiltInGuide.guide(isEnabled: true), BuiltInGuide.chunks)])
            return index.search("Oxford comma").first?.chunk.heading == "Serial comma"
        }

        print(failures == 0 ? "Self-test passed." : "Self-test failed (\(failures)).")
        exit(failures == 0 ? 0 : 1)
    }
}
