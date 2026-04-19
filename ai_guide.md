# AI Annotation Guide

This library provides a pluggable AI-annotation pipeline: tap the sparkles
button, optionally type a prompt, and returned annotations are placed on the
canvas as **editable subviews** (drag / rotate / resize / undo — exactly like
user-placed text, stickers, and shapes).

The library imports no AI frameworks and ships with no provider. The host app
supplies an implementation of `PhotoEditorAIProvider` backed by whatever
backend it chooses. This doc covers how to write one.

---

## 1. Concepts

### The contract

```swift
public struct PhotoEditorAIRequest {
    public let image: UIImage
    public let allowedTools: Set<PhotoEditorAITool>
    public let prompt: String?
    public let context: [String: String]
    public let stickerCatalog: [PhotoEditorStickerInfo]
    public let previousAnnotations: [PhotoEditorAnnotation]?
}

public protocol PhotoEditorAIProvider: AnyObject {
    func generateAnnotations(for request: PhotoEditorAIRequest)
        async throws -> [PhotoEditorAnnotation]
}

public enum PhotoEditorAITool: String, CaseIterable, Sendable {
    case text, box, ellipse, arrow, sticker
}
```

Your provider receives a request carrying the image plus the set of
annotation kinds the host permits, and returns annotations. Omit disallowed
tools from your prompt and response — the library also filters on return
as a safety net. The request is a struct so future fields (prompts,
context dictionary, sticker catalog) can land without breaking compiled
providers.

### Error surfacing

A provider may throw; the editor silently discards the result (canvas
unchanged, no undo snapshot). To show the user what went wrong:

```swift
editor.aiDelegate = self   // conforms to PhotoEditorAIDelegate

// MARK: PhotoEditorAIDelegate
func photoEditor(_ editor: PhotoEditorViewController,
                 aiAnnotationDidFail error: Error) {
    presentAlert("Annotation failed", message: error.localizedDescription)
}
```

### What the library guarantees

- The button only appears when you assign `editor.aiProvider = yourProvider`.
- No `Info.plist` permission prompts are forced on your users — whatever
  permissions your provider needs (network, etc.) are your concern.
- Returned annotations land as **editable** subviews (text = `UITextView`,
  box/ellipse/arrow = `UIImageView` with standard gestures + undo support).
- If your provider throws, nothing happens to the canvas. No partial state.

### Host-side wiring (minimal)

```swift
class HostViewController: UIViewController {
    // `PhotoEditorViewController.aiProvider` is weak — the editor does not
    // retain the provider. Hold a strong reference here, otherwise an
    // inline-constructed provider deallocates before the sparkles button fires.
    private let aiProvider = MyProvider()

    func openEditor(with image: UIImage) {
        let editor = PhotoEditorViewController()
        editor.aiProvider = aiProvider
        editor.availableShapes = [.box, .ellipse, .arrow]  // show shapes button
        editor.image = image
        present(editor, animated: true)
    }
}
```

### Restricting tools

```swift
// Global cap — the model can only produce text + ellipse annotations.
editor.aiAllowedTools = [.text, .ellipse]
```

Default is all four kinds. The library passes the allowed set to the
provider on each request (so its prompt can omit disallowed tools) and
silently drops any returned annotation whose kind isn't in the set. When
preset prompts ship, each prompt can further narrow the set via
intersection with this global cap — it can never widen it.

---

## 2. The image pipeline

**The provider does not receive the full-resolution image.** The editor
sends a **downscaled composite**:

1. Compose the current base image with any user annotations on it (circles,
   boxes, text, stickers, freehand strokes) — producing a rasterized snapshot
   of what the user currently sees.
2. Resize so the longest edge ≤ `editor.aiMaxImageDimension`
   (default `2048`).
3. Hand that UIImage to `generateAnnotations(for:)`.

**Why this matters for your provider:**

- **Coord system of returned annotations is the coord space of the image you
  received.** If you got a 2048×1536 UIImage, return coords between
  (0,0) and (2048,1536).
- You see user annotations in the image. A user can circle an object and ask
  "what's in the circle?" — you see the circle and know where to focus.
- You don't have to scale anything back to original resolution — the library
  does it for you, using the scale factor it captured at send time.

