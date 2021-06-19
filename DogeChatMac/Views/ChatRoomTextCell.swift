//
//  ChatRoomTextCell.swift
//  DogeChatMac
//
//  Created by 赵锡光 on 2021/6/15.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import AppKit
import DogeChatUniversal

class ChatRoomTextCell: ChatRoomCell {
    
    static let textCellID = "textMessage"
    let messageLabel = NSTextView()
    var constraintForMessageLabelWidth: NSLayoutConstraint!
    var constraintForMessageLabelHeight: NSLayoutConstraint!
    var constraintForMessageLabelSide: NSLayoutConstraint!
    var constraintForMessageLabelTop: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        messageLabel.isEditable = false
        messageLabel.alignment = .center
        messageLabel.textContainerInset = NSSize(width: 8, height: 4)
        self.addSubview(messageLabel)
        indicatorNeighborView = messageLabel
        constraintForMessageLabelWidth = NSLayoutConstraint(item: messageLabel, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 300)
        constraintForMessageLabelHeight = NSLayoutConstraint(item: messageLabel, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 100)
        constraintForMessageLabelTop = NSLayoutConstraint(item: messageLabel, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 10)
        constraintForMessageLabelWidth.isActive = true
        constraintForMessageLabelHeight.isActive = true
        constraintForMessageLabelTop.isActive = true
    }
    static var count = 0
    override func layout() {
        super.layout()
        guard message != nil else { return }
        let newHeight = height(forText: message.message, fontSize: 17, maxSize: NSSize(width: 500, height: CGFloat.greatestFiniteMagnitude))
        constraintForMessageLabelWidth.constant = newHeight.width + 30
        constraintForMessageLabelHeight.constant = newHeight.height + 20
    }
    
    override func apply(message: Message) {
        super.apply(message: message)
        messageLabel.string = message.message
        if message.messageSender == .ourself {
            messageLabel.backgroundColor = NSColor(red: 24/255, green: 180/255, blue: 128/255, alpha: 1.0)
        } else {
            messageLabel.backgroundColor = #colorLiteral(red: 0.09282096475, green: 0.7103053927, blue: 1, alpha: 1)
        }
        messageLabel.font = NSFont.systemFont(ofSize: 17)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        if let layer = messageLabel.layer {
            layer.cornerRadius = 20
            layer.masksToBounds = true
        }
        constraintForMessageLabelSide?.isActive = false
        if message.messageSender == .ourself {
            constraintForMessageLabelSide = NSLayoutConstraint(item: nameLabel, attribute: .trailing, relatedBy: .equal, toItem: avatarImageView, attribute: .leading, multiplier: 1, constant: -10)
        } else {
            constraintForMessageLabelSide = NSLayoutConstraint(item: nameLabel, attribute: .leading, relatedBy: .equal, toItem: avatarImageView, attribute: .trailing, multiplier: 1, constant: 10)
        }
        constraintForMessageLabelSide.isActive = true
    }
    

    func layoutForTextMessage() {
        messageLabel.textColor = .black
        messageLabel.font = NSFont.systemFont(ofSize: 17)
        let size = (message.message as NSString).boundingRect(with: CGSize(width: 2*(bounds.size.width/3), height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: [.font: messageLabel.font!])
        let labelSize = NSSize(width: size.width + 30, height: size.height + 30)
        let avatarFrame = avatarImageView.frame
        if message.messageSender == .someoneElse {
            messageLabel.frame = NSRect(x: avatarFrame.maxX + 5, y: 5, width: labelSize.width, height: labelSize.height)
        } else {
            messageLabel.frame = NSRect(x: self.bounds.width - avatarFrame.width - 5 * 2 - labelSize.width, y: 5, width: labelSize.width, height: labelSize.height)
        }
    }
    
    func layoutForRevokeMessage() {
        messageLabel.isHidden = false
        messageLabel.font = NSFont.systemFont(ofSize: 10)
        messageLabel.textColor = .lightGray
        messageLabel.backgroundColor = NSColor(red: 247/255, green: 247/255, blue: 247/255, alpha: 1.0)
        messageLabel.alignment = .center
        var size = CGSize.zero
        size.width += 50
        size.height += 10
        let center = CGPoint(x: bounds.size.width/2, y: bounds.size.height/2.0)
        messageLabel.frame = .init(center: center, size: size)
    }


}
