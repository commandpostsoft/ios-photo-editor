//
//  UIImage+Crop.swift
//  CropViewController
//
//  Created by Guilherme Moura on 2/26/16.
//  Copyright © 2016 Reefactor, Inc. All rights reserved.
// Credit https://github.com/sprint84/PhotoCropEditor

import UIKit

extension UIImage {
    func rotatedImageWithTransform(_ rotation: CGAffineTransform, croppedToRect rect: CGRect) -> UIImage {
        let rotatedImage = rotatedImageWithTransform(rotation)
        
        let scale = rotatedImage.scale
        let cropRect = rect.applying(CGAffineTransform(scaleX: scale, y: scale))
        
        let croppedImage = rotatedImage.cgImage?.cropping(to: cropRect)
        let image = UIImage(cgImage: croppedImage!, scale: self.scale, orientation: rotatedImage.imageOrientation)
        return image
    }
    
    fileprivate func rotatedImageWithTransform(_ transform: CGAffineTransform) -> UIImage {
        return autoreleasepool {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = scale
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            return renderer.image { ctx in
                let cg = ctx.cgContext
                cg.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                cg.concatenate(transform)
                cg.translateBy(x: size.width / -2.0, y: size.height / -2.0)
                draw(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
            }
        }
    }
}
