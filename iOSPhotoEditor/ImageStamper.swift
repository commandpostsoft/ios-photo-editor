import UIKit

// MARK: - Stamp Dimension

/// A dimension that can be expressed as absolute points or relative to the image size.
///
/// Use `.fractionOfMinDimension` for consistent sizing across landscape and portrait photos.
public enum StampDimension {
    case points(CGFloat)
    case fractionOfWidth(CGFloat)
    case fractionOfHeight(CGFloat)
    /// Fraction of `min(width, height)` — best for consistent sizing across orientations.
    case fractionOfMinDimension(CGFloat)

    /// Resolves to an absolute point value for the given image size.
    public func resolve(for imageSize: CGSize) -> CGFloat {
        switch self {
        case .points(let v):
            return v
        case .fractionOfWidth(let f):
            return f * imageSize.width
        case .fractionOfHeight(let f):
            return f * imageSize.height
        case .fractionOfMinDimension(let f):
            return f * min(imageSize.width, imageSize.height)
        }
    }
}

extension StampDimension: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .points(CGFloat(value))
    }
}

extension StampDimension: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .points(CGFloat(value))
    }
}

// MARK: - Stamp Position

/// Describes where a stamp item is placed on the image.
public enum StampPosition {
    case topLeft(inset: StampDimension)
    case topCenter(inset: StampDimension)
    case topRight(inset: StampDimension)
    case centerLeft(inset: StampDimension)
    case center
    case centerRight(inset: StampDimension)
    case bottomLeft(inset: StampDimension)
    case bottomCenter(inset: StampDimension)
    case bottomRight(inset: StampDimension)
    /// Normalized coordinates (0...1) relative to image size.
    case normalized(x: CGFloat, y: CGFloat)
    /// Absolute point in image coordinates.
    case absolute(CGPoint)

    public func origin(for itemSize: CGSize, in imageSize: CGSize) -> CGPoint {
        switch self {
        case .topLeft(let insetDim):
            let inset = insetDim.resolve(for: imageSize)
            return CGPoint(x: inset, y: inset)
        case .topCenter(let insetDim):
            let inset = insetDim.resolve(for: imageSize)
            return CGPoint(x: (imageSize.width - itemSize.width) / 2, y: inset)
        case .topRight(let insetDim):
            let inset = insetDim.resolve(for: imageSize)
            return CGPoint(x: imageSize.width - itemSize.width - inset, y: inset)
        case .centerLeft(let insetDim):
            let inset = insetDim.resolve(for: imageSize)
            return CGPoint(x: inset, y: (imageSize.height - itemSize.height) / 2)
        case .center:
            return CGPoint(x: (imageSize.width - itemSize.width) / 2,
                           y: (imageSize.height - itemSize.height) / 2)
        case .centerRight(let insetDim):
            let inset = insetDim.resolve(for: imageSize)
            return CGPoint(x: imageSize.width - itemSize.width - inset,
                           y: (imageSize.height - itemSize.height) / 2)
        case .bottomLeft(let insetDim):
            let inset = insetDim.resolve(for: imageSize)
            return CGPoint(x: inset, y: imageSize.height - itemSize.height - inset)
        case .bottomCenter(let insetDim):
            let inset = insetDim.resolve(for: imageSize)
            return CGPoint(x: (imageSize.width - itemSize.width) / 2,
                           y: imageSize.height - itemSize.height - inset)
        case .bottomRight(let insetDim):
            let inset = insetDim.resolve(for: imageSize)
            return CGPoint(x: imageSize.width - itemSize.width - inset,
                           y: imageSize.height - itemSize.height - inset)
        case .normalized(let x, let y):
            return CGPoint(x: x * imageSize.width - itemSize.width / 2,
                           y: y * imageSize.height - itemSize.height / 2)
        case .absolute(let point):
            return point
        }
    }
}

// MARK: - Stamp Shadow

/// Shadow configuration for stamped text.
public struct StampShadow {
    public var color: UIColor
    public var offset: CGSize
    public var blur: CGFloat

    public init(color: UIColor = UIColor.black.withAlphaComponent(0.7),
                offset: CGSize = CGSize(width: 1, height: 1),
                blur: CGFloat = 3) {
        self.color = color
        self.offset = offset
        self.blur = blur
    }

