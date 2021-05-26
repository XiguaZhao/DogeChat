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
import YPTransition

protocol MessageTableViewCellDelegate: AnyObject {
    func imageViewTapped(_ cell: MessageCollectionViewCell, imageView: FLAnimatedImageView, path: String)
    func emojiOutBounds(from cell: MessageCollectionViewCell, gesture: UIGestureRecognizer)
    func emojiInfoDidChange(from oldInfo: EmojiInfo?, to newInfo: EmojiInfo?, cell: MessageCollectionViewCell)
    func pkViewTapped(_ cell: MessageCollectionViewCell, pkView: UIView!)
}

class MessageCollectionViewCell: UICollectionViewCell {
    weak var delegate: MessageTableViewCellDelegate?
    var message: Message!
    var indexPath: IndexPath!
    var messageSender: MessageSender = .ourself
    var sendStatus: SendStatus = .success
    let messageLabel = Label()
    let nameLabel = UILabel()
    let indicator = UIActivityIndicatorView()
    var animatedImageView: FLAnimatedImageView!
    var videoView: AVPlayer!
    let imageDownloader = SDWebImageManager.shared
    var imageConstraint: NSLayoutConstraint!
    var emojis = [EmojiInfo: FLAnimatedImageView]()
    var contentSize: CGSize = CGSize.zero
    var activeEmojiView: UIView?
    static let emojiWidth: CGFloat = 150
    static let pkViewHeight: CGFloat = 100
    var isGif: Bool {
        guard let url = message.imageURL else {
            return false
        }
        return url.hasSuffix(".gif")
    }
    var cache: NSCache<NSString, NSData>!
    
