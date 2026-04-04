import UIKit

// MARK: - ImageProcessor

/// Headless image processing utilities — crop, rotate, flip, and resize without any UI.
public struct ImageProcessor {

    // MARK: - Resize Content Mode

    public enum ResizeContentMode {
        /// Stretches the image to exactly fill the target size (may distort).
        case scaleToFill
        /// Scales the image to fit within the target size, preserving aspect ratio.
        case aspectFit
        /// Scales the image to fill the target size, preserving aspect ratio (may crop edges).
        case aspectFill
    }

    // MARK: - Crop

    /// Crops the image to the given rectangle (in image point coordinates).
    ///
    /// The rectangle is intersected with the image bounds by `CGImage.cropping(to:)`.
    /// If the intersection is empty the original image is returned.
    ///
    /// - Parameters:
    ///   - image: The source image.
    ///   - rect: The crop rectangle in points.
    /// - Returns: The cropped image.
    public static func crop(_ image: UIImage, to rect: CGRect) -> UIImage {
        let scale = image.scale
        let scaledRect = CGRect(x: rect.origin.x * scale,
                                y: rect.origin.y * scale,
                                width: rect.size.width * scale,
                                height: rect.size.height * scale)

        guard let cgImage = image.cgImage,
              let cropped = cgImage.cropping(to: scaledRect) else {
            return image
        }
        return UIImage(cgImage: cropped, scale: scale, orientation: image.imageOrientation)
    }

    /// Crops the image to center with the given aspect ratio.
    ///
    /// - Parameters:
    ///   - image: The source image.
    ///   - aspectRatio: Desired width / height ratio (e.g. 16.0/9.0). Must be greater than zero.
    /// - Returns: The center-cropped image, or the original if the aspect ratio is invalid.
    public static func crop(_ image: UIImage, aspectRatio: CGFloat) -> UIImage {
        let size = image.size
        guard aspectRatio > 0, size.width > 0, size.height > 0 else { return image }

        let currentRatio = size.width / size.height

        let cropRect: CGRect
        if currentRatio > aspectRatio {
            // Wider than desired — trim sides
            let newWidth = size.height * aspectRatio
            let xOffset = (size.width - newWidth) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: size.height)
        } else {
            // Taller than desired — trim top/bottom
            let newHeight = size.width / aspectRatio
            let yOffset = (size.height - newHeight) / 2
            cropRect = CGRect(x: 0, y: yOffset, width: size.width, height: newHeight)
        }

        return crop(image, to: cropRect)
    }

    // MARK: - Rotate

    /// Rotates the image by the given number of degrees (clockwise).
    ///
    /// Delegates to `UIImage.rotate(radians:)` from UIImage+Size.swift.
    public static func rotate(_ image: UIImage, degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180
        return image.rotate(radians: radians)
    }

    // MARK: - Flip

    /// Flips the image horizontally (left ↔ right).
    public static func flipHorizontal(_ image: UIImage) -> UIImage {
        return flip(image, horizontal: true)
    }

    /// Flips the image vertically (top ↔ bottom).
    public static func flipVertical(_ image: UIImage) -> UIImage {
        return flip(image, horizontal: false)
    }

    private static func flip(_ image: UIImage, horizontal: Bool) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let width = cgImage.width
        let height = cgImage.height

        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return image
        }

        let drawRect = CGRect(x: 0, y: 0, width: width, height: height)

        if horizontal {
            context.translateBy(x: CGFloat(width), y: 0)
            context.scaleBy(x: -1, y: 1)
        } else {
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
        }

        context.draw(cgImage, in: drawRect)

        guard let flippedCG = context.makeImage() else { return image }
        return UIImage(cgImage: flippedCG, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Resize

    /// Resizes the image to the target size using the specified content mode.
    ///
    /// - Parameters:
    ///   - image: The source image.
    ///   - targetSize: The desired output size in points.
    ///   - contentMode: How the image fills the target size.
    /// - Returns: The resized image, preserving the source image's scale.
    public static func resize(_ image: UIImage,
                              to targetSize: CGSize,
                              contentMode: ResizeContentMode = .aspectFit) -> UIImage {
        guard image.size.width > 0, image.size.height > 0,
              targetSize.width > 0, targetSize.height > 0 else {
            return image
        }

        let drawSize: CGSize
        let canvasSize: CGSize

        switch contentMode {
        case .scaleToFill:
            drawSize = targetSize
            canvasSize = targetSize

        case .aspectFit:
            drawSize = image.suitableSizeWithinBounds(targetSize)
            canvasSize = drawSize

        case .aspectFill:
            let imageAspect = image.size.width / image.size.height
            let targetAspect = targetSize.width / targetSize.height
            if imageAspect > targetAspect {
                // Image is wider — scale to fill height, crop width
                let h = targetSize.height
                let w = h * imageAspect
                drawSize = CGSize(width: w, height: h)
            } else {
                // Image is taller — scale to fill width, crop height
                let w = targetSize.width
                let h = w / imageAspect
                drawSize = CGSize(width: w, height: h)
            }
            canvasSize = targetSize
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { _ in
            let origin = CGPoint(x: (canvasSize.width - drawSize.width) / 2,
                                 y: (canvasSize.height - drawSize.height) / 2)
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}
