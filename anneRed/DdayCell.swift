//
//  DdayCell.swift
//  anneRed
//
//  Created by zongbeen on 4/20/26.
//

import UIKit

final class DdayCell: UITableViewCell {
    static let reuseID = "DdayCell"

    private let ddayLabel = UILabel()
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let stack = UIStackView()
    private var pressAnimator: UIViewPropertyAnimator?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // D-day: 큰 숫자 — monospaced digit + largeTitle 스케일 + 네거티브 트래킹
        let ddayBase = UIFont.monospacedDigitSystemFont(ofSize: 34, weight: .light)
        ddayLabel.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: ddayBase)
        ddayLabel.adjustsFontForContentSizeCategory = true
        ddayLabel.textColor = .label
        ddayLabel.setContentHuggingPriority(.required, for: .horizontal)
        ddayLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        titleLabel.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1

        dateLabel.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13, weight: .regular))
        dateLabel.adjustsFontForContentSizeCategory = true
        dateLabel.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [titleLabel, dateLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.addArrangedSubview(textStack)
        stack.addArrangedSubview(UIView())   // spacer
        stack.addArrangedSubview(ddayLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let m = UIFontMetrics(forTextStyle: .body)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: m.scaledValue(for: 14)),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -m.scaledValue(for: 14)),
        ])

        isAccessibilityElement = true
    }

    func configure(with data: DdayData) {
        guard let date = data.selectedDate else { return }
        let daysLeft = DdayCalculator.days(from: Date(), to: date)
        let ddayText = DdayCalculator.text(daysLeft: daysLeft)

        // 큰 숫자에 네거티브 트래킹
        ddayLabel.attributedText = NSAttributedString(
            string: ddayText,
            attributes: [.kern: -0.6]
        )

        titleLabel.text = data.title
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        dateLabel.text = df.string(from: date)

        // 편집 모드에서는 D-day 숨김
        ddayLabel.alpha = isEditing ? 0 : 1

        accessibilityLabel = "\(dateLabel.text ?? ""), \(ddayText), \(data.title ?? "")"
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        let target: CGFloat = editing ? 0 : 1
        if Motion.reduce || !animated {
            ddayLabel.alpha = target
            return
        }
        let anim = Motion.spring(bounce: 0, duration: Motion.editDuration)
        anim.addAnimations { self.ddayLabel.alpha = target }
        anim.startAnimation()
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        pressAnimator?.stopAnimation(true)
        let scale: CGFloat = highlighted ? 0.97 : 1.0
        let bg: UIColor = highlighted ? .secondarySystemBackground : .clear
        if Motion.reduce {
            contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
            backgroundColor = bg
            return
        }
        let anim = Motion.spring(bounce: 0, duration: Motion.pressDuration)
        anim.addAnimations {
            self.contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.backgroundColor = bg
        }
        anim.startAnimation()
        pressAnimator = anim
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.transform = .identity
        backgroundColor = .clear
        ddayLabel.alpha = isEditing ? 0 : 1
    }
}
