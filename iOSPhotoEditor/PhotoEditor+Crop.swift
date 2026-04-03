//
//  PhotoEditor+Crop.swift
//  Pods
//
//  Created by Mohamed Hamed on 6/16/17.
//
//

import Foundation
import UIKit

// MARK: - CropView
extension PhotoEditorViewController: CropViewControllerDelegate {
    
    public func cropViewController(_ controller: CropViewController, didFinishCroppingImage image: UIImage, transform: CGAffineTransform, cropRect: CGRect) {
        controller.dismiss(animated: true, completion: nil)
        saveSnapshot()

        // Crop the drawing layer to match the cropped image
        cropDrawingLayer(transform: transform, cropRect: cropRect)
        
        self.setImageView(image: image)
        self.image = image
        hasImageBeenModified = true
    }
    
    private func cropDrawingLayer(transform: CGAffineTransform, cropRect: CGRect) {
        // Crop the drawing image if it exists
        if let drawingImage = canvasImageView.image, let currentImage = self.image {
            // Scale the crop rect from original image coordinates to drawing layer coordinates
            let scaleX = drawingImage.size.width / currentImage.size.width
            let scaleY = drawingImage.size.height / currentImage.size.height
            
            let scaledCropRect = CGRect(
                x: cropRect.origin.x * scaleX,
                y: cropRect.origin.y * scaleY,
                width: cropRect.size.width * scaleX,
                height: cropRect.size.height * scaleY
            )
            
            let croppedDrawing = drawingImage.rotatedImageWithTransform(transform, croppedToRect: scaledCropRect)
            canvasImageView.image = croppedDrawing
        }
        
        // Transform and crop subviews (text, stickers)
        let scaleX = cropRect.width / canvasImageView.bounds.width
        let scaleY = cropRect.height / canvasImageView.bounds.height
        let offsetX = cropRect.origin.x
        let offsetY = cropRect.origin.y
        
        for subview in canvasImageView.subviews.reversed() {
            // Apply the crop transform to the subview
            let currentCenter = subview.center
            
            // Apply transform and crop offset
            var newCenter = currentCenter.applying(transform)
            newCenter.x -= offsetX
            newCenter.y -= offsetY
            
            // Check if the subview is still within the cropped bounds
            let subviewBounds = CGRect(
                x: newCenter.x - subview.bounds.width / 2,
                y: newCenter.y - subview.bounds.height / 2,
                width: subview.bounds.width,
                height: subview.bounds.height
            )
            
            if CGRect(origin: .zero, size: CGSize(width: cropRect.width, height: cropRect.height)).intersects(subviewBounds) {
                // Subview is still visible, update its position and transform
                subview.center = newCenter
                subview.transform = subview.transform.concatenating(transform)
            } else {
                // Subview is outside crop area, remove it
                subview.removeFromSuperview()
            }
        }
    }
    
    public func cropViewControllerDidCancel(_ controller: CropViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
}
