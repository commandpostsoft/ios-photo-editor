# iOS Photo Editor

A powerful and easy-to-use photo editor for iOS, built with Swift and Swift Package Manager.

## Features
- [x] **Cropping** - Crop images with gesture-based interface
- [x] **Stickers** - Add custom stickers and emojis
- [x] **Text Overlay** - Add text with customizable colors
- [x] **Drawing** - Freehand draw on images with multiple colors
- [x] **Line Tool** - Draw straight lines with live preview
- [x] **Transformations** - Scale, rotate, and position objects
- [x] **Pan & Zoom** - Two-finger pinch-to-zoom and pan to navigate the canvas
- [x] **Delete Objects** - Remove unwanted elements
- [x] **Export & Share** - Save to Photos and share
- [x] **Animations** - Smooth, delightful animations
- [x] **Haptic Feedback** - iOS Taptic Engine integration
- [x] **High Resolution Export** - Maintains original image quality
- [x] **Undo/Redo** - Undo and redo editing actions with configurable history depth
- [x] **Headless API** - Stamp text/images, crop, rotate, flip, resize, and preserve EXIF metadata — all without any UI

## Requirements

- iOS 15.0+
- Swift 5.5+
- Xcode 13.0+

## Installation

### Swift Package Manager

**In Xcode:**
1. Go to **File > Add Package Dependencies**
2. Enter the repository URL: `https://github.com/M-Hamed/photo-editor.git`
3. Select the version you want to use

**In Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/M-Hamed/photo-editor.git", from: "2.0.0")
]
```

> **Note:** This package is SPM-only. CocoaPods support has been removed.

## Usage

### Basic Implementation

```swift
import iOSPhotoEditor

// Create the photo editor
let photoEditor = PhotoEditorViewController()

// Set the delegate to receive callbacks
photoEditor.photoEditorDelegate = self

// Set the image to be edited
photoEditor.image = yourUIImage

// Optional: Add custom stickers
photoEditor.stickers = [
    UIImage(named: "sticker1")!,
    UIImage(named: "sticker2")!
]

// Optional: Hide specific controls (e.g. hide emojis when using custom stickers only)
photoEditor.hiddenControls = [.save, .share, .emoji]

// Optional: Customize drawing and text colors
photoEditor.colors = [.red, .blue, .green, .yellow, .white, .black]

// Optional: Set drawing line thickness (default is 5.0)
photoEditor.drawLineWidth = 8.0

// Optional: Customize marker sizes (picker shown by default)
photoEditor.markerSizes = [5, 8, 12, 18]

// Optional: Disable undo/redo or marker size picker
// photoEditor.hiddenControls.append(.undoRedo)
// photoEditor.hiddenControls.append(.markerSize)

// Optional: Allow more undo steps (default is 5)
// photoEditor.maxUndoLevels = 10

// Present the editor
photoEditor.modalPresentationStyle = .fullScreen
present(photoEditor, animated: true)
```

### Implementing the Delegate

```swift
extension YourViewController: PhotoEditorDelegate {
    func doneEditing(image: UIImage) async throws {
        // Handle the edited image
        imageView.image = image
        dismiss(animated: true)
    }

