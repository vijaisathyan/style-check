// swift-tools-version: 6.2
//
// Style Check — an offline grammar & style assistant for macOS.
// Open this file in Xcode and press Run (⌘R), or build a standalone app
// with `./scripts/make-app.sh`.

import PackageDescription

let package = Package(
    name: "StyleCheck",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "StyleCheck", targets: ["StyleCheck"])
    ],
    dependencies: [
        // On-device LLM inference on Apple silicon (Apple's MLX).
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMinor(from: "3.32.3")),
        // One-time model download + tokenizers (used only by the setup screen).
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
    ],
    targets: [
        // Pure-Foundation logic: chunking, search, library storage, prompts.
        // No UI and no ML, so it is fast to test.
        .target(
            name: "StyleCheckCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "StyleCheck",
            dependencies: [
                "StyleCheckCore",
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "StyleCheckCoreTests",
            dependencies: ["StyleCheckCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
