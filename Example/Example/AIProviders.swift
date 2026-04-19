//
//  AIProviders.swift
//  Example — iOSPhotoEditor
//
//  Three reference PhotoEditorAIProvider implementations:
//
//    - StubAIProvider            : offline deterministic, for development/tests
//    - FoundationModelsProvider  : on-device Apple Intelligence, iOS 26+
//    - ClaudeAIProvider          : remote Anthropic Messages API, requires key
//
//  Pick one in ViewController.swift by swapping the `aiProvider` property.
//  See ai_guide.md for in-depth backend notes.
//

import UIKit
import iOSPhotoEditor

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - StubAIProvider

/// Deterministic offline provider — returns one of every annotation kind at
/// fixed positions. Handy for smoke-testing the pipeline and for CI runs
/// where you can't reach a real model. The smoke-test example uses this.
final class StubAIProvider: PhotoEditorAIProvider {
    func generateAnnotations(for request: PhotoEditorAIRequest)
        async throws -> [PhotoEditorAnnotation]
    {
        // Simulate latency so the spinner / review flow is visible.
        try await Task.sleep(nanoseconds: 800_000_000)

        let w = request.image.size.width
        let h = request.image.size.height
        var annotations: [PhotoEditorAnnotation] = []

        if request.allowedTools.contains(.text) {
            let label = request.prompt.map { "Revised: \($0)" } ?? "AI label"
            annotations.append(.text(
                label,
                at: CGPoint(x: w * 0.25, y: h * 0.15),
                fontSize: 30,
                color: .white,
                alignment: .center,
                outline: .black  // readable on any background
            ))
        }
        if request.allowedTools.contains(.box) {
            annotations.append(.box(
                CGRect(x: w * 0.10, y: h * 0.30, width: w * 0.25, height: h * 0.20),
                color: .systemRed, lineWidth: 6))
        }
        if request.allowedTools.contains(.ellipse) {
            annotations.append(.ellipse(
                CGRect(x: w * 0.55, y: h * 0.30, width: w * 0.25, height: h * 0.20),
                color: .systemGreen, lineWidth: 6))
        }
        if request.allowedTools.contains(.arrow) {
            annotations.append(.arrow(
                from: CGPoint(x: w * 0.15, y: h * 0.65),
                to:   CGPoint(x: w * 0.55, y: h * 0.80),
                color: .systemBlue, lineWidth: 6))
        }
        if request.allowedTools.contains(.sticker), let first = request.stickerCatalog.first {
            annotations.append(.sticker(
                id: first.id,
                at: CGPoint(x: w * 0.85, y: h * 0.85),
                size: 120))
        }
        return annotations
    }
}

// MARK: - FoundationModelsProvider  (iOS 26+, on-device)

#if canImport(FoundationModels)

/// Apple Foundation Models (iOS 26+) — on-device, no network, no API key, no
/// user permission prompts. The `@Generable` schema guides the model to
/// return structured JSON that we decode back into annotations.
///
/// Limitations to keep in mind:
///   - On-device models are smaller than frontier APIs, so prompts should be
///     simple and objective ("label visible equipment" rather than open-ended
///     reasoning).
///   - Multimodal / image input support evolves per iOS release. If image
///     input isn't yet available in your target OS version, pre-process with
///     Vision (VNClassifyImageRequest, VNRecognizeObjectsRequest, etc.) and
///     feed the resulting descriptors into the prompt as text.
@available(iOS 26.0, *)
final class FoundationModelsProvider: PhotoEditorAIProvider {

    @Generable
    struct AIAnnotationItem {
        /// "text" | "box" | "ellipse" | "arrow" | "sticker"
        let kind: String
        let text: String?
        let stickerID: String?
        let x: Double?
        let y: Double?
        let width: Double?
        let height: Double?
        let fromX: Double?
        let fromY: Double?
        let toX: Double?
        let toY: Double?
    }

    @Generable
    struct AIAnnotationsOutput {
        let items: [AIAnnotationItem]
    }

    func generateAnnotations(for request: PhotoEditorAIRequest)
        async throws -> [PhotoEditorAnnotation]
    {
        let promptText = Self.buildPrompt(request: request)

        let session = LanguageModelSession()
        let response = try await session.respond(
            to: promptText,
            generating: AIAnnotationsOutput.self
            // If your SDK version supports image input directly, pass the
            // image via a Transcript entry or the appropriate overload.
            // Otherwise pre-process with Vision and pass descriptors via the
            // prompt text.
        )
        return response.content.items.compactMap(Self.decode)
    }

