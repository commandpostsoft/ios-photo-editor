//
//  PhotoEditorAIHeadless.swift
//  iOSPhotoEditor
//
//  Headless AI annotation — runs the full pipeline (resize, provider call,
//  render annotations onto the base image) without any UI. Mirrors the
//  in-editor `aiButtonTapped` logic for server-side / batch / scripted use.
//

import UIKit

public struct PhotoEditorAIHeadless {

    /// Run one provider call and flatten the returned annotations onto a
    /// copy of `image`. No UI, no view controller required.
    ///
    /// - Parameters:
    ///   - image: base image (full resolution). Longest edge is downscaled
    ///     to `maxImageDimension` before being passed to the provider, then
    ///     returned coordinates are scaled back up when rendering onto this
    ///     image.
    ///   - provider: your `PhotoEditorAIProvider` implementation.
    ///   - allowedTools: annotation kinds permitted for this request.
    ///   - prompt: optional free-form instruction (e.g. "Place a timestamp
    ///     and logo in the best corner").
    ///   - context: host metadata (datetime, GPS, project name, ...).
    ///   - stickers: named stickers the provider may reference via `.sticker`.
    ///   - maxImageDimension: longest-edge cap in pixels for the image sent
    ///     to the provider. Default 2048.
    /// - Returns: a new UIImage with annotations flattened in at the size
    ///   and scale of `image`.
    public static func annotate(
        image: UIImage,
        provider: PhotoEditorAIProvider,
        allowedTools: Set<PhotoEditorAITool> = Set(PhotoEditorAITool.allCases),
        prompt: String? = nil,
        context: [String: String] = [:],
        stickers: [PhotoEditorSticker] = [],
        maxImageDimension: CGFloat = 2048
    ) async throws -> UIImage {
        let sent = image.resized(toMaxDimension: maxImageDimension)
        let sentWidth = max(sent.size.width, 1)
        let sentToBaseScale = image.size.width / sentWidth

        let catalog = stickers.map { PhotoEditorStickerInfo(id: $0.id, name: $0.name) }
        let request = PhotoEditorAIRequest(
            image: sent,
            allowedTools: allowedTools,
            prompt: prompt,
            context: context,
            stickerCatalog: catalog,
            previousAnnotations: nil
        )

        let raw = try await provider.generateAnnotations(for: request)
        let annotations = raw.filter { allowedTools.contains($0.tool) }

        return renderAnnotations(
            annotations,
            onto: image,
            sentToBaseScale: sentToBaseScale,
            stickerLookup: Dictionary(uniqueKeysWithValues: stickers.map { ($0.id, $0) })
        )
    }

    // MARK: - Rendering

