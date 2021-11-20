//
//  ContactTableViewCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/30.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatNetwork
import DogeChatUniversal

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
    weak var manager: WebSocketManager?
    weak var delegate: ContactTableViewCellDelegate?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        nameLabel.font = UIFont.systemFont(ofSize: 15)
        
        if #available(iOS 13, *) {
            latestMessageLabel.textColor = .lightGray
        } else {
            latestMessageLabel.textColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        }
        latestMessageLabel.numberOfLines = 1
        latestMessageLabel.lineBreakMode = .byTruncatingTail
        latestMessageLabel.font = UIFont.systemFont(ofSize: nameLabel.font.pointSize - 3)
        
        avatarImageView.layer.masksToBounds = true
        avatarImageView.layer.cornerRadius = (ContactTableViewCell.cellHeight - avataroffset) / 2
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.isUserInteractionEnabled = true
        
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
            make?.centerY.equalTo()(self.contentView.mas_centerY)
            make?.leading.equalTo()(self.contentView.mas_leading)?.offset()(15)
            make?.trailing.equalTo()(self.contentView.mas_trailing)?.offset()(-40)
        }
        
        unreadLabel.layer.masksToBounds = true
        unreadLabel.backgroundColor = .red
        unreadLabel.textAlignment = .center
        unreadLabel.font = .systemFont(ofSize: 13)
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        avatarImageView.mas_updateConstraints { [weak self] make in
            make?.width.mas_equalTo()(ContactTableViewCell.cellHeight - avataroffset)
            make?.width.mas_equalTo()(self?.avatarImageView.mas_height)
        }
    }
    
    @objc func avatarTapAction(_ tap: UITapGestureRecognizer) {
//        delegate?.avatarTapped(self, path: info.avatarUrl)
    }
    
    func apply(_ info: Friend, titleMore: String? = nil, subTitle: String? = nil) {
        self.info = info
        var title = info.username
        if let nickName = info.nickName, !nickName.isEmpty {
            title = nickName
        }
        if let titleMore = titleMore {
            title += titleMore
        }
        self.nameLabel.text = title
        var text = ""
        if let message = info.latestMessage {
            if info.isGroup {
                if let manager = manager,
                    message.messageSender == .ourself,
                   let myNameInGroup = manager.myInfo.nameInGroupsDict[info.userID] {
                    text += (myNameInGroup + "：")
                } else {
                    text += "\(message.senderUsername)："
                }
            }
            switch message.messageType {
            case .draw:
                text += "[速绘]"
            case .image:
                text += "[图片]"
            case .livePhoto:
                text += "[Live Photo]"
            case .join, .text:
                text += message.text
            case .video:
                text += "[视频]"
            case .track:
                text += "[歌曲分享]"
            case .voice:
                text += "[语音]"
            }
            latestMessageLabel.text = text
            latestMessageLabel.isHidden = false
        } else if let subTitle = subTitle {
            latestMessageLabel.text = subTitle
            latestMessageLabel.isHidden = false
        } else {
            latestMessageLabel.isHidden = true
        }
        avatarImageView.isHidden = info.avatarURL.isEmpty
        if !info.avatarURL.isEmpty {
            let avatarUrl = WebSocketManager.url_pre + info.avatarURL
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
