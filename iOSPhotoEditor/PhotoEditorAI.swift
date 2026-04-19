//
//  PhotoEditorAI.swift
//  iOSPhotoEditor
//
//  Pluggable AI annotation provider. The library imports no AI frameworks
//  and requires no permissions — the host app supplies an implementation
//  backed by Vision, Foundation Models, a remote API, etc.
//

import Foundation
import UIKit

/// Interactive shape kinds the user can draw via the shapes toolbar button.
/// Order matters — it drives the long-press cycle order.
public enum PhotoEditorShape: String, CaseIterable {
    case box
    case ellipse
    case arrow
}

/// Annotation kinds an AI provider is allowed to produce. A host restricts
/// the set via `PhotoEditorViewController.aiAllowedTools` (global) and — once
/// preset prompts ship — per-prompt `allowedTools` overrides that intersect
/// with the global set. The library filters returned annotations against the
/// effective set as a safety net.
public enum PhotoEditorAITool: String, CaseIterable, Sendable {
    case text
    case box
    case ellipse
    case arrow
    case sticker
}

/// A named sticker the host makes available for AI-driven placement.
/// The `id` is what the provider quotes back in `.sticker(id:at:size:)`
/// annotations; `name` is the human-readable label the AI sees in the
/// catalog so it knows what each sticker represents.
public struct PhotoEditorSticker {
    public let id: String
    public let name: String
    public let image: UIImage

    public init(id: String, name: String, image: UIImage) {
        self.id = id
        self.name = name
        self.image = image
    }
}

/// Metadata describing an available sticker, passed to the provider as part
/// of `PhotoEditorAIRequest.stickerCatalog`. The image itself is not sent —
/// the provider only needs to know ids and names so it can reference them.
public struct PhotoEditorStickerInfo: Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// A host-defined preset for the AI picker. When the user taps the sparkles
/// button and presets are configured, an action sheet lets them choose one
/// (or optionally type a custom instruction). The chosen preset's
/// `instruction` is sent to the provider as `request.prompt`.
///
/// Example catalog:
/// ```swift
/// editor.aiPresetPrompts = [
///     PhotoEditorAIPrompt(
///         id: "safety-ppe",
///         name: "Safety Check",
///         description: "Find people missing hard hats or safety vests",
///         instruction: "Circle every person not wearing a hard hat or high-vis vest. " +
///                      "Label each with 'MISSING PPE' in red."
///     ),
///     PhotoEditorAIPrompt(
///         id: "equipment",
///         name: "Label Equipment",
///         instruction: "Label each piece of visible heavy equipment with its type.",
///         allowedTools: [.text, .box]  // narrow the global set for this preset
///     ),
/// ]
/// ```
public struct PhotoEditorAIPrompt {
    /// Stable identifier. Not shown to the user; useful for logging or tests.
    public let id: String

    /// Short label shown in the picker (e.g. "Safety Check").
    public let name: String

    /// Optional longer description shown alongside the name in the picker.
    public let description: String?

    /// The full prompt text sent to the provider as `request.prompt`.
    public let instruction: String

    /// Optional per-preset narrowing of `aiAllowedTools`. The effective set
    /// is the intersection of this and the editor's global `aiAllowedTools`
    /// — a preset can narrow the set, never widen it. `nil` means use the
    /// editor's global set as-is.
    public let allowedTools: Set<PhotoEditorAITool>?

    public init(id: String,
                name: String,
                description: String? = nil,
                instruction: String,
                allowedTools: Set<PhotoEditorAITool>? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.instruction = instruction
        self.allowedTools = allowedTools
    }
}

public extension PhotoEditorAnnotation {
    var tool: PhotoEditorAITool {
        switch self {
        case .text:    return .text
        case .box:     return .box
        case .ellipse: return .ellipse
        case .arrow:   return .arrow
        case .sticker: return .sticker
        }
    }
}

/// Everything the editor hands a provider for one annotation request.
///
/// Bundled as a struct (rather than separate function parameters) so future
/// additions can land with defaults and keep existing providers compiling.
public struct PhotoEditorAIRequest {
    /// Downscaled composite of the canvas (base image + user-placed text,
    /// shapes, and freehand strokes). Longest edge has already been capped to
    /// `PhotoEditorViewController.aiMaxImageDimension`. The editor rescales
    /// returned coordinates back to full resolution before rendering, so
    /// treat this image as ground truth for the coord space you return in.
    public let image: UIImage

