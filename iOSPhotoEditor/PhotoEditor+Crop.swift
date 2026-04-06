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

        // Crop the BASE image (self.image), not the composite shown in crop preview
        guard let baseImage = self.image else { return }
        let croppedBaseImage = baseImage.rotatedImageWithTransform(transform, croppedToRect: cropRect)

        // NOTE: cropDrawingLayer MUST run before setImageView because it reads the
        // old displayImageSize via getImageBoundsInCanvas(). Same pattern as rotateDrawingLayer.
        cropDrawingLayer(transform: transform, cropRect: cropRect, newImage: croppedBaseImage)

        self.setImageView(image: croppedBaseImage)
        self.image = croppedBaseImage
        hasImageBeenModified = true
    }

    private func cropDrawingLayer(transform: CGAffineTransform, cropRect: CGRect, newImage: UIImage) {
        // 1. Crop drawing overlay (existing logic — works correctly in pixel space)
        if let drawingImage = drawingOverlayView.image, let currentImage = self.image {
            let scaleX = drawingImage.size.width / currentImage.size.width
            let scaleY = drawingImage.size.height / currentImage.size.height
            let scaledCropRect = CGRect(
                x: cropRect.origin.x * scaleX,
                y: cropRect.origin.y * scaleY,
                width: cropRect.size.width * scaleX,
                height: cropRect.size.height * scaleY
            )
            drawingOverlayView.image = drawingImage.rotatedImageWithTransform(transform, croppedToRect: scaledCropRect)
        }

        // 2. Reposition subviews using normalized coordinates
        guard let currentImage = self.image else { return }
        let oldImageRect = getImageBoundsInCanvas()
        guard oldImageRect.width > 0 && oldImageRect.height > 0 else { return }

        // Compute new display size (same formula as setImageView — pixel-snapped)
        let screenBounds = view.bounds.size
        let rawSize = newImage.suitableSizeWithinBounds(screenBounds)
        let screenScale = UIScreen.main.scale
        let newDisplaySize = CGSize(
            width: round(rawSize.width * screenScale) / screenScale,
            height: round(rawSize.height * screenScale) / screenScale
        )
        let newCanvasSize = CGSize(width: canvasImageView.bounds.width, height: newDisplaySize.height)
        let newImageRect = CGRect(
            x: (newCanvasSize.width - newDisplaySize.width) / 2,
            y: (newCanvasSize.height - newDisplaySize.height) / 2,
            width: newDisplaySize.width,
            height: newDisplaySize.height
        )

        // Normalize crop rect to 0..1 relative to full image
        let cropNormX = cropRect.origin.x / currentImage.size.width
        let cropNormY = cropRect.origin.y / currentImage.size.height
        let cropNormW = cropRect.width / currentImage.size.width
        let cropNormH = cropRect.height / currentImage.size.height

        // Scale factor to preserve proportional sticker/line coverage
        guard cropNormW > 0 && cropNormH > 0 else { return }
        let scaleFactor = newImageRect.width / (oldImageRect.width * cropNormW)

        for subview in contentSubviews.reversed() {
            // To 0..1 in OLD image rect
            let relX = (subview.center.x - oldImageRect.origin.x) / oldImageRect.width
            let relY = (subview.center.y - oldImageRect.origin.y) / oldImageRect.height

            // Apply crop-view rotation in pixel space (aspect-correct) then back to normalized
            let pixelX = relX * currentImage.size.width - currentImage.size.width / 2
            let pixelY = relY * currentImage.size.height - currentImage.size.height / 2
            let rotated = CGPoint(x: pixelX, y: pixelY).applying(transform)
            let rotRelX = (rotated.x + currentImage.size.width / 2) / currentImage.size.width
            let rotRelY = (rotated.y + currentImage.size.height / 2) / currentImage.size.height

            // Check if within crop area (small margin for edge elements)
            guard rotRelX >= cropNormX - 0.05 && rotRelX <= cropNormX + cropNormW + 0.05 &&
                  rotRelY >= cropNormY - 0.05 && rotRelY <= cropNormY + cropNormH + 0.05 else {
                subview.removeFromSuperview()
                continue
            }

            // Map to normalized position within cropped image
            let newRelX = (rotRelX - cropNormX) / cropNormW
            let newRelY = (rotRelY - cropNormY) / cropNormH

            // Back to canvas coords via NEW image rect
            subview.center = CGPoint(
                x: newImageRect.origin.x + newRelX * newImageRect.width,
                y: newImageRect.origin.y + newRelY * newImageRect.height
            )

            // Scale subview — text uses font scaling, others use transform
            if let textView = subview as? UITextView, let currentFont = textView.font {
                let newFontSize = min(max(currentFont.pointSize * scaleFactor, 8), 90)
                textView.font = UIFont(name: currentFont.fontName, size: newFontSize)
                let sizeToFit = textView.sizeThatFits(CGSize(
                    width: UIScreen.main.bounds.size.width,
                    height: CGFloat.greatestFiniteMagnitude))
                textView.bounds.size = CGSize(
                    width: textView.intrinsicContentSize.width,
                    height: sizeToFit.height)
            } else {
                subview.transform = subview.transform
                    .scaledBy(x: scaleFactor, y: scaleFactor)
            }

            // Apply crop-view rotation (if any) to all subview types
            if transform != .identity {
                subview.transform = subview.transform.concatenating(transform)
            }

            // Remove if fully outside new canvas
            if !CGRect(origin: .zero, size: newCanvasSize).intersects(subview.frame) {
                subview.removeFromSuperview()
            }
        }
    }
    
    public func cropViewControllerDidCancel(_ controller: CropViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
}
