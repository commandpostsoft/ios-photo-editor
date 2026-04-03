//
//  ViewController.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 4/23/17.
//  Copyright © 2017 Mohamed Hamed. All rights reserved.
//

import UIKit

public final class PhotoEditorViewController: UIViewController {
    
    /** holding the 2 imageViews original image and drawing & stickers */
    @IBOutlet weak var canvasView: UIView!
    //To hold the image
    @IBOutlet var imageView: UIImageView!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    //To hold the drawings and stickers
    @IBOutlet weak var canvasImageView: UIImageView!

    @IBOutlet weak var topToolbar: UIView!
    @IBOutlet weak var bottomToolbar: UIView!

    @IBOutlet weak var topGradient: UIView!
    @IBOutlet weak var bottomGradient: UIView!
    
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var colorsCollectionView: UICollectionView!
    @IBOutlet weak var colorPickerView: UIView!
    @IBOutlet weak var colorPickerViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var topToolbarTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var topGradientTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var colorPickerTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var doneButtonTopConstraint: NSLayoutConstraint!
    
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
    public var drawLineWidth: CGFloat = 5.0

    /**
     Whether to show undo/redo buttons. Default is true.
     When true, undo/redo buttons appear at the top-left of the screen.
     Use `maxUndoLevels` to configure how many undo steps are kept.
     */
    public var showUndoRedo: Bool = true

    /**
     Maximum number of undo levels to keep. Default is 5.
     Higher values use more memory since each level stores a full editor snapshot.
     */
    public var maxUndoLevels: Int = 5

    /**
     Whether to show the marker size picker in drawing mode. Default is true.
     When true and `markerSizes` is non-empty, a row of circles appears below the color picker.
     */
    public var showMarkerSizePicker: Bool = true

    /**
     Array of marker sizes for the marker size picker.
     Up to 4 values, minimum value 1. The second size is auto-selected by default.
     Default: [5, 8, 12, 18]
     */
    public var markerSizes: [CGFloat] = [5, 8, 12, 18]

    public weak var photoEditorDelegate: PhotoEditorDelegate?
    var colorsCollectionViewDelegate: ColorsCollectionViewDelegate!
    
    // list of controls to be hidden
    public var hiddenControls : [control] = []

    private static let cPostHighlight = UIColor(red:0.200, green:0.600, blue:0.800, alpha:0.800)
    
    var stickersVCIsVisible = false
    var drawColor: UIColor = cPostHighlight
    var textColor: UIColor = cPostHighlight
    var isDrawing: Bool = false
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
    var lastTextViewTransform: CGAffineTransform?
    var lastTextViewTransCenter: CGPoint?
    var lastTextViewFont:UIFont?
    var activeTextView: UITextView?
    var imageViewToPan: UIImageView?
    var isTyping: Bool = false
    
    
    var markerSizeCollectionView: UICollectionView?
    var markerSizeCollectionViewDelegate: MarkerSizeCollectionViewDelegate?
    var stickersViewController: StickersViewController!

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
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        
        setupIconFonts()
        
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
        hideControls()
        setupDrawButtonLongPress()
        setupUndoRedoButtons()
        updateActionButtons()
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Adjust top spacing based on safe area
        adjustTopSpacingForSafeArea()
        
        // Use full screen bounds for simpler sizing
        let currentScreenBounds = view.bounds.size
        
