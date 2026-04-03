//
//  ColorCollectionViewCell.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 5/1/17.
//  Copyright © 2017 Mohamed Hamed. All rights reserved.
//

import UIKit

@objc(ColorCollectionViewCell)
public class ColorCollectionViewCell: UICollectionViewCell {

    public let colorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        contentView.addSubview(colorView)
        NSLayoutConstraint.activate([
            colorView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            colorView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            colorView.widthAnchor.constraint(equalToConstant: 20),
            colorView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        colorView.layer.cornerRadius = colorView.frame.width / 2
        colorView.clipsToBounds = true
        updateBorder()
    }

    private func updateBorder() {
        if isSelected {
            colorView.layer.borderWidth = 3.0
            colorView.layer.borderColor = contrastingBorderColor().cgColor
        } else {
            colorView.layer.borderWidth = 1.0
            colorView.layer.borderColor = UIColor.white.cgColor
        }
    }

    private func contrastingBorderColor() -> UIColor {
        guard let bg = colorView.backgroundColor else { return .white }
        var white: CGFloat = 0
        bg.getWhite(&white, alpha: nil)
        return white > 0.75 ? .darkGray : .white
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        colorView.transform = .identity
        colorView.layer.borderWidth = 1.0
        colorView.layer.borderColor = UIColor.white.cgColor
    }

    public override var isSelected: Bool {
        didSet {
            updateBorder()
            if isSelected {
                let previouTransform = colorView.transform
                UIView.animate(withDuration: 0.2,
                               animations: {
                                self.colorView.transform = self.colorView.transform.scaledBy(x: 1.3, y: 1.3)
                },
                               completion: { _ in
                                UIView.animate(withDuration: 0.2) {
                                    self.colorView.transform = previouTransform
                                }
                })
            }
        }
    }
}
