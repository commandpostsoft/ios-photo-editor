// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iOSPhotoEditor",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "iOSPhotoEditor",
            targets: ["iOSPhotoEditor"]
        ),
    ],
    dependencies: [
        // No external dependencies - self-contained library
    ],
    targets: [
        .target(
            name: "iOSPhotoEditor",
            dependencies: [],
            path: "iOSPhotoEditor",
            exclude: [
                // Exclude app-specific files that shouldn't be part of the library
                "LaunchScreen.storyboard",
                "Assets.xcassets"
            ],
            resources: [
                // Include all XIB files for UI components
                .process("PhotoEditorViewController.xib"),
                .process("StickersViewController.xib"),
                .process("ColorCollectionViewCell.xib"),
                .process("EmojiCollectionViewCell.xib"),
                .process("StickerCollectionViewCell.xib"),

                // Include icon font
                .process("icomoon.ttf"),

                // Include crop editor border images
                .process("PhotoCropEditorBorder.png"),
                .process("PhotoCropEditorBorder@2x.png"),
                .process("PhotoCropEditorBorder@3x.png")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)