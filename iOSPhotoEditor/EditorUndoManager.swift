//
//  EditorUndoManager.swift
//  iOSPhotoEditor
//

import UIKit

struct SubviewSnapshot {
    enum Kind {
        case image(UIImage)
        case text(String, UIColor, UIFont)
    }
    let kind: Kind
    let center: CGPoint
    let transform: CGAffineTransform
    let bounds: CGRect
}

struct EditorSnapshot {
    let drawingImage: UIImage?
    let baseImage: UIImage?
    let subviewSnapshots: [SubviewSnapshot]
}

class EditorUndoManager {
    private(set) var undoStack: [EditorSnapshot] = []
    private(set) var redoStack: [EditorSnapshot] = []
    var maxUndoLevels: Int = 5

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func pushUndo(_ snapshot: EditorSnapshot) {
        undoStack.append(snapshot)
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    func undo(currentState: EditorSnapshot) -> EditorSnapshot? {
        guard let snapshot = undoStack.popLast() else { return nil }
        redoStack.append(currentState)
        return snapshot
    }

    func redo(currentState: EditorSnapshot) -> EditorSnapshot? {
        guard let snapshot = redoStack.popLast() else { return nil }
        undoStack.append(currentState)
        return snapshot
    }

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