    static let textCellIdentifier = "MessageCell"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        emojis.removeAll()
        for view in contentView.subviews {
            view.removeFromSuperview()
        }
        if let gestures = contentView.gestureRecognizers {
            for ges in gestures {
                contentView.removeGestureRecognizer(ges)
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.masksToBounds = false
        updateViews()
    }
    
    func apply(message: Message) {
        self.message = message
        messageLabel.clipsToBounds = true
        messageLabel.textColor = .white
        messageLabel.numberOfLines = 0
        
        nameLabel.textColor = .lightGray
        nameLabel.font = UIFont(name: "Helvetica", size: 10) //UIFont.systemFont(ofSize: 10)
        nameLabel.translatesAutoresizingMaskIntoConstraints = true
        clipsToBounds = true
        
        messageLabel.isHidden = true
        nameLabel.isHidden = true
        contentView.addSubview(messageLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(indicator)
        
        if message.messageType == .draw {
            downloadPKDataIfNeeded()
            addPKView()
        }
        
        animatedImageView = FLAnimatedImageView()
        
        animatedImageView.translatesAutoresizingMaskIntoConstraints = false
        animatedImageView.isHidden = true
        animatedImageView.contentMode = .scaleAspectFit
        contentView.addSubview(animatedImageView)
        indicator.isHidden = true
        addGestureForImageView()
        nameLabel.text = message.senderUsername
        messageLabel.text = message.message
        messageSender = message.messageSender
        sendStatus = message.sendStatus
        if message.imageURL != nil {
            self.addConstraintsForImageMessage()
        }
        layoutEmojis()
        layoutIfNeeded()
                
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
        if let data = cache.object(forKey: imageUrl as NSString) {
            if !isGif {
                self.animatedImageView.image = UIImage(data: data as Data)
                layoutIfNeeded()
                return
            } else {
                let animatedImage = FLAnimatedImage(gifData: data as Data)
                if animatedImage != nil {
                    self.animatedImageView.animatedImage = animatedImage
                    layoutIfNeeded()
                    return
                } 
            }
        }
        
        imageDownloader.loadImage(with: URL(string: imageUrl), options: .avoidDecodeImage) { (received, total, url) in
        } completed: { [self] (image, data, error, cacheType, finished, url) in
            guard capturedMessage.imageURL == message.imageURL else {
                return
            }
            if !isGif, let image = image { // is photo
                let compressed = WebSocketManager.shared.compressEmojis(image)
                animatedImageView.image = UIImage(data: compressed)
                cache.setObject(compressed as NSData, forKey: imageUrl as NSString)
            } else { // gif图处理
                animatedImageView.animatedImage = FLAnimatedImage(gifData: data)
                if let data = data {
                    cache.setObject(data as NSData, forKey: imageUrl as NSString)
                }
            }
            layoutIfNeeded()
            capturedMessage.sendStatus = .success
        }
    }
    
    func addGestureForImageView() {
        animatedImageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        animatedImageView.addGestureRecognizer(tap)
    }
    
    @objc func imageTapped() {
        delegate?.imageViewTapped(self, imageView: animatedImageView, path: message.imageURL ?? "")
    }
    
    func addConstraintsForImageMessage() {
        let offsetTop: CGFloat = 8
        imageConstraint = NSLayoutConstraint(item: animatedImageView!, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 200)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: offsetTop),
            animatedImageView.topAnchor.constraint(equalTo: (messageSender == .ourself ? contentView.topAnchor : nameLabel.topAnchor), constant: offsetTop + nameLabel.bounds.height + offsetTop),
            animatedImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -offsetTop),
            imageConstraint,
            (messageSender == .ourself ? animatedImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -offsetTop-safeAreaInsets.right) : animatedImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: offsetTop+safeAreaInsets.left))
        ])
    }
    
    // 计算高度
    class func height(for message: Message) -> CGFloat {
        let maxSize = CGSize(width: 2*(UIScreen.main.bounds.size.width/3), height: CGFloat.greatestFiniteMagnitude)
        let nameHeight = message.messageSender == .ourself ? 0 : (height(forText: message.senderUsername, fontSize: 10, maxSize: maxSize) + 4 )
        let messageHeight = height(forText: message.message, fontSize: 17, maxSize: maxSize)
        var height: CGFloat
        let screenWidth = UIScreen.main.bounds.width
        switch message.messageType {
        case .join, .text:
            height = nameHeight + messageHeight + 32 + 16
        case .image:
            height = nameHeight + 150
        case .video:
            height = nameHeight + 180
        case .draw:
            if  #available(iOS 14.0, *) {
                height = nameHeight + pkViewHeight
                if let pkDrawing = message.pkDrawing as? PKDrawing {
                    let bounds = pkDrawing.bounds
                    let maxWidth = UIScreen.main.bounds.width * 0.8
                    if bounds.maxX > maxWidth {
                        let ratio = maxWidth / bounds.maxX
                        height = bounds.height * ratio + nameHeight + bounds.origin.y * ratio + 30
                    } else {
                        height = nameHeight + bounds.maxY + 20
                    }
                }
            } else {
                height = 0
            }
        }
        var wholeFrame = CGRect(x: 0, y: 0, width: screenWidth, height: height)
        for emojiInfo in message.emojisInfo {
            let size = CGSize(width: emojiWidth * emojiInfo.scale, height: emojiWidth * emojiInfo.scale)
            let point = CGPoint(x: screenWidth * emojiInfo.x - size.width / 2, y: height * emojiInfo.y - size.height / 2)
            let frame = CGRect(origin: point, size: size)
            wholeFrame = wholeFrame.union(frame)
        }
        return wholeFrame.height
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