**Sizing guidance:** 2048 longest edge is enough detail for most vision
models and keeps token / latency costs bounded. Drop to 1024 if you're on
a tight budget, 1536 for a balance. Higher than 2048 rarely improves
annotation quality and gets expensive fast.

---

## 3. Annotation reference

```swift
public enum PhotoEditorAnnotation {
    case text(String, at: CGPoint, fontSize: CGFloat = 30,
              color: UIColor? = nil, alignment: NSTextAlignment = .center,
              outline: UIColor? = nil)
    case box(CGRect, color: UIColor = .yellow, lineWidth: CGFloat = 6)
    case ellipse(CGRect, color: UIColor = .yellow, lineWidth: CGFloat = 6)
    case arrow(from: CGPoint, to: CGPoint, color: UIColor = .yellow, lineWidth: CGFloat = 6)
    case sticker(id: String, at: CGPoint, size: CGFloat? = nil)
}
```

**Text outline** — when the AI can't predict the background (bright sky vs.
dark foreground), pass `outline:` to draw a contrasting stroke around every
character. A classic combo is `color: .white, outline: .black` — stays
readable on any backdrop. `nil` (default) skips the stroke.

All `CGPoint` / `CGRect` values are in **sent-image coordinate space** (origin
top-left, extent = size of the UIImage your provider received).

| Case | Use for |
|------|---------|
| `.text` | Labels, tags, captions at a point. `alignment` controls horizontal alignment (use `.right` for text anchored to a right corner, etc.) |
| `.box` | Bounding boxes around detected objects |
| `.ellipse` | Circling a subject (friendlier than a box for human highlighting) |
| `.arrow` | Pointing from a label to a location, before/after callouts |
| `.sticker` | Place a named sticker from `request.stickerCatalog` (e.g. a company logo, a warning icon) |

`fontSize` is in display points (same as `UIFont.pointSize`). `lineWidth` is
also in display points — the library maps it sensibly at render time.
`.sticker` `size` is the longest-edge length in display points; `nil`
uses a sensible default.

### Named stickers

Host-side:

```swift
editor.namedStickers = [
    PhotoEditorSticker(id: "logo",     name: "Company logo",     image: logoImage),
    PhotoEditorSticker(id: "warning",  name: "Warning triangle", image: warningImage),
    PhotoEditorSticker(id: "check",    name: "Checkmark",        image: checkImage),
]
editor.aiAllowedTools.insert(.sticker)  // default already includes all tools
```

The provider sees only `PhotoEditorStickerInfo` values (id + name). Use
the name to reason about what each sticker represents; return the id in
`.sticker(id:at:size:)`. Ids not in the catalog are silently dropped.

### Host-supplied context

```swift
editor.aiContext = [
    "projectName": "Project Phoenix",
    "datetime":    ISO8601DateFormatter().string(from: Date()),
    "latitude":    "43.6532",
    "longitude":   "-79.3832",
    "inspector":   currentUser.name,
]
```

Each key/value arrives in `request.context`. Inline values in your prompt
so the model sees them, e.g. `"Add a timestamp reading {datetime} in the
best corner."`

#### EXIF convenience

`ImageMetadata.summarize(from: Data)` flattens a raw image file's EXIF,
TIFF, and GPS dictionaries into a plain `[String: String]` with common
keys ready for `aiContext`:

| Key | Source |
|-----|--------|
| `datetime`       | EXIF DateTimeOriginal |
| `gps.latitude`   | GPS Latitude (signed, LatitudeRef applied) |
| `gps.longitude`  | GPS Longitude (signed) |
| `gps.altitude`   | GPS Altitude |
| `camera.make`    | TIFF Make |
| `camera.model`   | TIFF Model |
| `lens.model`     | EXIF LensModel |

Only fields actually present in the file are emitted.

```swift
if let data = try? Data(contentsOf: imageURL) {
    editor.aiContext.merge(ImageMetadata.summarize(from: data)) { host, _ in host }
}
```

The host-set values win on key collision above (swap the merge closure
if you want EXIF to override). For a `UIImage` from a photo picker,
request the underlying `PHAsset` or file URL to get raw Data — `UIImage`
usually strips EXIF in-memory.

---

## 4. Use cases

### Safety and compliance
"Circle every person not wearing a hard hat. Add a red ellipse and the
label 'MISSING PPE' above each."

