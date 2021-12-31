//
//  MessageTextCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/28.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatNetwork
import DogeChatUniversal
import AVFoundation

let messageFontSize: CGFloat = 17

class MessageTextCell: MessageBaseCell {
    
    static let macCatalystMaxTextLength = 200
    static let iosMaxTextLength = 5000
    static let cellID = "MessageTextCell"
    static let paraStyle: NSParagraphStyle = {
        let para = NSMutableParagraphStyle()
        para.lineSpacing = Label.lineSpacing
        return para
    }()
    
    let messageLabel = Label()
    var textLabelDoubleTap: UITapGestureRecognizer!
    var textLabelSingleTap: UITapGestureRecognizer!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        messageLabel.layer.masksToBounds = true
        messageLabel.textColor = .white
        messageLabel.numberOfLines = 0
        messageLabel.isUserInteractionEnabled = true
        messageLabel.lineBreakMode = .byTruncatingTail
        contentView.addSubview(messageLabel)
        indicationNeighborView = messageLabel
        
        textLabelDoubleTap = UITapGestureRecognizer(target: self, action: #selector(textLabelDoubleTapAction))
        textLabelDoubleTap.isEnabled = false
        textLabelDoubleTap.numberOfTapsRequired = 2
        
        textLabelSingleTap = UITapGestureRecognizer(target: self, action: #selector(textLabelSingleTapAction))
        textLabelSingleTap.isEnabled = false
        
        textLabelSingleTap.require(toFail: textLabelDoubleTap)
        
        messageLabel.addGestureRecognizer(textLabelDoubleTap)
        messageLabel.addGestureRecognizer(textLabelSingleTap)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.textAlignment = .left
        messageLabel.textColor = .white
        messageLabel.attributedText = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard message != nil else { return }
        if message.messageType == .text || message.messageType == .voice {
            layoutForTextMessage()
            layoutIndicatorViewAndMainView()
        } else {
            layoutForRevokeMessage()
        }
        messageLabel.layer.cornerRadius = min(messageLabel.bounds.size.height/2.0, 20)
    }
    
    override func apply(message: Message) {
        super.apply(message: message)
        textLabelDoubleTap.isEnabled = message.messageType == .text
        let textURLAndRange = message.text.webUrlifyWithountChange()
        textLabelSingleTap.isEnabled = textURLAndRange != nil
        
        messageLabel.font = UIFont(name: "Helvetica", size: min(maxFontSize, message.fontSize * fontSizeScale) + (isMac() ? 3 : 0))

        if message.messageType == .text || message.messageType == .join {
            let attrStr: NSAttributedString
            if let textURLAndRange = textURLAndRange {
                let attributedStr = NSMutableAttributedString(string: message.text)
                attributedStr.addAttributes([.underlineStyle: NSNumber(integerLiteral: NSUnderlineStyle.single.rawValue)], range: textURLAndRange.range)
                attrStr = attributedStr
            } else {
                attrStr = processText()
            }
            messageLabel.attributedText = processAtFor(attributedString: attrStr, message: message)
        } else if message.messageType == .voice {
            var count = message.voiceDuration
            count = min(count, 25)
            count = max(count, 3)
            let str = Array(repeating: " ", count: count).joined()
            messageLabel.text = message.messageSender == .someoneElse ? str + "\(message.voiceDuration)''" : "\(message.voiceDuration)''" + str
        }
        if message.messageSender == .ourself {
            messageLabel.backgroundColor = UIColor(red: 24/255, green: 180/255, blue: 128/255, alpha: 1.0)

        } else {
            messageLabel.backgroundColor = #colorLiteral(red: 0.09282096475, green: 0.7103053927, blue: 1, alpha: 1)
        }
    }
    
    func processText() -> NSAttributedString {
        var text = message.text
        var length = Self.iosMaxTextLength
        #if targetEnvironment(macCatalyst)
        length = Self.macCatalystMaxTextLength
        #endif
        if text.count > length {
            text = (text as NSString).substring(to: length) + "..."
        }
        let attr = NSAttributedString(string: text, attributes: [.paragraphStyle : Self.paraStyle])
        return attr
    }
    
    func processAtFor(attributedString: NSAttributedString, message: Message) -> NSAttributedString {
        guard message.messageType == .text, let group = message.friend as? Group else { return attributedString }
        if message.at.isEmpty {
            return attributedString
        }
        let res = NSMutableAttributedString(attributedString: attributedString)
        for atInfo in message.at {
            if atInfo.userID == group.userID || atInfo.userID == self.manager?.myID {
                if let range = atInfo.range.getRange() {
                    let nsRange = NSRange(location: range.location-1, length: range.length+1)
                    res.addAttributes([.foregroundColor : #colorLiteral(red: 0, green: 0.4159892797, blue: 1, alpha: 1),
                                       .font : UIFont.boldSystemFont(ofSize: messageLabel.font.pointSize)], range: nsRange)
                }
            }
        }
        return res
    }
    
    @objc func textLabelDoubleTapAction() {
        delegate?.textCellDoubleTap(self)
    }
    
    @objc func textLabelSingleTapAction() {
        delegate?.textCellSingleTap(self)
    }
    
    func layoutForTextMessage() {
        var size = messageLabel.sizeThatFits(CGSize(width: 2*(contentView.bounds.width/3), height: CGFloat.greatestFiniteMagnitude))
        size.height = min(size.height, maxTextHeight - ((nameLabel.isHidden ? 0 : nameLabel.bounds.height) + 3 * nameLabelStartY + 2 * Label.verticalPadding))
        messageLabel.bounds = CGRect(x: 0, y: 0, width: size.width + 2 * Label.horizontalPadding, height: size.height + 2 * Label.verticalPadding)
    }
    
    func layoutForRevokeMessage() {
        messageLabel.isHidden = false
        messageLabel.font = UIFont.systemFont(ofSize: 10)
        messageLabel.textColor = .lightGray
        messageLabel.backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 247/255, alpha: 1.0)
        messageLabel.textAlignment = .center
        var size = messageLabel.sizeThatFits(CGSize.zero)
        size.width += 50
        size.height += 10
        let center = CGPoint(x: bounds.size.width/2, y: bounds.size.height/2.0)
        messageLabel.frame = .init(center: center, size: size)
    }
    
    func isJoinOrQuitMessage() -> Bool {
        if let words = messageLabel.text?.components(separatedBy: " ") {
            if words.count >= 2 && words[words.count - 2] == "has" && (words[words.count - 1] == "joined" || words[words.count - 1] == "quited") {
                return true
            }
        }
        return false
    }

}
