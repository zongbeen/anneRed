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
    var onChange: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        textField.textAlignment = .right
        textField.clearButtonMode = .whileEditing
        textField.adjustsFontForContentSizeCategory = true
        textField.font = .preferredFont(forTextStyle: .body)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.addTarget(self, action: #selector(changed), for: .editingChanged)
        contentView.addSubview(titleLabel)
        contentView.addSubview(textField)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textField.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
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

    override func prepareForReuse() {
        super.prepareForReuse()
        onChange = nil
        textField.keyboardType = .default
    }
}