    /// Annotation kinds the host permits for this request. Omit any other
    /// kinds from your prompt and response. The editor also filters returned
    /// annotations against this set as a safety net.
    public let allowedTools: Set<PhotoEditorAITool>

    /// Free-form instructions from the user or host. Typical sources:
    ///   - a preset prompt selected from the AI menu
    ///   - a custom prompt the user typed
    ///   - a revision request ("don't circle the guy in red") during the
    ///     review flow — in which case `previousAnnotations` is also populated
    public let prompt: String?

    /// Key-value metadata the host wants the provider to see (project name,
    /// GPS, datetime, inspector, ...). The library does not extract EXIF —
    /// the host chooses what's safe/relevant and puts it in.
    public let context: [String: String]

    /// Named stickers the provider is allowed to place via
    /// `.sticker(id:at:size:)` annotations. Empty means no sticker tool
    /// available (even if `.sticker` is in `allowedTools`).
    public let stickerCatalog: [PhotoEditorStickerInfo]

    /// Populated on revision calls: the annotations the provider returned
    /// on the previous round, that the user wants changed. The provider
    /// should treat these plus `prompt` as the revision input.
    public let previousAnnotations: [PhotoEditorAnnotation]?

    public init(image: UIImage,
                allowedTools: Set<PhotoEditorAITool>,
                prompt: String? = nil,
                context: [String: String] = [:],
                stickerCatalog: [PhotoEditorStickerInfo] = [],
                previousAnnotations: [PhotoEditorAnnotation]? = nil) {
        self.image = image
        self.allowedTools = allowedTools
        self.prompt = prompt
        self.context = context
        self.stickerCatalog = stickerCatalog
        self.previousAnnotations = previousAnnotations
    }
}

public protocol PhotoEditorAIProvider: AnyObject {
    /// Generate annotations for `request.image`.
    /// - Returns: annotations in `request.image`'s coordinate space.
    func generateAnnotations(for request: PhotoEditorAIRequest) async throws -> [PhotoEditorAnnotation]
}

/// Optional delegate for observing AI pipeline errors. The protocol call
/// itself silently discards thrown errors (canvas is not mutated, no snapshot
/// taken) — this delegate lets the host surface them via toast / alert /
/// telemetry.
public protocol PhotoEditorAIDelegate: AnyObject {
    func photoEditor(_ editor: PhotoEditorViewController,
                     aiAnnotationDidFail error: Error)
}

public enum PhotoEditorAnnotation {
    /// Editable text at `at`, in the coordinate space of the image the provider
    /// received. `fontSize` is in display points (same units as UIFont.pointSize)
    /// and is NOT scaled with the sent-image rescale. `color` of nil uses the
    /// editor's current `textColor`. `alignment` controls horizontal alignment
    /// within the text box — set `.right` when placing in a right corner, etc.
    /// `outline` draws a contrasting stroke around each character for
    /// readability on ambiguous backgrounds (e.g. white fill on a bright sky —
    /// add `outline: .black`). `nil` = no outline (default).
    case text(
        String,
        at: CGPoint,
        fontSize: CGFloat = 30,
        color: UIColor? = nil,
        alignment: NSTextAlignment = .center,
        outline: UIColor? = nil
    )

    /// Rectangular outline. `rect` is in sent-image coordinate space.
    /// `lineWidth` is in display points.
    case box(
        CGRect,
        color: UIColor = .yellow,
        lineWidth: CGFloat = 6
    )

    /// Elliptical outline inscribed in `rect` (sent-image space).
    case ellipse(
        CGRect,
        color: UIColor = .yellow,
        lineWidth: CGFloat = 6
    )

    /// Line with arrowhead at `to`. Both points in sent-image space.
    case arrow(
        from: CGPoint,
        to: CGPoint,
        color: UIColor = .yellow,
        lineWidth: CGFloat = 6
    )

    /// Named sticker from the request's `stickerCatalog`, centered at `at`
    /// (sent-image space). `size` is the desired longest-edge length in
    /// display points; if `nil` the editor picks a reasonable default.
    case sticker(
        id: String,
        at: CGPoint,
        size: CGFloat? = nil
    )
}
