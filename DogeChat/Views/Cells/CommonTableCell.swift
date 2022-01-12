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
    let leadingImageView = FLAnimatedImageView()
    let textField = UITextField()
    let switcher = UISwitch()
    let trailingLabel = UILabel()
    var stackView: UIStackView!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        trailingLabel.font = .preferredFont(forTextStyle: .footnote)
        trailingLabel.numberOfLines = 0
        textField.font = .preferredFont(forTextStyle: .footnote)
        trailingLabel.textAlignment = .right
        textField.textAlignment = .right
        
        let middleStack = UIStackView(arrangedSubviews: [titleLabel, subTitleLabel])
        titleLabel.font = .preferredFont(forTextStyle: .body)
        subTitleLabel.font = .preferredFont(forTextStyle: .footnote)
        middleStack.spacing = 5
        middleStack.axis = .vertical
        
        let rightStack = UIStackView(arrangedSubviews: [trailingLabel, textField, switcher])
        textField.setContentCompressionResistancePriority(.required, for: .horizontal)
        trailingLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [leadingImageView, middleStack, rightStack])
        self.stackView = stack
        stack.setCustomSpacing(8, after: leadingImageView)
        stack.setCustomSpacing(20, after: middleStack)
        stack.distribution = .fill
        stack.alignment = .center
        
        contentView.addSubview(stack)
        stack.mas_makeConstraints { make in
            let offset: CGFloat = 16
            make?.leading.equalTo()(self.contentView)?.offset()(offset)
            make?.trailing.equalTo()(self.contentView)?.offset()(-offset)
            make?.top.equalTo()(self.contentView)?.offset()(tableViewCellTopBottomPadding)
            make?.bottom.equalTo()(self.contentView)?.offset()(-tableViewCellTopBottomPadding)
            make?.height.mas_greaterThanOrEqualTo()(40)
        }
        leadingImageView.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(40)
        }
        leadingImageView.layer.cornerRadius = 20
        leadingImageView.layer.masksToBounds = true
        leadingImageView.contentMode = .scaleAspectFill
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
        leadingImageView.image = nil
        leadingImageView.animatedImage = nil
    }
    
    func apply(title: String, subTitle: String?, imageURL: String?, trailingViewType: TrailingViewType?, trailingText: String?, switchOn: Bool? = nil, imageIsLeft: Bool = true) {
        self.trailingType = trailingViewType
        titleLabel.text = title
        subTitleLabel.text = subTitle
        leadingImageView.isHidden = imageURL == nil
        subTitleLabel.isHidden = subTitle == nil
        switcher.isHidden = trailingType != .switcher
        trailingLabel.isHidden = trailingType != .label
        textField.isHidden = trailingType != .textField
        if let type = trailingViewType {
            if let text = trailingText {
                if type == .textField {
                    textField.text = text
                } else if type == .label {
                    trailingLabel.text = text
                }
            } else if let switchOn = switchOn {
                switcher.isOn = switchOn
            }
        }
        if let imageURL = imageURL {
            if imageIsLeft {
                stackView.removeArrangedSubview(leadingImageView)
                stackView.insertArrangedSubview(leadingImageView, at: 0)
            } else {
                stackView.removeArrangedSubview(leadingImageView)
                stackView.addArrangedSubview(leadingImageView)
            }
            MediaLoader.shared.requestImage(urlStr: imageURL, type: .image, completion: { [weak self] image, data, _ in
                if imageURL.isGif {
                    self?.leadingImageView.animatedImage = FLAnimatedImage(gifData: data)
                } else {
                    self?.leadingImageView.image = image
                }
            }, progress: nil)
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
