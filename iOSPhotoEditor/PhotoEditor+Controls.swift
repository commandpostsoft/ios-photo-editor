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
    case ai
    case shapes
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
        exitShapeDrawingMode()
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
        exitShapeDrawingMode()
        addStickersViewController()
    }

    @objc func lineButtonTapped(_ sender: Any) {
        if isLineDrawing {
            exitLineDrawingMode()
        } else {
            exitDrawingMode()
            exitShapeDrawingMode()
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
        exitShapeDrawingMode()
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
        exitShapeDrawingMode()
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
        exitShapeDrawingMode()
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
        let wasShapeDrawing = isShapeDrawing
        exitDrawingMode()
        exitLineDrawingMode()
        exitShapeDrawingMode()
        colorPickerView.isHidden = true
        markerSizeCollectionView?.isHidden = true
        setTopToolbarItemsHidden(false)
        hideToolbar(hide: false)
        // If no drawing mode was active (e.g. text editing), none of the
        // exit helpers restored the mode, so do it explicitly.
        if !wasDrawing && !wasLineDrawing && !wasShapeDrawing {
            restorePreviousMode()
        }
    }
    
    //MARK: Bottom Toolbar
    
    @IBAction func saveButtonTapped(_ sender: AnyObject) {
        exitDrawingMode()
        exitLineDrawingMode()
        exitShapeDrawingMode()
        resetCanvasZoom(animated: false)
        UIImageWriteToSavedPhotosAlbum(createHighResolutionImage(),self, #selector(PhotoEditorViewController.image(_:withPotentialError:contextInfo:)), nil)
    }

    @IBAction func shareButtonTapped(_ sender: UIButton) {
        exitDrawingMode()
        exitLineDrawingMode()
        exitShapeDrawingMode()
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
        exitShapeDrawingMode()
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
        exitShapeDrawingMode()
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
    
    // MARK: AI

    @objc func aiButtonTapped(_ sender: Any) {
        guard aiProvider != nil, self.image != nil else { return }
        guard !isInAIReview else { return }   // no re-entry during review
        exitDrawingMode()
        exitLineDrawingMode()
        exitShapeDrawingMode()
        resetCanvasZoom(animated: false)

        // Route based on host config:
        //   no presets, no custom  → fire immediately
        //   custom only            → text-input alert
        //   presets only           → preset action sheet
        //   presets + custom       → action sheet with a "Custom…" entry
        if aiPresetPrompts.isEmpty && !aiAllowCustomPrompt {
            startAIRequest(prompt: nil, allowedToolsOverride: nil)
        } else if aiPresetPrompts.isEmpty && aiAllowCustomPrompt {
            presentCustomPromptAlert()
        } else {
            presentPromptPickerSheet()
        }
    }

    private func presentPromptPickerSheet() {
        let picker = AIPromptPickerViewController(
            presets: aiPresetPrompts,
            allowCustom: aiAllowCustomPrompt,
            onPick: { [weak self] id in
                guard let self else { return }
                if id == "_custom" {
                    self.presentCustomPromptAlert()
                } else if let preset = self.aiPresetPrompts.first(where: { $0.id == id }) {
                    self.startAIRequest(prompt: preset.instruction,
                                        allowedToolsOverride: preset.allowedTools)
                }
            },
            onCancel: {})
        present(picker, animated: true)
    }

    /// Present the multi-line custom-prompt editor. `presentCustomPromptAlert`
    /// is the legacy name; kept for internal call-site compatibility.
    private func presentCustomPromptAlert() {
        let editor = AIPromptEditorViewController(
            title: "Annotate",
            subtitle: "Describe what the AI should do. You can write multiple lines.",
            initialText: "",
            submitLabel: "Generate",
            placeholder: "e.g. Circle anyone without a hard hat.\nLabel each with \u{201C}MISSING PPE\u{201D} in red.",
            onSubmit: { [weak self] raw in
                guard let self else { return }
                self.startAIRequest(prompt: self.combineUserPromptWithSuffix(raw),
                                    allowedToolsOverride: nil)
            },
            onCancel: {})
        present(editor, animated: true)
    }

    /// Combine a user-typed prompt with `aiCustomPromptSuffix` (if set).
    /// Used by both the initial custom-prompt alert and the Revise flow.
    func combineUserPromptWithSuffix(_ userPrompt: String) -> String {
        guard let suffix = aiCustomPromptSuffix?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !suffix.isEmpty
        else { return userPrompt }
        return "\(userPrompt)\n\n\(suffix)"
    }

    /// Builds the request and dispatches it. Used by the initial AI button
    /// tap (direct, preset, or custom) and is reused by the Revise flow via
    /// `dispatchAIRequest` directly with `previousAnnotations` populated.
    func startAIRequest(prompt: String?,
                        allowedToolsOverride: Set<PhotoEditorAITool>?) {
        guard let provider = aiProvider, let base = self.image else { return }

        let composite = createHighResolutionImage()
        let sent = composite.resized(toMaxDimension: aiMaxImageDimension)
        let sentWidth = max(sent.size.width, 1)
        let sentToBaseScale = base.size.width / sentWidth

        // Effective allowed set: preset may narrow, never widen, the global.
        let effectiveTools: Set<PhotoEditorAITool> = {
            guard let preset = allowedToolsOverride else { return aiAllowedTools }
            return aiAllowedTools.intersection(preset)
        }()

        let catalog = namedStickers.map { PhotoEditorStickerInfo(id: $0.id, name: $0.name) }
        let request = PhotoEditorAIRequest(
            image: sent,
            allowedTools: effectiveTools,
            prompt: prompt,
            context: aiContext,
            stickerCatalog: catalog,
            previousAnnotations: nil
        )
        dispatchAIRequest(request, provider: provider,
                          sentImage: sent, sentToBaseScale: sentToBaseScale,
                          allowedTools: effectiveTools)
    }

    /// Runs one provider round-trip with spinner + error surfacing. If
    /// `aiReviewBeforeCommit` is true, places results in pending state and
    /// shows the review toolbar instead of committing.
    func dispatchAIRequest(_ request: PhotoEditorAIRequest,
                           provider: PhotoEditorAIProvider,
                           sentImage: UIImage,
                           sentToBaseScale: CGFloat,
                           allowedTools: Set<PhotoEditorAITool>) {
        let overlay = presentAISpinner()

        Task { @MainActor [weak self] in
            defer { overlay.removeFromSuperview() }
            guard let self else { return }
            do {
                let raw = try await provider.generateAnnotations(for: request)
                let annotations = raw.filter { allowedTools.contains($0.tool) }
                guard !annotations.isEmpty else { return }

                if self.aiReviewBeforeCommit {
                    self.applyAnnotationsForReview(annotations,
                                                   sentImage: sentImage,
                                                   sentToBaseScale: sentToBaseScale)
                } else {
                    self.saveSnapshot()
                    for annotation in annotations {
                        self.applyAnnotation(annotation, sentToBaseScale: sentToBaseScale)
                    }
                    self.ensureDrawingOverlayOnTop()
                    self.hasImageBeenModified = true
                    self.autoSwitchAfterContentPlacement()
                }
            } catch {
                self.aiDelegate?.photoEditor(self, aiAnnotationDidFail: error)
                print("AI annotation failed: \(error)")
            }
        }
    }

    func applyAnnotation(_ annotation: PhotoEditorAnnotation, sentToBaseScale s: CGFloat) {
        // Scale a sent-image-space point/rect into current-base-image space,
        // which is what `canvasPoint(fromOriginal:)` and `addShapeAnnotationSubview`
        // already expect.
        func scale(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * s, y: p.y * s) }
        func scale(_ r: CGRect)  -> CGRect  {
            CGRect(x: r.minX * s, y: r.minY * s, width: r.width * s, height: r.height * s)
        }

        switch annotation {
        case .text(let string, let sentPoint, let fontSize, let color, let alignment, let outline):
            // fontSize is in display points (same as UIFont.pointSize) and is
            // NOT scaled by the sent-image rescale.
            let displayFontSize = min(max(fontSize, 8), 90)
            let font = UIFont(name: "Helvetica", size: displayFontSize)
                ?? UIFont.systemFont(ofSize: displayFontSize)
            let fill = color ?? textColor

            let textView = UITextView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 30))
            textView.backgroundColor = .clear
            textView.isScrollEnabled = false
            textView.autocorrectionType = .no
            textView.delegate = self

            // Outline + shadow compound into a muddy look. Use one or the
            // other — outline when explicitly requested, otherwise the
            // subtle legibility shadow.
            if outline == nil {
                textView.layer.shadowColor = UIColor.black.cgColor
                textView.layer.shadowOffset = CGSize(width: 1.0, height: 0.0)
                textView.layer.shadowOpacity = 0.2
                textView.layer.shadowRadius = 1.0
            }

            // Attributed text wins over `font`/`textColor`; keep typingAttributes
            // in sync so the style survives user edits.
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = alignment
            var attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: fill,
                .paragraphStyle: paragraph,
            ]
            if let outline {
                attrs[.strokeColor] = outline
                attrs[.strokeWidth] = -4.0  // percent of font size (negative = fill+stroke)
            }
            textView.attributedText = NSAttributedString(string: string, attributes: attrs)
            textView.typingAttributes = attrs
            textView.textAlignment = alignment

            let fit = textView.sizeThatFits(CGSize(width: view.bounds.width,
                                                   height: .greatestFiniteMagnitude))
            textView.bounds.size = CGSize(width: textView.intrinsicContentSize.width,
                                          height: fit.height)
            textView.center = canvasPoint(fromOriginal: scale(sentPoint))
            canvasImageView.addSubview(textView)
            ensureDrawingOverlayOnTop()
            addGestures(view: textView)

        case .box(let rect, let color, let lineWidth):
            let r = scale(rect)
            addShapeAnnotationSubview(
                kind: .box,
                originalFrom: CGPoint(x: r.minX, y: r.minY),
                originalTo:   CGPoint(x: r.maxX, y: r.maxY),
                color: color,
                lineWidth: lineWidth
            )

        case .ellipse(let rect, let color, let lineWidth):
            let r = scale(rect)
            addShapeAnnotationSubview(
                kind: .ellipse,
                originalFrom: CGPoint(x: r.minX, y: r.minY),
                originalTo:   CGPoint(x: r.maxX, y: r.maxY),
                color: color,
                lineWidth: lineWidth
            )

        case .arrow(let from, let to, let color, let lineWidth):
            addShapeAnnotationSubview(
                kind: .arrow,
                originalFrom: scale(from),
                originalTo:   scale(to),
                color: color,
                lineWidth: lineWidth
            )

        case .sticker(let id, let sentPoint, let size):
            guard let sticker = namedStickers.first(where: { $0.id == id }) else {
                // Provider referenced an id not in the catalog — silently skip.
                return
            }
            // Default sticker size: roughly 1/6 of the canvas's shorter side.
            let defaultLongestEdge = min(view.bounds.width, view.bounds.height) / 6
            let longestEdge = size.map { min(max($0, 20), 800) } ?? defaultLongestEdge
            let aspect = sticker.image.size.width / max(sticker.image.size.height, 1)
            let displaySize: CGSize = aspect >= 1
                ? CGSize(width: longestEdge, height: longestEdge / aspect)
                : CGSize(width: longestEdge * aspect, height: longestEdge)

            let imageView = UIImageView(image: sticker.image)
            imageView.bounds = CGRect(origin: .zero, size: displaySize)
            imageView.center = canvasPoint(fromOriginal: scale(sentPoint))
            imageView.contentMode = .scaleAspectFit
            imageView.isUserInteractionEnabled = true
            canvasImageView.addSubview(imageView)
            ensureDrawingOverlayOnTop()
            addGestures(view: imageView)
        }
    }

    private func canvasPoint(fromOriginal p: CGPoint) -> CGPoint {
        let imageRect = getImageBoundsInCanvas()
        let s = 1.0 / max(displayToOriginalScale, 0.0001)
        return CGPoint(x: imageRect.origin.x + p.x * s,
                       y: imageRect.origin.y + p.y * s)
    }

    private static let aiSpinnerTag = 7777

    private func presentAISpinner() -> UIView {
        let overlay = UIView(frame: view.bounds)
        overlay.tag = Self.aiSpinnerTag
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blur.frame = CGRect(x: 0, y: 0, width: 160, height: 120)
        blur.center = overlay.center
        blur.layer.cornerRadius = 14
        blur.clipsToBounds = true
        blur.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin,
                                 .flexibleLeftMargin, .flexibleRightMargin]

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()

        let label = UILabel()
        label.text = "Generating…"
        label.textColor = .white
        label.font = .systemFont(ofSize: 13)

        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),
        ])

        overlay.addSubview(blur)
        view.addSubview(overlay)
        return overlay
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
            case .ai:
                aiButton?.isHidden = true
            case .shapes:
                shapesButton?.isHidden = true
            case .undoRedo, .markerSize, .emoji:
                break
            }
        }
    }
    
}