extension MessageCollectionViewCell {
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
        case .draw:
            if #available(iOS 14.0, *) {
                layoutForDrawMessage()
            }
        }
        
        if messageSender == .someoneElse {
            nameLabel.isHidden = false
            nameLabel.sizeToFit()
        } else {
            nameLabel.isHidden = true
        }
        if message.messageType == .join {
            nameLabel.isHidden = true
        }
        messageLabel.layer.cornerRadius = min(messageLabel.bounds.size.height/2.0, 20)
    }
    
    func layoutForJoinMessage() {
        animatedImageView.isHidden = true
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
            
            messageLabel.center = CGPoint(x: bounds.size.width - messageLabel.bounds.size.width/2.0 - 16 - safeAreaInsets.right, y: bounds.size.height/2.0)
            messageLabel.backgroundColor = UIColor(red: 24/255, green: 180/255, blue: 128/255, alpha: 1.0)
            
            indicator.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            let centerOfMessageLabel = messageLabel.center
            indicator.center = CGPoint(x: centerOfMessageLabel.x - messageLabel.bounds.size.width/2.0 - 16, y: centerOfMessageLabel.y)
        } else {
            nameLabel.isHidden = false
            nameLabel.sizeToFit()
            messageLabel.backgroundColor = #colorLiteral(red: 0.09282096475, green: 0.7103053927, blue: 1, alpha: 1)

            messageLabel.center = CGPoint(x: messageLabel.bounds.size.width/2.0 + 16, y: contentView.center.y + (nameLabel.bounds.size.height + 8)/2)
            nameLabel.frame = CGRect(x: messageLabel.frame.origin.x, y: messageLabel.frame.origin.y - 8 - nameLabel.bounds.height, width: nameLabel.bounds.width, height: nameLabel.bounds.height)
        }
    }
    
    func layoutForImageMessage() {
        messageLabel.isHidden = true
        animatedImageView.isHidden = false
    }
    
    func layoutForVideoMessage() {
        messageLabel.isHidden = true
    }
    
    // PencilKit相关
    @available(iOS 14.0, *)
    func layoutForDrawMessage() {
        messageLabel.isHidden = true
        guard let pkView = self.getPKView() else { return }
        let rightMargin:CGFloat = 0
        pkView.frame = CGRect(x: 0, y: 0, width: 0.8 * contentView.bounds.width + 20 - rightMargin, height: contentView.bounds.height - 30)
        pkView.contentSize = CGSize(width: pkView.frame.width, height: 2000)
        if messageSender == .ourself {
            pkView.center = CGPoint(x: contentView.bounds.width - pkView.bounds.width/2 - safeAreaInsets.right - rightMargin , y: contentView.center.y)
        } else {
            pkView.center = CGPoint(x: pkView.bounds.width/2.0 + 16, y: contentView.center.y + (nameLabel.bounds.size.height + 8)/2)
            nameLabel.frame = CGRect(x: 16, y: 8, width: nameLabel.bounds.width, height: nameLabel.bounds.height)
        }
        if let pkDrawing = message.pkDrawing as? PKDrawing {
            var maxWidth = contentView.bounds.width * 0.8
            if UIApplication.shared.statusBarOrientation == .landscapeLeft || UIApplication.shared.statusBarOrientation == .landscapeRight {
                maxWidth = UIScreen.main.bounds.height * 0.8
            }
            if pkDrawing.bounds.maxX > maxWidth {
                let ratio = max(0, maxWidth / pkDrawing.bounds.maxX)
                pkView.drawing = pkDrawing.transformed(using: CGAffineTransform(scaleX: ratio, y: ratio))
                message.pkViewScale = ratio
            } else {
                pkView.drawing = pkDrawing
            }
        }
    }
    
    func addPKView() {
        if #available(iOS 14.0, *) {
            if let pkView = self.getPKView() {
                pkView.removeFromSuperview()
            }
            let pkView = PKView()
            pkView.drawingPolicy = .anyInput
            pkView.isUserInteractionEnabled = false
            self.contentView.addSubview(pkView)
            let tap = UITapGestureRecognizer(target: self, action: #selector(pkViewTapAction(_:)))
            if message.messageSender == .ourself {
                contentView.addGestureRecognizer(tap)
            }
        }
    }
    
    @available(iOS 14.0, *)
    @objc func pkViewTapAction(_ tap: UITapGestureRecognizer) {
        if messageSender == .ourself {
            guard let pkView = self.getPKView() else { return }
            delegate?.pkViewTapped(self, pkView: pkView)
        }
    }
    
    @available(iOS 14.0, *)
    func getPKView() -> PKView? {
        for view in contentView.subviews {
            if view.isKind(of: PKView.self) {
                return view as? PKView
            }
        }
        return nil
    }
    func downloadPKDataIfNeeded() {
        guard #available(iOS 14.0, *),
              let pkDataStr = message.pkDataURL,
              let pkDataURL = URL(string: pkDataStr) else { return }
        let cache = ContactsTableViewController.pkDataCache
        if let cachedPKData = cache.object(forKey: pkDataStr as NSString),
           let pkDrawing = try? PKDrawing(data: cachedPKData as Data) {
            if !message.isDrawing {
                message.pkDrawing = pkDrawing
            }
        } else {
            let capturedMessage = self.message
            DispatchQueue.global().async {
                if let downloadedData = try? Data(contentsOf: pkDataURL),
                   let pkDrawing = try? PKDrawing(data: downloadedData) {
                    cache.setObject(downloadedData as NSData, forKey: pkDataStr as NSString)
                    capturedMessage?.pkDrawing = pkDrawing
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .drawDataDownloadedSuccess, object: capturedMessage)
                    }
                }
            }
        }
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