### Construction markup
"For each defect visible in this photo, add a yellow box and a text note
describing the issue and a rough severity (low/medium/high)."

### Inventory / asset tagging
"Label each piece of visible heavy equipment with its type (e.g. excavator,
skid-steer, dump-truck)."

### Field identification
"Label each plant or animal with its common name."

### Document / diagram
"Add a box around each signature line and label whether it's signed."

### Multi-step: circle-then-label
The user draws a shape around something interesting and taps sparkles with
the prompt "what's inside the circle?" The provider sees the composite
image (including the circle) and returns a `.text` annotation inside the
circled region.

---

## 5. Backend integration patterns

Four common backends are covered below, ordered from simplest / no-network
to most capable / remote.

### 5a. Apple Vision framework (iOS 13+)

**Best for:** deterministic object / text / face detection with no prompt
reasoning and no network. Fast, free, on-device, no user permissions.

**Can't do:** follow natural-language instructions like "circle the hazard."
Your provider decides what to detect; the model just finds it.

```swift
import Vision
import UIKit

final class VisionAIProvider: PhotoEditorAIProvider {
    func generateAnnotations(for request: PhotoEditorAIRequest)
        async throws -> [PhotoEditorAnnotation]
    {
        let image = request.image
        let allowedTools = request.allowedTools
        guard let cgImage = image.cgImage else { return [] }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let size = image.size
        var annotations: [PhotoEditorAnnotation] = []
        for obs in request.results ?? [] {
            // Vision returns normalized, origin bottom-left — convert.
            let rect = VNImageRectForNormalizedRect(obs.boundingBox,
                                                    Int(size.width), Int(size.height))
            let flipped = CGRect(
                x: rect.origin.x,
                y: size.height - rect.origin.y - rect.height,
                width: rect.width, height: rect.height
            )
            if allowedTools.contains(.box) {
                annotations.append(.box(flipped, color: .systemYellow, lineWidth: 4))
            }
            if allowedTools.contains(.text), let top = obs.topCandidates(1).first {
                annotations.append(.text(
                    top.string,
                    at: CGPoint(x: flipped.minX, y: max(flipped.minY - 8, 0)),
                    fontSize: 20,
                    color: .systemYellow
                ))
            }
        }
        return annotations
    }
}
```

Swap `VNRecognizeTextRequest` for `VNRecognizeAnimalsRequest`,
`VNClassifyImageRequest`, `VNDetectHumanRectanglesRequest`, etc. as needed.

### 5b. Foundation Models (iOS 26+, on-device)

**Best for:** natural-language prompts with structured JSON output, fully
on-device. No network, no API key, no cost, no permissions. Limited
reasoning compared to frontier remote models but enough for well-scoped
vision tasks.

```swift
import FoundationModels
import UIKit

@Generable
struct AIAnnotations {
    let annotations: [Item]

    @Generable
    struct Item {
        let kind: String      // "text" | "box" | "ellipse" | "arrow"
        let text: String?
        let x: Double?
        let y: Double?
        let width: Double?
        let height: Double?
        let fromX: Double?
        let fromY: Double?
        let toX: Double?
        let toY: Double?
    }
}

final class FoundationModelsProvider: PhotoEditorAIProvider {
    func generateAnnotations(for request: PhotoEditorAIRequest)
        async throws -> [PhotoEditorAnnotation]
    {
        let image = request.image
        let allowedTools = request.allowedTools
        let session = LanguageModelSession()
        let w = Int(image.size.width), h = Int(image.size.height)

        let prompt = """
        Image is \(w)x\(h) pixels, origin top-left.
        Identify notable objects and return annotations.
        For each, provide a box and a short text label positioned near the
        top-left corner of the box. Use pixel coordinates within the image.
        """

        let result = try await session.respond(
            to: prompt,
            image: image,
            generating: AIAnnotations.self
        )

        return result.content.annotations.compactMap { decode($0) }
    }

    private func decode(_ item: AIAnnotations.Item) -> PhotoEditorAnnotation? {
        switch item.kind {
        case "text":
            guard let x = item.x, let y = item.y, let s = item.text else { return nil }
            return .text(s, at: CGPoint(x: x, y: y))
        case "box":
            guard let x = item.x, let y = item.y, let w = item.width, let h = item.height
                else { return nil }
            return .box(CGRect(x: x, y: y, width: w, height: h))
        case "ellipse":
            guard let x = item.x, let y = item.y, let w = item.width, let h = item.height
                else { return nil }
            return .ellipse(CGRect(x: x, y: y, width: w, height: h))
        case "arrow":
            guard let fx = item.fromX, let fy = item.fromY,
                  let tx = item.toX, let ty = item.toY else { return nil }
            return .arrow(from: CGPoint(x: fx, y: fy), to: CGPoint(x: tx, y: ty))
        default: return nil
        }
    }
}
```

