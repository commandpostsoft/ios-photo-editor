//
//  StickersViewController.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 4/23/17.
//  Copyright © 2017 Mohamed Hamed. All rights reserved.
//  Credit https://github.com/AhmedElassuty/IOS-BottomSheet

import UIKit

@objc(StickersViewController)
class StickersViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var holdView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var pageControl: UIPageControl!
    
    var stickerCollectionView: UICollectionView?
    var emojiCollectionView: UICollectionView!
    
    var emojisDelegate: EmojisCollectionViewDelegate!
    
    var stickers : [UIImage] = []
    weak var stickersViewControllerDelegate : StickersViewControllerDelegate?
    
    let screenSize = UIScreen.main.bounds.size
    
    let fullView: CGFloat = 100 // remainder of screen height
    var partialView: CGFloat {
        return UIScreen.main.bounds.height - 380
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let hasStickers = !stickers.isEmpty
        configureCollectionViews(showStickers: hasStickers)

        if hasStickers {
            scrollView.contentSize = CGSize(width: 2.0 * screenSize.width,
                                            height: scrollView.frame.size.height)
            scrollView.isPagingEnabled = true
            scrollView.delegate = self
            pageControl.numberOfPages = 2
        } else {
            scrollView.contentSize = CGSize(width: screenSize.width,
                                            height: scrollView.frame.size.height)
            scrollView.isPagingEnabled = false
            pageControl.isHidden = true
        }

        holdView.layer.cornerRadius = 3
        let gesture = UIPanGestureRecognizer.init(target: self, action: #selector(StickersViewController.panGesture))
        gesture.delegate = self
        view.addGestureRecognizer(gesture)
    }
    
    func configureCollectionViews(showStickers: Bool) {

        if showStickers {
            let frame = CGRect(x: 0,
                               y: 0,
                               width: UIScreen.main.bounds.width,
                               height: view.frame.height - 40)

            let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
            layout.sectionInset = UIEdgeInsets(top: 20, left: 10, bottom: 10, right: 10)
            let width = (CGFloat) ((screenSize.width - 30) / 3.0)
            layout.itemSize = CGSize(width: width, height: 100)

            let cv = UICollectionView(frame: frame, collectionViewLayout: layout)
            cv.backgroundColor = .clear
            scrollView.addSubview(cv)
            cv.delegate = self
            cv.dataSource = self
            cv.register(
                UINib(nibName: "StickerCollectionViewCell", bundle: Bundle.module),
                forCellWithReuseIdentifier: "StickerCollectionViewCell")
            stickerCollectionView = cv
        }

        //-----------------------------------

        let emojisX: CGFloat = showStickers ? scrollView.frame.size.width : 0
        let emojisFrame = CGRect(x: emojisX,
                                 y: 0,
                                 width: UIScreen.main.bounds.width,
                                 height: view.frame.height - 40)
        
        let emojislayout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        emojislayout.sectionInset = UIEdgeInsets(top: 20, left: 10, bottom: 10, right: 10)
        emojislayout.itemSize = CGSize(width: 70, height: 70)
        
        emojiCollectionView = UICollectionView(frame: emojisFrame, collectionViewLayout: emojislayout)
        emojiCollectionView.backgroundColor = .clear
        scrollView.addSubview(emojiCollectionView)
        emojisDelegate = EmojisCollectionViewDelegate()
        emojisDelegate.stickersViewControllerDelegate = stickersViewControllerDelegate
        emojiCollectionView.delegate = emojisDelegate
        emojiCollectionView.dataSource = emojisDelegate
        
        emojiCollectionView.register(
            UINib(nibName: "EmojiCollectionViewCell", bundle: Bundle.module),
            forCellWithReuseIdentifier: "EmojiCollectionViewCell")
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepareBackgroundView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIView.animate(withDuration: 0.6) { [weak self] in
            guard let `self` = self else { return }
            let frame = self.view.frame
            let yComponent = self.partialView
            self.view.frame = CGRect(x: 0,
                                     y: yComponent,
                                     width: frame.width,
                                     height: UIScreen.main.bounds.height - self.partialView)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let hasStickers = stickerCollectionView != nil
        stickerCollectionView?.frame = CGRect(x: 0,
                                      y: 0,
                                      width: UIScreen.main.bounds.width,
                                      height: view.frame.height - 40)

        let emojisX: CGFloat = hasStickers ? scrollView.frame.size.width : 0
        emojiCollectionView.frame = CGRect(x: emojisX,
                                           y: 0,
                                           width: UIScreen.main.bounds.width,
                                           height: view.frame.height - 40)

        let pages: CGFloat = hasStickers ? 2.0 : 1.0
        scrollView.contentSize = CGSize(width: pages * screenSize.width,
                                        height: scrollView.frame.size.height)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //MARK: Pan Gesture
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        
        let translation = recognizer.translation(in: self.view)
        let velocity = recognizer.velocity(in: self.view)
        
        let y = self.view.frame.minY
        if y + translation.y >= fullView {
            let newMinY = y + translation.y
            self.view.frame = CGRect(x: 0, y: newMinY, width: view.frame.width, height: UIScreen.main.bounds.height - newMinY )
            self.view.layoutIfNeeded()
            recognizer.setTranslation(CGPoint.zero, in: self.view)
        }
        
        if recognizer.state == .ended {
            var duration =  velocity.y < 0 ? Double((y - fullView) / -velocity.y) : Double((partialView - y) / velocity.y )
            duration = duration > 1.3 ? 1 : duration
            //velocity is direction of gesture
            UIView.animate(withDuration: duration, delay: 0.0, options: [.allowUserInteraction], animations: {
                if  velocity.y >= 0 {
                    if y + translation.y >= self.partialView  {
                        self.removeBottomSheetView()
                    } else {
                        self.view.frame = CGRect(x: 0, y: self.partialView, width: self.view.frame.width, height: UIScreen.main.bounds.height - self.partialView)
                        self.view.layoutIfNeeded()
                    }
                } else {
                    if y + translation.y >= self.partialView  {
                        self.view.frame = CGRect(x: 0, y: self.partialView, width: self.view.frame.width, height: UIScreen.main.bounds.height - self.partialView)
                        self.view.layoutIfNeeded()
                    } else {
                        self.view.frame = CGRect(x: 0, y: self.fullView, width: self.view.frame.width, height: UIScreen.main.bounds.height - self.fullView)
                        self.view.layoutIfNeeded()
                    }
                }
                
            }, completion: nil)
        }
    }
    
    func removeBottomSheetView() {
        UIView.animate(withDuration: 0.3,
                       delay: 0,
                       options: UIView.AnimationOptions.curveEaseIn,
                       animations: { () -> Void in
                        var frame = self.view.frame
                        frame.origin.y = UIScreen.main.bounds.maxY
                        self.view.frame = frame
                        
        }, completion: { (finished) -> Void in
            self.view.removeFromSuperview()
            self.removeFromParent()
            self.stickersViewControllerDelegate?.stickersViewDidDisappear()
        })
    }
    
    func prepareBackgroundView(){
        let blurEffect = UIBlurEffect.init(style: .light)
        let visualEffect = UIVisualEffectView.init(effect: blurEffect)
        let bluredView = UIVisualEffectView.init(effect: blurEffect)
        bluredView.contentView.addSubview(visualEffect)
        visualEffect.frame = UIScreen.main.bounds
        bluredView.frame = UIScreen.main.bounds
        view.insertSubview(bluredView, at: 0)
    }
    
    
    
}

extension StickersViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageWidth = scrollView.bounds.width
        let pageFraction = scrollView.contentOffset.x / pageWidth
        self.pageControl.currentPage = Int(round(pageFraction))
    }
}

// MARK: - UICollectionViewDataSource
extension StickersViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return stickers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        stickersViewControllerDelegate?.didSelectImage(image: stickers[indexPath.item])
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = "StickerCollectionViewCell"
        let cell  = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as! StickerCollectionViewCell
        cell.stickerImage.image = stickers[indexPath.item]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 4
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
}

