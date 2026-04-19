//
//  ViewController.swift
//  Example — iOSPhotoEditor
//
//  Demonstrates PhotoEditorViewController with all host-configurable features
//  wired up: stickers, shapes, AI annotations (stub provider), named stickers,
//  review flow, and the AI delegate.
//

import UIKit
import iOSPhotoEditor

class ViewController: UIViewController {

    // PhotoEditorViewController.aiProvider is declared `weak` — the editor
    // does not own the provider. Host must retain it strongly.
    //
    // Swap for a real backend when you're ready:
    //
    //   // On-device, iOS 26+, no API key needed:
    //   private let aiProvider: PhotoEditorAIProvider = {
    //       if #available(iOS 26, *) { return FoundationModelsProvider() }
    //       return StubAIProvider()
    //   }()
    //
    //   // Remote Claude — set your Anthropic key:
    //   private let aiProvider = ClaudeAIProvider(apiKey: "sk-ant-...")
    //
    // See AIProviders.swift for the reference implementations.
    private let aiProvider = StubAIProvider()

    @IBOutlet weak var imageView: UIImageView!

    // MARK: - Entry points

    @IBAction func pickImageButtonTapped(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true)
    }

    // MARK: - Editor configuration

    private func presentEditor(with image: UIImage) {
        let photoEditor = PhotoEditorViewController()
        photoEditor.image = image
        photoEditor.photoEditorDelegate = self

        // Bundled emoji-style stickers (UIImages named "0"..."10" in the asset catalog)
        // picked up by the sticker bottom sheet.
        for i in 0...10 {
            if let s = UIImage(named: i.description) { photoEditor.stickers.append(s) }
        }

        // Enable the shapes toolbar button. Long-press the button cycles through
        // the listed kinds (`.box` → `.ellipse` → `.arrow` → back to `.box`).
        photoEditor.availableShapes = [.box, .ellipse, .arrow]

        // AI integration —
        //   - aiProvider is weak, so the host MUST retain the provider (see the
        //     `aiProvider` property above).
        //   - namedStickers is the catalog the AI can place via `.sticker(id:…)`.
        //     Each sticker has an id (quoted back by the provider) and a name
        //     (shown to the AI so it knows what each sticker represents).
        //   - aiContext is free-form key/value metadata forwarded to the
        //     provider on every request.
        //   - aiReviewBeforeCommit gates AI output behind an Accept/Decline/
        //     Revise toolbar; set to false for instant commit.
        photoEditor.aiProvider = aiProvider
        photoEditor.aiDelegate = self
        photoEditor.aiAllowedTools = Set(PhotoEditorAITool.allCases)
        photoEditor.namedStickers = [
            PhotoEditorSticker(id: "s0", name: "Checkmark", image: UIImage(named: "0")!),
            PhotoEditorSticker(id: "s1", name: "Warning",   image: UIImage(named: "1")!),
        ]
        var context: [String: String] = [
            "projectName": "Demo Project",
            "datetime":    ISO8601DateFormatter().string(from: Date()),
        ]

        // Optional: pull EXIF (capture date, GPS) from the raw image data.
        // Hosts that receive a UIImage from a photo picker can request the
        // underlying PHAsset or file URL and pass that Data here. We use the
        // bundled sample image as a stand-in.
        if let path = Bundle.main.path(forResource: "img", ofType: "jpg"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            // Host-set keys take precedence on collision.
            context.merge(ImageMetadata.summarize(from: data)) { host, _ in host }
        }
        photoEditor.aiContext = context
        photoEditor.aiReviewBeforeCommit = true

        // Preset prompts — shown in an action sheet when the user taps the
        // sparkles button. Each preset's `instruction` is sent verbatim as
        // `request.prompt` when picked. `allowedTools` can narrow (never
        // widen) the editor's global `aiAllowedTools` per preset.
        photoEditor.aiPresetPrompts = [
            PhotoEditorAIPrompt(
                id: "describe-scene",
                name: "Describe Scene",
                description: "Label the main subjects visible in the photo",
                instruction: "Identify the 3–5 most prominent subjects in this image. " +
                             "For each, add a yellow box around the subject and a short " +
                             "text label above it with a descriptive name."
            ),
            PhotoEditorAIPrompt(
                id: "wildlife",
                name: "Label Wildlife",
                description: "Identify visible animals with common names",
                instruction: "For each animal visible, add a green ellipse around it and " +
                             "a text label with its common English name.",
                allowedTools: [.text, .ellipse]  // only text+ellipse for this preset
            ),
        ]
        // Let the user also type a custom instruction. Set to false to lock
        // users to the preset list; set to true with an empty preset list
        // to require a custom prompt on every AI call.
        photoEditor.aiAllowCustomPrompt = true

        // Appended to user-typed prompts (including Revise). Useful for
        // enforcing host-wide style rules without repeating them in the UI.
        photoEditor.aiCustomPromptSuffix =
            "Keep annotations concise. Place labels near but not over the subject."

        // Other optional customization —
        // photoEditor.hiddenControls = [.crop, .share]   // hide specific buttons
        // photoEditor.colors = [.red, .blue, .green]     // draw/text palette
        // photoEditor.aiMaxImageDimension = 1024         // smaller for cheaper AI calls

        photoEditor.modalPresentationStyle = .fullScreen
        present(photoEditor, animated: true)
    }
}

// MARK: - PhotoEditor delegates

extension ViewController: PhotoEditorDelegate {
    func doneEditing(image: UIImage) {
        imageView.image = image
    }

    func canceledEditing() {
        print("Editing canceled")
    }
}

extension ViewController: PhotoEditorAIDelegate {
    func photoEditor(_ editor: PhotoEditorViewController, aiAnnotationDidFail error: Error) {
        // In a real app: show a toast or alert. Here we just log.
        print("AI annotation failed: \(error)")
    }
}

// MARK: - Image picker

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        presentEditor(with: image)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

