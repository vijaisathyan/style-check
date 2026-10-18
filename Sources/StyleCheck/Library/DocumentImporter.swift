import AppKit
import Foundation
import PDFKit
import StyleCheckCore
import UniformTypeIdentifiers
import Vision

/// Pulls plain text out of the documents people use for style guides.
/// Everything happens on this Mac; scanned PDF pages are read with Apple's
/// built-in, offline text recognition (Vision).
enum DocumentImporter {

    static let supportedTypes: [UTType] = {
        var types: [UTType] = [.pdf, .plainText, .rtf, .rtfd, .html]
        for ext in ["docx", "doc", "odt", "md", "markdown", "txt", "htm", "webarchive"] {
            if let t = UTType(filenameExtension: ext) { types.append(t) }
        }
        return types
    }()

    enum ImportError: LocalizedError {
        case unreadable(String)
        case empty(String)
        var errorDescription: String? {
            switch self {
            case .unreadable(let name): "Couldn't read “\(name)”. Try saving it as PDF, Word, or plain text."
            case .empty(let name): "No text was found in “\(name)”."
            }
        }
    }

    /// Extracts text sections. `progress` is called with 0...1 on the main actor.
    static func sections(
        from url: URL, progress: @escaping @MainActor (Double) -> Void
    ) async throws -> [TextSection] {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()

        let sections: [TextSection]
        switch ext {
        case "pdf":
            sections = try await Task.detached(priority: .userInitiated) {
                try pdfSections(url: url, progress: progress)
            }.value
        case "txt", "md", "markdown", "text":
            let text = try readPlainText(url)
            sections = [TextSection(text: text)]
        case "html", "htm", "webarchive":
            // HTML import uses WebKit and must run on the main thread.
            let text = try await MainActor.run { try attributedText(url: url, type: nil) }
            sections = [TextSection(text: text)]
        case "docx":
            sections = [TextSection(text: try attributedText(url: url, type: .officeOpenXML))]
        case "doc":
            sections = [TextSection(text: try attributedText(url: url, type: .docFormat))]
        case "odt":
            sections = [TextSection(text: try attributedText(url: url, type: .openDocument))]
        case "rtf":
            sections = [TextSection(text: try attributedText(url: url, type: .rtf))]
        case "rtfd":
            sections = [TextSection(text: try attributedText(url: url, type: .rtfd))]
        default:
            if let text = try? readPlainText(url) {
                sections = [TextSection(text: text)]
            } else {
                throw ImportError.unreadable(name)
            }
        }

        let total = sections.reduce(0) { $0 + $1.text.trimmingCharacters(in: .whitespacesAndNewlines).count }
        guard total > 20 else { throw ImportError.empty(name) }
        await progress(1)
        return sections
    }

    /// A friendly default title from the file name.
    static func title(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Formats

    private static func readPlainText(_ url: URL) throws -> String {
        if let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        var encoding = String.Encoding.utf8
        return try String(contentsOf: url, usedEncoding: &encoding)
    }

    private static func attributedText(url: URL, type: NSAttributedString.DocumentType?) throws -> String {
        var options: [NSAttributedString.DocumentReadingOptionKey: Any] = [:]
        if let type { options[.documentType] = type }
        do {
            let attributed = try NSAttributedString(url: url, options: options, documentAttributes: nil)
            return attributed.string
        } catch {
            throw ImportError.unreadable(url.lastPathComponent)
        }
    }

    private static func pdfSections(
        url: URL, progress: @escaping @MainActor (Double) -> Void
    ) throws -> [TextSection] {
        guard let document = PDFDocument(url: url) else {
            throw ImportError.unreadable(url.lastPathComponent)
        }
        var sections: [TextSection] = []
        let count = document.pageCount
        for index in 0..<count {
            guard let page = document.page(at: index) else { continue }
            var text = page.string ?? ""
            // Scanned page with no text layer: read it with on-device OCR.
            if text.trimmingCharacters(in: .whitespacesAndNewlines).count < 40 {
                text = (try? recognizeText(on: page)) ?? text
            }
            let label = page.label.flatMap { $0.isEmpty ? nil : $0 } ?? "\(index + 1)"
            sections.append(TextSection(text: text, location: "p. \(label)"))
            if index % 5 == 0 || index == count - 1 {
                let fraction = Double(index + 1) / Double(max(count, 1))
                Task { @MainActor in progress(fraction * 0.95) }
            }
        }
        return sections
    }

    private static func recognizeText(on page: PDFPage) throws -> String {
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let image = page.thumbnail(of: size, for: .mediaBox)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: "\n")
    }
}
