//
//  EditorUndoManager.swift
//  iOSPhotoEditor
//

import UIKit

struct SubviewSnapshot {
    enum Kind {
        case image(UIImage, UIView.ContentMode)
        case text(String, UIColor, UIFont)
        case label(String, UIColor, UIFont)
    }
    let kind: Kind
    let center: CGPoint
    let transform: CGAffineTransform
    let bounds: CGRect
    let tag: Int
}

struct EditorSnapshot {
    let drawingImage: UIImage?
    let baseImage: UIImage?
    let subviewSnapshots: [SubviewSnapshot]
}

/// Undo stack entry. `.snapshot` is the heavyweight bitmap-capturing path;
/// `.rotate` is a lossless delta that avoids retaining the pre-rotation base image.
enum EditorUndoEntry {
    case snapshot(EditorSnapshot)
    /// Applying this entry rotates the current base image by `delta` radians,
    /// restores `drawingImage` as the drawing overlay bitmap verbatim (no
    /// re-rotation, avoiding cumulative resample drift), and installs
    /// `subviewSnapshots` as the content layer.
    case rotate(delta: CGFloat, drawingImage: UIImage?, subviewSnapshots: [SubviewSnapshot])
}

class EditorUndoManager {
    private(set) var undoStack: [EditorUndoEntry] = []
    private(set) var redoStack: [EditorUndoEntry] = []
    var maxUndoLevels: Int = 5

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func pushUndo(_ entry: EditorUndoEntry) {
        undoStack.append(entry)
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    /// Atomically pop an undo entry and push its reverse to the redo stack.
    /// The `reverse` closure receives the popped entry and returns the entry
    /// that, when applied, returns the editor to its current (pre-apply) state.
    /// Ensures stacks cannot diverge if the caller forgets a push.
    func applyUndo(reverse: (EditorUndoEntry) -> EditorUndoEntry) -> EditorUndoEntry? {
        guard let entry = undoStack.popLast() else { return nil }
        redoStack.append(reverse(entry))
        return entry
    }

    /// Atomically pop a redo entry and push its reverse back to the undo stack.
    /// Does not clear the redo stack (preserves in-progress redo history
    /// relative to other redo operations).
    func applyRedo(reverse: (EditorUndoEntry) -> EditorUndoEntry) -> EditorUndoEntry? {
        guard let entry = redoStack.popLast() else { return nil }
        undoStack.append(reverse(entry))
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
        return entry
    }

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
