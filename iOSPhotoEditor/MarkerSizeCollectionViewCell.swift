//
//  MarkerSizeCollectionViewCell.swift
//  Photo Editor
//

import UIKit

class MarkerSizeCollectionViewCell: UICollectionViewCell {

    let circleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.borderWidth = 1.0
        view.layer.borderColor = UIColor.white.cgColor
        return view
    }()

    private var widthConstraint: NSLayoutConstraint!
    private var heightConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        contentView.addSubview(circleView)
        widthConstraint = circleView.widthAnchor.constraint(equalToConstant: 10)
        heightConstraint = circleView.heightAnchor.constraint(equalToConstant: 10)
        NSLayoutConstraint.activate([
            circleView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            circleView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            widthConstraint,
            heightConstraint
        ])
    }

    func configure(diameter: CGFloat, color: UIColor) {
        // Clamp diameter to cell size
        let clamped = min(diameter, 36)
        widthConstraint.constant = clamped
        heightConstraint.constant = clamped
        circleView.backgroundColor = color
        circleView.layer.cornerRadius = clamped / 2
        circleView.clipsToBounds = true
    }

    override var isSelected: Bool {
        didSet {
            if isSelected {
                let prev = circleView.transform
                UIView.animate(withDuration: 0.2, animations: {
                    self.circleView.transform = self.circleView.transform.scaledBy(x: 1.3, y: 1.3)
                }, completion: { _ in
                    UIView.animate(withDuration: 0.2) {
                        self.circleView.transform = prev
                    }
                })
            }
        }
    }
}
