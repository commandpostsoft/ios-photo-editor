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
     Returns a copy with the longest edge scaled down to `maxDimension` (aspect
     preserved). If the image is already within the limit, `self` is returned
     unchanged. Used by the AI pipeline to cap request size.
     */
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }
        let ratio = maxDimension / longest
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /**
     Rotates the image by the specified radians
     */
    func rotate(radians: CGFloat) -> UIImage {
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .size
        
        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return self }
        
        let origin = CGPoint(x: rotatedSize.width / 2.0,
                             y: rotatedSize.height / 2.0)
        
        context.translateBy(x: origin.x, y: origin.y)
        context.rotate(by: radians)
        
        draw(in: CGRect(x: -size.width / 2.0,
                         y: -size.height / 2.0,
                         width: size.width,
                         height: size.height))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage ?? self
    }
}
