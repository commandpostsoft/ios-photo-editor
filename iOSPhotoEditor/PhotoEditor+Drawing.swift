//
//  PhotoEditor+Drawing.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 6/16/17.
//
//

import UIKit

extension PhotoEditorViewController {
    
    override public func touchesBegan(_ touches: Set<UITouch>,
                                      with event: UIEvent?){
        if isDrawing {
            swiped = false
            if let touch = touches.first {
                let canvasPoint = touch.location(in: self.canvasImageView)
                // Only start drawing if within image bounds
                if isPointWithinImageBounds(canvasPoint) {
                    saveSnapshot()
                    // Convert canvas coordinates to image coordinates
                    lastPoint = convertCanvasPointToImagePoint(canvasPoint)
                } else {
                    lastPoint = nil
                }
            }
        }
            //Hide stickersVC if clicked outside it
        else if stickersVCIsVisible == true {
            if let touch = touches.first {
                let location = touch.location(in: self.view)
                if !stickersViewController.view.frame.contains(location) {
                    removeStickersView()
                }
            }
        }
        
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>,
                                      with event: UIEvent?){
        if isDrawing && lastPoint != nil {
            swiped = true
            if let touch = touches.first {
                let canvasPoint = touch.location(in: canvasImageView)
                // Only draw if both points are within image bounds
                if isPointWithinImageBounds(canvasPoint) {
                    let imagePoint = convertCanvasPointToImagePoint(canvasPoint)
                    drawLineFrom(lastPoint, toPoint: imagePoint)
                    lastPoint = imagePoint
                } else {
                    // If we move outside bounds, stop the current stroke
                    lastPoint = nil
                }
            }
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>,
                                      with event: UIEvent?){
        if isDrawing && lastPoint != nil {
            if !swiped {
                // draw a single point
                drawLineFrom(lastPoint, toPoint: lastPoint)
            }
        }
        lastPoint = nil
        swiped = false
    }

    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastPoint = nil
        swiped = false
    }
    
    func drawLineFrom(_ fromPoint: CGPoint, toPoint: CGPoint) {
        // Use display image size for drawing layer to match the visible image exactly
        let drawingSize = displayImageSize
        
        UIGraphicsBeginImageContextWithOptions(drawingSize, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return
        }

        // Draw existing drawing layer
        canvasImageView.image?.draw(in: CGRect(origin: .zero, size: drawingSize))

        // Draw the new line
        context.move(to: fromPoint)
        context.addLine(to: toPoint)
        context.setLineCap(.round)
        context.setLineWidth(drawLineWidth)
        context.setStrokeColor(drawColor.cgColor)
        context.setBlendMode(.normal)
        context.strokePath()

        canvasImageView.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        // Mark image as modified when drawing occurs
        hasImageBeenModified = true
    }
    
    // Helper function to check if a point is within the image bounds
    func isPointWithinImageBounds(_ point: CGPoint) -> Bool {
        let imageRect = getImageBoundsInCanvas()
        return imageRect.contains(point)
    }
    
    // Get the actual image bounds within the canvas view
    func getImageBoundsInCanvas() -> CGRect {
        let canvasSize = canvasImageView.bounds.size
        let imageSize = displayImageSize
        
        // Calculate the centered position of the image within the canvas
        let x = (canvasSize.width - imageSize.width) / 2
        let y = (canvasSize.height - imageSize.height) / 2
        
        return CGRect(x: x, y: y, width: imageSize.width, height: imageSize.height)
    }
    
    // Convert canvas coordinates to image coordinates (for drawing layer)
    func convertCanvasPointToImagePoint(_ canvasPoint: CGPoint) -> CGPoint {
        let imageRect = getImageBoundsInCanvas()
        
        // Convert from canvas coordinates to image-relative coordinates
        let relativeX = canvasPoint.x - imageRect.origin.x
        let relativeY = canvasPoint.y - imageRect.origin.y
        
        return CGPoint(x: relativeX, y: relativeY)
    }
    
}
