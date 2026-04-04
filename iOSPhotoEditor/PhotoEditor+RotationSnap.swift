//
//  PhotoEditor+RotationSnap.swift
//  Photo Editor
//
//  Shared angle-snapping and transform extraction helpers.
//  Used by rotation gestures, corner handle drag, and line drawing.
//

import UIKit

extension PhotoEditorViewController {

    /// Cardinal snap angles in radians: 0, 90, 180, 270 degrees.
    static let cardinalAngles: [CGFloat] = [0, .pi / 2, .pi, -.pi / 2]

    /// 8-direction snap angles for line drawing (every 45 degrees).
    static let lineSnapAngles: [CGFloat] = [
        0, .pi / 4, .pi / 2, 3 * .pi / 4,
        .pi, -3 * .pi / 4, -.pi / 2, -.pi / 4
    ]

    /// Snap threshold: ±7 degrees in radians.
    static let snapThreshold: CGFloat = 7 * .pi / 180

    // MARK: - Angle Snapping

    /// Snap a raw angle to the nearest cardinal direction (0/90/180/270) if within threshold.
    /// Returns the snapped angle if within range, otherwise returns the raw angle.
    func snapAngle(_ rawAngle: CGFloat) -> CGFloat {
        let normalized = normalizeAngle(rawAngle)
        for cardinal in Self.cardinalAngles {
            let diff = abs(normalizeAngle(normalized - cardinal))
            if diff < Self.snapThreshold {
                let wasInSnap = isInRotationSnapZone
                isInRotationSnapZone = true
                if !wasInSnap {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
                return cardinal
            }
        }
        isInRotationSnapZone = false
        return normalized
    }

    /// Snap a line angle to the nearest of 8 directions if within threshold.
    func snapLineAngle(_ rawAngle: CGFloat) -> CGFloat {
        let normalized = normalizeAngle(rawAngle)
        for snapAngle in Self.lineSnapAngles {
            let diff = abs(normalizeAngle(normalized - snapAngle))
            if diff < Self.snapThreshold {
                return snapAngle
            }
        }
        return normalized
    }

    // MARK: - Normalize

    /// Normalize angle to [-pi, pi].
    func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var a = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if a > .pi { a -= 2 * .pi }
        if a < -.pi { a += 2 * .pi }
        return a
    }

    // MARK: - Transform Extraction

    /// Extract the current uniform scale from a view's transform.
    func currentScale(of view: UIView) -> CGFloat {
        let a = view.transform.a
        let c = view.transform.c
        return sqrt(a * a + c * c)
    }

    /// Extract the current rotation angle from a view's transform.
    func currentRotation(of view: UIView) -> CGFloat {
        return atan2(view.transform.b, view.transform.a)
    }
}
