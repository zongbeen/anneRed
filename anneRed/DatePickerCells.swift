//
//  DatePickerCells.swift
//  anneRed
//
//  Created by zongbeen on 4/20/26.
//

import UIKit

final class ValueCell: UITableViewCell {
    static let reuseID = "ValueCell"
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, value: String, valueFont: UIFont? = nil) {
        var content = UIListContentConfiguration.valueCell()
        content.text = title
        content.secondaryText = value
        if let f = valueFont { content.secondaryTextProperties.font = f }
        contentConfiguration = content
    }
}

final class InputCell: UITableViewCell {
    static let reuseID = "InputCell"
    private let titleLabel = UILabel()
    let textField = UITextField()
    private let resultLabel = UILabel()
    var onChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        textField.textAlignment = .right
        textField.clearButtonMode = .whileEditing
        textField.adjustsFontForContentSizeCategory = true
        textField.font = .preferredFont(forTextStyle: .body)
        textField.addTarget(self, action: #selector(changed), for: .editingChanged)

        resultLabel.font = .preferredFont(forTextStyle: .footnote)
        resultLabel.adjustsFontForContentSizeCategory = true
        resultLabel.textColor = .secondaryLabel
        resultLabel.textAlignment = .right
        resultLabel.isHidden = true

        let topRow = UIStackView(arrangedSubviews: [titleLabel, textField])
        topRow.axis = .horizontal
        topRow.spacing = 12
        topRow.alignment = .firstBaseline

        let vStack = UIStackView(arrangedSubviews: [topRow, resultLabel])
        vStack.axis = .vertical
        vStack.spacing = 2
        vStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(vStack)

        NSLayoutConstraint.activate([
            vStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            vStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 11),
            vStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -11),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func changed() { onChange?(textField.text ?? "") }

    func configure(title: String, text: String, placeholder: String, keyboard: UIKeyboardType = .default) {
        titleLabel.text = title
        textField.text = text
        textField.placeholder = placeholder
        textField.keyboardType = keyboard
    }

    /// 계산 결과를 셀 내부에 직접 표시한다(리로드 없이 → 입력 포커스 유지).
    func setResult(_ text: String?) {
        let value = text ?? ""
        resultLabel.text = value
        resultLabel.isHidden = value.isEmpty
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onChange = nil
        textField.keyboardType = .default
        setResult(nil)
    }
}
