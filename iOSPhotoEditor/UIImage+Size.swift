//
//  UIImage+Size.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 5/2/17.
//  Copyright © 2017 Mohamed Hamed. All rights reserved.
//

import UIKit

public extension UIImage {
    
    /**
     Suitable size for specific height or width to keep same image ratio
     */
    func suitableSize(heightLimit: CGFloat? = nil,
                             widthLimit: CGFloat? = nil )-> CGSize? {
        
        if let height = heightLimit {
            
            let width = (height / self.size.height) * self.size.width
            
            return CGSize(width: width, height: height)
        }
        
        if let width = widthLimit {
            let height = (width / self.size.width) * self.size.height
            return CGSize(width: width, height: height)
        }
        
        return nil
    }
    
    /**
     Returns size that fits within the given bounds while maintaining aspect ratio
     */
    func suitableSizeWithinBounds(_ bounds: CGSize) -> CGSize {
        let imageSize = self.size
        let imageAspectRatio = imageSize.width / imageSize.height
        let boundsAspectRatio = bounds.width / bounds.height
        
        if imageAspectRatio > boundsAspectRatio {
            // Image is wider relative to bounds, fit to width
            let newWidth = bounds.width
            let newHeight = newWidth / imageAspectRatio
            return CGSize(width: newWidth, height: newHeight)
        } else {
            // Image is taller relative to bounds, fit to height
            let newHeight = bounds.height
            let newWidth = newHeight * imageAspectRatio
            return CGSize(width: newWidth, height: newHeight)
        }
    }
    
    /**
     Rotates the image by the specified radians
     */
    func rotate(radians: CGFloat) -> UIImage {
        return autoreleasepool {
            // Exact integer-size swap for axis-aligned 90° rotations avoids the
            // sub-pixel drift that CGRect.applying(rotationAngle:).size accumulates
            // across repeated undo/redo round-trips.
            let rotatedSize: CGSize
            let normalized = normalizedQuarterTurn(radians)
            if let quarterSize = quarterTurnSize(for: normalized, original: size) {
                rotatedSize = quarterSize
            } else {
                rotatedSize = CGRect(origin: .zero, size: size)
                    .applying(CGAffineTransform(rotationAngle: radians))
                    .size
            }

            let format = UIGraphicsImageRendererFormat.default()
            format.scale = scale
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: rotatedSize, format: format)

            return renderer.image { ctx in
                let cg = ctx.cgContext
                cg.translateBy(x: rotatedSize.width / 2.0, y: rotatedSize.height / 2.0)
                cg.rotate(by: radians)
                draw(in: CGRect(x: -size.width / 2.0,
                                y: -size.height / 2.0,
                                width: size.width,
                                height: size.height))
            }
        }
    }

    private func normalizedQuarterTurn(_ radians: CGFloat) -> CGFloat {
        let twoPi = CGFloat.pi * 2
        var r = radians.truncatingRemainder(dividingBy: twoPi)
        if r > .pi { r -= twoPi }
        if r < -.pi { r += twoPi }
        return r
    }

    /// Returns the exact rotated size for ±π/2 or π (within a small epsilon);
    /// returns nil for non-quarter-turn angles.
    private func quarterTurnSize(for radians: CGFloat, original: CGSize) -> CGSize? {
        let eps: CGFloat = 1e-6
        if abs(radians) < eps { return original }
        if abs(abs(radians) - .pi) < eps { return original }
        if abs(abs(radians) - .pi / 2) < eps {
            return CGSize(width: original.height, height: original.width)
        }
        return nil
    }
}
