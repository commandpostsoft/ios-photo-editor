//
//  PhotoEditor+Gestures.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 6/16/17.
//
//

import Foundation


import UIKit

extension PhotoEditorViewController : UIGestureRecognizerDelegate  {
    
    /**
     UIPanGestureRecognizer - Moving Objects
     Selecting transparent parts of the imageview won't move the object
     */
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        if let view = recognizer.view {
            if let imageView = view as? UIImageView {
                if imageView.tag == lineSubviewTag {
                    // Line subviews are mostly transparent — use full bounds
                    moveView(view: imageView, recognizer: recognizer)
                } else {
                    // Tap only on visible parts on the image
                    // Check topmost (most recently placed) items first
                    if recognizer.state == .began {
                        for iv in subImageViews(view: canvasImageView).reversed() {
                            let location = recognizer.location(in: iv)
                            let alpha = iv.alphaAtPoint(location)
                            if alpha > 0 {
                                imageViewToPan = iv
                                break
                            }
                        }
                    }
                    if let pan = imageViewToPan {
                        moveView(view: pan, recognizer: recognizer)
                    }
                }
            } else {
                moveView(view: view, recognizer: recognizer)
            }
        }
    }
    
    /**
     UIPinchGestureRecognizer - Pinching Objects
     If it's a UITextView will make the font bigger so it doen't look pixlated.
     Scale is clamped: stickers/lines 0.3–4.0, text 8pt–90pt.
     */
    @objc func pinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        if let view = recognizer.view {
            if recognizer.state == .began {
                saveSnapshot()
            }
            if let textView = view as? UITextView, let currentFont = textView.font {
                let proposedSize = currentFont.pointSize * recognizer.scale
                let clampedSize = min(max(proposedSize, 8), 90)
                let font = UIFont(name: currentFont.fontName, size: clampedSize)
                textView.font = font
                let sizeToFit = textView.sizeThatFits(CGSize(width: UIScreen.main.bounds.size.width,
                                                             height: CGFloat.greatestFiniteMagnitude))
                textView.bounds.size = CGSize(width: textView.intrinsicContentSize.width,
                                              height: sizeToFit.height)
                textView.setNeedsDisplay()
            } else {
                let currentS = currentScale(of: view)
                let proposedS = currentS * recognizer.scale
                let clampedS = min(max(proposedS, 0.3), 4.0)
                let currentR = currentRotation(of: view)
                view.transform = CGAffineTransform(scaleX: clampedS, y: clampedS)
                    .rotated(by: currentR)
            }
            recognizer.scale = 1
            if view == selectedSubview { refreshSelectionUI() }
        }
    }
    
    /**
     UIRotationGestureRecognizer - Rotating Objects
     Uses virtual angle tracking with snap to cardinal directions.
     */
    @objc func rotationGesture(_ recognizer: UIRotationGestureRecognizer) {
        if let view = recognizer.view {
            switch recognizer.state {
            case .began:
                saveSnapshot()
                virtualRotationAngle = currentRotation(of: view)
                isInRotationSnapZone = false
            case .changed:
                virtualRotationAngle += recognizer.rotation
                recognizer.rotation = 0
                let snappedAngle = snapAngle(virtualRotationAngle)
                let scale = currentScale(of: view)

                if view is UITextView {
                    view.transform = CGAffineTransform(rotationAngle: snappedAngle)
                } else {
                    view.transform = CGAffineTransform(scaleX: scale, y: scale)
                        .rotated(by: snappedAngle)
                }
                if view == selectedSubview { refreshSelectionUI() }
            default:
                break
            }
        }
    }
    
    /**
     UITapGestureRecognizer - Taping on Objects
     First tap selects (shows border + handle). Second tap on same view bounces.
     Selecting transparent parts of the imageview won't move the object.
     */
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if let view = recognizer.view {
            if let imageView = view as? UIImageView {
                if imageView.tag == lineSubviewTag {
                    selectSubview(imageView)
                } else {
                    // Tap only on visible parts — topmost items checked first
                    for iv in subImageViews(view: canvasImageView).reversed() {
                        let location = recognizer.location(in: iv)
                        let alpha = iv.alphaAtPoint(location)
                        if alpha > 0 {
                            selectSubview(iv)
                            break
                        }
                    }
                }
            } else {
                selectSubview(view)
            }
        }
    }
    
    /*
     Support Multiple Gesture at the same time
     */
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == canvasZoomSingleFingerPanGesture {
            return isPanZoomMode && canvasZoomScale > 1.0 && !isDrawing && !isLineDrawing
        }
        return true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer == canvasZoomPanGesture || gestureRecognizer == canvasZoomSingleFingerPanGesture) &&
           otherGestureRecognizer is UIScreenEdgePanGestureRecognizer {
            return true
        }
        return false
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    @objc func screenEdgeSwiped(_ recognizer: UIScreenEdgePanGestureRecognizer) {
        if recognizer.state == .recognized {
            if !stickersVCIsVisible {
                addStickersViewController()
            }
        }
    }
    
    // to Override Control Center screen edge pan from bottom
    override public var prefersStatusBarHidden: Bool {
        return true
    }
    
    /**
     Scale Effect
     */
    func scaleEffect(view: UIView) {
        view.superview?.bringSubviewToFront(view)
        
        if #available(iOS 10.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        }
        let previouTransform =  view.transform
        UIView.animate(withDuration: 0.2,
                       animations: {
                        view.transform = view.transform.scaledBy(x: 1.2, y: 1.2)
        },
                       completion: { _ in
                        UIView.animate(withDuration: 0.2) {
                            view.transform  = previouTransform
                        }
        })
    }
    
    /**
     Moving Objects 
     delete the view if it's inside the delete view
     Snap the view back if it's out of the canvas
     */

    func moveView(view: UIView, recognizer: UIPanGestureRecognizer)  {

        if recognizer.state == .began {
            saveSnapshot()
        }

        hideToolbar(hide: true)
        deleteView.isHidden = false
        
        view.superview?.bringSubviewToFront(view)
        let pointToSuperView = recognizer.location(in: self.view)

        view.center = CGPoint(x: view.center.x + recognizer.translation(in: canvasImageView).x,
                              y: view.center.y + recognizer.translation(in: canvasImageView).y)

        recognizer.setTranslation(CGPoint.zero, in: canvasImageView)

        if view == selectedSubview { refreshSelectionUI() }
        
        if let previousPoint = lastPanPoint {
            //View is going into deleteView
            if deleteView.frame.contains(pointToSuperView) && !deleteView.frame.contains(previousPoint) {
                if #available(iOS 10.0, *) {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                }
                UIView.animate(withDuration: 0.3, animations: {
                    view.transform = view.transform.scaledBy(x: 0.25, y: 0.25)
                    view.center = recognizer.location(in: self.canvasImageView)
                })
            }
                //View is going out of deleteView
            else if deleteView.frame.contains(previousPoint) && !deleteView.frame.contains(pointToSuperView) {
                //Scale to original Size
                UIView.animate(withDuration: 0.3, animations: {
                    view.transform = view.transform.scaledBy(x: 4, y: 4)
                    view.center = recognizer.location(in: self.canvasImageView)
                })
            }
        }
        lastPanPoint = pointToSuperView
        
        if recognizer.state == .ended {
            imageViewToPan = nil
            lastPanPoint = nil
            hideToolbar(hide: false)
            deleteView.isHidden = true
            let point = recognizer.location(in: self.view)

            // Update saved center so text returns to the moved position
            if view is UITextView && view == activeTextView {
                lastTextViewTransCenter = view.center
            }

            if deleteView.frame.contains(point) { // Delete the view
                if view == selectedSubview { deselectCurrentSubview() }
                view.removeFromSuperview()
                if #available(iOS 10.0, *) {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } else if !canvasImageView.bounds.contains(view.center) { //Snap the view back to canvasImageView
                UIView.animate(withDuration: 0.3, animations: {
                    view.center = self.canvasImageView.center
                })
                
            }
        }
    }

    func subImageViews(view: UIView) -> [UIImageView] {
        var imageviews: [UIImageView] = []
        for imageView in view.subviews {
            if imageView is UIImageView {
                imageviews.append(imageView as! UIImageView)
            }
        }
        return imageviews
    }
}
