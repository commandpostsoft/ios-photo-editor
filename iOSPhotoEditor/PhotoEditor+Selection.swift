//
//  PhotoEditor+Selection.swift
//  Photo Editor
//
//  Selection state management: dashed border, corner handle, one-finger resize+rotate.
//  The overlay lives on self.view (not canvasImageView) so it is never captured in exports.
//

import UIKit

extension PhotoEditorViewController {

    // MARK: - Setup

    /// Call from viewDidLoad to create the overlay container.
    func setupSelectionOverlay() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isUserInteractionEnabled = true
        container.backgroundColor = .clear
        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Ensure it's above canvasView but below toolbars
        if let topToolbar = topToolbar {
            view.insertSubview(container, belowSubview: topToolbar)
        }

        container.isHidden = true
        selectionOverlayContainer = container

        // Dashed border layer
        let borderLayer = CAShapeLayer()
        borderLayer.strokeColor = UIColor.white.cgColor
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineWidth = 1.5
        borderLayer.lineDashPattern = [6, 4]
        borderLayer.shadowColor = UIColor.black.cgColor
        borderLayer.shadowOffset = CGSize(width: 0, height: 1)
        borderLayer.shadowOpacity = 0.5
        borderLayer.shadowRadius = 1
        container.layer.addSublayer(borderLayer)
        selectionBorderLayer = borderLayer

        // Corner handle
        let handle = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        handle.backgroundColor = UIColor.white
        handle.layer.cornerRadius = 22
        handle.layer.shadowColor = UIColor.black.cgColor
        handle.layer.shadowOffset = CGSize(width: 0, height: 2)
        handle.layer.shadowOpacity = 0.4
        handle.layer.shadowRadius = 3

        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        let symbolImage = UIImage(systemName: "arrow.up.left.and.arrow.down.right", withConfiguration: config)
        let symbolView = UIImageView(image: symbolImage)
        symbolView.tintColor = .darkGray
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        handle.addSubview(symbolView)
        NSLayoutConstraint.activate([
            symbolView.centerXAnchor.constraint(equalTo: handle.centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: handle.centerYAnchor)
        ])

        container.addSubview(handle)
        cornerHandleView = handle

