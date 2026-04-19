//
//  ViewController.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 4/23/17.
//  Copyright © 2017 Mohamed Hamed. All rights reserved.
//

import UIKit

@objc(PhotoEditorViewController)
public final class PhotoEditorViewController: UIViewController {
    
    /** holding the 2 imageViews original image and drawing & stickers */
    @IBOutlet weak var canvasView: UIView!
    //To hold the image
    @IBOutlet var imageView: UIImageView!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    //To hold the drawings and stickers
    @IBOutlet weak var canvasImageView: UIImageView!
    var drawingOverlayView: UIImageView!

    @IBOutlet weak var topToolbar: UIView!
    @IBOutlet weak var bottomToolbar: UIView!

    @IBOutlet weak var topGradient: UIView!
    @IBOutlet weak var bottomGradient: UIView!
    
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var colorsCollectionView: UICollectionView!
    @IBOutlet weak var colorPickerView: UIView!
    @IBOutlet weak var colorPickerViewBottomConstraint: NSLayoutConstraint!
    // These are reassigned at runtime in anchorTopConstraintsToSafeArea();
    // NSLayoutConstraint outlets must not be weak when reassigned — the RHS
    // temporary deallocates before activation otherwise.
    @IBOutlet var topToolbarTopConstraint: NSLayoutConstraint!
    @IBOutlet var topGradientTopConstraint: NSLayoutConstraint!
    @IBOutlet var colorPickerTopConstraint: NSLayoutConstraint!
    @IBOutlet var doneButtonTopConstraint: NSLayoutConstraint!
    //Controls
    @IBOutlet weak var cropButton: UIButton!
    @IBOutlet weak var stickerButton: UIButton!
    @IBOutlet weak var drawButton: UIButton!
    @IBOutlet weak var textButton: UIButton!
    @IBOutlet weak var rotateButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!
    
    public var image: UIImage?
    var originalImage: UIImage?
    var originalImageSize: CGSize = CGSize.zero
    var displayToOriginalScale: CGFloat = 1.0
    var displayImageSize: CGSize = CGSize.zero
    var previousCanvasBounds: CGSize = CGSize.zero
    /**
     Array of Stickers -UIImage- that the user will choose from
     */
    public var stickers : [UIImage] = []
    /**
     Array of Colors that will show while drawing or typing
     */
    public var colors  : [UIColor] = []
    
    /**
     Line width for drawing. Default is 5.0.
     */
    public var drawLineWidth: CGFloat = 5.0 {
        didSet { drawLineWidth = min(max(drawLineWidth, 1.0), 100.0) }
    }

    /**
     Maximum number of undo levels to keep. Default is 5.
     Higher values use more memory since each level stores a full editor snapshot.
     */
    public var maxUndoLevels: Int = 5

    /**
     Array of marker sizes for the marker size picker.
     Up to 5 values, minimum value 1. The second size is auto-selected by default.
     Default: [5, 8, 12, 18]
     */
    public var markerSizes: [CGFloat] = [5, 8, 12, 18]

    public weak var photoEditorDelegate: PhotoEditorDelegate?
    /**
     Optional provider for AI-generated annotations. When set, a "sparkles" button
     appears in the top toolbar. Tapping it hands the current base image to the
     provider and applies returned annotations as editable subviews. The library
     itself imports no AI frameworks — the host app chooses the backend.
     Hide the button via `.ai` in `hiddenControls`.
     */
    public weak var aiProvider: PhotoEditorAIProvider? {
        didSet { aiButton?.isHidden = hiddenControls.contains(.ai) || aiProvider == nil }
    }

    /// Optional delegate notified when an AI provider call throws.
    /// The editor swallows the error (canvas unchanged, no snapshot); this
    /// lets the host surface the failure to the user.
    public weak var aiDelegate: PhotoEditorAIDelegate?

    /**
     Longest-edge pixel cap for the image handed to `aiProvider`. Default 2048.
     The editor composites the current base image with any user annotations,
     then scales so `max(width, height) <= aiMaxImageDimension` before calling
     the provider. Smaller values cut token/bandwidth cost; larger values give
     vision models more detail. Returned annotation coordinates are interpreted
     as being in the coord space of the image the provider received, and the
     library rescales them back to original resolution before rendering.
     Set to a very large value (e.g. `.greatestFiniteMagnitude`) to disable.
     */
    public var aiMaxImageDimension: CGFloat = 2048

    /**
     Annotation kinds the AI provider is permitted to produce on this editor.
     Default: all four (`.text`, `.box`, `.ellipse`, `.arrow`). Restrict to a
     subset to prevent the model from returning other kinds; the library passes
     this set to the provider so it can omit disallowed tools from its prompt,
     and filters returned annotations against it as a safety net.
     Future preset prompts may further narrow this set per-prompt (intersection).
     */
    public var aiAllowedTools: Set<PhotoEditorAITool> = Set(PhotoEditorAITool.allCases)

    /**
     Named stickers the AI provider may reference via `.sticker(id:at:size:)`.
     Each has an `id` (quoted back by the provider) and a `name` (shown to
     the AI in the catalog so it knows what each sticker represents — e.g.
     `"checkmark"`, `"warning-triangle"`, `"company-logo"`).
     Empty (default) means the sticker tool is effectively unavailable even
     if `.sticker` is in `aiAllowedTools`.
     */
    public var namedStickers: [PhotoEditorSticker] = []

    /**
     Host-supplied metadata passed to the AI provider on every request.
     Typical keys: `"projectName"`, `"datetime"`, `"latitude"`, `"longitude"`,
     `"capturedBy"`. The library does not extract EXIF — the host decides
     what's safe and relevant to share.
     */
    public var aiContext: [String: String] = [:]

    /**
     When true, AI-generated annotations are placed in a "pending" state
     with a visual tint and a review toolbar (Accept / Decline / Revise).
     The host's undo stack is not mutated until the user accepts.
     Default: `false` (annotations commit immediately).
     */
    public var aiReviewBeforeCommit: Bool = false

    /**
     Host-defined preset prompts shown in the picker when the user taps the
     sparkles button. See `PhotoEditorAIPrompt` for the structure. Empty
     (default) skips the preset list.
     */
    public var aiPresetPrompts: [PhotoEditorAIPrompt] = []

    /**
     When true, the AI picker includes a "Custom…" entry that lets the user
     type their own instruction. Default `false`. Combine with
     `aiPresetPrompts` to offer both; leave presets empty for custom-only.
     */
    public var aiAllowCustomPrompt: Bool = false

    /**
     Text appended to any user-typed custom prompt (including Revise).
     Useful for host-wide style rules — e.g. `"Always use a green font"`
     or `"Only annotate the foreground subject."` Ignored for preset
     prompts, since those already reflect the host's full instruction.
     */
    public var aiCustomPromptSuffix: String? = nil

    // Review-flow runtime state — set between provider return and Accept/Decline/Revise.
    var pendingAIAnnotationViews: [UIView] = []
    var lastAISentImage: UIImage?
    var lastAISentScale: CGFloat = 1.0
    var lastAIAnnotations: [PhotoEditorAnnotation] = []
    var aiReviewToolbar: UIView?
    var isInAIReview: Bool { !pendingAIAnnotationViews.isEmpty || aiReviewToolbar != nil }

