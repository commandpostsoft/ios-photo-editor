//
//  PhotoEditor+Zoom.swift
//  Photo Editor
//
//  Pinch-to-zoom and two-finger pan on the canvas.
//  Toggle between pan/zoom mode and grab mode via bottom toolbar buttons.
//

import UIKit

extension PhotoEditorViewController {

    var grabModeAvailable: Bool {
        !hiddenControls.contains(.text) || !hiddenControls.contains(.sticker) || !hiddenControls.contains(.line)
    }

    // MARK: - Setup

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

        let singlePan = UIPanGestureRecognizer(target: self, action: #selector(handleCanvasZoomSingleFingerPan(_:)))
        singlePan.minimumNumberOfTouches = 1
        singlePan.maximumNumberOfTouches = 1
        singlePan.delegate = self
        self.view.addGestureRecognizer(singlePan)
        canvasZoomSingleFingerPanGesture = singlePan
    }

    func setupPanGrabToggle() {
        guard let stackView = clearButton?.superview as? UIStackView else { return }

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)

        if grabModeAvailable {
            let toggleBtn = UIButton(type: .custom)
            toggleBtn.setImage(UIImage(systemName: "arrow.up.and.down.and.arrow.left.and.right", withConfiguration: config), for: .normal)
            toggleBtn.tintColor = .white
            toggleBtn.layer.shadowColor = UIColor.black.cgColor
            toggleBtn.layer.shadowOffset = CGSize(width: 1.0, height: 0.0)
            toggleBtn.layer.shadowOpacity = 0.15
            toggleBtn.layer.shadowRadius = 1.0
            toggleBtn.addTarget(self, action: #selector(panGrabToggleTapped), for: .touchUpInside)
            stackView.addArrangedSubview(toggleBtn)
            panGrabButton = toggleBtn
        }

        // Reset zoom button (hidden by default) — placed after toggle so it appears to its right
        let resetBtn = UIButton(type: .custom)
        resetBtn.setImage(UIImage(systemName: "arrow.down.right.and.arrow.up.left", withConfiguration: config), for: .normal)
        resetBtn.tintColor = .white
        resetBtn.layer.shadowColor = UIColor.black.cgColor
        resetBtn.layer.shadowOffset = CGSize(width: 1.0, height: 0.0)
        resetBtn.layer.shadowOpacity = 0.15
        resetBtn.layer.shadowRadius = 1.0
        resetBtn.isHidden = true
        resetBtn.addTarget(self, action: #selector(resetZoomButtonTapped), for: .touchUpInside)
        stackView.addArrangedSubview(resetBtn)
        resetZoomButton = resetBtn

        if isPanZoomMode {
            switchToPanMode()
        }
    }

    // MARK: - Mode Switching

    func switchToPanMode() {
        isPanZoomMode = true
        canvasZoomPinchGesture?.isEnabled = true
        canvasZoomPanGesture?.isEnabled = true
        canvasZoomSingleFingerPanGesture?.isEnabled = true
        canvasImageView.isUserInteractionEnabled = false
        updatePanGrabUI()
    }

    func switchToGrabMode() {
        guard grabModeAvailable else {
            switchToPanMode()
            return
        }
        isPanZoomMode = false
        canvasZoomPinchGesture?.isEnabled = false
        canvasZoomPanGesture?.isEnabled = false
        canvasZoomSingleFingerPanGesture?.isEnabled = false
        canvasImageView.isUserInteractionEnabled = true
        updatePanGrabUI()
    }

    func autoSwitchAfterContentPlacement() {
        switchToGrabMode()
    }

    func restorePreviousMode() {
        if modeBeforeActiveOperation {
            switchToPanMode()
        } else {
            switchToGrabMode()
        }
    }

    func disableZoomGestures() {
        canvasZoomPinchGesture?.isEnabled = false
        canvasZoomPanGesture?.isEnabled = false
        canvasZoomSingleFingerPanGesture?.isEnabled = false
    }

    func updatePanGrabUI() {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        if isPanZoomMode {
            panGrabButton?.setImage(UIImage(systemName: "arrow.up.and.down.and.arrow.left.and.right", withConfiguration: config), for: .normal)
        } else {
            panGrabButton?.setImage(UIImage(systemName: "hand.raised.fill", withConfiguration: config), for: .normal)
        }
        resetZoomButton?.isHidden = canvasZoomScale <= 1.0 || hiddenControls.contains(.panZoom)
    }

    // MARK: - Crop from Zoom

    func visibleImageCropRect() -> CGRect {
        guard canvasZoomScale > 1.0, let img = self.image else { return .zero }

        // Map screen corners to canvas-local coordinates via UIKit's transform-aware conversion
        let topLeft = view.convert(CGPoint(x: view.bounds.minX, y: view.bounds.minY), to: canvasView)
        let bottomRight = view.convert(CGPoint(x: view.bounds.maxX, y: view.bounds.maxY), to: canvasView)
        let visibleInCanvas = CGRect(
            x: topLeft.x, y: topLeft.y,
            width: bottomRight.x - topLeft.x,
            height: bottomRight.y - topLeft.y
        )

        let imageBounds = getImageBoundsInCanvas()
        let intersection = visibleInCanvas.intersection(imageBounds)
        guard !intersection.isNull else { return .zero }

        let relX = (intersection.origin.x - imageBounds.origin.x) / imageBounds.width
        let relY = (intersection.origin.y - imageBounds.origin.y) / imageBounds.height
        let relW = intersection.width / imageBounds.width
        let relH = intersection.height / imageBounds.height

        return CGRect(x: relX * img.size.width, y: relY * img.size.height,
                      width: relW * img.size.width, height: relH * img.size.height)
    }

    // MARK: - Button Actions

    @objc private func panGrabToggleTapped() {
        if isPanZoomMode {
            switchToGrabMode()
        } else {
            switchToPanMode()
        }
    }

    @objc private func resetZoomButtonTapped() {
        resetCanvasZoom(animated: true)
        updatePanGrabUI()
    }

    // MARK: - Pinch

    @objc private func handleCanvasZoomPinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            cancelCurrentDrawingStroke()
        case .changed:
            let pinchCenter = recognizer.location(in: self.view)
            let viewCenter = CGPoint(x: view.bounds.midX, y: view.bounds.midY)

            let oldScale = canvasZoomScale
            let newScale = min(max(canvasZoomScale * recognizer.scale, 1.0), 5.0)
            let ratio = newScale / oldScale

            // Offset from view center to pinch point
            let dx = pinchCenter.x - viewCenter.x
            let dy = pinchCenter.y - viewCenter.y

            // Adjust pan offset so the pinch point stays stationary on screen
            canvasPanOffset.x = canvasPanOffset.x * ratio + dx * (1 - ratio)
            canvasPanOffset.y = canvasPanOffset.y * ratio + dy * (1 - ratio)
            canvasZoomScale = newScale

            recognizer.scale = 1.0
            clampPanOffset()
            applyCanvasTransform()
            updatePanGrabUI()
        case .ended, .cancelled:
            if canvasZoomScale < 1.05 {
                resetCanvasZoom(animated: true)
            }
            updatePanGrabUI()
        default:
            break
        }
    }

    // MARK: - Pan

    @objc private func handleCanvasZoomPan(_ recognizer: UIPanGestureRecognizer) {
        guard canvasZoomScale > 1.0 else { return }

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

    // MARK: - Single-Finger Pan (when zoomed)

    @objc private func handleCanvasZoomSingleFingerPan(_ recognizer: UIPanGestureRecognizer) {
        guard isPanZoomMode && canvasZoomScale > 1.0 else { return }

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
        refreshSelectionUI()
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
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) { [weak self] in
                self?.canvasView.transform = .identity
            } completion: { [weak self] _ in
                self?.refreshSelectionUI()
            }
        } else {
            canvasView.transform = .identity
            refreshSelectionUI()
        }
        updatePanGrabUI()
    }

    private func cancelCurrentDrawingStroke() {
        discardPendingDrawSnapshot()
        lastPoint = nil
        swiped = false
    }
}