### 5c. Claude API (remote)

**Best for:** frontier reasoning quality, complex prompts, nuanced
understanding. Requires network and API key. Costs per request.

> **⚠️ Do not ship an App Store build with a hardcoded API key.**
> Keys compiled into the binary are extractable (`strings`, Hopper,
> jailbroken device); anyone with your TestFlight IPA can spend your
> Anthropic quota and exfiltrate data through it.
>
> For production, put a proxy between the app and the model provider:
>
> ```
> iOS app  ──(user auth token)──►  your server  ──(secret key)──►  Anthropic
> ```
>
> Your server holds the secret key, authenticates the *user*, forwards
> the request, and returns annotations. This also lets you rate-limit
> per user, log / audit / moderate usage, and rotate the key without
> shipping an update. In your `PhotoEditorAIProvider`, point the URL at
> your server and send a user auth token instead of `x-api-key`.
>
> The sample below calls Anthropic directly — fine for development,
> internal tools, and private enterprise distribution; not for a public
> release.

```swift
import UIKit

final class ClaudeProvider: PhotoEditorAIProvider {
    let apiKey: String
    init(apiKey: String) { self.apiKey = apiKey }

    func generateAnnotations(for request: PhotoEditorAIRequest)
        async throws -> [PhotoEditorAnnotation]
    {
        let image = request.image
        let allowedTools = request.allowedTools
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return [] }
        let base64 = jpeg.base64EncodedString()
        let w = Int(image.size.width), h = Int(image.size.height)

        let body: [String: Any] = [
            "model": "claude-opus-4-7",
            "max_tokens": 2048,
            "system": systemPrompt(width: w, height: h, allowedTools: allowedTools),
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image",
                     "source": ["type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64]],
                    ["type": "text", "text": "Annotate this image."]
                ]
            ]]
        ]

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        let text = resp.content.first?.text ?? "[]"
        return try decodeJSONSchema(text)
    }

    private func systemPrompt(width: Int, height: Int,
                              allowedTools: Set<PhotoEditorAITool>) -> String {
        let schemas: [(PhotoEditorAITool, String)] = [
            (.text,    #"{"type":"text","x":N,"y":N,"text":"...","color":"#RRGGBB"}"#),
            (.box,     #"{"type":"box","x":N,"y":N,"w":N,"h":N,"color":"#RRGGBB"}"#),
            (.ellipse, #"{"type":"ellipse","x":N,"y":N,"w":N,"h":N,"color":"#RRGGBB"}"#),
            (.arrow,   #"{"type":"arrow","fromX":N,"fromY":N,"toX":N,"toY":N,"color":"#RRGGBB"}"#)
        ]
        let schema = schemas
            .filter { allowedTools.contains($0.0) }
            .map { "  " + $0.1 }
            .joined(separator: "\n")

        return """
        You annotate images. Image dimensions are \(width)x\(height) pixels,
        origin top-left. Return ONLY a JSON array (no prose). Each item MUST be
        one of these forms — do NOT produce any other types:

        \(schema)

        All coordinates are in pixels within the image provided. Colors are
        optional and default to yellow for shapes. Keep annotations legible —
        don't overlap labels, and place text near (not over) the subject.
        """
    }

    // See "Prompt templates & JSON schema" section for decodeJSONSchema.
}

struct ClaudeResponse: Decodable {
    let content: [Block]
    struct Block: Decodable { let text: String? }
}
```

### 5d. Generic OpenAI-compatible (GPT-4V, local LLaVA, etc.)

Same shape as the Claude example above — swap the endpoint, the auth
header, and the response decoding path. The system prompt and JSON schema
are identical.

The same key-security warning from 5c applies: don't ship with a hardcoded
OpenAI / third-party API key. Proxy through your own backend. A key
`grep`-able out of your App Store IPA is a key someone else will spend.

