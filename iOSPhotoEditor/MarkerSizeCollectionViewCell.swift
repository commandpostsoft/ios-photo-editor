//
//  MarkerSizeCollectionViewCell.swift
//  Photo Editor
//

import UIKit

@objc(MarkerSizeCollectionViewCell)
public class MarkerSizeCollectionViewCell: UICollectionViewCell {

    public let circleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.borderWidth = 1.0
        view.layer.borderColor = UIColor.white.cgColor
        return view
    }()

    private var widthConstraint: NSLayoutConstraint!
    private var heightConstraint: NSLayoutConstraint!

    public override init(frame: CGRect) {
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
        updateBorder()
    }

    private func updateBorder() {
        let borderColor: UIColor = isSelected ? contrastingBorderColor() : .gray
        circleView.layer.borderColor = borderColor.cgColor
    }

    private func contrastingBorderColor() -> UIColor {
        guard let bg = circleView.backgroundColor else { return .gray }
        var white: CGFloat = 0
        bg.getWhite(&white, alpha: nil)
        // Use dark border on light fills, light border on dark fills
        return white > 0.75 ? .darkGray : .white
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        circleView.transform = .identity
        circleView.layer.borderWidth = 1.0
        circleView.layer.borderColor = UIColor.gray.cgColor
    }

    public override var isSelected: Bool {
        didSet {
            circleView.layer.borderWidth = isSelected ? 2.0 : 1.0
            updateBorder()
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