    /**
     Shapes to expose in the top-toolbar shapes button. Default is empty (button hidden).
     Host populates with `[.box, .ellipse, .arrow]` (or any subset) to enable.
     Long-press on the button cycles through the provided kinds.
     */
    public var availableShapes: [PhotoEditorShape] = [] {
        didSet {
            if !availableShapes.contains(currentShapeKind), let first = availableShapes.first {
                currentShapeKind = first
                refreshShapesButtonIcon()
            }
            updateShapesButtonVisibility()
        }
    }
    var colorsCollectionViewDelegate: ColorsCollectionViewDelegate!
    
    // list of controls to be hidden
    public var hiddenControls : [control] = []

    /**
     Left-to-right order of buttons in the top-right toolbar stack.
     Set this before the view loads to override the default layout.
     Controls not listed here are removed from the stack — use `hiddenControls`
     instead if you only want to hide a button while preserving its slot.
     `.undoRedo`, `.markerSize`, `.emoji`, `.save`, `.share`, `.clear`, and
     `.panZoom` do not live in this stack and are ignored.
     Default: `[.rotate, .crop, .text, .sticker, .shapes, .ai, .line, .draw]`
     (`.draw` rightmost / closest to the user's thumb).
     */
    public var topRightToolbarOrder: [control] = [.rotate, .crop, .text, .sticker, .shapes, .ai, .line, .draw]

    /**
     Left-to-right order of buttons in the bottom-left toolbar stack.
     Set this before the view loads to override the default layout.
     Controls not listed here are removed from the stack.
     `.panZoom` represents both the pan/grab toggle and the reset-zoom button —
     they always appear together as a pair at that position.
     Default: `[.save, .share, .clear, .panZoom]`.
     */
    public var bottomLeftToolbarOrder: [control] = [.save, .share, .clear, .panZoom]

    private static let cPostHighlight = UIColor(red:0.200, green:0.600, blue:0.800, alpha:0.800)
    
    var stickersVCIsVisible = false
    var drawColor: UIColor = cPostHighlight
    var textColor: UIColor = cPostHighlight
    var isDrawing: Bool = false
    var isLineDrawing: Bool = false
    var lineStartCanvasPoint: CGPoint?
    var linePreviewLayer: CAShapeLayer?
    var lineButton: UIButton?
    var aiButton: UIButton?
    var shapesButton: UIButton?

    // Shape drawing state (parallel to isLineDrawing / lineStartCanvasPoint / linePreviewLayer)
    var isShapeDrawing: Bool = false
    var currentShapeKind: PhotoEditorShape = .box
    var shapeStartCanvasPoint: CGPoint?
    var shapePreviewLayer: CAShapeLayer?
    var pickerHiddenWhileDrawing: Bool = false
    var hasImageBeenModified: Bool = false {
        didSet { updateActionButtons() }
    }
    
    // UserDefaults keys for persistence
    private let drawColorKey = "PhotoEditor.DrawColor"
    private let textColorKey = "PhotoEditor.TextColor"
    private let markerSizeKey = "PhotoEditor.MarkerSize"
    var lastPoint: CGPoint!
    var swiped = false
    var lastPanPoint: CGPoint?
    var pendingDrawSnapshot: EditorSnapshot?
    var lastTextViewTransform: CGAffineTransform?
    var lastTextViewTransCenter: CGPoint?
    var lastTextViewFont:UIFont?
    var activeTextView: UITextView?
    var imageViewToPan: UIImageView?
    var isTyping: Bool = false
    
    
    var markerSizeCollectionView: UICollectionView?
    var markerSizeCollectionViewDelegate: MarkerSizeCollectionViewDelegate?
    var stickersViewController: StickersViewController!

    // False when `colors` has exactly 1 entry -- the swatch row offers no choice
    // so it's hidden and the single color is applied to drawColor/textColor.
    var colorsPickerAvailable: Bool = true

    var canvasZoomScale: CGFloat = 1.0
    var canvasPanOffset: CGPoint = .zero
    var canvasZoomPinchGesture: UIPinchGestureRecognizer?
    var canvasZoomPanGesture: UIPanGestureRecognizer?
    var canvasZoomSingleFingerPanGesture: UIPanGestureRecognizer?

    var isPanZoomMode: Bool = true
    var panGrabButton: UIButton?
    var resetZoomButton: UIButton?
    var modeBeforeActiveOperation: Bool = true

    var editorUndoManager = EditorUndoManager()
    private var undoButton: UIButton?
    private var redoButton: UIButton?
    var undoRedoStack: UIStackView?

    public init() {
        super.init(nibName: "PhotoEditorViewController", bundle: Bundle.module)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    //Register Custom font before we load XIB
    public override func loadView() {
        registerFont()
        super.loadView()
    }
    
    deinit {
        colorsCollectionViewDelegate?.colorDelegate = nil
        colorsCollectionViewDelegate = nil
        markerSizeCollectionViewDelegate?.markerSizeDelegate = nil
        markerSizeCollectionViewDelegate = nil
        markerSizeCollectionView = nil
        stickersViewController?.stickersViewControllerDelegate = nil
        stickersViewController = nil
        undoButton = nil
        redoButton = nil
        undoRedoStack = nil
        linePreviewLayer?.removeFromSuperlayer()
        linePreviewLayer = nil
        lineButton = nil
        aiButton = nil
        shapesButton = nil
        shapePreviewLayer?.removeFromSuperlayer()
        shapePreviewLayer = nil
        panGrabButton = nil
        resetZoomButton = nil
        drawingOverlayView?.image = nil
        drawingOverlayView = nil
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        
        setupIconFonts()
        setupButtonPressFeedback()

        deleteView.layer.cornerRadius = deleteView.bounds.height / 2
        deleteView.layer.borderWidth = 2.0
        deleteView.layer.borderColor = UIColor.white.cgColor
        deleteView.clipsToBounds = true
        
        let edgePan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(screenEdgeSwiped))
        edgePan.edges = .bottom
        edgePan.delegate = self
        self.view.addGestureRecognizer(edgePan)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow),
                                               name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self,selector: #selector(keyboardWillChangeFrame(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        
        
        loadSavedColors()
        configureCollectionView()
        setupMarkerSizePicker()
        stickersViewController = StickersViewController(nibName: "StickersViewController", bundle: Bundle.module)
        setupLineButton()
        setupShapesButton()
        setupAIButton()
        setupDrawButtonLongPress()
        setupUndoRedoButtons()
        setupCanvasZoomGestures()
        setupPanGrabToggle()
        applyToolbarButtonOrders()
        hideControls()
        tightenToolbarSpacingIfNeeded()
        updateActionButtons()
        anchorTopConstraintsToSafeArea()

