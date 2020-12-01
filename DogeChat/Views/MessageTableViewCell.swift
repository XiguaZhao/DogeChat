/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit

enum MessageSender {
  case ourself
  case someoneElse
}

class MessageTableViewCell: UITableViewCell {
  var messageSender: MessageSender = .ourself
  var messageType: MessageType = .text
  var sendStatus: SendStatus = .success
  let messageLabel = Label()
  let nameLabel = UILabel()
  let indicator = UIActivityIndicatorView()
  
  func apply(message: Message) {
    nameLabel.text = message.senderUsername
    messageLabel.text = message.message
    messageSender = message.messageSender
    sendStatus = message.sendStatus
    setNeedsLayout()
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    messageLabel.clipsToBounds = true
    messageLabel.textColor = .white
    messageLabel.numberOfLines = 0
    
    nameLabel.textColor = .lightGray
    nameLabel.font = UIFont(name: "Helvetica", size: 10) //UIFont.systemFont(ofSize: 10)

    clipsToBounds = true
    
    addSubview(messageLabel)
    addSubview(nameLabel)
    addSubview(indicator)
    indicator.isHidden = true
  }
  
  class func height(for message: Message) -> CGFloat {
    let maxSize = CGSize(width: 2*(UIScreen.main.bounds.size.width/3), height: CGFloat.greatestFiniteMagnitude)
    let nameHeight = message.messageSender == .ourself ? 0 : (height(forText: message.senderUsername, fontSize: 10, maxSize: maxSize) + 4 )
    let messageHeight = height(forText: message.message, fontSize: 17, maxSize: maxSize)
    
    return nameHeight + messageHeight + 32 + 16
  }
  
  private class func height(forText text: String, fontSize: CGFloat, maxSize: CGSize) -> CGFloat {
    let font = UIFont(name: "Helvetica", size: fontSize)!
    let attrString = NSAttributedString(string: text, attributes:[NSAttributedString.Key.font: font,
                                                                  NSAttributedString.Key.foregroundColor: UIColor.white])
    let textHeight = attrString.boundingRect(with: maxSize, options: .usesLineFragmentOrigin, context: nil).size.height

    return textHeight
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension MessageTableViewCell {
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if messageType == .join {
      layoutForJoinMessage()
    } else {
      messageLabel.font = UIFont(name: "Helvetica", size: 17) //UIFont.systemFont(ofSize: 17)
      messageLabel.textColor = .white
      
      let size = messageLabel.sizeThatFits(CGSize(width: 2*(bounds.size.width/3), height: CGFloat.greatestFiniteMagnitude))
      messageLabel.frame = CGRect(x: 0, y: 0, width: size.width + 32, height: size.height + 16)
      
      if messageSender == .ourself {
        nameLabel.isHidden = true
        indicator.isHidden = false
        switch sendStatus {
        case .fail:
          indicator.startAnimating()
        case .success:
          indicator.stopAnimating()
          indicator.removeFromSuperview()
        }
        
        messageLabel.center = CGPoint(x: bounds.size.width - messageLabel.bounds.size.width/2.0 - 16, y: bounds.size.height/2.0)
        messageLabel.backgroundColor = UIColor(red: 24/255, green: 180/255, blue: 128/255, alpha: 1.0)
        
        indicator.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        let centerOfMessageLabel = messageLabel.center
        indicator.center = CGPoint(x: centerOfMessageLabel.x - messageLabel.bounds.size.width/2.0 - 16, y: centerOfMessageLabel.y)
      } else {
        nameLabel.isHidden = false
        nameLabel.sizeToFit()
        nameLabel.center = CGPoint(x: nameLabel.bounds.size.width/2.0 + 16 + 4, y: nameLabel.bounds.size.height/2.0 + 4)
        
        messageLabel.center = CGPoint(x: messageLabel.bounds.size.width/2.0 + 16, y: messageLabel.bounds.size.height/2.0 + nameLabel.bounds.size.height + 8)
        messageLabel.backgroundColor = .lightGray
      }
    }
    
    messageLabel.layer.cornerRadius = min(messageLabel.bounds.size.height/2.0, 20)
  }
  
  func layoutForJoinMessage() {
    messageLabel.font = UIFont.systemFont(ofSize: 10)
    messageLabel.textColor = .lightGray
    messageLabel.backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 247/255, alpha: 1.0)
    
    let size = messageLabel.sizeThatFits(CGSize(width: 2*(bounds.size.width/3), height: CGFloat.greatestFiniteMagnitude))
    messageLabel.frame = CGRect(x: 0, y: 0, width: size.width + 32, height: size.height + 16)
    messageLabel.center = CGPoint(x: bounds.size.width/2, y: bounds.size.height/2.0)
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