    /// The default dark shadow for legibility on most photos.
    public static let `default` = StampShadow()
}

// MARK: - Stamp Stroke

/// Outline stroke for maximum text readability on any background.
public struct StampStroke {
    public var color: UIColor
    public var width: StampDimension

    public init(color: UIColor = .black, width: StampDimension = 2) {
        self.color = color
        self.width = width
    }
}

// MARK: - Stamp Text Style

/// Styling options for stamped text.
public struct StampTextStyle {
    public var fontSize: StampDimension
    public var fontName: String?
    public var color: UIColor
    public var shadow: StampShadow?
    public var stroke: StampStroke?
    /// Maximum width of the text as a fraction (0...1) of the image width.
    /// Text will wrap if it exceeds this width. `nil` means no wrapping.
    public var maxWidthFraction: CGFloat?

    public init(fontSize: StampDimension = .points(64),
                fontName: String? = nil,
                color: UIColor = .white,
                shadow: StampShadow? = .default,
                stroke: StampStroke? = nil,
                maxWidthFraction: CGFloat? = nil) {
        self.fontSize = fontSize
        self.fontName = fontName
        self.color = color
        self.shadow = shadow
        self.stroke = stroke
        self.maxWidthFraction = maxWidthFraction
    }

    /// Backward-compatible convenience initializer accepting a UIFont directly.
    public init(font: UIFont,
                color: UIColor = .white,
                shadow: StampShadow? = .default,
                stroke: StampStroke? = nil,
                maxWidthFraction: CGFloat? = nil) {
        self.fontSize = .points(font.pointSize)
        self.fontName = font.fontName
        self.color = color
        self.shadow = shadow
        self.stroke = stroke
        self.maxWidthFraction = maxWidthFraction
    }

    /// Resolves the font at the appropriate size for the given image dimensions.
    public func resolvedFont(for imageSize: CGSize) -> UIFont {
        let size = fontSize.resolve(for: imageSize)
        if let name = fontName, let font = UIFont(name: name, size: size) {
            return font
        }
        return .boldSystemFont(ofSize: size)
    }
}

// MARK: - Stamp Image Size

/// Sizing options for an image overlay.
public enum StampImageSize {
    /// Fixed pixel size.
    case absolute(CGSize)
    /// Width as a fraction of the base image width; height derived from aspect ratio.
    case relativeWidth(CGFloat)
    /// Height as a fraction of the base image height; width derived from aspect ratio.
    case relativeHeight(CGFloat)
    /// Longest side as a fraction of `min(baseWidth, baseHeight)`.
    case relativeToMinDimension(CGFloat)

    public func resolve(for overlayImage: UIImage, in imageSize: CGSize) -> CGSize {
        let overlaySize = overlayImage.size
        guard overlaySize.width > 0, overlaySize.height > 0 else { return overlaySize }
        let aspect = overlaySize.width / overlaySize.height

        switch self {
        case .absolute(let size):
            return size
        case .relativeWidth(let fraction):
            let w = imageSize.width * fraction
            return CGSize(width: w, height: w / aspect)
        case .relativeHeight(let fraction):
            let h = imageSize.height * fraction
            return CGSize(width: h * aspect, height: h)
        case .relativeToMinDimension(let fraction):
            let dim = min(imageSize.width, imageSize.height) * fraction
            if overlaySize.width >= overlaySize.height {
                return CGSize(width: dim, height: dim / aspect)
            } else {
                return CGSize(width: dim * aspect, height: dim)
            }
        }
    }
}

// MARK: - Stamp Item

/// An item to stamp onto an image.
public enum StampItem {
    case text(String, position: StampPosition, style: StampTextStyle = StampTextStyle())
    case image(UIImage, position: StampPosition, size: StampImageSize, rotation: CGFloat = 0)
}

// MARK: - ImageStamper

/// Stamps text and/or images onto a photo without any UI.
///
/// Usage:
/// ```swift
/// let result = ImageStamper.stamp([
///     .text("Hello", position: .topLeft(inset: 20)),
///     .image(logo, position: .bottomRight(inset: .fractionOfMinDimension(0.03)),
///            size: .relativeWidth(0.15)),
/// ], onto: photo)
/// ```
public struct ImageStamper {