        drawingOverlayView = UIImageView()
        drawingOverlayView.contentMode = .scaleToFill
        drawingOverlayView.isUserInteractionEnabled = false
        canvasImageView.addSubview(drawingOverlayView)
    }
    
    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        editorUndoManager.clear()
        updateUndoRedoButtons()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Use full screen bounds for simpler sizing
        let currentScreenBounds = view.bounds.size

        // Re-evaluate toolbar overflow when orientation flips (portrait ↔ landscape).
        let isPortraitNow = currentScreenBounds.height >= currentScreenBounds.width
        if lastLayoutWasPortrait != isPortraitNow {
            lastLayoutWasPortrait = isPortraitNow
            applyToolbarButtonOrders()
            tightenToolbarSpacingIfNeeded()
        }

        // Set image after views are laid out to get correct bounds
        if imageView.image == nil && image != nil {
            self.setImageView(image: image!)
            previousCanvasBounds = currentScreenBounds
        } else if previousCanvasBounds != CGSize.zero && currentScreenBounds != previousCanvasBounds {
            // Reset zoom before rescaling to avoid layout conflicts with transforms
            resetCanvasZoom(animated: false)
            updatePanGrabUI()
            // Screen size changed, rescale everything
            rescaleCanvas(from: previousCanvasBounds, to: currentScreenBounds)
            previousCanvasBounds = currentScreenBounds
        }
    }

    private var lastLayoutWasPortrait: Bool?
    
    /// Call once from viewDidLoad. Deactivates the xib's top constraints
    /// (pinned to `view.top` with baked-in 44/44/50/55 constants) and
    /// re-anchors them to `safeAreaLayoutGuide.topAnchor` so UIKit tracks
    /// safe-area changes automatically — no race with the first layout pass.
    ///
    /// Also insets the topToolbar horizontally to the safe-area guide so
    /// both ends (cancel button, right-side button stack) clear the notch
    /// / Dynamic Island / home-indicator in landscape — without needing
    /// per-child safe-area anchors. On iPadOS 26 we use the corner-adapted
    /// safe area so Stage Manager traffic-light chrome is honored too.
    private func anchorTopConstraintsToSafeArea() {
        topToolbarTopConstraint?.isActive = false
        topGradientTopConstraint?.isActive = false
        colorPickerTopConstraint?.isActive = false
        doneButtonTopConstraint?.isActive = false

        let guide = view.safeAreaLayoutGuide
        topToolbarTopConstraint  = topToolbar.topAnchor.constraint(equalTo: guide.topAnchor)
        topGradientTopConstraint = topGradient.topAnchor.constraint(equalTo: guide.topAnchor)
        colorPickerTopConstraint = colorPickerView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 66)
        doneButtonTopConstraint  = doneButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 11)

        NSLayoutConstraint.activate([
            topToolbarTopConstraint,
            topGradientTopConstraint,
            colorPickerTopConstraint,
            doneButtonTopConstraint
        ])

        anchorTopToolbarHorizontallyToSafeArea()
    }

    /// Replace the xib's edge-to-edge leading/trailing constraints on the
    /// top toolbar with ones anchored to the horizontal safe-area guide.
    /// This shifts the entire toolbar inside the notch / home-indicator
    /// inset in landscape, so the cancel button (pinned to `topToolbar.leading + 12`)
    /// and the right button stack (pinned to `topToolbar.trailing - 12`) stay
    /// symmetric without each child having its own safe-area constraint.
    private func anchorTopToolbarHorizontallyToSafeArea() {
        // Deactivate any existing superview-owned leading/trailing constraints
        // that target `topToolbar` so our replacements don't fight the xib.
        for c in view.constraints {
            guard c.firstItem as? UIView === topToolbar || c.secondItem as? UIView === topToolbar else { continue }
            let attrs: [NSLayoutConstraint.Attribute] = [.leading, .trailing, .left, .right]
            if attrs.contains(c.firstAttribute) || attrs.contains(c.secondAttribute) {
                c.isActive = false
            }
        }

        let leadingAnchor: NSLayoutXAxisAnchor
        let trailingAnchor: NSLayoutXAxisAnchor
        if #available(iOS 26.0, *) {
            let g = view.layoutGuide(for: .safeArea(cornerAdaptation: .horizontal))
            leadingAnchor  = g.leadingAnchor
            trailingAnchor = g.trailingAnchor
        } else {
            leadingAnchor  = view.safeAreaLayoutGuide.leadingAnchor
            trailingAnchor = view.safeAreaLayoutGuide.trailingAnchor
        }

        NSLayoutConstraint.activate([
            topToolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            topToolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
    
    private func setupIconFonts() {
        let icomoonFont = UIFont(name: "icomoon", size: 25)
        let icomoonFontLarge = UIFont(name: "icomoon", size: 50)
        
        // Top toolbar buttons
        cropButton?.setTitle("\u{E90A}", for: .normal)
        cropButton?.titleLabel?.font = icomoonFont
        
        let stickerSymbolConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        stickerButton?.setTitle(nil, for: .normal)
        stickerButton?.setImage(UIImage(systemName: "seal.fill", withConfiguration: stickerSymbolConfig), for: .normal)
        stickerButton?.tintColor = .white
        
        drawButton?.setTitle("\u{E905}", for: .normal)
        drawButton?.titleLabel?.font = icomoonFont
        
        textButton?.setTitle("\u{E901}", for: .normal)
        textButton?.titleLabel?.font = icomoonFont
        
        rotateButton?.setTitle("↻", for: .normal)
        rotateButton?.titleLabel?.font = UIFont.systemFont(ofSize: 25)
        
        // Bottom toolbar buttons
        saveButton?.setTitle("\u{E903}", for: .normal)
        saveButton?.titleLabel?.font = icomoonFont
        
        shareButton?.setTitle("\u{E904}", for: .normal)
        shareButton?.titleLabel?.font = icomoonFont
        
        clearButton?.setTitle("\u{E909}", for: .normal)
        clearButton?.titleLabel?.font = icomoonFont
        
        // Find and set cancel button (in top toolbar)
        if let cancelButton = topToolbar?.subviews.first(where: {
            ($0 as? UIButton)?.actions(forTarget: self, forControlEvent: .touchUpInside)?
                .contains("cancelButtonTapped:") ?? false
        }) as? UIButton {
            cancelButton.setTitle("\u{E902}", for: .normal)
            cancelButton.titleLabel?.font = icomoonFont
        }
        
        // Find and set continue button (in bottom toolbar - larger size)
        if let continueButton = bottomToolbar?.subviews.first(where: {
            ($0 as? UIButton)?.actions(forTarget: self, forControlEvent: .touchUpInside)?
                .contains("continueButtonPressed:") ?? false
        }) as? UIButton {
            continueButton.setTitle("\u{E900}", for: .normal)
            continueButton.titleLabel?.font = icomoonFontLarge
        }
        
        // Set delete view label
        if let deleteLabel = deleteView?.subviews.first as? UILabel {
            deleteLabel.text = "\u{E907}"
            deleteLabel.font = UIFont(name: "icomoon", size: 30)
        }
    }
    
    private func setupButtonPressFeedback() {
        let toolbarButtons: [UIButton?] = [
            cropButton, stickerButton, drawButton, textButton, rotateButton,
            saveButton, shareButton, clearButton, continueButton
        ]
        for button in toolbarButtons {
            guard let btn = button else { continue }
            addPressFeedback(to: btn)
        }
        // Cancel button found dynamically
        if let cancelButton = topToolbar?.subviews.first(where: {
            ($0 as? UIButton)?.actions(forTarget: self, forControlEvent: .touchUpInside)?
                .contains("cancelButtonTapped:") ?? false
        }) as? UIButton {
            addPressFeedback(to: cancelButton)
        }
    }

    private func addPressFeedback(to button: UIButton) {
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.allowUserInteraction, .curveEaseIn]) {
            sender.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            sender.alpha = 0.6
        }
    }

    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.15, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
            sender.transform = .identity
            sender.alpha = sender.isEnabled ? 1.0 : 0.3
        }
    }

    func configureCollectionView() {
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 30, height: 30)
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        colorsCollectionView.collectionViewLayout = layout
        colorsCollectionViewDelegate = ColorsCollectionViewDelegate()
        colorsCollectionViewDelegate.colorDelegate = self
        if colors.count == 1 {
            // Only one color available: apply it and hide the swatch row.
            let only = colors[0]
            drawColor = only
            textColor = only
            colorsCollectionViewDelegate.colors = colors
            colorsCollectionView.isHidden = true
            colorsPickerAvailable = false
        } else if !colors.isEmpty {
            colorsCollectionViewDelegate.colors = colors
        }
        colorsCollectionView.delegate = colorsCollectionViewDelegate
        colorsCollectionView.dataSource = colorsCollectionViewDelegate

        colorsCollectionView.register(
            ColorCollectionViewCell.self,
            forCellWithReuseIdentifier: "ColorCollectionViewCell")
    }

    /// Show or hide the color picker bar, respecting current child visibility.
    /// The bar stays hidden if neither the color swatches nor the marker size
    /// picker would be visible — avoids showing an empty bar (e.g. during text
    /// editing with a single configured color, when the marker picker is hidden
    /// outside drawing mode).
    ///
    /// Callers that also toggle `markerSizeCollectionView?.isHidden` must set
    /// that first, so this helper sees the up-to-date child state.
    func setColorPickerBarVisible(_ visible: Bool) {
        if !visible {
            colorPickerView.isHidden = true
            return
        }
        let colorsVisible = colorsPickerAvailable && !colorsCollectionView.isHidden
        let markerVisible = !(markerSizeCollectionView?.isHidden ?? true)
        colorPickerView.isHidden = !(colorsVisible || markerVisible)
    }
    
    private func setupMarkerSizePicker() {
        guard !hiddenControls.contains(.markerSize) else { return }
        // Filter out invalid values, enforce minimum of 1, and limit to 5
        let sanitized = markerSizes.filter { $0.isFinite && $0 > 0 }.map { max($0, 1) }.sorted().prefix(5)
        let sizes = Array(sanitized)
        // With 0 or 1 sizes the picker offers no choice, so hide it:
        //  - 0 sizes: keep the default drawLineWidth
        //  - 1 size:  always use that size for draw and line
        guard sizes.count > 1 else {
            if let single = sizes.first {
                drawLineWidth = single
            }
            return
        }

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.isHidden = true
        cv.register(MarkerSizeCollectionViewCell.self, forCellWithReuseIdentifier: "MarkerSizeCollectionViewCell")

        let delegate = MarkerSizeCollectionViewDelegate()
        delegate.sizes = sizes
        delegate.drawColor = drawColor
        delegate.markerSizeDelegate = self

        cv.delegate = delegate
        cv.dataSource = delegate

        colorPickerView.addSubview(cv)

        let cvWidth = CGFloat(sizes.count) * 40
        NSLayoutConstraint.activate([
            cv.topAnchor.constraint(equalTo: colorsCollectionView.topAnchor),
            cv.trailingAnchor.constraint(equalTo: colorPickerView.trailingAnchor),
            cv.widthAnchor.constraint(equalToConstant: cvWidth),
            cv.heightAnchor.constraint(equalToConstant: 40)
        ])

        markerSizeCollectionView = cv
        markerSizeCollectionViewDelegate = delegate

        // Restore saved size, or default to second option (index 1)
        let savedSize = UserDefaults.standard.double(forKey: markerSizeKey)
        let selectedIndex: Int
        if savedSize > 0, let idx = sizes.firstIndex(of: CGFloat(savedSize)) {
            selectedIndex = idx
        } else {
            selectedIndex = sizes.count > 1 ? 1 : 0
        }
        drawLineWidth = sizes[selectedIndex]
        DispatchQueue.main.async {
            let indexPath = IndexPath(item: selectedIndex, section: 0)
            cv.selectItem(at: indexPath, animated: false, scrollPosition: .centeredHorizontally)
        }
    }

    func setImageView(image: UIImage) {
        imageView.image = image
        
        // Store original image and size on first load only
        if originalImage == nil {
            originalImage = image
            originalImageSize = image.size
        }
        
        // Fit image to screen bounds (width or height, whichever fits best)
        let screenBounds = view.bounds.size
        let rawSize = image.suitableSizeWithinBounds(screenBounds)
        // Pixel-snap to prevent cumulative resampling drift in drawLineFrom bitmap contexts
        let screenScale = UIScreen.main.scale
        displayImageSize = CGSize(
            width: round(rawSize.width * screenScale) / screenScale,
            height: round(rawSize.height * screenScale) / screenScale
        )
        
        // Calculate scale factor from display to current image size
        displayToOriginalScale = image.size.width / displayImageSize.width
        
        // Set the image view constraints
        imageViewHeightConstraint.constant = displayImageSize.height

        // Force layout update
        view.layoutIfNeeded()

        // Pin drawing overlay to the actual image rect so its bitmap is not
        // stretched across the horizontal letterbox margins (iPad portrait).
        updateDrawingOverlayFrame()
    }

    func updateDrawingOverlayFrame() {
        guard isViewLoaded, drawingOverlayView != nil else { return }
        drawingOverlayView.frame = getImageBoundsInCanvas()
    }
    
    func setTopToolbarItemsHidden(_ hidden: Bool) {
        undoRedoStack?.isHidden = hidden
        if hidden {
            rotateButton?.isHidden = true
            cropButton?.isHidden = true
            drawButton?.isHidden = true
            lineButton?.isHidden = true
            stickerButton?.isHidden = true
            textButton?.isHidden = true
            aiButton?.isHidden = true
            shapesButton?.isHidden = true
        } else {
            // Respect hiddenControls when showing items back
            rotateButton?.isHidden = hiddenControls.contains(.rotate)
            cropButton?.isHidden = hiddenControls.contains(.crop)
            drawButton?.isHidden = hiddenControls.contains(.draw)
            lineButton?.isHidden = hiddenControls.contains(.line)
            stickerButton?.isHidden = hiddenControls.contains(.sticker)
            textButton?.isHidden = hiddenControls.contains(.text)
            aiButton?.isHidden = hiddenControls.contains(.ai) || aiProvider == nil
            updateShapesButtonVisibility()
        }
    }

    func updateShapesButtonVisibility() {
        shapesButton?.isHidden = hiddenControls.contains(.shapes) || availableShapes.isEmpty
    }

    func hideToolbar(hide: Bool) {
        topToolbar.isHidden = hide
        topGradient.isHidden = hide
        bottomToolbar.isHidden = hide
        bottomGradient.isHidden = hide
    }

    func exitDrawingMode() {
        guard isDrawing else { return }
        isDrawing = false
        pickerHiddenWhileDrawing = false
        colorPickerView.isHidden = true
        markerSizeCollectionView?.isHidden = true
        showDrawButtonHighlight(false)
        restorePreviousMode()
    }

    func exitLineDrawingMode() {
        guard isLineDrawing else { return }
        isLineDrawing = false
        pickerHiddenWhileDrawing = false
        colorPickerView.isHidden = true
        markerSizeCollectionView?.isHidden = true
        showLineButtonHighlight(false)
        linePreviewLayer?.removeFromSuperlayer()
        linePreviewLayer = nil
        lineStartCanvasPoint = nil
        restorePreviousMode()
    }

    private let drawHighlightTag = 9999
    private let lineHighlightTag = 9998
    let lineSubviewTag = 8888

    var contentSubviews: [UIView] {
        canvasImageView.subviews.filter { $0 !== drawingOverlayView }
    }

    func ensureDrawingOverlayOnTop() {
        canvasImageView.bringSubviewToFront(drawingOverlayView)
    }

    func showLineButtonHighlight(_ show: Bool) {
        guard let lineButton = lineButton else { return }
        if show {
            guard lineButton.superview?.viewWithTag(lineHighlightTag) == nil else { return }
            let size: CGFloat = 35
            let highlight = UIView(frame: CGRect(
                x: lineButton.frame.midX - size / 2,
                y: lineButton.frame.midY - size / 2,
                width: size, height: size))
            highlight.tag = lineHighlightTag
            highlight.backgroundColor = UIColor.white.withAlphaComponent(0.25)
            highlight.layer.cornerRadius = size / 2
            highlight.isUserInteractionEnabled = false
            lineButton.superview?.insertSubview(highlight, belowSubview: lineButton)
        } else {
            lineButton.superview?.viewWithTag(lineHighlightTag)?.removeFromSuperview()
        }
    }

    func showDrawButtonHighlight(_ show: Bool) {
        guard let drawButton = drawButton else { return }
        if show {
            guard drawButton.superview?.viewWithTag(drawHighlightTag) == nil else { return }
            let size: CGFloat = 35
            let highlight = UIView(frame: CGRect(
                x: drawButton.frame.midX - size / 2,
                y: drawButton.frame.midY - size / 2,
                width: size, height: size))
            highlight.tag = drawHighlightTag
            highlight.backgroundColor = UIColor.white.withAlphaComponent(0.25)
            highlight.layer.cornerRadius = size / 2
            highlight.isUserInteractionEnabled = false
            drawButton.superview?.insertSubview(highlight, belowSubview: drawButton)
        } else {
            drawButton.superview?.viewWithTag(drawHighlightTag)?.removeFromSuperview()
        }
    }

    /// Map a `control` enum case to the button (if any) that lives in a toolbar stack.
    /// Returns nil for controls that aren't toolbar-stack buttons (e.g. `.undoRedo`).
    private func toolbarButton(for ctrl: control) -> UIButton? {
        switch ctrl {
        case .rotate:    return rotateButton
        case .crop:      return cropButton
        case .sticker:   return stickerButton
        case .text:      return textButton
        case .draw:      return drawButton
        case .line:      return lineButton
        case .ai:        return aiButton
        case .shapes:    return shapesButton
        case .save:      return saveButton
        case .share:     return shareButton
        case .clear:     return clearButton
        case .panZoom:   return panGrabButton  // resetZoomButton is paired in apply()
        case .undoRedo, .markerSize, .emoji:
            return nil
        }
    }

    /// Re-arrange the top-right and bottom-left toolbar stacks per
    /// `topRightToolbarOrder` / `bottomLeftToolbarOrder`. Buttons not listed in
    /// the order arrays are removed from their stack (they remain in memory and
    /// can still be referenced, just not laid out by the stack).
    func applyToolbarButtonOrders() {
        applyOrder(topRightToolbarOrder, to: drawButton?.superview as? UIStackView)
        applyOrder(bottomLeftToolbarOrder, to: saveButton?.superview as? UIStackView)
        applyTopToolbarOverflow()
        installLastSelectedTracking()
    }

    /// The XIB ships with 15pt stack spacing sized for the original 5-button
    /// toolbar. With shapes + AI + line added (up to 8 icons), the icons get
    /// visually cramped. Scale spacing down once the count grows. Call this
    /// AFTER `hideControls()` so hidden buttons don't inflate the count.
    func tightenToolbarSpacingIfNeeded() {
        if let topStack = drawButton?.superview as? UIStackView {
            let visible = topStack.arrangedSubviews.filter { !$0.isHidden }.count
            topStack.spacing = visible >= 7 ? 6 : (visible == 6 ? 10 : 15)
        }
    }

    // MARK: - Top toolbar overflow
    //
    // On iPhone portrait, limit the top-right stack to 5 slots, laid out
    // left-to-right as:
    //   slots 1–2: `.rotate` and `.crop` (in their configured order, stay put).
    //   slot 3:    MRU "rotating" slot — last-selected non-fixed control.
    //              Defaults to the first non-fixed entry in
    //              `topRightToolbarOrder` (usually `.text`).
    //   slot 4:    the right-most entry of `topRightToolbarOrder` — pinned
    //              so the host's "primary" action (defaults to `.draw`) is
    //              always one tap away, right next to the overflow.
    //   slot 5:    overflow ellipsis with the remaining controls in a UIMenu.
    // iPad / landscape skip overflow and show every button in order.
    //
    // "Fixed" controls (never overflow): `.rotate`, `.crop`, and the last
    // entry in `topRightToolbarOrder`. Everything else rotates through MRU.

    private var overflowButton: UIButton?
    private var lastSelectedToolbarControl: control?

    private var shouldShowTopOverflow: Bool {
        let isPhone = traitCollection.userInterfaceIdiom == .phone
        let isPortrait = view.bounds.height >= view.bounds.width
        return isPhone && isPortrait
    }

    private func applyTopToolbarOverflow() {
        guard let stack = drawButton?.superview as? UIStackView else { return }

        // Remove any prior overflow button.
        if let btn = overflowButton {
            stack.removeArrangedSubview(btn)
            btn.removeFromSuperview()
            overflowButton = nil
        }
        // Reset overflow-driven hiding; permanent hiding is reapplied below.
        for ctrl in topRightToolbarOrder {
            guard let btn = toolbarButton(for: ctrl), btn.superview === stack else { continue }
            btn.isHidden = isPermanentlyHidden(ctrl)
        }

        guard shouldShowTopOverflow else { return }

        let visibleOrder = topRightToolbarOrder.filter { ctrl in
            guard let btn = toolbarButton(for: ctrl) else { return false }
            return btn.superview === stack && !btn.isHidden
        }
        guard visibleOrder.count > 5 else { return }

        // Fixed controls: .rotate, .crop (leftmost), and the last-in-order
        // (pinned right-most, next to overflow).
        let pinnedRightmost = visibleOrder.last
        let isFixed: (control) -> Bool = { ctrl in
            ctrl == .rotate || ctrl == .crop || ctrl == pinnedRightmost
        }

        let leftFixed = visibleOrder.filter { $0 == .rotate || $0 == .crop }  // in order
        let rotatables = visibleOrder.filter { !isFixed($0) }                  // rotating pool

        // Slot 3: last-selected non-fixed, falling back to the first rotatable.
        guard let defaultMRU = rotatables.first else { return }
        let mru: control = {
            if let last = lastSelectedToolbarControl,
               !isFixed(last),
               rotatables.contains(last) {
                return last
            }
            return defaultMRU
        }()

        // Layout: leftFixed (rotate/crop), MRU, pinnedRightmost, overflow.
        var kept = leftFixed + [mru]
        if let right = pinnedRightmost, !kept.contains(right) { kept.append(right) }
        let overflow = visibleOrder.filter { !kept.contains($0) }

        // Arrange the kept buttons in order; overflow button goes last.
        for (i, ctrl) in kept.enumerated() {
            guard let btn = toolbarButton(for: ctrl), btn.superview === stack else { continue }
            stack.removeArrangedSubview(btn)
            stack.insertArrangedSubview(btn, at: i)
        }
        for ctrl in overflow { toolbarButton(for: ctrl)?.isHidden = true }

        let btn = makeOverflowButton(for: overflow)
        stack.addArrangedSubview(btn)
        overflowButton = btn
    }

    private func isPermanentlyHidden(_ ctrl: control) -> Bool {
        if hiddenControls.contains(ctrl) { return true }
        if ctrl == .ai,     aiProvider == nil          { return true }
        if ctrl == .shapes, availableShapes.isEmpty    { return true }
        return false
    }

    private func makeOverflowButton(for controls: [control]) -> UIButton {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let btn = UIButton(type: .custom)
        btn.setImage(UIImage(systemName: "ellipsis.circle", withConfiguration: config), for: .normal)
        btn.tintColor = .white
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 1.0, height: 0.0)
        btn.layer.shadowOpacity = 0.15
        btn.layer.shadowRadius = 1.0
        addPressFeedback(to: btn)

        let actions: [UIMenuElement] = controls.compactMap { ctrl in
            guard let target = toolbarButton(for: ctrl) else { return nil }
            return UIAction(title: overflowMenuTitle(for: ctrl),
                            image: overflowMenuImage(for: ctrl)) { [weak self, weak target] _ in
                self?.lastSelectedToolbarControl = ctrl
                target?.sendActions(for: .touchUpInside)
                DispatchQueue.main.async { self?.applyToolbarButtonOrders() }
            }
        }
        btn.menu = UIMenu(title: "", children: actions)
        btn.showsMenuAsPrimaryAction = true
        return btn
    }

    private func overflowMenuTitle(for ctrl: control) -> String {
        switch ctrl {
        case .rotate:  return "Rotate"
        case .crop:    return "Crop"
        case .text:    return "Text"
        case .sticker: return "Sticker"
        case .shapes:  return "Shape"
        case .ai:      return "AI"
        case .line:    return "Line"
        case .draw:    return "Draw"
        default:       return ""
        }
    }

    private func overflowMenuImage(for ctrl: control) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        switch ctrl {
        case .rotate:  return UIImage(systemName: "rotate.right", withConfiguration: config)
        case .crop:    return UIImage(systemName: "crop", withConfiguration: config)
        case .text:    return UIImage(systemName: "textformat", withConfiguration: config)
        case .sticker: return UIImage(systemName: "face.smiling", withConfiguration: config)
        case .shapes:  return UIImage(systemName: "square.on.circle", withConfiguration: config)
        case .ai:      return UIImage(systemName: "sparkles", withConfiguration: config)
        case .line:    return UIImage(systemName: "line.diagonal", withConfiguration: config)
        case .draw:    return UIImage(systemName: "pencil.tip", withConfiguration: config)
        default:       return nil
        }
    }

    private func installLastSelectedTracking() {
        // Only track controls eligible for the MRU slot (excludes the fixed
        // slots: .rotate, .crop, and the pinned right-most).
        let pinnedRightmost = topRightToolbarOrder.last
        for ctrl in topRightToolbarOrder
            where ctrl != .rotate && ctrl != .crop && ctrl != pinnedRightmost {
            guard let btn = toolbarButton(for: ctrl) else { continue }
            let id = "photoEditor.lastSelected.\(ctrl)"
            btn.removeAction(identifiedBy: .init(id), for: .touchUpInside)
            btn.addAction(UIAction(identifier: .init(id)) { [weak self] _ in
                self?.lastSelectedToolbarControl = ctrl
                DispatchQueue.main.async { self?.applyToolbarButtonOrders() }
            }, for: .touchUpInside)
        }
    }

    private func applyOrder(_ order: [control], to stackView: UIStackView?) {
        guard let stack = stackView else { return }

        // Snapshot first so we can drop unmentioned buttons after re-arranging.
        let original = stack.arrangedSubviews

        var added = Set<UIView>()
        for ctrl in order {
            if let btn = toolbarButton(for: ctrl), btn.superview === stack, added.insert(btn).inserted {
                stack.removeArrangedSubview(btn)
                stack.addArrangedSubview(btn)
            }
            // .panZoom carries both panGrabButton and resetZoomButton as a pair.
            if ctrl == .panZoom, let reset = resetZoomButton, reset.superview === stack, added.insert(reset).inserted {
                stack.removeArrangedSubview(reset)
                stack.addArrangedSubview(reset)
            }
        }

        // Anything originally in the stack that wasn't mentioned: remove from layout.
        for view in original where !added.contains(view) {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    private func setupLineButton() {
        guard let drawButton = drawButton,
              let stackView = drawButton.superview as? UIStackView else { return }

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let btn = UIButton(type: .custom)
        btn.setImage(UIImage(systemName: "line.diagonal", withConfiguration: config), for: .normal)
        btn.tintColor = .white
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 1.0, height: 0.0)
        btn.layer.shadowOpacity = 0.15
        btn.layer.shadowRadius = 1.0
        btn.addTarget(self, action: #selector(lineButtonTapped(_:)), for: .touchUpInside)
        addPressFeedback(to: btn)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(lineButtonLongPressed(_:)))
        btn.addGestureRecognizer(longPress)

        lineButton = btn
        // Append to the stack; final left-to-right ordering is applied by
        // applyToolbarButtonOrders() once all dynamic buttons exist.
        stackView.addArrangedSubview(btn)
    }

    private func setupShapesButton() {
        guard let drawButton = drawButton,
              let stackView = drawButton.superview as? UIStackView else { return }

        let btn = UIButton(type: .custom)
        btn.tintColor = .white
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 1.0, height: 0.0)
        btn.layer.shadowOpacity = 0.15
        btn.layer.shadowRadius = 1.0
        btn.addTarget(self, action: #selector(shapesButtonTapped(_:)), for: .touchUpInside)
        addPressFeedback(to: btn)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(shapesButtonLongPressed(_:)))
        btn.addGestureRecognizer(longPress)

        shapesButton = btn
        // Append to the stack; final left-to-right ordering is applied by
        // applyToolbarButtonOrders() once all dynamic buttons exist.
        stackView.addArrangedSubview(btn)

        refreshShapesButtonIcon()
        updateShapesButtonVisibility()
    }

    @objc private func shapesButtonLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        guard availableShapes.count > 1 else { return }
        let currentIndex = availableShapes.firstIndex(of: currentShapeKind) ?? -1
        let nextIndex = (currentIndex + 1) % availableShapes.count
        currentShapeKind = availableShapes[nextIndex]
        refreshShapesButtonIcon()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func refreshShapesButtonIcon() {
        guard let btn = shapesButton else { return }
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let symbol: String
        switch currentShapeKind {
        case .box:     symbol = "rectangle"
        case .ellipse: symbol = "circle"
        case .arrow:   symbol = "arrow.up.right"
        }
        btn.setImage(UIImage(systemName: symbol, withConfiguration: config), for: .normal)
    }

    private let shapesHighlightTag = 9997

    func showShapesButtonHighlight(_ show: Bool) {
        guard let shapesButton = shapesButton else { return }
        if show {
            guard shapesButton.superview?.viewWithTag(shapesHighlightTag) == nil else { return }
            let size: CGFloat = 35
            let highlight = UIView(frame: CGRect(
                x: shapesButton.frame.midX - size / 2,
                y: shapesButton.frame.midY - size / 2,
                width: size, height: size))
            highlight.tag = shapesHighlightTag
            highlight.backgroundColor = UIColor.white.withAlphaComponent(0.25)
            highlight.layer.cornerRadius = size / 2
            highlight.isUserInteractionEnabled = false
            shapesButton.superview?.insertSubview(highlight, belowSubview: shapesButton)
        } else {
            shapesButton.superview?.viewWithTag(shapesHighlightTag)?.removeFromSuperview()
        }
    }

    private func setupAIButton() {
        guard let drawButton = drawButton,
              let stackView = drawButton.superview as? UIStackView else { return }

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let btn = UIButton(type: .custom)
        btn.setImage(UIImage(systemName: "sparkles", withConfiguration: config), for: .normal)
        btn.tintColor = .white
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 1.0, height: 0.0)
        btn.layer.shadowOpacity = 0.15
        btn.layer.shadowRadius = 1.0
        btn.addTarget(self, action: #selector(aiButtonTapped(_:)), for: .touchUpInside)
        addPressFeedback(to: btn)

        aiButton = btn
        // Append; final left-to-right ordering is applied by applyToolbarButtonOrders().
        stackView.addArrangedSubview(btn)

        btn.isHidden = hiddenControls.contains(.ai) || aiProvider == nil
    }

    @objc private func lineButtonLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, isLineDrawing else { return }
        pickerHiddenWhileDrawing.toggle()
        markerSizeCollectionView?.isHidden = pickerHiddenWhileDrawing
        setColorPickerBarVisible(!pickerHiddenWhileDrawing)
    }

    private func setupDrawButtonLongPress() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(drawButtonLongPressed(_:)))
        drawButton.addGestureRecognizer(longPress)
    }

    @objc private func drawButtonLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, isDrawing else { return }
        pickerHiddenWhileDrawing.toggle()
        markerSizeCollectionView?.isHidden = pickerHiddenWhileDrawing
        setColorPickerBarVisible(!pickerHiddenWhileDrawing)
    }
    
    // MARK: - Color Persistence
    private func loadSavedColors() {
        if let drawColorData = UserDefaults.standard.data(forKey: drawColorKey),
           let savedDrawColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: drawColorData) {
            drawColor = savedDrawColor
        }

        if let textColorData = UserDefaults.standard.data(forKey: textColorKey),
           let savedTextColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: textColorData) {
            textColor = savedTextColor
        }
    }
    
    private func saveDrawColor() {
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: drawColor, requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: drawColorKey)
        }
    }
    
    private func saveTextColor() {
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: textColor, requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: textColorKey)
        }
    }
    
    // MARK: - High Resolution Image Composition
    func createHighResolutionImage() -> UIImage {
        guard let currentImage = self.image else {
            return canvasView.toImage()
        }
        
        // Start with the current image (which may be cropped/rotated)
        let originalSize = currentImage.size
        
        // Create high-resolution context using the original image's scale
        UIGraphicsBeginImageContextWithOptions(originalSize, false, currentImage.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return canvasView.toImage()
        }
        
        // Draw the base image at full resolution
        currentImage.draw(in: CGRect(origin: .zero, size: originalSize))

        // Render text views and stickers at high resolution
        let imageRect = getImageBoundsInCanvas()

        for subview in contentSubviews {
            context.saveGState()

            // Convert subview position from canvas coordinates to image coordinates
            let subviewCenter = subview.center
            let relativeX = (subviewCenter.x - imageRect.origin.x) / imageRect.width
            let relativeY = (subviewCenter.y - imageRect.origin.y) / imageRect.height

            // Skip if subview is outside image bounds
            guard relativeX >= 0 && relativeX <= 1 && relativeY >= 0 && relativeY <= 1 else {
                context.restoreGState()
                continue
            }

            // Calculate position and size at original resolution
            let originalCenterX = relativeX * originalSize.width
            let originalCenterY = relativeY * originalSize.height
            let scale = displayToOriginalScale

            context.translateBy(x: originalCenterX, y: originalCenterY)
            context.scaleBy(x: scale, y: scale)
            context.concatenate(subview.transform)
            context.translateBy(x: -subview.bounds.width/2, y: -subview.bounds.height/2)

            // Render the subview
            subview.layer.render(in: context)

            context.restoreGState()
        }

        // Draw the freehand drawing overlay on top of subviews
        if let drawingImage = drawingOverlayView.image {
            let scaledDrawingRect = CGRect(origin: .zero, size: originalSize)
            drawingImage.draw(in: scaledDrawingRect)
        }

        guard let finalImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return canvasView.toImage()
        }
        
        return finalImage
    }
    
    // MARK: - Canvas Rescaling
    private func rescaleCanvas(from oldBounds: CGSize, to newBounds: CGSize) {
        guard let currentImage = self.image else { return }
        
        // Calculate new display size for the image (pixel-snapped to prevent drift)
        let rawDisplaySize = currentImage.suitableSizeWithinBounds(newBounds)
        let screenScale = UIScreen.main.scale
        let newDisplaySize = CGSize(
            width: round(rawDisplaySize.width * screenScale) / screenScale,
            height: round(rawDisplaySize.height * screenScale) / screenScale
        )
        
        // Calculate scaling factors
        let scaleX = newDisplaySize.width / displayImageSize.width
        let scaleY = newDisplaySize.height / displayImageSize.height
        
        // Update image view size
        displayImageSize = newDisplaySize
        displayToOriginalScale = currentImage.size.width / displayImageSize.width
        imageViewHeightConstraint.constant = displayImageSize.height
        
        // Force layout to get correct canvas positioning
        view.layoutIfNeeded()
        
        // Rescale drawing layer if it exists
        if let drawingImage = drawingOverlayView.image {
            let scaledDrawing = rescaleDrawingImage(drawingImage, scaleX: scaleX, scaleY: scaleY)
            drawingOverlayView.image = scaledDrawing
        }
        updateDrawingOverlayFrame()

        // Rescale all subviews (text, stickers)
        for subview in contentSubviews {
            // Scale position
            let currentCenter = subview.center
            subview.center = CGPoint(
                x: currentCenter.x * scaleX,
                y: currentCenter.y * scaleY
            )
            
            // Scale size by applying scale transform
            let currentTransform = subview.transform
            let scaleTransform = CGAffineTransform(scaleX: scaleX, y: scaleY)
            subview.transform = currentTransform.concatenating(scaleTransform)
        }
    }
    
    private func rescaleDrawingImage(_ image: UIImage, scaleX: CGFloat, scaleY: CGFloat) -> UIImage {
        let newSize = CGSize(width: image.size.width * scaleX, height: image.size.height * scaleY)

        guard newSize.width > 0, newSize.height > 0,
              newSize.width.isFinite, newSize.height.isFinite,
              newSize.width < 16384, newSize.height < 16384 else {
            return image
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: newSize))

        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }

    // MARK: - Undo/Redo

    private func setupUndoRedoButtons() {
        guard !hiddenControls.contains(.undoRedo) else { return }
        editorUndoManager.maxUndoLevels = max(1, maxUndoLevels)

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)

        let undo = UIButton(type: .custom)
        undo.setImage(UIImage(systemName: "arrow.uturn.backward", withConfiguration: config), for: .normal)
        undo.tintColor = .white
        undo.layer.shadowColor = UIColor.black.cgColor
        undo.layer.shadowOffset = CGSize(width: 1.0, height: 0.0)
        undo.layer.shadowOpacity = 0.15
        undo.layer.shadowRadius = 1.0
        undo.isHidden = true
        undo.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)

        let redo = UIButton(type: .custom)
        redo.setImage(UIImage(systemName: "arrow.uturn.forward", withConfiguration: config), for: .normal)
        redo.tintColor = .white
        redo.layer.shadowColor = UIColor.black.cgColor
        redo.layer.shadowOffset = CGSize(width: 1.0, height: 0.0)
        redo.layer.shadowOpacity = 0.15
        redo.layer.shadowRadius = 1.0
        redo.isHidden = true
        redo.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [undo, redo])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        topToolbar.addSubview(stack)

        // Find the cancel button in the toolbar to position after it
        let cancelButton = topToolbar.subviews.first(where: {
            ($0 as? UIButton)?.actions(forTarget: self, forControlEvent: .touchUpInside)?
                .contains("cancelButtonTapped:") ?? false
        })

        if let cancelButton = cancelButton {
            // The xib pins the cancel button to `topToolbar.leading + 12`, and
            // `anchorTopToolbarHorizontallyToSafeArea()` shifts the entire toolbar
            // inside the notch / Stage Manager chrome in landscape and on iPad.
            // That means we can keep the xib constraint as-is — the cancel button
            // and the right button stack stay symmetric, inset equally from the
            // visible safe-area edges. Only the undo/redo stack needs explicit
            // positioning relative to the cancel button.
            NSLayoutConstraint.activate([
                stack.centerYAnchor.constraint(equalTo: topToolbar.centerYAnchor),
                stack.leadingAnchor.constraint(equalTo: cancelButton.trailingAnchor, constant: 12)
            ])
        } else {
            NSLayoutConstraint.activate([
                stack.centerYAnchor.constraint(equalTo: topToolbar.centerYAnchor),
                stack.leadingAnchor.constraint(equalTo: topToolbar.leadingAnchor, constant: 54)
            ])
        }

        undoButton = undo
        redoButton = redo
        undoRedoStack = stack
    }

    func saveSnapshot() {
        guard !hiddenControls.contains(.undoRedo) else { return }
        let snapshot = createSnapshot()
        editorUndoManager.pushUndo(snapshot)
        updateUndoRedoButtons()
    }

    /// Stage a snapshot for drawing — only committed if a stroke actually occurs.
    func savePendingDrawSnapshot() {
        guard !hiddenControls.contains(.undoRedo), pendingDrawSnapshot == nil else { return }
        pendingDrawSnapshot = createSnapshot()
    }

    /// Commit the pending draw snapshot to the undo stack (called after actual drawing).
    func commitPendingDrawSnapshot() {
        guard let snapshot = pendingDrawSnapshot else { return }
        pendingDrawSnapshot = nil
        editorUndoManager.pushUndo(snapshot)
        updateUndoRedoButtons()
    }

    /// Discard the pending draw snapshot if no drawing occurred.
    func discardPendingDrawSnapshot() {
        pendingDrawSnapshot = nil
    }

    private func createSnapshot() -> EditorSnapshot {
        var subviewSnapshots: [SubviewSnapshot] = []
        for subview in contentSubviews {
            let kind: SubviewSnapshot.Kind
            if let textView = subview as? UITextView,
               let font = textView.font,
               let color = textView.textColor {
                kind = .text(textView.text, color, font)
            } else if let imageView = subview as? UIImageView,
                      let img = imageView.image {
                kind = .image(img, imageView.contentMode)
            } else if let label = subview as? UILabel,
                      let text = label.text,
                      let font = label.font {
                kind = .label(text, label.textColor, font)
            } else {
                continue
            }
            subviewSnapshots.append(SubviewSnapshot(
                kind: kind,
                center: subview.center,
                transform: subview.transform,
                bounds: subview.bounds,
                tag: subview.tag
            ))
        }
        return EditorSnapshot(
            drawingImage: drawingOverlayView.image,
            baseImage: self.image,
            subviewSnapshots: subviewSnapshots
        )
    }

    private func restoreSnapshot(_ snapshot: EditorSnapshot, isRedo: Bool = false) {
        // Restore drawing layer
        drawingOverlayView.image = snapshot.drawingImage

        // Restore base image
        if let baseImage = snapshot.baseImage {
            self.image = baseImage
            setImageView(image: baseImage)
        }

        // Remove all content subviews (keep drawingOverlayView)
        for subview in contentSubviews {
            subview.removeFromSuperview()
        }

        // Recreate subviews
        for sub in snapshot.subviewSnapshots {
            let view: UIView
            switch sub.kind {
            case .image(let img, let contentMode):
                let iv = UIImageView(image: img)
                iv.contentMode = contentMode
                view = iv
            case .text(let text, let color, let font):
                let tv = UITextView(frame: .zero)
                tv.text = text
                tv.textColor = color
                tv.font = font
                tv.textAlignment = .center
                tv.layer.shadowColor = UIColor.black.cgColor
                tv.layer.shadowOffset = CGSize(width: 1.0, height: 0.0)
                tv.layer.shadowOpacity = 0.2
                tv.layer.shadowRadius = 1.0
                tv.layer.backgroundColor = UIColor.clear.cgColor
                tv.autocorrectionType = .no
                tv.isScrollEnabled = false
                tv.delegate = self
                view = tv
            case .label(let text, let color, let font):
                let lbl = UILabel(frame: .zero)
                lbl.text = text
                lbl.textColor = color
                lbl.font = font
                lbl.textAlignment = .center
                view = lbl
            }
            view.bounds = sub.bounds
            view.center = sub.center
            view.transform = sub.transform
            view.tag = sub.tag
            canvasImageView.addSubview(view)
            addGestures(view: view)
        }
        ensureDrawingOverlayOnTop()

        hasImageBeenModified = isRedo || editorUndoManager.canUndo
        updateUndoRedoButtons()
    }

    private func updateUndoRedoButtons() {
        let hasHistory = editorUndoManager.canUndo || editorUndoManager.canRedo

        // Undo: hidden when no history at all, visible+disabled when can't undo but redo exists
        undoButton?.isHidden = !hasHistory
        undoButton?.isEnabled = editorUndoManager.canUndo
        undoButton?.alpha = editorUndoManager.canUndo ? 1.0 : 0.4

        // Redo: completely hidden when nothing to redo
        redoButton?.isHidden = !editorUndoManager.canRedo

        updateActionButtons()
    }

    private func updateActionButtons() {
        let canAct = hasImageBeenModified || editorUndoManager.canUndo
        continueButton?.isEnabled = canAct
        continueButton?.alpha = canAct ? 1.0 : 0.3
        clearButton?.isEnabled = canAct
        clearButton?.alpha = canAct ? 1.0 : 0.3
    }

    @objc private func undoTapped() {
        // Don't undo mid-stroke
        guard lastPoint == nil && lineStartCanvasPoint == nil && shapeStartCanvasPoint == nil && !isInAIReview else { return }
        let current = createSnapshot()
        if let snapshot = editorUndoManager.undo(currentState: current) {
            restoreSnapshot(snapshot)
        }
    }

    @objc private func redoTapped() {
        guard lastPoint == nil && lineStartCanvasPoint == nil && shapeStartCanvasPoint == nil && !isInAIReview else { return }
        let current = createSnapshot()
        if let snapshot = editorUndoManager.redo(currentState: current) {
            restoreSnapshot(snapshot, isRedo: true)
        }
    }
}

extension PhotoEditorViewController: ColorDelegate {
    func didSelectColor(color: UIColor) {
        if isDrawing || isLineDrawing {
            self.drawColor = color
            saveDrawColor()
            if let cv = markerSizeCollectionView {
                markerSizeCollectionViewDelegate?.reloadWithColor(color, collectionView: cv)
            }
        } else if activeTextView != nil {
            activeTextView?.textColor = color
            textColor = color
            saveTextColor()
        }
    }
}

extension PhotoEditorViewController: MarkerSizeDelegate {
    func didSelectMarkerSize(width: CGFloat) {
        drawLineWidth = width
        UserDefaults.standard.set(Double(width), forKey: markerSizeKey)
    }
}





