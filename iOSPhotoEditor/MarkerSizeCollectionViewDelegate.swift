//
//  MarkerSizeCollectionViewDelegate.swift
//  Photo Editor
//

import UIKit

class MarkerSizeCollectionViewDelegate: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    weak var markerSizeDelegate: MarkerSizeDelegate?
    var sizes: [CGFloat] = []
    var drawColor: UIColor = .white

    func reloadWithColor(_ color: UIColor, collectionView: UICollectionView) {
        let selectedIndexPath = collectionView.indexPathsForSelectedItems?.first
        drawColor = color
        collectionView.reloadData()
        if let indexPath = selectedIndexPath {
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
    }

    // MARK: - UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sizes.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MarkerSizeCollectionViewCell", for: indexPath) as! MarkerSizeCollectionViewCell
        let size = sizes[indexPath.item]
        // Scale diameter: use the size value directly, clamped inside the cell
        cell.configure(diameter: size + 6, color: drawColor)
        return cell
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        markerSizeDelegate?.didSelectMarkerSize(width: sizes[indexPath.item])
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 40, height: 40)
    }

}
