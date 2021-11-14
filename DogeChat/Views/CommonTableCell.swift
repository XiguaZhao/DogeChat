//
//  SettingCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/27.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import FLAnimatedImage

protocol TrailingViewProtocol: AnyObject {
    func didSwitch(cell: CommonTableCell, isOn: Bool)
    func textFieldDidEndInputing(cell: CommonTableCell, text: String)
}

class CommonTableCell: DogeChatTableViewCell, UITextFieldDelegate {
    
    enum TrailingViewType {
        case label
        case textField
        case switcher
    }
    

    weak var delegate: TrailingViewProtocol?
    
    static let cellID = "SettingCellID"
    
    var trailingType: TrailingViewType?
    
    let titleLabel = UILabel()
    let subTitleLabel = UILabel()
    let leaingImageView = FLAnimatedImageView()
    let textField = UITextField()
    let switcher = UISwitch()
    let trailingLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        trailingLabel.font = .systemFont(ofSize: 15)
        textField.font = .systemFont(ofSize: 15)
        trailingLabel.textAlignment = .right
        textField.textAlignment = .right
        
        let middleStack = UIStackView(arrangedSubviews: [titleLabel, subTitleLabel])
        titleLabel.font = .boldSystemFont(ofSize: 15)
        subTitleLabel.font = .systemFont(ofSize: 12)
        middleStack.spacing = 5
        middleStack.axis = .vertical
        
        let rightStack = UIStackView(arrangedSubviews: [trailingLabel, textField, switcher])
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        trailingLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [leaingImageView, middleStack, rightStack])
        stack.setCustomSpacing(8, after: leaingImageView)
        stack.setCustomSpacing(20, after: middleStack)
        stack.distribution = .fill
        stack.alignment = .center
        
        contentView.addSubview(stack)
        stack.mas_makeConstraints { make in
            let offset: CGFloat = 16
            make?.leading.equalTo()(self.contentView)?.offset()(offset)
            make?.trailing.equalTo()(self.contentView)?.offset()(-offset)
            make?.center.equalTo()(self.contentView)
        }
        textField.delegate = self
        switcher.addTarget(self, action: #selector(switcherAction(_:)), for: .valueChanged)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.accessoryView = .none
        leaingImageView.image = nil
        leaingImageView.animatedImage = nil
    }
    
    func apply(title: String, subTitle: String?, imageURL: String?, trailingViewType: TrailingViewType?, trailingText: String?) {
        self.trailingType = trailingViewType
        titleLabel.text = title
        subTitleLabel.text = subTitle
        leaingImageView.isHidden = imageURL == nil
        subTitleLabel.isHidden = subTitle == nil
        switcher.isHidden = trailingType != .switcher
        trailingLabel.isHidden = trailingType != .label
        textField.isHidden = trailingType != .textField
        if let type = trailingViewType, let text = trailingText {
            if type == .textField {
                textField.text = text
            } else if type == .label {
                trailingLabel.text = text
            }
        }
    }
    
    @objc func switcherAction(_ switcher: UISwitch) {
        delegate?.didSwitch(cell: self, isOn: switcher.isOn)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        delegate?.textFieldDidEndInputing(cell: self, text: textField.text ?? "")
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