    private static func buildPrompt(request: PhotoEditorAIRequest) -> String {
        let w = Int(request.image.size.width)
        let h = Int(request.image.size.height)
        let tools = request.allowedTools.map { $0.rawValue }.sorted().joined(separator: ", ")

        var contextLines: [String] = []
        for (k, v) in request.context.sorted(by: { $0.key < $1.key }) {
            contextLines.append("\(k): \(v)")
        }
        let contextBlock = contextLines.isEmpty ? "" : "\nContext:\n" + contextLines.joined(separator: "\n")

        let stickers = request.stickerCatalog
            .map { "\($0.id) — \($0.name)" }
            .joined(separator: ", ")
        let stickerLine = stickers.isEmpty ? "" : "\nAvailable sticker ids: \(stickers)"

        let userPrompt = request.prompt ?? "Annotate notable subjects in the image."

        return """
        You annotate images. Image size is \(w)x\(h) pixels, origin top-left.
        You may only use these tools: \(tools).
        \(contextBlock)\(stickerLine)

        Task: \(userPrompt)

        Return a list of items where each item is one of:
          text    — kind:"text",    x, y, text (label)
          box     — kind:"box",     x, y, width, height
          ellipse — kind:"ellipse", x, y, width, height
          arrow   — kind:"arrow",   fromX, fromY, toX, toY
          sticker — kind:"sticker", x, y, stickerID
        """
    }

    private static func decode(_ item: AIAnnotationItem) -> PhotoEditorAnnotation? {
        switch item.kind.lowercased() {
        case "text":
            guard let s = item.text, let x = item.x, let y = item.y else { return nil }
            return .text(s, at: CGPoint(x: x, y: y))
        case "box":
            guard let x = item.x, let y = item.y,
                  let w = item.width, let h = item.height else { return nil }
            return .box(CGRect(x: x, y: y, width: w, height: h))
        case "ellipse":
            guard let x = item.x, let y = item.y,
                  let w = item.width, let h = item.height else { return nil }
            return .ellipse(CGRect(x: x, y: y, width: w, height: h))
        case "arrow":
            guard let fx = item.fromX, let fy = item.fromY,
                  let tx = item.toX,   let ty = item.toY else { return nil }
            return .arrow(from: CGPoint(x: fx, y: fy),
                          to:   CGPoint(x: tx, y: ty))
        case "sticker":
            guard let id = item.stickerID, let x = item.x, let y = item.y else { return nil }
            return .sticker(id: id, at: CGPoint(x: x, y: y))
        default:
            return nil
        }
    }
}

#endif  // canImport(FoundationModels)

// MARK: - ClaudeAIProvider  (Anthropic Messages API, remote)

/// Anthropic Claude with vision — strong general-purpose backend for complex
/// prompts. Requires network and an API key. Cost scales with input image
/// tokens (roughly proportional to resolution) + output tokens.
///
/// ⚠️ SECURITY — do NOT ship to the App Store with a hardcoded API key.
/// Any key compiled into the binary can be extracted (binaries are trivially
/// inspectable: `strings`, Hopper, Ghidra, a jailbroken device). An attacker
/// who pulls your key from TestFlight / App Store builds can run up arbitrary
/// bills on your account and exfiltrate data through your quota.
///
/// For a shipping app, route AI calls through a backend you control:
///
///   iOS app  ──(auth token)──►  your server  ──(API key)──►  Anthropic
///
///   - Your server holds the Anthropic key (env var, secrets manager, etc.).
///   - The iOS app authenticates the USER (Sign in with Apple, your own
///     auth, etc.) and sends the image + request metadata to your server.
///   - Your server validates the user, forwards the image to Anthropic with
///     the server-held key, and returns the annotations.
///   - This also lets you rate-limit per-user, log/audit usage, enforce
///     content moderation, and rotate the key without shipping a new build.
///
/// In this provider you'd then point `URL` at your own endpoint and pass
/// your user's auth token instead of `x-api-key`. This sample uses the
/// direct Anthropic endpoint only so the code is self-contained for
/// development and internal tools — not for a public release.
///
/// `YOUR_ANTHROPIC_API_KEY` is a placeholder — throws an error if unset so
/// no silent failures slip through.
final class ClaudeAIProvider: PhotoEditorAIProvider {

    let apiKey: String
    let model: String

    init(apiKey: String = "YOUR_ANTHROPIC_API_KEY",
         model: String = "claude-opus-4-7") {
        self.apiKey = apiKey
        self.model = model
    }

