//
//  ContactTableViewCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/30.
//  Copyright © 2021 Luke Parham. All rights reserved.
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
    static var avatarCache = [String: Data]()
    
    let avatarImageView = FLAnimatedImageView()
    let nameLabel = UILabel()
    let latestMessageLabel = UILabel()
    var info: (name: String, avatarUrl: String, latestMessage: Message?)!
    var labelStackView: UIStackView!
    var stackView: UIStackView!
    weak var delegate: ContactTableViewCellDelegate?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        self.selectionStyle = .none
        nameLabel.font = UIFont.systemFont(ofSize: 15)
        
        latestMessageLabel.textColor = .lightGray
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
    
    func apply(_ info: (name: String, avatarUrl: String, latestMessage: Message?)) {
        self.info = info
        nameLabel.text = info.name
        var text = ""
        if let message = info.latestMessage {
            switch message.messageType {
            case .draw:
                text = "[速绘]"
            case .image, .livePhoto:
                text = "[图片]"
            case .join, .text:
                text = message.message
            case .video:
                text = "[视频]"
            case .track:
                text = "[歌曲分享]"
            }
            latestMessageLabel.text = text
            if latestMessageLabel.superview == nil {
                labelStackView.addArrangedSubview(latestMessageLabel)
            }
        } else {
            latestMessageLabel.removeFromSuperview()
        }
        if !info.avatarUrl.isEmpty {
            let avatarUrl = WebSocketManager.shared.url_pre + info.avatarUrl
            let isGif = avatarUrl.hasSuffix(".gif")
            if let data = ContactTableViewCell.avatarCache[avatarUrl] {
                if isGif {
                    avatarImageView.animatedImage = FLAnimatedImage(gifData: data as Data)
                } else {
                    avatarImageView.image = UIImage(data: data as Data)
                }
                return
            }
            SDWebImageManager.shared.loadImage(with: URL(string: avatarUrl), options: [.avoidDecodeImage, .allowInvalidSSLCertificates]) { (received, total, url) in
            } completed: { [self] (image, data, error, cacheType, finished, url) in
                guard info.name == self.info.name else {
                    return
                }
                if !isGif, let image = image { // is photo
                    let compressed = WebSocketManager.shared.messageManager.compressEmojis(image)
                    avatarImageView.image = UIImage(data: compressed)
                    ContactTableViewCell.avatarCache[avatarUrl] = compressed
                } else { // gif图处理
                    avatarImageView.animatedImage = FLAnimatedImage(gifData: data)
                    if let data = data {
                        ContactTableViewCell.avatarCache[avatarUrl] = data
                    }
                }
            }
        }
    }
    
    
}
