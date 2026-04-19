//
//  PhotoEditor+AIReview.swift
//  iOSPhotoEditor
//
//  When `aiReviewBeforeCommit` is true, AI-returned annotations land on
//  the canvas in a pending state with a visual border tint and a review
//  toolbar (Accept / Decline / Revise). The editor's undo stack is not
//  mutated until Accept fires. Revise prompts for feedback, then re-calls
//  the provider with `prompt` and `previousAnnotations` populated — the
//  provider returns a replacement set.
//

import UIKit

extension PhotoEditorViewController {

    private static let pendingBorderColor = UIColor.systemYellow

    // MARK: - Entry from aiButtonTapped

    func applyAnnotationsForReview(_ annotations: [PhotoEditorAnnotation],
                                   sentImage: UIImage,
                                   sentToBaseScale: CGFloat) {
        // Snapshot BEFORE the placement so that post-Accept undo takes the
        // user back to the pre-AI canvas. On Decline we just remove the
        // pending views — the snapshot is left on the stack but represents
        // the correct pre-AI state (effectively a no-op undo slot).
        if pendingAIAnnotationViews.isEmpty {
            // Only the FIRST review round saves — revisions don't stack snapshots.
            saveSnapshot()
        }

        // Capture the subviews present before so we can diff to find what
        // applyAnnotation adds (it doesn't return the created view).
        let before = Set(canvasImageView.subviews.map { ObjectIdentifier($0) })

        for annotation in annotations {
            applyAnnotation(annotation, sentToBaseScale: sentToBaseScale)
        }
        ensureDrawingOverlayOnTop()

        let added = canvasImageView.subviews.filter {
            !before.contains(ObjectIdentifier($0))
        }
        pendingAIAnnotationViews = added
        for view in added {
            markPending(view)
        }

        lastAISentImage = sentImage
        lastAISentScale = sentToBaseScale
        lastAIAnnotations = annotations

        showAIReviewToolbar()
        setNonReviewControlsEnabled(false)
    }

    private func markPending(_ view: UIView) {
        view.layer.borderWidth = 2
        view.layer.borderColor = Self.pendingBorderColor.withAlphaComponent(0.9).cgColor
        view.layer.cornerRadius = 4
    }

    private func clearPendingMarker(_ view: UIView) {
        view.layer.borderWidth = 0
        view.layer.borderColor = nil
        view.layer.cornerRadius = 0
    }

    // MARK: - Accept / Decline / Revise

    @objc private func aiReviewAcceptTapped() {
        // Snapshot was taken at review start; just strip the cosmetic border
        // and mark modified. Accepted annotations are now permanent canvas
        // state; undo goes to pre-AI.
        for view in pendingAIAnnotationViews {
            clearPendingMarker(view)
        }
        hasImageBeenModified = !pendingAIAnnotationViews.isEmpty || hasImageBeenModified
        teardownReview()
        autoSwitchAfterContentPlacement()
    }

    @objc private func aiReviewDeclineTapped() {
        for view in pendingAIAnnotationViews {
            view.removeFromSuperview()
        }
        ensureDrawingOverlayOnTop()
        teardownReview()
    }

    @objc private func aiReviewReviseTapped() {
        guard aiProvider != nil, let sentImage = lastAISentImage else { return }
        let editor = AIPromptEditorViewController(
            title: "Revise annotations",
            subtitle: "Tell the AI what to change. You can write multiple lines.",
            initialText: "",
            submitLabel: "Revise",
            placeholder: "e.g. Don\u{2019}t circle the person in red.\nRelabel the truck as \u{201C}Excavator\u{201D}.",
            onSubmit: { [weak self] text in
                guard let self else { return }
                // Apply the host-wide suffix to user-typed revisions too.
                self.revise(with: self.combineUserPromptWithSuffix(text),
                            sentImage: sentImage)
            },
            onCancel: {})
        present(editor, animated: true)
    }

    private func revise(with prompt: String, sentImage: UIImage) {
        guard let provider = aiProvider else { return }

        // Strip the current pending batch before sending the revision request,
        // then place the replacement.
        for view in pendingAIAnnotationViews {
            view.removeFromSuperview()
        }
        pendingAIAnnotationViews = []
        ensureDrawingOverlayOnTop()
        hideAIReviewToolbar()

        let catalog = namedStickers.map { PhotoEditorStickerInfo(id: $0.id, name: $0.name) }
        let request = PhotoEditorAIRequest(
            image: sentImage,
            allowedTools: aiAllowedTools,
            prompt: prompt,
            context: aiContext,
            stickerCatalog: catalog,
            previousAnnotations: lastAIAnnotations
        )
        dispatchAIRequest(request,
                          provider: provider,
                          sentImage: sentImage,
                          sentToBaseScale: lastAISentScale,
                          allowedTools: aiAllowedTools)
    }

    // MARK: - Toolbar

    private static let aiReviewToolbarTag = 6666

    private func showAIReviewToolbar() {
        guard aiReviewToolbar == nil else { return }

        let container = UIView()
        container.tag = Self.aiReviewToolbarTag
        container.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        container.layer.cornerRadius = 24
        container.translatesAutoresizingMaskIntoConstraints = false

        let decline = reviewButton(title: "Decline",
                                   tint: .systemRed,
                                   selector: #selector(aiReviewDeclineTapped))
        let revise = reviewButton(title: "Revise…",
                                  tint: .systemBlue,
                                  selector: #selector(aiReviewReviseTapped))
        let accept = reviewButton(title: "Accept",
                                  tint: .systemGreen,
                                  selector: #selector(aiReviewAcceptTapped))

        let stack = UIStackView(arrangedSubviews: [decline, revise, accept])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        view.addSubview(container)
        aiReviewToolbar = container

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                              constant: -96),
            container.heightAnchor.constraint(equalToConstant: 48),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),
        ])
    }

    private func reviewButton(title: String, tint: UIColor, selector: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        btn.backgroundColor = tint
        btn.layer.cornerRadius = 16
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        btn.addTarget(self, action: selector, for: .touchUpInside)
        return btn
    }

    private func hideAIReviewToolbar() {
        aiReviewToolbar?.removeFromSuperview()
        aiReviewToolbar = nil
    }

    private func teardownReview() {
        pendingAIAnnotationViews = []
        lastAISentImage = nil
        lastAIAnnotations = []
        hideAIReviewToolbar()
        setNonReviewControlsEnabled(true)
    }

    /// Gate non-review toolbar controls while the user is reviewing AI output.
    /// During review, the pending batch has a yellow border that would leak
    /// into crop/save/share output, and mode switches would strand the
    /// review toolbar. Disable everything except the review buttons.
    private func setNonReviewControlsEnabled(_ enabled: Bool) {
        // Top toolbar
        rotateButton?.isEnabled = enabled
        cropButton?.isEnabled = enabled
        drawButton?.isEnabled = enabled
        lineButton?.isEnabled = enabled
        stickerButton?.isEnabled = enabled
        textButton?.isEnabled = enabled
        shapesButton?.isEnabled = enabled
        aiButton?.isEnabled = enabled
        // Bottom toolbar
        saveButton?.isEnabled = enabled
        shareButton?.isEnabled = enabled
        clearButton?.isEnabled = enabled
        continueButton?.isEnabled = enabled
    }
}
