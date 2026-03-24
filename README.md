# iOS Photo Editor

A powerful and easy-to-use photo editor for iOS, built with Swift and Swift Package Manager.

## Features
- [x] **Cropping** - Crop images with gesture-based interface
- [x] **Stickers** - Add custom stickers and emojis
- [x] **Text Overlay** - Add text with customizable colors
- [x] **Drawing** - Draw on images with multiple colors
- [x] **Transformations** - Scale, rotate, and position objects
- [x] **Delete Objects** - Remove unwanted elements
- [x] **Export & Share** - Save to Photos and share
- [x] **Animations** - Smooth, delightful animations
- [x] **Haptic Feedback** - iOS Taptic Engine integration
- [x] **High Resolution Export** - Maintains original image quality

## Requirements

- iOS 13.0+
- Swift 5.5+
- Xcode 13.0+

## Installation

### Swift Package Manager

**In Xcode:**
1. Go to **File → Add Package Dependencies**
2. Enter the repository URL: `https://github.com/M-Hamed/photo-editor.git`
3. Select the version you want to use

**In Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/M-Hamed/photo-editor.git", from: "1.0.0")
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

// Optional: Hide specific controls
photoEditor.hiddenControls = [.save, .share]

// Optional: Customize drawing and text colors
photoEditor.colors = [.red, .blue, .green, .yellow, .white, .black]

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
    case text
    case save
    case share
    case clear
}
```

### Customization Options

| Property | Type | Description |
|----------|------|-------------|
| `image` | `UIImage?` | The image to be edited |
| `stickers` | `[UIImage]` | Custom stickers for the user to choose from |
| `colors` | `[UIColor]` | Colors available for drawing and text |
| `hiddenControls` | `[control]` | Controls to hide from the toolbar |

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

- This package requires iOS 13.0+ (up from iOS 10.0 in the CocoaPods version)
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