    /// Stamps the given items onto the image and returns the composited result.
    ///
    /// - Parameters:
    ///   - items: The text and image items to stamp.
    ///   - image: The base image.
    /// - Returns: A new `UIImage` with all items composited. Preserves the input image's size and scale.
    public static func stamp(_ items: [StampItem], onto image: UIImage) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size, format: rendererFormat(for: image))

        return renderer.image { context in
            // Draw the base image
            image.draw(in: CGRect(origin: .zero, size: size))

            for item in items {
                switch item {
                case .text(let string, let position, let style):
                    drawText(string, position: position, style: style, imageSize: size, context: context)
                case .image(let overlay, let position, let stampSize, let rotation):
                    let resolvedSize = stampSize.resolve(for: overlay, in: size)
                    drawImage(overlay, position: position, size: resolvedSize, rotation: rotation,
                              imageSize: size, context: context)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private static func rendererFormat(for image: UIImage) -> UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return format
    }

    private static func drawText(_ string: String,
                                 position: StampPosition,
                                 style: StampTextStyle,
                                 imageSize: CGSize,
                                 context: UIGraphicsImageRendererContext) {
        let cgContext = context.cgContext
        let font = style.resolvedFont(for: imageSize)

        // Build fill attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        var fillAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: style.color,
            .paragraphStyle: paragraphStyle,
        ]

        // Determine maximum draw width
        let maxWidth: CGFloat
        if let fraction = style.maxWidthFraction {
            maxWidth = imageSize.width * fraction
        } else {
            maxWidth = imageSize.width
        }

        // Measure text size
        let constraintSize = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
        let textRect = (string as NSString).boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: fillAttributes,
            context: nil
        )
        let textSize = CGSize(width: ceil(textRect.width), height: ceil(textRect.height))

        let origin = position.origin(for: textSize, in: imageSize)
        let drawRect = CGRect(origin: origin, size: CGSize(width: maxWidth, height: textSize.height))

        // Apply shadow if configured
        if let shadow = style.shadow {
            cgContext.setShadow(offset: shadow.offset, blur: shadow.blur, color: shadow.color.cgColor)
        }

        // Two-pass stroke rendering
        if let stroke = style.stroke {
            let resolvedStrokeWidth = stroke.width.resolve(for: imageSize)

            cgContext.saveGState()
            // Clear shadow for the stroke pass to avoid double shadow
            cgContext.setShadow(offset: .zero, blur: 0, color: nil)

            var strokeAttributes = fillAttributes
            strokeAttributes[.strokeColor] = stroke.color
            strokeAttributes[.strokeWidth] = resolvedStrokeWidth
            // Positive strokeWidth draws stroke only (no fill)
            (string as NSString).draw(in: drawRect, withAttributes: strokeAttributes)
            cgContext.restoreGState()

            // Re-apply shadow for the fill pass
            if let shadow = style.shadow {
                cgContext.setShadow(offset: shadow.offset, blur: shadow.blur, color: shadow.color.cgColor)
            }
        }

        // Fill pass
        (string as NSString).draw(in: drawRect, withAttributes: fillAttributes)

        // Reset shadow so it doesn't bleed into subsequent items
        cgContext.setShadow(offset: .zero, blur: 0, color: nil)
    }

    private static func drawImage(_ overlay: UIImage,
                                  position: StampPosition,
                                  size: CGSize,
                                  rotation: CGFloat,
                                  imageSize: CGSize,
                                  context: UIGraphicsImageRendererContext) {
        let cgContext = context.cgContext
        let origin = position.origin(for: size, in: imageSize)

        cgContext.saveGState()

        if rotation != 0 {
            // Translate to the center of the overlay, rotate, then draw centered
            let centerX = origin.x + size.width / 2
            let centerY = origin.y + size.height / 2
            cgContext.translateBy(x: centerX, y: centerY)
            cgContext.rotate(by: rotation)
            overlay.draw(in: CGRect(x: -size.width / 2, y: -size.height / 2,
                                    width: size.width, height: size.height))
        } else {
            overlay.draw(in: CGRect(origin: origin, size: size))
        }

        cgContext.restoreGState()
    }
}
