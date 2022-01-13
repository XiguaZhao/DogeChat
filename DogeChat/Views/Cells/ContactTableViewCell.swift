//
//  ContactTableViewCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/30.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatUniversal
import DogeChatCommonDefines

protocol ContactTableViewCellDelegate: AnyObject {
    func avatarTapped(_ cell: ContactTableViewCell?, path: String)
}

class ContactTableViewCell: UITableViewCell {
    
    static let cellID = "ContactTableViewCell"
    static let cellHeight: CGFloat = 60
    let avataroffset: CGFloat = 12
    
    let avatarImageView = FLAnimatedImageView()
    let nameLabel = UILabel()
    let latestMessageLabel = UILabel()
    var info: Friend!
    let unreadLabel = UILabel()
    var unreadCount = 0 {
        didSet {
            DispatchQueue.main.async { [self] in
                unreadLabel.isHidden = unreadCount == 0
                unreadLabel.text = String(unreadCount)
            }
        }
    }
    var labelStackView: UIStackView!
    var stackView: UIStackView!
    weak var delegate: ContactTableViewCellDelegate?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        
        latestMessageLabel.textColor = .lightGray
        latestMessageLabel.numberOfLines = 1
        latestMessageLabel.lineBreakMode = .byTruncatingTail
        latestMessageLabel.font = .preferredFont(forTextStyle: .footnote)// UIFont.systemFont(ofSize: nameLabel.font.pointSize - 3)
        
        avatarImageView.layer.masksToBounds = true
        avatarImageView.layer.cornerRadius = 24
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.isUserInteractionEnabled = true
        
        avatarImageView.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(48)
        }
        
        labelStackView = UIStackView(arrangedSubviews: [nameLabel, latestMessageLabel])
        labelStackView.axis = .vertical
        labelStackView.spacing = 5
        
        stackView = UIStackView(arrangedSubviews: [avatarImageView, labelStackView])
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.alignment = .center
        contentView.addSubview(stackView)
        stackView.mas_makeConstraints { [weak self] make in
            guard let self = self else { return }
            make?.leading.equalTo()(self.contentView.mas_leading)?.offset()(15)
            make?.trailing.equalTo()(self.contentView.mas_trailing)
            make?.top.equalTo()(self.contentView)?.offset()(tableViewCellTopBottomPadding)
            make?.bottom.equalTo()(self.contentView)?.offset()(-tableViewCellTopBottomPadding)
        }
        
        unreadLabel.layer.masksToBounds = true
        unreadLabel.backgroundColor = .red
        unreadLabel.textAlignment = .center
        unreadLabel.font = .systemFont(ofSize: 13)
        unreadLabel.textColor = .white
        unreadLabel.bounds = CGRect(x: 0, y: 0, width: 22, height: 22)
        unreadLabel.layer.cornerRadius = 11
        self.accessoryView = unreadLabel
        unreadLabel.isHidden = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.image = nil
        avatarImageView.animatedImage = nil
        unreadLabel.isHidden = true
        latestMessageLabel.text = nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
        
    @objc func avatarTapAction(_ tap: UITapGestureRecognizer) {
//        delegate?.avatarTapped(self, path: info.avatarUrl)
    }
    
    func apply(_ info: Friend, titleMore: String? = nil, subTitle: String? = nil, hasAt: Bool = false) {
        self.info = info
        var title = info.username
        if let nickName = info.nickName, !nickName.isEmpty {
            title = nickName
        }
        if let titleMore = titleMore {
            title += titleMore
        }
        let attributedTitle = NSMutableAttributedString(string: title + " ", attributes: [
            .font : UIFont.preferredFont(forTextStyle: .body)
        ])
        if info.isMuted {
            let imageAttach = NSTextAttachment()
            imageAttach.image = UIImage(named: "jingyin")
            imageAttach.bounds = CGRect(x: 0, y: 0, width: 15, height: 15)
            attributedTitle.append(NSAttributedString(attachment: imageAttach))
        }
        self.nameLabel.attributedText = attributedTitle
        var text = ""
        var latestMessageText: String?
        if let message = info.latestMessage {
            if info.isGroup {
                text += "\(message.senderUsername)："
            }
            text += message.summary()
            latestMessageText = text
            latestMessageLabel.isHidden = false
        } else if let subTitle = subTitle {
            latestMessageText = subTitle
            latestMessageLabel.isHidden = false
        } else if let latestMessageStr = info.latestMessageString {
            latestMessageText = latestMessageStr
            latestMessageLabel.isHidden = false
        } else {
            latestMessageLabel.isHidden = true
        }
        if let latestMessageText = latestMessageText {
            let attrStr = NSMutableAttributedString()
            if hasAt {
                attrStr.append(NSAttributedString(string: "[有人@你]", attributes: [.foregroundColor : #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 1)]))
            }
            attrStr.append(NSAttributedString(string: latestMessageText))
            latestMessageLabel.attributedText = attrStr
        }
        avatarImageView.isHidden = info.avatarURL.isEmpty
        if !info.avatarURL.isEmpty {
            let avatarUrl = info.avatarURL
            let isGif = avatarUrl.hasSuffix(".gif")
            MediaLoader.shared.requestImage(urlStr: avatarUrl, type: .image, syncIfCan: false) { [self] image, data, _ in
                guard info.username == self.info.username, let data = data else {
                    return
                }
                if !isGif { // is photo
                    avatarImageView.image = UIImage(data: data)
                } else { // gif图处理
                    avatarImageView.animatedImage = FLAnimatedImage(gifData: data)
                }
            }
        }
    }
    
    
}