    func canceledEditing() {
        // Handle cancellation
        dismiss(animated: true)
    }
}
```

### Available Controls

You can hide specific controls using the `hiddenControls` property:

```swift
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
```

### Customization Options

| Property | Type | Description |
|----------|------|-------------|
| `image` | `UIImage?` | The image to be edited |
| `stickers` | `[UIImage]` | Custom stickers for the user to choose from |
| `colors` | `[UIColor]` | Colors available for drawing and text |
| `hiddenControls` | `[control]` | Controls to hide from the toolbar |
| `drawLineWidth` | `CGFloat` | Drawing line thickness (default: `5.0`) |
| `markerSizes` | `[CGFloat]` | Marker sizes for the picker (default: `[5, 8, 12, 18]`). Min value: 1, max 4 entries. Hidden via `.markerSize` in `hiddenControls`. |
| `maxUndoLevels` | `Int` | Number of undo steps to keep (default: `5`). Higher values use more memory. Hidden via `.undoRedo` in `hiddenControls`. |

### Pan & Zoom

The editor supports two-finger pinch-to-zoom (up to 5x) and two-finger pan for navigating large images. A toggle button in the bottom toolbar switches between **Pan/Zoom mode** and **Grab mode** (for moving stickers and text).

- **Pan/Zoom mode** (arrows icon): pinch and pan to navigate the canvas. Drawing/text interaction is disabled.
- **Grab mode** (hand icon): interact with stickers, text, and line elements. Zoom gestures are disabled.
- **Reset zoom** (inward arrows icon): appears when zoomed in. Tap to reset to 1x.

When you crop while zoomed in, the crop view is pre-set to the visible region.

### Line Drawing

The line tool draws perfectly straight lines between two points:

1. Tap the **line** button in the toolbar to enter line drawing mode.
2. Touch and drag to preview the line in real time.
3. Release to commit the line as a movable, scalable, rotatable element.

Lines are rendered as subviews with gesture recognizers, so they can be repositioned, resized, or deleted just like stickers and text.

### Undo/Redo

Undo and redo is enabled by default. It captures a snapshot of the editor state before each action (drawing a stroke, adding text or stickers, cropping, rotating, clearing, or deleting an element). Tapping undo restores the previous snapshot; tapping redo re-applies it.

- The number of undo levels defaults to **5** and is configurable via `maxUndoLevels`.
- Each snapshot stores the drawing layer, base image, and all text/sticker subview state, so higher values will increase memory usage.
- Add `.undoRedo` to `hiddenControls` to disable the feature entirely (no snapshots are captured and no buttons are shown).

---

## Headless API

Three headless utilities let you process images programmatically without presenting any UI. All types are public and available via `import iOSPhotoEditor`.

### ImageStamper

Stamps text and images onto a photo.

```swift
let result = ImageStamper.stamp([
    .text("Hello World",
          position: .topLeft(inset: .fractionOfMinDimension(0.03)),
          style: StampTextStyle(fontSize: .fractionOfMinDimension(0.05))),
    .image(logo,
           position: .bottomRight(inset: .fractionOfMinDimension(0.03)),
           size: .relativeWidth(0.15)),
], onto: photo)
```

#### Relative Sizing with `StampDimension`

All insets, font sizes, and stroke widths accept a `StampDimension` value:

| Case | Description |
|------|-------------|
| `.points(CGFloat)` | Absolute points (also the default for integer/float literals) |
| `.fractionOfWidth(CGFloat)` | Fraction of the image width |
| `.fractionOfHeight(CGFloat)` | Fraction of the image height |
| `.fractionOfMinDimension(CGFloat)` | Fraction of `min(width, height)` — best for consistent sizing across landscape/portrait |

Integer and float literals are treated as `.points`, so existing call sites like `.topLeft(inset: 20)` continue to compile.

#### Image Overlay Sizing with `StampImageSize`

| Case | Description |
|------|-------------|
| `.absolute(CGSize)` | Fixed pixel size |
| `.relativeWidth(CGFloat)` | Width as fraction of base image width; height from aspect ratio |
| `.relativeHeight(CGFloat)` | Height as fraction of base image height; width from aspect ratio |
| `.relativeToMinDimension(CGFloat)` | Longest side as fraction of `min(baseWidth, baseHeight)` |

### ImageProcessor

Crop, rotate, flip, and resize without any UI.

```swift
// Crop to a specific region
let cropped = ImageProcessor.crop(photo, to: CGRect(x: 100, y: 100, width: 500, height: 500))

// Center-crop to 16:9
let widescreen = ImageProcessor.crop(photo, aspectRatio: 16.0 / 9.0)

