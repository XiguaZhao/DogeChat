//
//  TableViewCell.swift
//  DogeChat
//
//  Created by zhaoxiguang on 2022/9/17.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatCommonDefines

class MessageIndicateCell: MessageBaseCell {

    let messageLabel = InsetLabel()
    
    static let cellID = "MessageIndicateCell"
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        messageLabel.font = UIFont.systemFont(ofSize: 10)
        messageLabel.textColor = .lightGray
        messageLabel.backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 247/255, alpha: 1.0)
        messageLabel.layer.masksToBounds = true
        messageLabel.numberOfLines = 1
        messageLabel.textAlignment = .center
        contentView.addSubview(messageLabel)
        
        self.indicationNeighborView = messageLabel
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func apply(message: Message) {
        super.apply(message: message)
        messageLabel.text = String.localizedStringWithFormat(localizedString("someoneRecallMessage"), message.senderUsername)
        self.setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        messageLabel.sizeToFit()
        messageLabel.bounds = CGRect(x: 0, y: 0, width: messageLabel.bounds.width + 2 * InsetLabel.horizontalPadding, height: messageLabel.bounds.height + 2 * InsetLabel.verticalPadding)
        messageLabel.layer.cornerRadius = messageLabel.bounds.height / 2
        messageLabel.center = self.contentView.center
    }
}