---

## 6. Prompt templates & JSON schema

The recommended response schema is a flat array of objects:

```json
[
  {"type": "text",    "x": 420, "y": 210, "text": "No hard hat", "color": "#ff3b30"},
  {"type": "ellipse", "x": 380, "y": 150, "w": 180, "h": 240, "color": "#ff3b30"},
  {"type": "box",     "x": 900, "y": 500, "w": 240, "h": 180, "color": "#ffcc00"},
  {"type": "arrow",   "fromX": 800, "fromY": 600, "toX": 910, "toY": 590, "color": "#ffcc00"}
]
```

A generic decoder you can reuse across remote backends:

```swift
func decodeJSONSchema(_ raw: String) throws -> [PhotoEditorAnnotation] {
    // Strip optional ```json fences
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "```json", with: "")
        .replacingOccurrences(of: "```", with: "")
    let data = Data(trimmed.utf8)
    let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []

    return items.compactMap { dict in
        let color = (dict["color"] as? String).flatMap(UIColor.init(hex:)) ?? .yellow
        switch dict["type"] as? String {
        case "text":
            guard let s = dict["text"] as? String,
                  let x = dict["x"] as? Double, let y = dict["y"] as? Double
                else { return nil }
            return .text(s, at: CGPoint(x: x, y: y), color: color)
        case "box":
            guard let x = dict["x"] as? Double, let y = dict["y"] as? Double,
                  let w = dict["w"] as? Double, let h = dict["h"] as? Double
                else { return nil }
            return .box(CGRect(x: x, y: y, width: w, height: h), color: color)
        case "ellipse":
            guard let x = dict["x"] as? Double, let y = dict["y"] as? Double,
                  let w = dict["w"] as? Double, let h = dict["h"] as? Double
                else { return nil }
            return .ellipse(CGRect(x: x, y: y, width: w, height: h), color: color)
        case "arrow":
            guard let fx = dict["fromX"] as? Double, let fy = dict["fromY"] as? Double,
                  let tx = dict["toX"] as? Double,   let ty = dict["toY"] as? Double
                else { return nil }
            return .arrow(from: CGPoint(x: fx, y: fy),
                          to:   CGPoint(x: tx, y: ty), color: color)
        default: return nil
        }
    }
}
```

### Example prompt library

**Safety inspector (hard hat check):**
> Find every person in the image. For each person not wearing a hard hat,
> add a red ellipse tightly around their head and a red text label
> "NO HARD HAT" directly above.

**Construction defect catalog:**
> Identify visible defects: cracks, water damage, exposed rebar, missing
> components, unsafe clearances. For each, add a yellow box and a short
> red text label naming the defect. Limit to 10 most significant.

**Species identification:**
> Label each plant and animal with its common English name. Place the
> label near (not over) the subject.

**Inventory tagging:**
> List each piece of equipment visible. For each, add a yellow box and
> a text label with the type (e.g. "Excavator", "Skid-steer",
> "Generator").

### Prompt tips

- Ask for JSON only. Models default to being chatty.
- Include image dimensions in the system prompt, not just the user prompt.
- Specify coordinate origin explicitly ("top-left, pixels").
- Cap the result set ("at most 10") — runaway lists crowd the canvas.
- Few-shot examples help structure — show one ideal output.

---

## 7. Headless mode

For batch processing, server-side use, or any flow that doesn't need the
editor UI, call `PhotoEditorAIHeadless.annotate(...)` directly:

```swift
let result = try await PhotoEditorAIHeadless.annotate(
    image: rawPhoto,
    provider: myProvider,
    allowedTools: [.text, .sticker],
    prompt: "Place the project name and {datetime} in the best corner. " +
            "Pick a text color that contrasts the image.",
    context: [
        "projectName": "Project Phoenix",
        "datetime":    ISO8601DateFormatter().string(from: Date()),
    ],
    stickers: [companyLogoSticker]
)
// `result` is a UIImage with text + logo flattened into the photo.
```

The headless path:
1. Downscales the image to `maxImageDimension` (default 2048),
2. Calls your provider with a request struct identical to the in-editor one,
3. Filters the response against `allowedTools` (safety net),
4. Flattens all returned annotations into a copy of the full-resolution
   image and returns it.

No UI is shown, no view controller is required, and returned coordinates
are scaled back to the full resolution automatically.

**Reusing a stored annotation list** — `renderAnnotations(_:onto:...)` is
also public, so you can persist annotations (encode the enum cases) and
render them later without re-calling the provider.

## 8. Advanced

### Review flow (accept / decline / revise)

Opt in with:

```swift
editor.aiReviewBeforeCommit = true
```

When the provider returns, annotations land on the canvas with a yellow
pending border and a bottom-centered review toolbar appears:

- **Accept** — commits the batch as a single undo step. Border disappears.
- **Decline** — removes all pending annotations. Nothing enters the undo stack.
- **Revise…** — prompts for a text instruction (e.g. "don't circle the
  guy in red"), then re-calls the provider with both your revision text
  in `request.prompt` and the current batch in
  `request.previousAnnotations`. Your provider interprets this as
  "given these annotations, apply this change and return a replacement
  set." The pending batch is swapped in place; the review toolbar stays.

During review, the undo button is disabled and re-tapping the sparkles
button is ignored — finish the review first.

The user can still drag, pinch, rotate, or delete individual pending
annotations before accepting. Edits to accepted annotations are committed
as part of the Accept snapshot.

### Preset prompts, custom prompts, and suffixes

Four host-configurable prompts control what happens when the user taps
the sparkles button:

```swift
public var aiPresetPrompts: [PhotoEditorAIPrompt]   // named prompts shown in picker
public var aiAllowCustomPrompt: Bool                // "Custom…" entry / text input
public var aiCustomPromptSuffix: String?            // appended to user-typed prompts
```

The picker auto-adapts:

| `aiPresetPrompts` | `aiAllowCustomPrompt` | Behavior on tap |
|-------------------|-----------------------|-----------------|
| empty | `false` | Fire immediately, `request.prompt = nil` |
| empty | `true`  | Text-input alert — user must type a prompt |
| non-empty | `false` | Action sheet with preset names only |
| non-empty | `true`  | Action sheet with presets + "Custom…" |

A `PhotoEditorAIPrompt` carries a stable id, a short `name`, an optional
`description` (shown as subtitle), the full `instruction` text sent to
the provider, and optionally a narrower `allowedTools` set:

```swift
editor.aiPresetPrompts = [
    PhotoEditorAIPrompt(
        id: "safety-ppe",
        name: "Safety Check",
        description: "Find people missing hard hats",
        instruction: "Circle every person not wearing a hard hat. Label each " +
                     "with 'MISSING PPE' in red."
    ),
    PhotoEditorAIPrompt(
        id: "equipment",
        name: "Label Equipment",
        instruction: "Label each piece of heavy equipment with its type.",
        allowedTools: [.text, .box]  // narrows the global set for this preset
    ),
]
editor.aiAllowCustomPrompt = true
```

#### Custom prompt suffix

`aiCustomPromptSuffix` is appended (with a blank line separator) to any
**user-typed** prompt — both the initial "Custom…" entry and Revise-flow
feedback. Preset instructions are **not** suffixed, since the host
already authors those in full. Useful for enforcing style rules without
repeating them in every alert dialog:

```swift
editor.aiCustomPromptSuffix =
    "Use a light blue color so annotations are visible on dark water."
```

#### Effective `allowedTools`

A preset's `allowedTools` is intersected with the editor's global
`aiAllowedTools` — a preset can narrow, never widen, the set.

### Error handling

If your provider throws, the editor silently discards the result — the
canvas is not mutated, no snapshot is taken, no partial state. Set
`editor.aiDelegate` to observe errors and surface them to the user.

### Latency expectations

| Backend              | Typical latency   | Notes |
|----------------------|-------------------|-------|
| Vision               | 50–300 ms         | Per-request, on-device |
| Foundation Models    | 1–5 s             | On-device, iOS 26+ |
| Claude (remote)      | 3–10 s            | Network + inference |

The editor shows a modal spinner during the request. For interactive
backends (Vision), consider replacing it with an inline indicator later.

### Cost expectations (remote)

A 2048×1536 JPEG at 85% quality is ~400 KB, ~1400 tokens as input for
Claude vision. Plus output tokens (typically 200–800 for an annotation
set). Budget accordingly. Drop `aiMaxImageDimension` to 1024 if you need
to cut cost roughly in half.
