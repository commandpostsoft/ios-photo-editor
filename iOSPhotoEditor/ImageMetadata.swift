import UIKit
import ImageIO

// MARK: - ImageMetadata

/// Extracts and re-embeds EXIF/GPS/TIFF metadata for camera photos.
///
/// Operates at the `Data` level so you can round-trip metadata from the
/// original capture through editing and back to a JPEG file.
public struct ImageMetadata {

    /// Extracts all image properties (EXIF, GPS, TIFF, IPTC, etc.) from raw image data.
    ///
    /// - Parameter data: The original image file data (e.g. from `AVCapturePhoto.fileDataRepresentation()`).
    /// - Returns: The properties dictionary, or `nil` if the data cannot be parsed.
    public static func extractProperties(from data: Data) -> [String: Any]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        return properties
    }

    /// Creates new image data with metadata from the source re-embedded.
    ///
    /// The orientation tag is stripped (since `UIImage` is already oriented),
    /// but GPS, EXIF, TIFF, and IPTC dictionaries are preserved.
    ///
    /// - Parameters:
    ///   - sourceData: The original camera data containing metadata.
    ///   - image: The edited `UIImage` to encode.
    ///   - format: The UTI for the output format (default `"public.jpeg"`).
    ///   - compressionQuality: JPEG compression quality 0...1 (default 0.92).
    /// - Returns: Encoded image data with metadata, or `nil` on failure.
    public static func applyingMetadata(from sourceData: Data,
                                        to image: UIImage,
                                        format: String = "public.jpeg",
                                        compressionQuality: CGFloat = 0.92) -> Data? {
        guard var properties = extractProperties(from: sourceData) else { return nil }

        // Strip orientation since UIImage is already correctly oriented
        properties.removeValue(forKey: kCGImagePropertyOrientation as String)
        if var tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            tiff.removeValue(forKey: kCGImagePropertyTIFFOrientation as String)
            properties[kCGImagePropertyTIFFDictionary as String] = tiff
        }

        // Update pixel dimensions to match the edited image
        if var exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            exif[kCGImagePropertyExifPixelXDimension as String] = Int(image.size.width * image.scale)
            exif[kCGImagePropertyExifPixelYDimension as String] = Int(image.size.height * image.scale)
            properties[kCGImagePropertyExifDictionary as String] = exif
        }
        properties[kCGImagePropertyPixelWidth as String] = Int(image.size.width * image.scale)
        properties[kCGImagePropertyPixelHeight as String] = Int(image.size.height * image.scale)

        // Encode the edited image
        guard let cgImage = image.cgImage else { return nil }

        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData as CFMutableData,
            format as CFString,
            1,
            nil
        ) else { return nil }

        // Merge compression quality into properties
        var destinationProperties = properties
        destinationProperties[kCGImageDestinationLossyCompressionQuality as String] = compressionQuality

        CGImageDestinationAddImage(destination, cgImage, destinationProperties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }
        return outputData as Data
    }
}
