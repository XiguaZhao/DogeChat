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
import AVFoundation

enum MessageSender {
    case ourself
    case someoneElse
}

protocol MessageTableViewCellDelegate: class {
    func imageViewTapped(_ cell: MessageTableViewCell, imageView: FLAnimatedImageView)
}

class MessageTableViewCell: UITableViewCell {
    weak var delegate: MessageTableViewCellDelegate?
    var message: Message!
    var messageSender: MessageSender = .ourself
    var sendStatus: SendStatus = .success
    let messageLabel = Label()
    let nameLabel = UILabel()
    let indicator = UIActivityIndicatorView()
    var animatedImageView: FLAnimatedImageView!
    var videoView: AVPlayer!
    let imageDownloader = SDWebImageManager.shared
    var percentIndicator: DACircularProgressView!
    var imageConstraint: NSLayoutConstraint!
    var isGif: Bool {
        guard let url = message.imageURL else {
            return false
        }
        return url.hasSuffix(".gif")
    }
    
    static let textCellIdentifier = "MessageCell"
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        textLabel?.removeFromSuperview()
        messageLabel.removeFromSuperview()
        indicator.removeFromSuperview()
        animatedImageView.removeFromSuperview()
        percentIndicator.removeFromSuperview()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13.0, *) {
            percentIndicator.progressTintColor = (UITraitCollection.current.userInterfaceStyle == .dark ? .white : .black)
        }
    }
    
    func apply(message: Message) {
        messageLabel.clipsToBounds = true
        messageLabel.textColor = .white
        messageLabel.numberOfLines = 0
        
        nameLabel.textColor = .lightGray
        nameLabel.font = UIFont(name: "Helvetica", size: 10) //UIFont.systemFont(ofSize: 10)
        
        clipsToBounds = true
        
        messageLabel.isHidden = true
        nameLabel.isHidden = true
        contentView.addSubview(messageLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(indicator)
        
        animatedImageView = FLAnimatedImageView()
        percentIndicator = DACircularProgressView()
        
        if #available(iOS 13.0, *) {
            percentIndicator.progressTintColor = (UITraitCollection.current.userInterfaceStyle == .dark ? .white : .black)
        }
        animatedImageView.translatesAutoresizingMaskIntoConstraints = false
        percentIndicator.translatesAutoresizingMaskIntoConstraints = false
        animatedImageView.isHidden = true
        percentIndicator.isHidden = true
        animatedImageView.contentMode = .scaleAspectFit
        contentView.addSubview(animatedImageView)
        contentView.addSubview(percentIndicator)
        indicator.isHidden = true
        addGestureForImageView()
        self.message = message
        nameLabel.text = message.senderUsername
        messageLabel.text = message.message
        messageSender = message.messageSender
        sendStatus = message.sendStatus
        if message.imageURL != nil {
            self.addConstraintsForImageMessage()
        }
        updateViews()
        guard let imageUrl = message.imageURL else { return }
        if imageUrl.hasPrefix("file://") {
            DispatchQueue.global().async {
                if let imageUrl = WebSocketManager.shared.imageDict[message.uuid] as? URL{
                    guard let data = try? Data(contentsOf: imageUrl) else { return }
                    DispatchQueue.main.async {
                        if self.isGif {
                            self.animatedImageView.animatedImage = FLAnimatedImage(gifData: data)
                        } else {
                            guard let image = UIImage(data: data) else { return }
                            self.animatedImageView.image = image
                        }
                    }                    
                }
            }
            return
        }
        // 接下来进入下载操作
        let capturedMessage = message
        if isGif {
            DispatchQueue.global().async {
                guard let url = URL(string: imageUrl), let data = try? Data(contentsOf: url) else { return }
                let fileUrl = URL(string: "file://" + NSTemporaryDirectory() + UUID().uuidString + ".gif")!
                try? data.write(to: fileUrl)
                WebSocketManager.shared.imageDict[message.uuid] = fileUrl
                capturedMessage.imageURL = fileUrl.absoluteString
                capturedMessage.sendStatus = .success
                DispatchQueue.main.async {
                    guard message.imageURL == capturedMessage.imageURL else { return }
                    self.animatedImageView.animatedImage = FLAnimatedImage(gifData: data)
                    self.percentIndicator.removeFromSuperview()
                }
            }
            return
        }
        imageDownloader.loadImage(with: URL(string: imageUrl), options: .allowInvalidSSLCertificates) { (received, total, url) in
            DispatchQueue.main.async {
                let percent = CGFloat(received) / CGFloat(total)
                self.percentIndicator.setProgress(percent, animated: true)
                if percent == 1 {
                    self.percentIndicator.removeFromSuperview()
                }
            }
        } completed: { (image, data, error, cacheType, finished, url) in
            guard capturedMessage.imageURL == message.imageURL else {
                return
            }
            capturedMessage.sendStatus = .success
            self.percentIndicator.removeFromSuperview()
            DispatchQueue.main.async {
                self.animatedImageView.image = image
            }
        }
    }
    
    func addGestureForImageView() {
        animatedImageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        animatedImageView.addGestureRecognizer(tap)
    }
    
    @objc func imageTapped() {
        delegate?.imageViewTapped(self, imageView: animatedImageView)
    }
        
    func addConstraintsForImageMessage() {
        let offsetTop: CGFloat = 8
        imageConstraint = NSLayoutConstraint(item: animatedImageView!, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: contentView.bounds.width/2)

        NSLayoutConstraint.activate([
            animatedImageView.topAnchor.constraint(equalTo: (messageSender == .ourself ? contentView.topAnchor : nameLabel.bottomAnchor), constant: offsetTop),
            animatedImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -offsetTop),
            imageConstraint,
            (messageSender == .ourself ? animatedImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -offsetTop) : animatedImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: offsetTop))
        ])
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: percentIndicator!, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 30),
            NSLayoutConstraint(item: percentIndicator!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 30),
            percentIndicator.centerYAnchor.constraint(equalTo: animatedImageView.centerYAnchor),
            (messageSender == .ourself ? percentIndicator.trailingAnchor.constraint(equalTo: animatedImageView.leadingAnchor, constant: -offsetTop) : percentIndicator.leadingAnchor.constraint(equalTo: animatedImageView.trailingAnchor, constant: offsetTop))
        ])
    }
    
    class func height(for message: Message) -> CGFloat {
        let maxSize = CGSize(width: 2*(UIScreen.main.bounds.size.width/3), height: CGFloat.greatestFiniteMagnitude)
        let nameHeight = message.messageSender == .ourself ? 0 : (height(forText: message.senderUsername, fontSize: 10, maxSize: maxSize) + 4 )
        let messageHeight = height(forText: message.message, fontSize: 17, maxSize: maxSize)
        switch message.messageType {
        case .join, .text:
            return nameHeight + messageHeight + 32 + 16
        case .image:
            return nameHeight + 150
        case .video:
            return nameHeight + 180
        }
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
    func updateViews() {
        
        switch message.messageType {
        case .join:
            layoutForJoinMessage()
        case .text:
            layoutForTextMessage()
        case .image:
            layoutForImageMessage()
        case .video:
            layoutForVideoMessage()
        }
        
        if messageSender == .someoneElse {
            nameLabel.isHidden = false
            nameLabel.sizeToFit()
            nameLabel.center = CGPoint(x: nameLabel.bounds.size.width/2.0 + 16 + 4, y: nameLabel.bounds.size.height/2.0 + 4)
        }
        
        messageLabel.layer.cornerRadius = min(messageLabel.bounds.size.height/2.0, 20)
    }
    
    func layoutForJoinMessage() {
        animatedImageView.isHidden = true
        percentIndicator.isHidden = true
        messageLabel.font = UIFont.systemFont(ofSize: 10)
        messageLabel.textColor = .lightGray
        messageLabel.backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 247/255, alpha: 1.0)
        
        let size = messageLabel.sizeThatFits(CGSize(width: 2*(bounds.size.width/3), height: CGFloat.greatestFiniteMagnitude))
        messageLabel.frame = CGRect(x: 0, y: 0, width: size.width + 32, height: size.height + 16)
        messageLabel.center = CGPoint(x: bounds.size.width/2, y: bounds.size.height/2.0)
    }
    
    func layoutForTextMessage() {
        messageLabel.isHidden = false
        nameLabel.isHidden = false
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
    
    func layoutForImageMessage() {
        messageLabel.isHidden = true
        animatedImageView.isHidden = false
        percentIndicator.isHidden = message.sendStatus == .success

    }
    
    func layoutForVideoMessage() {
        messageLabel.isHidden = true
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
