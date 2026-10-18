import Foundation

/// Open-weight models small enough for an 8 GB Apple-silicon Mac.
/// All are 4-bit quantized MLX builds from the mlx-community on Hugging Face.
struct LocalModel: Identifiable, Hashable, Sendable {
    let id: String  // Hugging Face repository
    let name: String
    let summary: String
    let downloadSize: String
    let license: String
    let extraEOSTokens: Set<String>
    /// Turns off "thinking" for Qwen3 so answers start immediately.
    let disablesThinking: Bool

    var additionalContext: [String: any Sendable]? {
        disablesThinking ? ["enable_thinking": false] : nil
    }

    static func == (lhs: LocalModel, rhs: LocalModel) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum ModelCatalog {
    static let qwen3_4B = LocalModel(
        id: "mlx-community/Qwen3-4B-4bit",
        name: "Qwen3 4B",
        summary: "Best answers that still run comfortably on 8 GB. Recommended.",
        downloadSize: "2.3 GB",
        license: "Apache 2.0",
        extraEOSTokens: ["<|im_end|>"],
        disablesThinking: true)

    static let llama3_2_3B = LocalModel(
        id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
        name: "Llama 3.2 3B",
        summary: "A little lighter and quick. Good general writing knowledge.",
        downloadSize: "1.8 GB",
        license: "Llama 3.2 Community License",
        extraEOSTokens: ["<|eot_id|>"],
        disablesThinking: false)

    static let qwen3_1_7B = LocalModel(
        id: "mlx-community/Qwen3-1.7B-4bit",
        name: "Qwen3 1.7B",
        summary: "Fastest and lightest. Shorter, less reliable explanations.",
        downloadSize: "1.0 GB",
        license: "Apache 2.0",
        extraEOSTokens: ["<|im_end|>"],
        disablesThinking: true)

    static let all = [qwen3_4B, llama3_2_3B, qwen3_1_7B]
    static let recommended = qwen3_4B

    static func model(id: String) -> LocalModel {
        all.first { $0.id == id } ?? recommended
    }
}

enum AnswerLength: String, CaseIterable, Identifiable {
    case short, normal, detailed
    var id: String { rawValue }
    var label: String {
        switch self {
        case .short: "Short"
        case .normal: "Normal"
        case .detailed: "Detailed"
        }
    }
    var maxTokens: Int {
        switch self {
        case .short: 350
        case .normal: 700
        case .detailed: 1100
        }
    }
}