// drop
extension MessageCollectionViewCell {
    func didDrop(imageLink: String, image: UIImage, point: CGPoint, cache: NSCache<NSString, NSData>) {
        let width: CGFloat = MessageCollectionViewCell.emojiWidth
        let emojiInfo = EmojiInfo(x: max(0, point.x/self.contentSize.width), y: max(0, point.y/self.contentSize.height), rotation: 0, scale: 1, imageLink: imageLink, lastModifiedBy: WebSocketManager.shared.myName)
        message.emojisInfo.append(emojiInfo)
        let frame = CGRect(x: point.x - width / 2, y: point.y - width / 2, width: width, height: width)
        let contentBounds = CGRect(origin: CGPoint(x: 0, y: 0), size: self.contentSize)
        if !contentBounds.contains(frame) {
            delegate?.emojiInfoDidChange(from: nil, to: emojiInfo, cell: self)
            return
        }
        let imageView = FLAnimatedImageView(frame: frame)
        imageView.contentMode = .scaleAspectFit
        contentView.addSubview(imageView)
        if let data = self.cache.object(forKey: imageLink as NSString) {
            contentView.layer.masksToBounds = false
            if imageLink.hasSuffix(".gif") {
                imageView.animatedImage = FLAnimatedImage(gifData: data as Data)
            } else {
                imageView.image = UIImage(data: data as Data)
            }
        } else if (!imageLink.hasSuffix(".gif")), let imageData = cache.object(forKey: imageLink as NSString) {
            imageView.image = UIImage(data: imageData as Data)
        } else { // 到这里就需要来加载gif图了
            SDWebImageManager.shared.loadImage(with: URL(string: imageLink), options: .avoidDecodeImage, progress: nil) { (image, data, error, _, _, _) in
                guard error == nil, let data = data else { return }
                imageView.animatedImage = FLAnimatedImage(gifData: data)
                DispatchQueue.global().async {
                    self.cache.setObject(data as NSData, forKey: imageLink as NSString)
                }
            }
        }
    }
    
