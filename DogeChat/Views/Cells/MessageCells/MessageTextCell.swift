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
import YYText
import DogeChatCommonDefines

class MessageTextCell: MessageBaseCell {
    
    static var atColor = #colorLiteral(red: 0, green: 0.4159892797, blue: 1, alpha: 1)
    static let atDefaultColor = #colorLiteral(red: 0, green: 0.4159892797, blue: 1, alpha: 1)
    static var sendTextColor = UIColor.white
    static let sendTextDefaultColor = UIColor.white
    static var receiveTextColor = UIColor.white
    static let receiveTextDefaultColor = UIColor.white
    static var sendBubbleColor = UIColor(red: 24/255, green: 180/255, blue: 128/255, alpha: 1.0)
    static let sendBubbleDefaultColor = UIColor(red: 24/255, green: 180/255, blue: 128/255, alpha: 1.0)
    static var receiveBubbleColor = #colorLiteral(red: 0.09282096475, green: 0.7103053927, blue: 1, alpha: 1)
    static let receiveBubbleDefaultColor = #colorLiteral(red: 0.09282096475, green: 0.7103053927, blue: 1, alpha: 1)

    
    static let macCatalystMaxTextLength = Int.max
    static let iosMaxTextLength = Int.max
    static let cellID = "MessageTextCell"
    static let macCatalystFontSizeOffset: CGFloat = 0
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

        messageLabel.displaysAsynchronously = true
        messageLabel.layer.masksToBounds = true
        messageLabel.textColor = .white
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .left
        messageLabel.isUserInteractionEnabled = true
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
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard message != nil else { return }
        layoutForTextMessage()
        layoutIndicatorViewAndMainView()
        messageLabel.layer.cornerRadius = min(messageLabel.bounds.size.height/2.0, 20)
    }
    
    override func apply(message: Message) {
        super.apply(message: message)
        textLabelDoubleTap.isEnabled = message.messageType == .text
        let textURLAndRange = message.text.webUrlifyWithountChange()
        textLabelSingleTap.isEnabled = textURLAndRange != nil
        
        let fontSize = min(maxFontSize, message.fontSize * fontSizeScale + (isMac() ? Self.macCatalystFontSizeOffset : 0))
        messageLabel.font = UIFont.systemFont(ofSize: fontSize)
        
        if message.messageSender == .ourself {
            messageLabel.backgroundColor = Self.sendBubbleColor
            messageLabel.textColor = Self.sendTextColor
        } else {
            messageLabel.backgroundColor = Self.receiveBubbleColor
            messageLabel.textColor = Self.receiveTextColor
        }
        messageLabel.layer.backgroundColor = messageLabel.backgroundColor?.cgColor

        if message.messageType == .text {
            let attrStr = NSMutableAttributedString(attributedString: processText())
            if let textURLAndRange = textURLAndRange {
                let range = textURLAndRange.range
                if range.location + range.length <= attrStr.length {
                    attrStr.addAttributes([.underlineStyle: NSNumber(integerLiteral: NSUnderlineStyle.single.rawValue)], range: textURLAndRange.range)
                }
            }
            messageLabel.attributedText = processAtFor(attributedString: attrStr, message: message)
        } else if message.messageType == .voice {
            var count = message.voiceDuration
            count = min(count, 25)
            count = max(count, 3)
            let str = Array(repeating: " ", count: count).joined()
            messageLabel.text = message.messageSender == .someoneElse ? str + "\(message.voiceDuration)''" : "\(message.voiceDuration)''" + str
        }
        setNeedsLayout()
    }
    
    func processText() -> NSAttributedString {
        var text = message.text
        var length = Self.iosMaxTextLength
        #if targetEnvironment(macCatalyst)
        length = Self.macCatalystMaxTextLength
        #endif
        if text.count > length {
            text = text.prefix(length) + "..."
        }
        let attr = NSAttributedString(string: text, attributes: [.paragraphStyle : Self.paraStyle,
                                                                 .font : messageLabel.font!,
                                                                 .foregroundColor : messageLabel.textColor!])
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
                    res.addAttributes([.foregroundColor : Self.atColor,
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
        let size = MessageBaseCell.computeTextSizeForMessage(self.message, viewSize: contentView.bounds.size, userID: manager?.myInfo.userID)
        let width = min(size.width, self.contentView.bounds.width * MessageBaseCell.maxWidthRatio) + 2 * Label.horizontalPadding
        messageLabel.bounds = CGRect(x: 0, y: 0, width: width, height: size.height + 2 * Label.verticalPadding)
    }
    
//    func layoutForRevokeMessage() {
//        messageLabel.isHidden = false
//        messageLabel.font = UIFont.systemFont(ofSize: 10)
//        messageLabel.textColor = .lightGray
//        messageLabel.backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 247/255, alpha: 1.0)
//        messageLabel.layer.backgroundColor = messageLabel.backgroundColor?.cgColor
//        var size = MessageBaseCell.size(forText: message.text, fontSize: 10, maxSize: CGSize(width: self.contentView.bounds.width, height: .greatestFiniteMagnitude), message: nil, userID: nil)
//        size.width += 50
//        size.height += 10
//        messageLabel.frame = .init(center: self.contentView.center, size: size)
//    }
    
}
