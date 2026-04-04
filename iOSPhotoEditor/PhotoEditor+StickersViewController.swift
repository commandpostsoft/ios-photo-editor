//
//  PhotoEditor+StickersViewController.swift
//  Pods
//
//  Created by Mohamed Hamed on 6/16/17.
//
//

import Foundation
import UIKit

extension PhotoEditorViewController {
    
    func addStickersViewController() {
        stickersVCIsVisible = true
        hideToolbar(hide: true)
        modeBeforeActiveOperation = isPanZoomMode
        disableZoomGestures()
        self.canvasImageView.isUserInteractionEnabled = false
        stickersViewController.stickersViewControllerDelegate = self
        stickersViewController.hideEmojis = hiddenControls.contains(.emoji)

        for image in self.stickers {
            stickersViewController.stickers.append(image)
        }
        self.addChild(stickersViewController)
        self.view.addSubview(stickersViewController.view)
        stickersViewController.didMove(toParent: self)
        let height = view.frame.height
        let width  = view.frame.width
        stickersViewController.view.frame = CGRect(x: 0, y: self.view.frame.maxY , width: width, height: height)
    }
    
    func removeStickersView() {
        stickersVCIsVisible = false
        restorePreviousMode()
        UIView.animate(withDuration: 0.3,
                       delay: 0,
                       options: UIView.AnimationOptions.curveEaseIn,
                       animations: { [weak self] () -> Void in
                        guard let self = self else { return }
                        var frame = self.stickersViewController.view.frame
                        frame.origin.y = UIScreen.main.bounds.maxY
                        self.stickersViewController.view.frame = frame

        }, completion: { [weak self] (finished) -> Void in
            self?.stickersViewController.view.removeFromSuperview()
            self?.stickersViewController.removeFromParent()
            self?.hideToolbar(hide: false)
        })
    }    
}

extension PhotoEditorViewController: StickersViewControllerDelegate {
    
    func didSelectView(view: UIView) {
        self.removeStickersView()
        saveSnapshot()

        view.center = canvasImageView.center
        self.canvasImageView.addSubview(view)
        //Gestures
        addGestures(view: view)
        hasImageBeenModified = true
        autoSwitchAfterContentPlacement()
    }
    
    func didSelectImage(image: UIImage) {
        self.removeStickersView()
        saveSnapshot()

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame.size = CGSize(width: 150, height: 150)
        imageView.center = canvasImageView.center

        self.canvasImageView.addSubview(imageView)
        //Gestures
        addGestures(view: imageView)
        hasImageBeenModified = true
        autoSwitchAfterContentPlacement()
    }
    
    func stickersViewDidDisappear() {
        // Only restore if removeStickersView hasn't already handled it
        guard stickersVCIsVisible else { return }
        stickersVCIsVisible = false
        hideToolbar(hide: false)
        restorePreviousMode()
    }
    
    func addGestures(view: UIView) {
        //Gestures
        view.isUserInteractionEnabled = true
        
        let panGesture = UIPanGestureRecognizer(target: self,
                                                action: #selector(PhotoEditorViewController.panGesture))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self,
                                                    action: #selector(PhotoEditorViewController.pinchGesture))
        pinchGesture.delegate = self
        view.addGestureRecognizer(pinchGesture)
        
        let rotationGestureRecognizer = UIRotationGestureRecognizer(target: self,
                                                                    action:#selector(PhotoEditorViewController.rotationGesture) )
        rotationGestureRecognizer.delegate = self
        view.addGestureRecognizer(rotationGestureRecognizer)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(PhotoEditorViewController.tapGesture))
        view.addGestureRecognizer(tapGesture)
        
    }
}
