//
//  ContactTableViewCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/30.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import YPTransition

class ContactTableViewCell: UITableViewCell {
    
    static let cellID = "ContactTableViewCell"
    
    let avatarImageView = FLAnimatedImageView()
    let nameLabel = UILabel()
    let latestMessageLabel = UILabel()
    var message: Message!
    var labelStackView: UIStackView!
    var stackView: UIStackView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        nameLabel.font = UIFont.systemFont(ofSize: 15)
        
        latestMessageLabel.adjustsFontSizeToFitWidth = true
        latestMessageLabel.textColor = .lightGray
        latestMessageLabel.numberOfLines = 1
        latestMessageLabel.lineBreakMode = .byTruncatingTail
        
        avatarImageView.layer.masksToBounds = true
        avatarImageView.layer.cornerRadius = 8
        
        labelStackView = UIStackView(arrangedSubviews: [nameLabel, latestMessageLabel])
        labelStackView.axis = .vertical
        labelStackView.spacing = 5
        
        stackView = UIStackView(arrangedSubviews: [avatarImageView, labelStackView])
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.alignment = .center
        contentView.addSubview(stackView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        avatarImageView.mas_updateConstraints { [weak self] make in
            make?.width.mas_lessThanOrEqualTo()(self?.stackView.mas_height)
            make?.width.mas_equalTo()(self?.avatarImageView.mas_height)
        }
    }
    
    func apply(message: Message?, name: String, imageUrl: String) {
        self.message = message
        nameLabel.text = name
        var text = ""
        if let message = message {
            switch message.messageType {
            case .draw:
                text = "[速绘]"
            case .image:
                text = "[图片]"
            case .join, .text:
                text = message.message
            case .video:
                text = "[视频]"
            }
            latestMessageLabel.text = text
            if latestMessageLabel.superview == nil {
                labelStackView.addArrangedSubview(latestMessageLabel)
            }
        } else {
            latestMessageLabel.removeFromSuperview()
        }
        if !imageUrl.isEmpty {
            WebSocketManager.shared.getCacheImage(from: nil, path: imageUrl) { [weak self] image, data in
                guard let self = self, let data = data else { return }
                if imageUrl.hasSuffix(".gif") {
                    self.avatarImageView.animatedImage = FLAnimatedImage(gifData: data)
                } else {
                    self.avatarImageView.image = UIImage(data: data)
                }
            }
        }
    }
    
}