        // Set image after views are laid out to get correct bounds
        if imageView.image == nil && image != nil {
            self.setImageView(image: image!)
            previousCanvasBounds = currentScreenBounds
        } else if previousCanvasBounds != CGSize.zero && currentScreenBounds != previousCanvasBounds {
            // Screen size changed, rescale everything
            rescaleCanvas(from: previousCanvasBounds, to: currentScreenBounds)
            previousCanvasBounds = currentScreenBounds
        }
    }
    
    private func adjustTopSpacingForSafeArea() {
        let safeAreaTop = view.safeAreaInsets.top
        
        // Adjust constraints based on safe area - use minimal spacing when no safe area needed
        topToolbarTopConstraint.constant = safeAreaTop > 0 ? safeAreaTop : 0
        topGradientTopConstraint.constant = safeAreaTop > 0 ? safeAreaTop : 0
        colorPickerTopConstraint.constant = safeAreaTop > 0 ? safeAreaTop + 66 : 66
        doneButtonTopConstraint.constant = safeAreaTop > 0 ? safeAreaTop + 11 : 11
    }
    
    private func setupIconFonts() {
        let icomoonFont = UIFont(name: "icomoon", size: 25)
        let icomoonFontLarge = UIFont(name: "icomoon", size: 50)
        
        // Top toolbar buttons
        cropButton?.setTitle("\u{E90A}", for: .normal)
        cropButton?.titleLabel?.font = icomoonFont
        
        stickerButton?.setTitle("\u{E906}", for: .normal)
        stickerButton?.titleLabel?.font = icomoonFont
        
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
    
    func configureCollectionView() {
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 30, height: 30)
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        colorsCollectionView.collectionViewLayout = layout
        colorsCollectionViewDelegate = ColorsCollectionViewDelegate()
        colorsCollectionViewDelegate.colorDelegate = self
        if !colors.isEmpty {
            colorsCollectionViewDelegate.colors = colors
        }
        colorsCollectionView.delegate = colorsCollectionViewDelegate
        colorsCollectionView.dataSource = colorsCollectionViewDelegate

        colorsCollectionView.register(
            ColorCollectionViewCell.self,
            forCellWithReuseIdentifier: "ColorCollectionViewCell")
    }
    
    private func setupMarkerSizePicker() {
        guard showMarkerSizePicker else { return }
        // Filter out invalid values, enforce minimum of 1, and limit to 4
        let sanitized = markerSizes.filter { $0.isFinite && $0 > 0 }.map { max($0, 1) }.sorted().prefix(4)
        let sizes = Array(sanitized)
        guard !sizes.isEmpty else { return }

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
        displayImageSize = image.suitableSizeWithinBounds(screenBounds)
        
        // Calculate scale factor from display to current image size
        displayToOriginalScale = image.size.width / displayImageSize.width
        
        // Set the image view constraints
        imageViewHeightConstraint.constant = displayImageSize.height
        
        // Force layout update
        view.layoutIfNeeded()
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
        canvasImageView.isUserInteractionEnabled = true
        colorPickerView.isHidden = true
        markerSizeCollectionView?.isHidden = true
        showDrawButtonHighlight(false)
    }

    private let drawHighlightTag = 9999

    func showDrawButtonHighlight(_ show: Bool) {
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

    private func setupDrawButtonLongPress() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(drawButtonLongPressed(_:)))
        drawButton.addGestureRecognizer(longPress)
    }

    @objc private func drawButtonLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, isDrawing else { return }
        pickerHiddenWhileDrawing.toggle()
        colorPickerView.isHidden = pickerHiddenWhileDrawing
        markerSizeCollectionView?.isHidden = pickerHiddenWhileDrawing
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
        
        // Get the drawing layer from canvasImageView and scale it up
        if let drawingImage = canvasImageView.image {
            // The drawing layer is already at display resolution, scale it to original
            let scaledDrawingRect = CGRect(origin: .zero, size: originalSize)
            drawingImage.draw(in: scaledDrawingRect)
        }
        
        // Render text views and stickers at high resolution
        let imageRect = getImageBoundsInCanvas()
        
        for subview in canvasImageView.subviews {
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
            context.translateBy(x: -subview.bounds.width/2, y: -subview.bounds.height/2)
            
            // Apply the subview's transform
            context.concatenate(subview.transform)
            
            // Render the subview
            subview.layer.render(in: context)
            
            context.restoreGState()
        }
        
        guard let finalImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return canvasView.toImage()
        }
        
        return finalImage
    }
    
    // MARK: - Canvas Rescaling
    private func rescaleCanvas(from oldBounds: CGSize, to newBounds: CGSize) {
        guard let currentImage = self.image else { return }
        
        // Calculate new display size for the image
        let newDisplaySize = currentImage.suitableSizeWithinBounds(newBounds)
        
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
        if let drawingImage = canvasImageView.image {
            let scaledDrawing = rescaleDrawingImage(drawingImage, scaleX: scaleX, scaleY: scaleY)
            canvasImageView.image = scaledDrawing
        }
        
        // Rescale all subviews (text, stickers)
        for subview in canvasImageView.subviews {
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

        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: newSize))

        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }

    // MARK: - Undo/Redo

    private func setupUndoRedoButtons() {
        guard showUndoRedo else { return }
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
        guard showUndoRedo else { return }
        let snapshot = createSnapshot()
        editorUndoManager.pushUndo(snapshot)
        updateUndoRedoButtons()
    }

    private func createSnapshot() -> EditorSnapshot {
        var subviewSnapshots: [SubviewSnapshot] = []
        for subview in canvasImageView.subviews {
            let kind: SubviewSnapshot.Kind
            if let textView = subview as? UITextView,
               let font = textView.font,
               let color = textView.textColor {
                kind = .text(textView.text, color, font)
            } else if let imageView = subview as? UIImageView,
                      let img = imageView.image {
                kind = .image(img)
            } else {
                continue
            }
            subviewSnapshots.append(SubviewSnapshot(
                kind: kind,
                center: subview.center,
                transform: subview.transform,
                bounds: subview.bounds
            ))
        }
        return EditorSnapshot(
            drawingImage: canvasImageView.image,
            baseImage: self.image,
            subviewSnapshots: subviewSnapshots
        )
    }

    private func restoreSnapshot(_ snapshot: EditorSnapshot, isRedo: Bool = false) {
        // Restore drawing layer
        canvasImageView.image = snapshot.drawingImage

        // Restore base image
        if let baseImage = snapshot.baseImage {
            self.image = baseImage
            setImageView(image: baseImage)
        }

        // Remove all subviews
        for subview in canvasImageView.subviews {
            subview.removeFromSuperview()
        }

        // Recreate subviews
        for sub in snapshot.subviewSnapshots {
            let view: UIView
            switch sub.kind {
            case .image(let img):
                let iv = UIImageView(image: img)
                iv.contentMode = .scaleAspectFit
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
            }
            view.bounds = sub.bounds
            view.center = sub.center
            view.transform = sub.transform
            canvasImageView.addSubview(view)
            addGestures(view: view)
        }

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
        let current = createSnapshot()
        if let snapshot = editorUndoManager.undo(currentState: current) {
            restoreSnapshot(snapshot)
        }
    }

    @objc private func redoTapped() {
        let current = createSnapshot()
        if let snapshot = editorUndoManager.redo(currentState: current) {
            restoreSnapshot(snapshot, isRedo: true)
        }
    }
}

extension PhotoEditorViewController: ColorDelegate {
    func didSelectColor(color: UIColor) {
        if isDrawing {
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





