//
//  PhotoEditor+Zoom.swift
//  Photo Editor
//
//  Pinch-to-zoom and two-finger pan on the canvas during drawing mode.
//  One-finger touch continues to draw as before.
//

import UIKit

extension PhotoEditorViewController {

    func setupCanvasZoomGestures() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handleCanvasZoomPinch(_:)))
        pinch.delegate = self
        self.view.addGestureRecognizer(pinch)
        canvasZoomPinchGesture = pinch

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleCanvasZoomPan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        pan.delegate = self
        self.view.addGestureRecognizer(pan)
        canvasZoomPanGesture = pan
    }

    // MARK: - Pinch

    @objc private func handleCanvasZoomPinch(_ recognizer: UIPinchGestureRecognizer) {
        guard isDrawing else { return }

        switch recognizer.state {
        case .began:
            cancelCurrentDrawingStroke()
        case .changed:
            let newScale = canvasZoomScale * recognizer.scale
            canvasZoomScale = min(max(newScale, 1.0), 5.0)
            recognizer.scale = 1.0
            clampPanOffset()
            applyCanvasTransform()
        case .ended, .cancelled:
            if canvasZoomScale < 1.05 {
                resetCanvasZoom(animated: true)
            }
        default:
            break
        }
    }

    // MARK: - Pan

    @objc private func handleCanvasZoomPan(_ recognizer: UIPanGestureRecognizer) {
        guard isDrawing, canvasZoomScale > 1.0 else { return }

        switch recognizer.state {
        case .began:
            cancelCurrentDrawingStroke()
        case .changed:
            let translation = recognizer.translation(in: self.view)
            canvasPanOffset.x += translation.x
            canvasPanOffset.y += translation.y
            recognizer.setTranslation(.zero, in: self.view)
            clampPanOffset()
            applyCanvasTransform()
        default:
            break
        }
    }

    // MARK: - Transform helpers

    private func applyCanvasTransform() {
        let scale = CGAffineTransform(scaleX: canvasZoomScale, y: canvasZoomScale)
        let translate = CGAffineTransform(translationX: canvasPanOffset.x, y: canvasPanOffset.y)
        canvasView.transform = scale.concatenating(translate)
    }

    private func clampPanOffset() {
        guard canvasZoomScale > 1.0 else {
            canvasPanOffset = .zero
            return
        }

        let viewSize = self.view.bounds.size
        let scaledWidth = viewSize.width * canvasZoomScale
        let scaledHeight = viewSize.height * canvasZoomScale

        let maxX = (scaledWidth - viewSize.width) / 2
        let maxY = (scaledHeight - viewSize.height) / 2

        canvasPanOffset.x = min(max(canvasPanOffset.x, -maxX), maxX)
        canvasPanOffset.y = min(max(canvasPanOffset.y, -maxY), maxY)
    }

    func resetCanvasZoom(animated: Bool) {
        canvasZoomScale = 1.0
        canvasPanOffset = .zero
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                self.canvasView.transform = .identity
            }
        } else {
            canvasView.transform = .identity
        }
    }

    private func cancelCurrentDrawingStroke() {
        lastPoint = nil
        swiped = false
    }
}