    /// Flatten annotations onto a copy of `base`. Public so hosts can render
    /// a stored annotation list later without calling a provider.
    public static func renderAnnotations(
        _ annotations: [PhotoEditorAnnotation],
        onto base: UIImage,
        sentToBaseScale s: CGFloat = 1.0,
        stickerLookup: [String: PhotoEditorSticker] = [:]
    ) -> UIImage {
        let size = base.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = base.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            base.draw(in: CGRect(origin: .zero, size: size))

            for annotation in annotations {
                switch annotation {
                case .text(let string, let sentPoint, let fontSize, let color, let alignment, let outline):
                    let origin = scalePoint(sentPoint, s)
                    drawText(string,
                             originInBase: origin,
                             fontSize: max(fontSize, 8) * s,
                             color: color ?? .white,
                             alignment: alignment,
                             outline: outline,
                             imageSize: size,
                             context: cg)

                case .box(let sentRect, let color, let lineWidth):
                    cg.setStrokeColor(color.cgColor)
                    cg.setLineWidth(lineWidth * s)
                    cg.stroke(scaleRect(sentRect, s))

                case .ellipse(let sentRect, let color, let lineWidth):
                    cg.setStrokeColor(color.cgColor)
                    cg.setLineWidth(lineWidth * s)
                    cg.strokeEllipse(in: scaleRect(sentRect, s))

                case .arrow(let from, let to, let color, let lineWidth):
                    let a = scalePoint(from, s)
                    let b = scalePoint(to, s)
                    cg.setStrokeColor(color.cgColor)
                    cg.setLineWidth(lineWidth * s)
                    cg.setLineCap(.round)
                    cg.setLineJoin(.round)
                    cg.move(to: a)
                    cg.addLine(to: b)
                    cg.strokePath()

                    let headLength = max(lineWidth * s * 3.5, 16)
                    let angle = atan2(b.y - a.y, b.x - a.x)
                    let wing: CGFloat = .pi / 7
                    let left = CGPoint(x: b.x - headLength * cos(angle - wing),
                                       y: b.y - headLength * sin(angle - wing))
                    let right = CGPoint(x: b.x - headLength * cos(angle + wing),
                                        y: b.y - headLength * sin(angle + wing))
                    cg.move(to: left)
                    cg.addLine(to: b)
                    cg.addLine(to: right)
                    cg.strokePath()

                case .sticker(let id, let sentPoint, let sentSize):
                    guard let sticker = stickerLookup[id] else { continue }
                    let requestedLongest = sentSize ?? 120
                    let longest = min(max(requestedLongest, 20), 800) * s
                    let overlaySize = sticker.image.size
                    let aspect = overlaySize.width / max(overlaySize.height, 1)
                    let drawSize: CGSize = aspect >= 1
                        ? CGSize(width: longest, height: longest / aspect)
                        : CGSize(width: longest * aspect, height: longest)
                    let center = scalePoint(sentPoint, s)
                    let rect = CGRect(x: center.x - drawSize.width / 2,
                                      y: center.y - drawSize.height / 2,
                                      width: drawSize.width, height: drawSize.height)
                    sticker.image.draw(in: rect)
                }
            }
        }
    }

    // MARK: - Private

    private static func drawText(_ string: String,
                                 originInBase: CGPoint,
                                 fontSize: CGFloat,
                                 color: UIColor,
                                 alignment: NSTextAlignment,
                                 outline: UIColor?,
                                 imageSize: CGSize,
                                 context cg: CGContext) {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        if let outline {
            attributes[.strokeColor] = outline
            attributes[.strokeWidth] = -3.0  // negative = fill AND stroke
        }
        let maxWidth = imageSize.width * 0.9
        let bounds = (string as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let textSize = CGSize(width: ceil(bounds.width), height: ceil(bounds.height))

        // Align the text box relative to the requested origin point.
        let topLeft: CGPoint = {
            switch alignment {
            case .right:
                return CGPoint(x: originInBase.x - textSize.width,
                               y: originInBase.y - textSize.height / 2)
            case .left:
                return CGPoint(x: originInBase.x,
                               y: originInBase.y - textSize.height / 2)
            default:
                return CGPoint(x: originInBase.x - textSize.width / 2,
                               y: originInBase.y - textSize.height / 2)
            }
        }()

        // Drop shadow for legibility against arbitrary backgrounds.
        cg.setShadow(offset: CGSize(width: 1, height: 1),
                     blur: 3,
                     color: UIColor.black.withAlphaComponent(0.7).cgColor)
        (string as NSString).draw(in: CGRect(origin: topLeft, size: textSize),
                                  withAttributes: attributes)
        cg.setShadow(offset: .zero, blur: 0, color: nil)
    }

    private static func scalePoint(_ p: CGPoint, _ s: CGFloat) -> CGPoint {
        CGPoint(x: p.x * s, y: p.y * s)
    }
    private static func scaleRect(_ r: CGRect, _ s: CGFloat) -> CGRect {
        CGRect(x: r.minX * s, y: r.minY * s, width: r.width * s, height: r.height * s)
    }
}