    func generateAnnotations(for request: PhotoEditorAIRequest)
        async throws -> [PhotoEditorAnnotation]
    {
        guard apiKey != "YOUR_ANTHROPIC_API_KEY", !apiKey.isEmpty else {
            throw NSError(domain: "ClaudeAIProvider", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Set your Anthropic API key before calling."])
        }
        guard let jpeg = request.image.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "ClaudeAIProvider", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Could not encode image as JPEG."])
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": Self.buildSystemPrompt(request: request),
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": jpeg.base64EncodedString(),
                        ],
                    ],
                    [
                        "type": "text",
                        "text": request.prompt ?? "Annotate the image.",
                    ],
                ],
            ]],
        ]

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? "<non-text response>"
            throw NSError(domain: "ClaudeAIProvider", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(text)"])
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        let responseText = decoded.content.compactMap { $0.text }.joined()
        return Self.decodeAnnotationList(from: responseText)
    }

    // MARK: Prompt

    private static func buildSystemPrompt(request: PhotoEditorAIRequest) -> String {
        let w = Int(request.image.size.width)
        let h = Int(request.image.size.height)

        // Only offer schemas for allowed tools — keeps the model from
        // producing kinds the library will drop anyway.
        let schemas: [(PhotoEditorAITool, String)] = [
            (.text,    ##"{"type":"text","x":N,"y":N,"text":"...","color":"#RRGGBB","alignment":"left|center|right","outline":"#RRGGBB"}"##),
            (.box,     ##"{"type":"box","x":N,"y":N,"w":N,"h":N,"color":"#RRGGBB"}"##),
            (.ellipse, ##"{"type":"ellipse","x":N,"y":N,"w":N,"h":N,"color":"#RRGGBB"}"##),
            (.arrow,   ##"{"type":"arrow","fromX":N,"fromY":N,"toX":N,"toY":N,"color":"#RRGGBB"}"##),
            (.sticker, ##"{"type":"sticker","x":N,"y":N,"id":"..."}"##),
        ]
        let schemaBlock = schemas
            .filter { request.allowedTools.contains($0.0) }
            .map { "  " + $0.1 }
            .joined(separator: "\n")

        var contextLines: [String] = []
        for (k, v) in request.context.sorted(by: { $0.key < $1.key }) {
            contextLines.append("  \(k): \(v)")
        }
        let contextBlock = contextLines.isEmpty ? "" : "\n\nHost-supplied context:\n" + contextLines.joined(separator: "\n")

        let stickerBlock: String = {
            guard !request.stickerCatalog.isEmpty else { return "" }
            let lines = request.stickerCatalog
                .map { "  \($0.id): \($0.name)" }
                .joined(separator: "\n")
            return "\n\nAvailable stickers (use the id in the \"id\" field):\n" + lines
        }()

        return """
        You annotate images. The image dimensions are \(w)x\(h) pixels, origin top-left.
        Respond with a raw JSON array (no markdown, no prose). Each element must
        match one of these shapes exactly — do NOT produce any other kinds:

        \(schemaBlock)

        Coordinates are in pixels within the image provided. Colors are
        optional and default to yellow. Keep annotations legible — place
        text near (not over) the subject, and don't overlap labels.
        \(contextBlock)\(stickerBlock)
        """
    }

    // MARK: Response decoding

    private struct ClaudeResponse: Decodable {
        let content: [Block]
        struct Block: Decodable {
            let text: String?
        }
    }

    private static func decodeAnnotationList(from raw: String) -> [PhotoEditorAnnotation] {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")

        guard let data = trimmed.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }

        return items.compactMap { dict in
            let color = (dict["color"] as? String).flatMap(UIColor.init(hex:)) ?? .systemYellow
            switch dict["type"] as? String {
            case "text":
                guard let s = dict["text"] as? String,
                      let x = (dict["x"] as? NSNumber)?.doubleValue,
                      let y = (dict["y"] as? NSNumber)?.doubleValue
                else { return nil }
                let alignment: NSTextAlignment = {
                    switch dict["alignment"] as? String {
                    case "left":  return .left
                    case "right": return .right
                    default:      return .center
                    }
                }()
                let outline = (dict["outline"] as? String).flatMap(UIColor.init(hex:))
                return .text(s,
                             at: CGPoint(x: x, y: y),
                             color: color,
                             alignment: alignment,
                             outline: outline)
            case "box":
                guard let x = (dict["x"] as? NSNumber)?.doubleValue,
                      let y = (dict["y"] as? NSNumber)?.doubleValue,
                      let w = (dict["w"] as? NSNumber)?.doubleValue,
                      let h = (dict["h"] as? NSNumber)?.doubleValue
                else { return nil }
                return .box(CGRect(x: x, y: y, width: w, height: h), color: color)
            case "ellipse":
                guard let x = (dict["x"] as? NSNumber)?.doubleValue,
                      let y = (dict["y"] as? NSNumber)?.doubleValue,
                      let w = (dict["w"] as? NSNumber)?.doubleValue,
                      let h = (dict["h"] as? NSNumber)?.doubleValue
                else { return nil }
                return .ellipse(CGRect(x: x, y: y, width: w, height: h), color: color)
            case "arrow":
                guard let fx = (dict["fromX"] as? NSNumber)?.doubleValue,
                      let fy = (dict["fromY"] as? NSNumber)?.doubleValue,
                      let tx = (dict["toX"]   as? NSNumber)?.doubleValue,
                      let ty = (dict["toY"]   as? NSNumber)?.doubleValue
                else { return nil }
                return .arrow(from: CGPoint(x: fx, y: fy),
                              to:   CGPoint(x: tx, y: ty),
                              color: color)
            case "sticker":
                guard let id = dict["id"] as? String,
                      let x = (dict["x"] as? NSNumber)?.doubleValue,
                      let y = (dict["y"] as? NSNumber)?.doubleValue
                else { return nil }
                return .sticker(id: id, at: CGPoint(x: x, y: y))
            default:
                return nil
            }
        }
    }
}

// MARK: - Tiny UIColor hex helper

fileprivate extension UIColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let rgb = UInt64(s, radix: 16) else { return nil }
        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >>  8) & 0xFF) / 255.0,
            blue:  CGFloat( rgb        & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