    func layoutEmojis() {
        for emojiInfo in message.emojisInfo {
            let width = emojiInfo.scale * MessageCollectionViewCell.emojiWidth
            let contentSize = self.contentSize
            let size = CGSize(width: width, height: width)
            let origin = CGPoint(x: emojiInfo.x * contentSize.width - size.width / 2, y: max(0, emojiInfo.y) * contentSize.height - size.height / 2)
            let imageView = FLAnimatedImageView(frame: CGRect(origin: origin, size: size))
            imageView.contentMode = .scaleAspectFit
            contentView.addSubview(imageView)
            emojis[emojiInfo] = imageView
            WebSocketManager.shared.getCacheImage(from: cache, path: emojiInfo.imageLink) { (image, data) in
                if let data = data {
                    if emojiInfo.imageLink.hasSuffix(".gif") {
                        imageView.animatedImage = FLAnimatedImage(gifData: data)
                    } else {
                        imageView.image = UIImage(data: data)
                    }
                }
            }
            imageView.isUserInteractionEnabled = true
            let beginReceiveGes = UITapGestureRecognizer(target: self, action: #selector(beginReceiveGes(_:)))
            beginReceiveGes.numberOfTapsRequired = 1
            imageView.addGestureRecognizer(beginReceiveGes)
            let deleteGes = UITapGestureRecognizer(target: self, action: #selector(deleteGes(_:)))
            deleteGes.numberOfTapsRequired = 2
            imageView.addGestureRecognizer(deleteGes)
            let moveGes = UIPanGestureRecognizer(target: self, action: #selector(moveGes(_:)))
            imageView.addGestureRecognizer(moveGes)
            moveGes.isEnabled = false
        }
    }
    
    func getIndex(for gesture: UIGestureRecognizer) -> (emojiInfo: EmojiInfo?, messageIndex: Int?, dictIndex: Dictionary<EmojiInfo, FLAnimatedImageView>.Index?)? {
        var res: (emojiInfo: EmojiInfo?, messageIndex: Int?, dictIndex: Dictionary<EmojiInfo, FLAnimatedImageView>.Index?)? = (nil, nil, nil)
        var emojiView = gesture.view
        if gesture.isKind(of: UIPinchGestureRecognizer.self) {
            emojiView = activeEmojiView
        }
        for (emojiInfo, view) in emojis {
            if view == emojiView {
                if let index = message.emojisInfo.firstIndex(of: emojiInfo) {
                    res?.messageIndex = index
                    res?.emojiInfo = emojiInfo
                }
                res?.dictIndex = emojis.index(forKey: emojiInfo)!
                break
            }
        }
        return res
    }
    
    @objc func beginReceiveGes(_ ges: UITapGestureRecognizer) {
        if let view = ges.view, let gestures = view.gestureRecognizers {
            activeEmojiView = view
            for gesture in gestures {
                if gesture.isKind(of: UIPanGestureRecognizer.self) {
                    gesture.isEnabled = true
                    if let gesturesOfContentView = contentView.gestureRecognizers {
                        for gestureOfContentView in gesturesOfContentView {
                            if gestureOfContentView.isKind(of: UIPinchGestureRecognizer.self) {
                                gestureOfContentView.isEnabled = true
                                return
                            }
                        }
                    }
                    let pinchGes = UIPinchGestureRecognizer(target: self, action: #selector(pinchGes(_:)))
                    contentView.addGestureRecognizer(pinchGes)
                }
            }
        }
    }
    
    @objc func deleteGes(_ ges: UITapGestureRecognizer) {
        if let emojiView = ges.view {
            emojiView.removeFromSuperview()
            if let (_emojiInfo, _messageIndex, _dictIndex) = getIndex(for: ges),
               let emojiInfo = _emojiInfo,
               let messageIndex = _messageIndex,
               let dictIndex = _dictIndex {
                message.emojisInfo.remove(at: messageIndex)
                emojis.remove(at: dictIndex)
                // 发送更新的通知
                delegate?.emojiInfoDidChange(from: emojiInfo, to: nil, cell: self)
            }
        }
    }
    
    @objc func pinchGes(_ ges: UIPinchGestureRecognizer) {
        let scale = ges.scale
        guard let emojiView = activeEmojiView else { return }
        emojiView.transform = CGAffineTransform(scaleX: scale, y: scale)
        guard ges.state == .ended else { return }
        ges.isEnabled = false
        if let (_emojiInfo, _messageIndex, _) = getIndex(for: ges),
           let emojiInfo = _emojiInfo,
           let messageIndex = _messageIndex {
            message.emojisInfo[messageIndex].scale *= scale
            guard let copy = emojiInfo.copy() as? EmojiInfo else { return }
            delegate?.emojiInfoDidChange(from: copy, to: emojiInfo, cell: self)
            activeEmojiView = nil
        }
    }
    
    @objc func moveGes(_ ges: UIPanGestureRecognizer) {
        guard let emojiView = ges.view else { return }
        let point = ges.location(in: contentView)
        emojiView.center = point
        guard ges.state == .ended else { return }
        if !contentView.bounds.contains(point) { //超出当前cell了，要更换indexPath了
            delegate?.emojiOutBounds(from: self, gesture: ges)
        } else {
            if let (_emojiInfo, _, _) = getIndex(for: ges),
               let emojiInfo = _emojiInfo {
                guard let copy = emojiInfo.copy() as? EmojiInfo else { return }
                emojiInfo.x = point.x / UIScreen.main.bounds.width
                emojiInfo.y = point.y / contentSize.height
                delegate?.emojiInfoDidChange(from: copy, to: emojiInfo, cell: self)
            }
        }
    }
    
}