        // Drag gesture on the handle
        let dragGesture = UIPanGestureRecognizer(target: self, action: #selector(handleCornerDrag(_:)))
        handle.addGestureRecognizer(dragGesture)

        // Tap on overlay container to deselect
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(overlayTapped(_:)))
        container.addGestureRecognizer(tapGesture)
    }

    // MARK: - Select / Deselect

    func selectSubview(_ subview: UIView) {
        guard subview.superview == canvasImageView else { return }

        // If same view already selected, do bounce
        if selectedSubview === subview {
            scaleEffect(view: subview)
            return
        }

        selectedSubview = subview
        selectionOverlayContainer?.isHidden = false
        refreshSelectionUI()
    }

    func deselectCurrentSubview() {
        guard selectedSubview != nil else { return }
        selectedSubview = nil
        selectionOverlayContainer?.isHidden = true
        selectionBorderLayer?.path = nil
    }

    // MARK: - Update UI

    /// Recalculate and redraw both the dashed border and handle position.
    func refreshSelectionUI() {
        guard let subview = selectedSubview, subview.superview != nil else {
            deselectCurrentSubview()
            return
        }
        updateSelectionBorder()
        updateHandlePosition()
    }

    private func updateSelectionBorder() {
        guard let subview = selectedSubview,
              let container = selectionOverlayContainer else { return }

        // Get the four corners of the subview in container (self.view) coordinates
        let bounds = subview.bounds
        let corners = [
            CGPoint(x: bounds.minX, y: bounds.minY),
            CGPoint(x: bounds.maxX, y: bounds.minY),
            CGPoint(x: bounds.maxX, y: bounds.maxY),
            CGPoint(x: bounds.minX, y: bounds.maxY)
        ]

        let converted = corners.map { subview.convert($0, to: container) }

        let path = UIBezierPath()
        path.move(to: converted[0])
        path.addLine(to: converted[1])
        path.addLine(to: converted[2])
        path.addLine(to: converted[3])
        path.close()

        selectionBorderLayer?.path = path.cgPath
    }

    private func updateHandlePosition() {
        guard let subview = selectedSubview,
              let container = selectionOverlayContainer,
              let handle = cornerHandleView else { return }

        // Bottom-right corner of the selected view, converted to overlay space
        let bottomRight = CGPoint(x: subview.bounds.maxX, y: subview.bounds.maxY)
        let screenPoint = subview.convert(bottomRight, to: container)
        handle.center = screenPoint
    }

    // MARK: - Corner Handle Drag

    @objc private func handleCornerDrag(_ recognizer: UIPanGestureRecognizer) {
        guard let subview = selectedSubview,
              let container = selectionOverlayContainer else { return }

        let touch = recognizer.location(in: container)

        switch recognizer.state {
        case .began:
            saveSnapshot()
            let center = selectedSubviewCenterInView()
            handleDragInitialAngle = atan2(touch.y - center.y, touch.x - center.x)
            handleDragInitialDistance = distance(center, touch)
            handleDragInitialScale = currentScale(of: subview)
            handleDragInitialRotation = currentRotation(of: subview)
            virtualRotationAngle = handleDragInitialRotation
            isInRotationSnapZone = false

        case .changed:
            let center = selectedSubviewCenterInView()
            let currentAngle = atan2(touch.y - center.y, touch.x - center.x)
            let angleDelta = currentAngle - handleDragInitialAngle
            virtualRotationAngle = handleDragInitialRotation + angleDelta
            let snappedRotation = snapAngle(virtualRotationAngle)

            let currentDistance = distance(center, touch)
            guard handleDragInitialDistance > 0 else { return }
            let scaleFactor = currentDistance / handleDragInitialDistance
            var targetScale = handleDragInitialScale * scaleFactor

            if subview is UITextView {
                // For text views, apply rotation only (scale is via font size)
                subview.transform = CGAffineTransform(rotationAngle: snappedRotation)
            } else {
                // Clamp scale 0.3–4.0
                targetScale = min(max(targetScale, 0.3), 4.0)
                subview.transform = CGAffineTransform(scaleX: targetScale, y: targetScale)
                    .rotated(by: snappedRotation)
            }

            refreshSelectionUI()

        case .ended, .cancelled:
            break

        default:
            break
        }
    }

    // MARK: - Overlay Tap

    @objc private func overlayTapped(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: selectionOverlayContainer)

        // Check if tap is on the handle itself — ignore
        if let handle = cornerHandleView, handle.frame.contains(location) {
            return
        }

        // Check if tap hits the selected subview's screen-space bounds
        if let subview = selectedSubview, let container = selectionOverlayContainer {
            let bounds = subview.bounds
            let corners = [
                CGPoint(x: bounds.minX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.maxY),
                CGPoint(x: bounds.minX, y: bounds.maxY)
            ]
            let converted = corners.map { subview.convert($0, to: container) }
            let path = UIBezierPath()
            path.move(to: converted[0])
            path.addLine(to: converted[1])
            path.addLine(to: converted[2])
            path.addLine(to: converted[3])
            path.close()

            if path.contains(location) {
                // Tap on the selected view itself — do bounce
                scaleEffect(view: subview)
                return
            }
        }

        deselectCurrentSubview()
    }

    // MARK: - Helpers

    func selectedSubviewCenterInView() -> CGPoint {
        guard let subview = selectedSubview, let container = selectionOverlayContainer else {
            return .zero
        }
        let boundsCenter = CGPoint(x: subview.bounds.midX, y: subview.bounds.midY)
        return subview.convert(boundsCenter, to: container)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Cleanup

    func cleanupSelectionOverlay() {
        selectionBorderLayer?.removeFromSuperlayer()
        selectionBorderLayer = nil
        cornerHandleView?.removeFromSuperview()
        cornerHandleView = nil
        selectionOverlayContainer?.removeFromSuperview()
        selectionOverlayContainer = nil
        selectedSubview = nil
    }
}
