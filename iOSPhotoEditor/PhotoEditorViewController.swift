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

    public weak var photoEditorDelegate: PhotoEditorDelegate?
    var colorsCollectionViewDelegate: ColorsCollectionViewDelegate!
    
    // list of controls to be hidden
    public var hiddenControls : [control] = []

    private static let cPostHighlight = UIColor(red:0.200, green:0.600, blue:0.800, alpha:0.800)
    
    var stickersVCIsVisible = false
    var drawColor: UIColor = cPostHighlight
    var textColor: UIColor = cPostHighlight
    var isDrawing: Bool = false
    var hasImageBeenModified: Bool = false
    
    // UserDefaults keys for color persistence
    private let drawColorKey = "PhotoEditor.DrawColor"
    private let textColorKey = "PhotoEditor.TextColor"
    var lastPoint: CGPoint!
    var swiped = false
    var lastPanPoint: CGPoint?
    var lastTextViewTransform: CGAffineTransform?
    var lastTextViewTransCenter: CGPoint?
    var lastTextViewFont:UIFont?
    var activeTextView: UITextView?
    var imageViewToPan: UIImageView?
    var isTyping: Bool = false
    
    
    var stickersViewController: StickersViewController!

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
        stickersViewController?.stickersViewControllerDelegate = nil
        stickersViewController = nil
        colorsCollectionViewDelegate?.colorDelegate = nil
        colorsCollectionViewDelegate = nil
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
        
        
        configureCollectionView()
        stickersViewController = StickersViewController(nibName: "StickersViewController", bundle: Bundle.module)
        hideControls()
        loadSavedColors()
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
        colorPickerTopConstraint.constant = safeAreaTop > 0 ? safeAreaTop + 6 : 6
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
}

extension PhotoEditorViewController: ColorDelegate {
    func didSelectColor(color: UIColor) {
        if isDrawing {
            self.drawColor = color
            saveDrawColor()
        } else if activeTextView != nil {
            activeTextView?.textColor = color
            textColor = color
            saveTextColor()
        }
    }
}





