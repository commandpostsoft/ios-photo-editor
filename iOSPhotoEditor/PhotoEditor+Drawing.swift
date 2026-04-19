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
                    savePendingDrawSnapshot()
                    // Convert canvas coordinates to image coordinates
                    lastPoint = convertCanvasPointToImagePoint(canvasPoint)
                } else {
                    lastPoint = nil
                }
            }
        } else if isLineDrawing {
            if let touch = touches.first {
                let canvasPoint = touch.location(in: self.canvasImageView)
                if isPointWithinImageBounds(canvasPoint) {
                    // Clean up any stale preview layer
                    linePreviewLayer?.removeFromSuperlayer()
                    lineStartCanvasPoint = canvasPoint

                    let layer = CAShapeLayer()
                    layer.strokeColor = drawColor.cgColor
                    layer.lineWidth = drawLineWidth
                    layer.lineCap = .round
                    layer.fillColor = UIColor.clear.cgColor
                    canvasImageView.layer.addSublayer(layer)
                    linePreviewLayer = layer
                }
            }
        } else if isShapeDrawing {
            if let touch = touches.first { shapeTouchBegan(touch) }
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
        } else if isLineDrawing, let start = lineStartCanvasPoint, let layer = linePreviewLayer {
            if let touch = touches.first {
                let current = clampPointToImageBounds(touch.location(in: canvasImageView))
                let path = UIBezierPath()
                path.move(to: start)
                path.addLine(to: current)
                layer.path = path.cgPath
            }
        } else if isShapeDrawing {
            if let touch = touches.first { shapeTouchMoved(touch) }
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>,
                                      with event: UIEvent?){
        if isDrawing && lastPoint != nil {
            if !swiped {
                // draw a single point
                drawLineFrom(lastPoint, toPoint: lastPoint)
            }
        } else if isLineDrawing, let start = lineStartCanvasPoint {
            linePreviewLayer?.removeFromSuperlayer()
            linePreviewLayer = nil

            if let touch = touches.first {
                let end = clampPointToImageBounds(touch.location(in: canvasImageView))
                // Only create if we have meaningful distance
                let dx = end.x - start.x
                let dy = end.y - start.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > 8 {
                    createLineSubview(from: start, to: end)
                }
            }
            lineStartCanvasPoint = nil
            return
        } else if isShapeDrawing {
            if let touch = touches.first { shapeTouchEnded(touch) }
            return
        }
        // Discard pending snapshot if no drawing occurred
        discardPendingDrawSnapshot()
        lastPoint = nil
        swiped = false
    }

    override public func touchesCancelled(_ touches: Set<UITouch>,
                                          with event: UIEvent?) {
        // Clean up freehand drawing state
        discardPendingDrawSnapshot()
        lastPoint = nil
        swiped = false

        // Clean up line drawing state
        linePreviewLayer?.removeFromSuperlayer()
        linePreviewLayer = nil
        lineStartCanvasPoint = nil

        // Clean up shape drawing state
        shapePreviewLayer?.removeFromSuperlayer()
        shapePreviewLayer = nil
        shapeStartCanvasPoint = nil
    }

    func drawLineFrom(_ fromPoint: CGPoint, toPoint: CGPoint) {
        // Commit the pre-draw snapshot on first actual stroke segment
        commitPendingDrawSnapshot()

        // Use display image size for drawing layer to match the visible image exactly
        let drawingSize = displayImageSize
        
        UIGraphicsBeginImageContextWithOptions(drawingSize, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return
        }

        // Draw existing drawing layer
        drawingOverlayView.image?.draw(in: CGRect(origin: .zero, size: drawingSize))

        // Draw the new line
        context.move(to: fromPoint)
        context.addLine(to: toPoint)
        context.setLineCap(.round)
        context.setLineWidth(drawLineWidth)
        context.setStrokeColor(drawColor.cgColor)
        context.setBlendMode(.normal)
        context.strokePath()

        drawingOverlayView.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        // Mark image as modified when drawing occurs
        hasImageBeenModified = true
    }
    
    private func createLineSubview(from start: CGPoint, to end: CGPoint) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)
        let angle = atan2(dy, dx)
        let padding = max(drawLineWidth, 20)
        let midpoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)

        // Render a horizontal line into a thin rectangle image
        let imageSize = CGSize(width: length + padding * 2, height: drawLineWidth + padding * 2)
        let lineStart = CGPoint(x: padding, y: imageSize.height / 2)
        let lineEnd = CGPoint(x: padding + length, y: imageSize.height / 2)

        UIGraphicsBeginImageContextWithOptions(imageSize, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return
        }

        context.setLineCap(.round)
        context.setLineWidth(drawLineWidth)
        context.setStrokeColor(drawColor.cgColor)
        context.move(to: lineStart)
        context.addLine(to: lineEnd)
        context.strokePath()

        let lineImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let image = lineImage else { return }

        saveSnapshot()

        let imageView = UIImageView(image: image)
        imageView.bounds = CGRect(origin: .zero, size: imageSize)
        imageView.center = midpoint
        imageView.transform = CGAffineTransform(rotationAngle: angle)
        imageView.contentMode = .scaleToFill
        imageView.tag = lineSubviewTag
        canvasImageView.addSubview(imageView)
        ensureDrawingOverlayOnTop()
        addGestures(view: imageView)
        hasImageBeenModified = true
    }

    // Clamp a point to the image bounds within the canvas
    func clampPointToImageBounds(_ point: CGPoint) -> CGPoint {
        let rect = getImageBoundsInCanvas()
        return CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
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
