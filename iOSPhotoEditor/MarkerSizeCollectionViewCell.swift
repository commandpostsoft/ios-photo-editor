//
//  MarkerSizeCollectionViewCell.swift
//  Photo Editor
//

import UIKit

@objc(MarkerSizeCollectionViewCell)
public class MarkerSizeCollectionViewCell: UICollectionViewCell {

    private let ringView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()

    public let circleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var circleWidthConstraint: NSLayoutConstraint!
    private var circleHeightConstraint: NSLayoutConstraint!
    private var ringWidthConstraint: NSLayoutConstraint!
    private var ringHeightConstraint: NSLayoutConstraint!

    private var circleDiameter: CGFloat = 10

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        contentView.addSubview(ringView)
        contentView.addSubview(circleView)

        ringWidthConstraint = ringView.widthAnchor.constraint(equalToConstant: 14)
        ringHeightConstraint = ringView.heightAnchor.constraint(equalToConstant: 14)
        circleWidthConstraint = circleView.widthAnchor.constraint(equalToConstant: 10)
        circleHeightConstraint = circleView.heightAnchor.constraint(equalToConstant: 10)

        NSLayoutConstraint.activate([
            ringView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            ringView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            ringWidthConstraint,
            ringHeightConstraint,
            circleView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            circleView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            circleWidthConstraint,
            circleHeightConstraint
        ])
    }

    func configure(diameter: CGFloat, color: UIColor) {
        let clamped = min(diameter, 36)
        circleDiameter = clamped

        circleWidthConstraint.constant = clamped
        circleHeightConstraint.constant = clamped
        circleView.backgroundColor = color
        circleView.layer.cornerRadius = clamped / 2
        circleView.clipsToBounds = true

        let ringSize = clamped + 4
        ringWidthConstraint.constant = ringSize
        ringHeightConstraint.constant = ringSize
        ringView.layer.cornerRadius = ringSize / 2
        ringView.clipsToBounds = true

        updateRing()
    }

    private func updateRing() {
        if isSelected {
            ringView.backgroundColor = contrastingBorderColor()
        } else {
            ringView.backgroundColor = .gray
        }
    }

    private func contrastingBorderColor() -> UIColor {
        guard let bg = circleView.backgroundColor else { return .gray }
        var white: CGFloat = 0
        bg.getWhite(&white, alpha: nil)
        return white > 0.75 ? .darkGray : .white
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        circleView.transform = .identity
        ringView.backgroundColor = .gray
    }

    public override var isSelected: Bool {
        didSet {
            updateRing()
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
