//
//  PhotoEditor+Shapes.swift
//  iOSPhotoEditor
//
//  Interactive shape drawing (box / ellipse / arrow). Mirrors the line
//  drawing pattern in PhotoEditor+Drawing.swift — touch-down records a
//  start point, a CAShapeLayer previews the shape while the finger
//  drags, touch-up commits a UIImageView subview tagged for gestures.
//

import UIKit

extension PhotoEditorViewController {

    // MARK: Mode toggle

    @objc func shapesButtonTapped(_ sender: Any) {
        if isShapeDrawing {
            exitShapeDrawingMode()
        } else {
            exitDrawingMode()
            exitLineDrawingMode()
            modeBeforeActiveOperation = isPanZoomMode
            disableZoomGestures()
            isShapeDrawing = true
            canvasImageView.isUserInteractionEnabled = false
            let showPicker = !pickerHiddenWhileDrawing
            markerSizeCollectionView?.isHidden = !showPicker
            setColorPickerBarVisible(showPicker)
            showShapesButtonHighlight(true)
        }
    }

    func exitShapeDrawingMode() {
        guard isShapeDrawing else { return }
        isShapeDrawing = false
        pickerHiddenWhileDrawing = false
        colorPickerView.isHidden = true
        markerSizeCollectionView?.isHidden = true
        showShapesButtonHighlight(false)
        shapePreviewLayer?.removeFromSuperlayer()
        shapePreviewLayer = nil
        shapeStartCanvasPoint = nil
        restorePreviousMode()
    }

    // MARK: Touch handling (called from PhotoEditor+Drawing.swift)

    func shapeTouchBegan(_ touch: UITouch) {
        let canvasPoint = touch.location(in: canvasImageView)
        guard isPointWithinImageBounds(canvasPoint) else { return }

        shapePreviewLayer?.removeFromSuperlayer()
        shapeStartCanvasPoint = canvasPoint

        let layer = CAShapeLayer()
        layer.strokeColor = drawColor.cgColor
        layer.lineWidth = drawLineWidth
        layer.lineCap = .round
        layer.lineJoin = .round
        layer.fillColor = UIColor.clear.cgColor
        canvasImageView.layer.addSublayer(layer)
        shapePreviewLayer = layer
    }

    func shapeTouchMoved(_ touch: UITouch) {
        guard let start = shapeStartCanvasPoint, let layer = shapePreviewLayer else { return }
        let current = clampPointToImageBounds(touch.location(in: canvasImageView))
        layer.path = shapePreviewPath(from: start, to: current, kind: currentShapeKind).cgPath
    }

    func shapeTouchEnded(_ touch: UITouch) {
        guard let start = shapeStartCanvasPoint else { return }
        shapePreviewLayer?.removeFromSuperlayer()
        shapePreviewLayer = nil

        let end = clampPointToImageBounds(touch.location(in: canvasImageView))
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = sqrt(dx * dx + dy * dy)
        if distance > 8 {
            createShapeSubview(from: start, to: end, kind: currentShapeKind,
                               color: drawColor, lineWidth: drawLineWidth)
        }
        shapeStartCanvasPoint = nil
    }

    // MARK: Path generation

    private func shapePreviewPath(from start: CGPoint, to end: CGPoint, kind: PhotoEditorShape) -> UIBezierPath {
        switch kind {
        case .box:
            return UIBezierPath(rect: CGRect(from: start, to: end))
        case .ellipse:
            return UIBezierPath(ovalIn: CGRect(from: start, to: end))
        case .arrow:
            return arrowPath(from: start, to: end, lineWidth: drawLineWidth)
        }
    }

    private func arrowPath(from start: CGPoint, to end: CGPoint, lineWidth: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)

        // Arrowhead — size scales with lineWidth for visual balance
        let headLength = max(lineWidth * 3.5, 16)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let wing: CGFloat = .pi / 7  // ~25°
        let left = CGPoint(
            x: end.x - headLength * cos(angle - wing),
            y: end.y - headLength * sin(angle - wing)
        )
        let right = CGPoint(
            x: end.x - headLength * cos(angle + wing),
            y: end.y - headLength * sin(angle + wing)
        )
        path.move(to: left)
        path.addLine(to: end)
        path.addLine(to: right)
        return path
    }

    // MARK: Commit — create subview from two canvas points

    private func createShapeSubview(from start: CGPoint, to end: CGPoint,
                                    kind: PhotoEditorShape,
                                    color: UIColor, lineWidth: CGFloat) {
        // Compute bounding rect in canvas space
        let rect = CGRect(from: start, to: end)
        let padding = max(lineWidth, 20)

        // For box/ellipse the shape lives inside `rect`. For arrow we need
        // to accommodate the arrowhead which extends beyond the line endpoints.
        let imageSize = CGSize(
            width:  rect.width  + padding * 2,
            height: rect.height + padding * 2
        )

        // Translate canvas points into the image-local coordinate space (inset by padding).
        let localStart = CGPoint(x: start.x - rect.minX + padding,
                                 y: start.y - rect.minY + padding)
        let localEnd   = CGPoint(x: end.x   - rect.minX + padding,
                                 y: end.y   - rect.minY + padding)
        let localRect  = CGRect(x: padding, y: padding, width: rect.width, height: rect.height)

        UIGraphicsBeginImageContextWithOptions(imageSize, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return
        }
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(lineWidth)
        context.setStrokeColor(color.cgColor)

        let path: UIBezierPath
        switch kind {
        case .box:     path = UIBezierPath(rect: localRect)
        case .ellipse: path = UIBezierPath(ovalIn: localRect)
        case .arrow:   path = arrowPath(from: localStart, to: localEnd, lineWidth: lineWidth)
        }
        context.addPath(path.cgPath)
        context.strokePath()

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let image else { return }

        saveSnapshot()

        let imageView = UIImageView(image: image)
        imageView.bounds = CGRect(origin: .zero, size: imageSize)
        imageView.center = CGPoint(x: rect.midX, y: rect.midY)
        imageView.contentMode = .scaleToFill
        imageView.tag = lineSubviewTag  // reuse existing tag so gestures + delete work
        canvasImageView.addSubview(imageView)
        ensureDrawingOverlayOnTop()
        addGestures(view: imageView)
        hasImageBeenModified = true
    }

    // MARK: AI rendering — called from applyAnnotation

    /// Render a box/ellipse/arrow described in ORIGINAL-image space as a
    /// UIImageView subview on the canvas.
    func addShapeAnnotationSubview(kind: PhotoEditorShape,
                                   originalFrom: CGPoint,
                                   originalTo: CGPoint,
                                   color: UIColor,
                                   lineWidth: CGFloat) {
        let s = 1.0 / max(displayToOriginalScale, 0.0001)
        let imageRect = getImageBoundsInCanvas()

        let canvasFrom = CGPoint(x: imageRect.origin.x + originalFrom.x * s,
                                 y: imageRect.origin.y + originalFrom.y * s)
        let canvasTo   = CGPoint(x: imageRect.origin.x + originalTo.x   * s,
                                 y: imageRect.origin.y + originalTo.y   * s)

        createShapeSubview(from: canvasFrom, to: canvasTo, kind: kind,
                           color: color, lineWidth: lineWidth)
    }
}

// MARK: - CGRect helper

fileprivate extension CGRect {
    /// Rect spanning two points (handles any corner order).
    init(from a: CGPoint, to b: CGPoint) {
        self.init(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width:  abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }
}
