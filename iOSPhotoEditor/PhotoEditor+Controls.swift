//
//  PhotoEditor+Controls.swift
//  Pods
//
//  Created by Mohamed Hamed on 6/16/17.
//
//

import Foundation
import UIKit

// MARK: - Control
public enum control {
    case crop
    case sticker
    case draw
    case line
    case text
    case rotate
    case save
    case share
    case clear
    case panZoom
    case undoRedo
    case markerSize
    case emoji
}

extension PhotoEditorViewController {

     //MARK: Top Toolbar
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        if hasImageBeenModified || editorUndoManager.canUndo {
            let alert = UIAlertController(
                title: "Discard Changes?",
                message: "You have unsaved changes. Are you sure you want to discard them?",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Keep Editing", style: .cancel))
            alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
                self?.photoEditorDelegate?.canceledEditing()
                self?.dismiss(animated: true, completion: nil)
            })
            present(alert, animated: true)
        } else {
            photoEditorDelegate?.canceledEditing()
            self.dismiss(animated: true, completion: nil)
        }
    }

    @IBAction func cropButtonTapped(_ sender: UIButton) {
        exitDrawingMode()
        exitLineDrawingMode()
        let initialCropRect = visibleImageCropRect()
        resetCanvasZoom(animated: false)
        let controller = CropViewController()
        controller.delegate = self
        controller.image = createHighResolutionImage()
        if initialCropRect != .zero {
            controller.imageCropRect = initialCropRect
        }
        let navController = UINavigationController(rootViewController: controller)

        // Dark navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = .black
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navController.navigationBar.standardAppearance = navAppearance
        navController.navigationBar.scrollEdgeAppearance = navAppearance
        navController.navigationBar.tintColor = .white

        // Dark toolbar appearance
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithOpaqueBackground()
        toolbarAppearance.backgroundColor = .black
        navController.toolbar.standardAppearance = toolbarAppearance
        navController.toolbar.scrollEdgeAppearance = toolbarAppearance
        navController.toolbar.tintColor = .white

        navController.modalPresentationStyle = .fullScreen
        navController.view.backgroundColor = .black

        present(navController, animated: true, completion: nil)
    }

    @IBAction func stickersButtonTapped(_ sender: Any) {
        exitDrawingMode()
        exitLineDrawingMode()
        addStickersViewController()
    }

    @objc func lineButtonTapped(_ sender: Any) {
        if isLineDrawing {
            exitLineDrawingMode()
        } else {
            exitDrawingMode()
            modeBeforeActiveOperation = isPanZoomMode
            disableZoomGestures()
            isLineDrawing = true
            canvasImageView.isUserInteractionEnabled = false
            let showPicker = !pickerHiddenWhileDrawing
            markerSizeCollectionView?.isHidden = !showPicker
            setColorPickerBarVisible(showPicker)
            showLineButtonHighlight(true)
        }
    }

    @IBAction func drawButtonTapped(_ sender: Any) {
        exitLineDrawingMode()
        if isDrawing {
            exitDrawingMode()
        } else {
            modeBeforeActiveOperation = isPanZoomMode
            disableZoomGestures()
            isDrawing = true
            canvasImageView.isUserInteractionEnabled = false
            let showPicker = !pickerHiddenWhileDrawing
            markerSizeCollectionView?.isHidden = !showPicker
            setColorPickerBarVisible(showPicker)
            showDrawButtonHighlight(true)
        }
    }

    @IBAction func textButtonTapped(_ sender: Any) {
        exitDrawingMode()
        exitLineDrawingMode()
        modeBeforeActiveOperation = isPanZoomMode
        disableZoomGestures()
        canvasImageView.isUserInteractionEnabled = false
        isTyping = true
        setTopToolbarItemsHidden(true)
        // Convert the visible screen center to canvas coordinates so text appears where the user is looking
        let screenCenter = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        let canvasCenter = view.convert(screenCenter, to: canvasImageView)
        let textView = UITextView(frame: CGRect(x: canvasCenter.x - view.bounds.width / 2,
                                                y: canvasCenter.y,
                                                width: view.bounds.width, height: 30))
        
        textView.textAlignment = .center
        textView.font = UIFont(name: "Helvetica", size: 30)
        textView.textColor = textColor
        textView.layer.shadowColor = UIColor.black.cgColor
        textView.layer.shadowOffset = CGSize(width: 1.0, height: 0.0)
        textView.layer.shadowOpacity = 0.2
        textView.layer.shadowRadius = 1.0
        textView.layer.backgroundColor = UIColor.clear.cgColor
        textView.autocorrectionType = .no
        textView.isScrollEnabled = false
        textView.delegate = self
        saveSnapshot()
        self.canvasImageView.addSubview(textView)
        ensureDrawingOverlayOnTop()
        addGestures(view: textView)
        textView.becomeFirstResponder()
    }    
    
    @IBAction func rotateButtonTapped(_ sender: Any) {
        exitDrawingMode()
        exitLineDrawingMode()
        resetCanvasZoom(animated: false)
        guard let image = self.image else { return }
        saveSnapshot()

        // Rotate the full resolution image 90 degrees clockwise
        let rotatedImage = image.rotate(radians: .pi / 2)
        
        // Rotate the drawing layer as well
        rotateDrawingLayer(newImage: rotatedImage)

        // Update the image view
        setImageView(image: rotatedImage)
        self.image = rotatedImage
        hasImageBeenModified = true
    }
    
    private func rotateDrawingLayer(newImage: UIImage) {
        // Rotate the drawing bitmap
        if let drawingImage = drawingOverlayView.image {
            drawingOverlayView.image = drawingImage.rotate(radians: .pi / 2)
        }

        // OLD image rect (before setImageView updates displayImageSize)
        let oldImageRect = getImageBoundsInCanvas()

        // Compute NEW display size using same formula as setImageView()
        let screenBounds = view.bounds.size
        let rawSize = newImage.suitableSizeWithinBounds(screenBounds)
        let screenScale = UIScreen.main.scale
        let newDisplaySize = CGSize(
            width: round(rawSize.width * screenScale) / screenScale,
            height: round(rawSize.height * screenScale) / screenScale
        )

        // After setImageView, canvas resizes: width stays same, height = newDisplaySize.height.
        // Use the NEW canvas size (not the old canvasImageView.bounds) to avoid a spurious
        // centering offset that compounds through rotations.
        let newCanvasSize = CGSize(width: canvasImageView.bounds.width, height: newDisplaySize.height)
        let newImageRect = CGRect(
            x: (newCanvasSize.width - newDisplaySize.width) / 2,
            y: (newCanvasSize.height - newDisplaySize.height) / 2,
            width: newDisplaySize.width,
            height: newDisplaySize.height
        )

        // Scale factor to preserve proportional sticker coverage across aspect ratio changes
        guard oldImageRect.height > 0 && oldImageRect.width > 0 else { return }
        let scaleFactor = newImageRect.width / oldImageRect.height

        // Reposition subviews via normalized coordinates
        for subview in contentSubviews.reversed() {
            // To 0..1 in OLD rect
            let relX = (subview.center.x - oldImageRect.origin.x) / oldImageRect.width
            let relY = (subview.center.y - oldImageRect.origin.y) / oldImageRect.height

            // 90° CW in normalized space
            let newRelX = 1.0 - relY
            let newRelY = relX

            // Back to canvas coords via NEW rect
            let newCenter = CGPoint(
                x: newImageRect.origin.x + newRelX * newImageRect.width,
                y: newImageRect.origin.y + newRelY * newImageRect.height
            )
            subview.center = newCenter

            // Text views use rotation-only transforms (scale via font size)
            if let textView = subview as? UITextView, let currentFont = textView.font {
                let newSize = min(max(currentFont.pointSize * scaleFactor, 8), 90)
                textView.font = UIFont(name: currentFont.fontName, size: newSize)
                let sizeToFit = textView.sizeThatFits(CGSize(width: UIScreen.main.bounds.size.width,
                                                             height: CGFloat.greatestFiniteMagnitude))
                textView.bounds.size = CGSize(width: textView.intrinsicContentSize.width,
                                              height: sizeToFit.height)
                subview.transform = subview.transform.rotated(by: .pi / 2)
            } else {
                subview.transform = subview.transform
                    .scaledBy(x: scaleFactor, y: scaleFactor)
                    .rotated(by: .pi / 2)
            }

            // Clip subviews completely outside the NEW canvas bounds
            if !CGRect(origin: .zero, size: newCanvasSize).intersects(subview.frame) {
                subview.removeFromSuperview()
            }
        }
    }
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        view.endEditing(true)
        doneButton.isHidden = true
        let wasDrawing = isDrawing
        let wasLineDrawing = isLineDrawing
        exitDrawingMode()
        exitLineDrawingMode()
        colorPickerView.isHidden = true
        markerSizeCollectionView?.isHidden = true
        setTopToolbarItemsHidden(false)
        hideToolbar(hide: false)
        // If neither drawing mode was active (e.g. text editing),
        // exitDrawingMode/exitLineDrawingMode won't restore the mode,
        // so do it explicitly.
        if !wasDrawing && !wasLineDrawing {
            restorePreviousMode()
        }
    }
    
    //MARK: Bottom Toolbar
    
    @IBAction func saveButtonTapped(_ sender: AnyObject) {
        exitDrawingMode()
        exitLineDrawingMode()
        resetCanvasZoom(animated: false)
        UIImageWriteToSavedPhotosAlbum(createHighResolutionImage(),self, #selector(PhotoEditorViewController.image(_:withPotentialError:contextInfo:)), nil)
    }

    @IBAction func shareButtonTapped(_ sender: UIButton) {
        exitDrawingMode()
        exitLineDrawingMode()
        resetCanvasZoom(animated: false)
        let activity = UIActivityViewController(activityItems: [createHighResolutionImage()], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        present(activity, animated: true, completion: nil)
    }
    
    @IBAction func clearButtonTapped(_ sender: AnyObject) {
        exitDrawingMode()
        exitLineDrawingMode()
        let alert = UIAlertController(
            title: "Clear All Changes?",
            message: "This will remove all changes and restore the original image.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.saveSnapshot()
            self.drawingOverlayView.image = nil
            for subview in self.contentSubviews {
                subview.removeFromSuperview()
            }
            if let originalImage = self.originalImage {
                self.setImageView(image: originalImage)
                self.image = originalImage
            }
            self.hasImageBeenModified = false
        })
        present(alert, animated: true)
    }
    
    @IBAction func continueButtonPressed(_ sender: Any) {
        exitDrawingMode()
        exitLineDrawingMode()
        resetCanvasZoom(animated: false)
        if hasImageBeenModified || editorUndoManager.canUndo {
            // Image was modified, process and return high-resolution edited image
            let img = createHighResolutionImage()
            Task { @MainActor [weak self] in
                do {
                    try await self?.photoEditorDelegate?.doneEditing(image: img)
                } catch {
                    print("Error in doneEditing: \(error)")
                }
                self?.dismiss(animated: true, completion: nil)
            }
        } else {
            // If no changes made, just dismiss without calling delegate (like cancel/close)
            self.dismiss(animated: true, completion: nil)
        }
    }

    //MAKR: helper methods
    
    @objc func image(_ image: UIImage, withPotentialError error: NSErrorPointer, contextInfo: UnsafeRawPointer) {
        let alert = UIAlertController(title: "Image Saved", message: "Image successfully saved to Photos library", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func hideControls() {
        for control in hiddenControls {
            switch control {

            case .clear:
                clearButton.isHidden = true
            case .crop:
                cropButton.isHidden = true
            case .draw:
                drawButton.isHidden = true
            case .line:
                lineButton?.isHidden = true
            case .save:
                saveButton.isHidden = true
            case .share:
                shareButton.isHidden = true
            case .sticker:
                stickerButton.isHidden = true
            case .text:
                textButton.isHidden = true
            case .rotate:
                rotateButton.isHidden = true
            case .panZoom:
                panGrabButton?.isHidden = true
                resetZoomButton?.isHidden = true
            case .undoRedo, .markerSize, .emoji:
                break
            }
        }
    }
    
}
