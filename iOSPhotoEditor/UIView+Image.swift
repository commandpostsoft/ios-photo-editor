//
//  UIView+Image.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 4/23/17.
//  Copyright © 2017 Mohamed Hamed. All rights reserved.
//

import UIKit

extension UIView {
    /**
     Convert UIView to UIImage with proper scale handling
     */
    func toImage() -> UIImage {
        return autoreleasepool {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = UIScreen.main.scale
            format.opaque = self.isOpaque
            let renderer = UIGraphicsImageRenderer(size: self.bounds.size, format: format)
            let drawRect = CGRect(origin: .zero, size: self.bounds.size)
            return renderer.image { _ in
                self.drawHierarchy(in: drawRect, afterScreenUpdates: false)
            }
        }
    }
}
