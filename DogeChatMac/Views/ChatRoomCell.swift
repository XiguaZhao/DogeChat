//
//  ChatRoomCell.swift
//  DogeChatMac
//
//  Created by 赵锡光 on 2021/6/15.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import AppKit
import DogeChatUniversal
import YPTransition

var avatarCache = [String : Data]()

class ChatRoomCell: NSTableCellView {
    
    static let cellID = "message"

    var message: Message!
    let nameLabel = NSTextField()
    let indicator = NSProgressIndicator()
    var indicatorNeighborView: NSView?
    let avatarImageView = NSImageView()
    let nameLabelStartX: CGFloat = 40 + 5 + 5
    let nameLabelStartY: CGFloat = 10
    let avatarWidth: CGFloat = 40
    let avatarMargin: CGFloat = 5

    override func awakeFromNib() {
        super.awakeFromNib()
        nameLabel.textColor = .lightGray
        nameLabel.font = NSFont.systemFont(ofSize: 10)
        avatarImageView.layer?.masksToBounds = true
        avatarImageView.layer?.cornerRadius = avatarWidth / 2
        
        self.addSubview(avatarImageView)
        self.addSubview(nameLabel)
        self.addSubview(indicator)
    }
    
    
    override func layout() {
        super.layout()
        guard let message = message else {
            return
        }
        if message.messageSender == .someoneElse {
            nameLabel.frame = NSRect(x: nameLabelStartX, y: nameLabelStartY, width: nameLabel.bounds.width, height: nameLabel.bounds.height)
            avatarImageView.frame = NSRect(x: avatarMargin, y: avatarMargin, width: avatarWidth, height: avatarWidth)
        } else {
            avatarImageView.frame = NSRect(x: self.bounds.width - 50, y: avatarMargin, width: avatarWidth, height: avatarWidth)
        }
    }
    
    func apply(message: Message) {
        self.message = message
        nameLabel.stringValue = message.senderUsername
        loadAvatar()
        if message.messageSender == .someoneElse {
            nameLabel.isHidden = false
            nameLabel.sizeToFit()
            indicator.isHidden = true
        } else {
            nameLabel.isHidden = true
            if message.sendStatus == .fail {
                indicator.isHidden = false
                indicator.startAnimation(nil)
            }
        }
        if message.messageType == .join {
            nameLabel.isHidden = true
        }
    }
    
    func loadAvatar() {
        let block: (String) -> Void = { [self] urlStr in
            avatarImageView.animates = true
            if let data = avatarCache[urlStr] {
                avatarImageView.image = NSImage(data: data)
            } else {
                guard let url = URL(string: urlStr) else { return }
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data {
                        avatarCache[urlStr] = data
                        DispatchQueue.main.async {
                            avatarImageView.image = NSImage(data: data)
                        }
                    }
                }.resume()
            }
        }
        if message.messageSender == .ourself {
            let url = WebSocketManager.shared.messageManager.myAvatarUrl
            block(url)
        } else if message.option == .toOne {
            if let index = usersInfos.firstIndex(where: { $0.name == message.senderUsername }) {
                let url = WebSocketManager.shared.url_pre + usersInfos[index].avatarUrl
                block(url)
            }
        } else {
            let url = message.avatarUrl
            guard !url.isEmpty else { return }
            block(url)
        }
    }
    
}

func height(for message: Message) -> CGFloat {
    let maxSize = NSSize(width: 500, height: CGFloat.greatestFiniteMagnitude)
    let nameHeight = message.messageSender == .ourself ? 0 : height(forText: message.senderUsername, fontSize: 10, maxSize: maxSize).height
    let messageHeight = height(forText: message.message, fontSize: 17, maxSize: maxSize)
    var height: CGFloat = 30
    switch message.messageType {
    case .join, .text:
        height = nameHeight + messageHeight.height + 32 + 16
    case .image:
        height = nameHeight + 150
    default:
        break
    }
    return height
}

func height(forText text: String, fontSize: CGFloat, maxSize: NSSize) -> CGSize {
    let font = NSFont.systemFont(ofSize: fontSize)
    let attrString = NSAttributedString(string: text, attributes: [
        .font: font,
        .foregroundColor: NSColor.white
    ])
    let textHeight = attrString.boundingRect(with: maxSize, options: .usesLineFragmentOrigin, context: nil).size
    return textHeight
}