// Rotate 90 degrees clockwise
let rotated = ImageProcessor.rotate(photo, degrees: 90)

// Flip horizontally
let mirrored = ImageProcessor.flipHorizontal(photo)

// Resize to fit within bounds (aspect-fit)
let thumbnail = ImageProcessor.resize(photo, to: CGSize(width: 200, height: 200), contentMode: .aspectFit)

// Resize to fill bounds (crops edges)
let square = ImageProcessor.resize(photo, to: CGSize(width: 400, height: 400), contentMode: .aspectFill)
```

### ImageMetadata

Extract and re-embed EXIF, GPS, TIFF, and IPTC metadata. Operates at the `Data` level for round-trip preservation.

```swift
// Extract all metadata properties
if let properties = ImageMetadata.extractProperties(from: originalJPEGData) {
    print(properties)
}

// Re-embed metadata from the original capture into an edited image
if let outputData = ImageMetadata.applyingMetadata(
    from: originalJPEGData,
    to: editedUIImage,
    compressionQuality: 0.92
) {
    try outputData.write(to: outputURL)
}
```

The orientation tag is automatically stripped (since `UIImage` is already correctly oriented), but GPS, EXIF, TIFF, and IPTC dictionaries are preserved.

### Camera Workflow Example

End-to-end: capture, stamp, crop, re-embed EXIF, save.

```swift
func processCapture(jpegData: Data, image: UIImage) throws {
    // 1. Stamp a watermark and date
    let stamped = ImageStamper.stamp([
        .text(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short),
              position: .bottomLeft(inset: .fractionOfMinDimension(0.02)),
              style: StampTextStyle(
                  fontSize: .fractionOfMinDimension(0.03),
                  color: .white,
                  shadow: .default)),
        .image(watermarkLogo,
               position: .bottomRight(inset: .fractionOfMinDimension(0.02)),
               size: .relativeToMinDimension(0.08)),
    ], onto: image)

    // 2. Crop to 4:3
    let cropped = ImageProcessor.crop(stamped, aspectRatio: 4.0 / 3.0)

    // 3. Re-embed original EXIF metadata
    guard let outputData = ImageMetadata.applyingMetadata(
        from: jpegData, to: cropped
    ) else { return }

    // 4. Save
    try outputData.write(to: outputURL)
}
```

---

## Architecture

This package uses:
- **Swift Package Manager** for dependency management
- **XIB files** for UI layout
- **Programmatic UI** for collection view cells
- **Gesture recognizers** for intuitive interactions
- **High-resolution rendering** for quality export

## Migration from CocoaPods

If you were using the CocoaPods version, here are the key changes:

1. **Installation**: Use Swift Package Manager instead of CocoaPods
2. **Initialization**: Simplified to `PhotoEditorViewController()` (no need to specify nibName/bundle)
3. **Delegate**: The `doneEditing` method is now `async throws`
4. **Module Name**: Import as `import iOSPhotoEditor`

## Known Issues

- This package requires iOS 15.0+ (up from iOS 10.0 in the CocoaPods version)
- Some collection view cells are now programmatic instead of XIB-based for better SPM compatibility

<img src="Assets/screenshot.PNG" width="350" height="600" />

# Live Demo appetize.io
[![Demo](Assets/appetize.png)](https://appetize.io/app/jtanmwtzbz1favhvhw5g24n7b0?device=iphone7plus&scale=50&orientation=portrait&osVersion=10.3)


# Demo Video
[![Demo](https://img.youtube.com/vi/9VeIl9i30dI/0.jpg)](https://youtu.be/9VeIl9i30dI)

## Credits

Written by [Mohamed Hamed](https://github.com/M-Hamed).

Initially sponsored by [![Eventtus](http://assets.eventtus.com/logos/eventtus/standard.png)](http://eventtus.com)

## License

Released under the [MIT License](http://www.opensource.org/licenses/MIT).
