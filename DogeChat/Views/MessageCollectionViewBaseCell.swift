
import UIKit
import AVFoundation
import YPTransition

let nameLabelStartX: CGFloat = 40 + 5 + 5
let nameLabelStartY: CGFloat = 10
let avatarWidth: CGFloat = 40
let avatarMargin: CGFloat = 5

protocol MessageTableViewCellDelegate: AnyObject {
    func imageViewTapped(_ cell: MessageCollectionViewBaseCell, imageView: FLAnimatedImageView, path: String)
    func emojiOutBounds(from cell: MessageCollectionViewBaseCell, gesture: UIGestureRecognizer)
    func emojiInfoDidChange(from oldInfo: EmojiInfo?, to newInfo: EmojiInfo?, cell: MessageCollectionViewBaseCell)
    func pkViewTapped(_ cell: MessageCollectionViewBaseCell, pkView: UIView!)
}

class MessageCollectionViewBaseCell: UICollectionViewCell {
    weak var delegate: MessageTableViewCellDelegate?
    var message: Message!
    var indexPath: IndexPath!
    let nameLabel = UILabel()
    let indicator = UIActivityIndicatorView()
    var emojis = [EmojiInfo: FLAnimatedImageView]()
    var contentSize: CGSize = CGSize.zero
    var activeEmojiView: UIView?
    static let emojiWidth: CGFloat = 150
    static let pkViewHeight: CGFloat = 100
    var cache: NSCache<NSString, NSData>!
    var indicationNeighborView: UIView?
    var pinchGes: UIPinchGestureRecognizer?
    let avatarImageView = FLAnimatedImageView()
    
    static let textCellIdentifier = "MessageCell"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        nameLabel.textColor = .lightGray
        nameLabel.font = UIFont(name: "Helvetica", size: 10) 
        clipsToBounds = true
        
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.masksToBounds = true
        avatarImageView.layer.cornerRadius = avatarWidth / 2
        avatarImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapAvatarAction(_:))))
        avatarImageView.isUserInteractionEnabled = true
        
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(indicator)
    }
        
    override func prepareForReuse() {
        super.prepareForReuse()
        for emojiView in emojis.values {
            emojiView.removeFromSuperview()
        }
        emojis.removeAll()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.masksToBounds = false
        guard let message = message else { return }
        if message.messageSender == .someoneElse {
            nameLabel.isHidden = false
            nameLabel.sizeToFit()
            nameLabel.frame = CGRect(x: nameLabelStartX, y: nameLabelStartY, width: nameLabel.bounds.width, height: nameLabel.bounds.height)
            avatarImageView.frame = CGRect(x: avatarMargin, y: avatarMargin, width: avatarWidth, height: avatarWidth)
            indicator.isHidden = true
        } else {
            nameLabel.isHidden = true
            if message.sendStatus == .fail {
                indicator.isHidden = false
                indicator.startAnimating()
            }
            avatarImageView.frame = CGRect(x: 0, y: 0, width: avatarWidth, height: avatarWidth)
            avatarImageView.center = CGPoint(x: contentView.bounds.width - avatarImageView.bounds.width / 2 - avatarMargin, y: contentView.center.y)
        }
        if message.messageType == .join {
            nameLabel.isHidden = true
        }
    }
    
    func apply(message: Message) {
        self.message = message
        nameLabel.text = message.senderUsername
        DispatchQueue.main.async {
            self.loadAvatar()
        }
        layoutEmojis()
    }
    
    @objc func tapAvatarAction(_ ges: UITapGestureRecognizer) {
        let username = message.senderUsername
        var url: String?
        if message.messageSender == .ourself {
            url = WebSocketManager.shared.myAvatarUrl
        } else {
            switch message.option {
            case .toOne:
                if let index = ContactsTableViewController.usernames.firstIndex(of: username) {
                    url = WebSocketManager.shared.url_pre +  ContactsTableViewController.usersInfos[index].avatarUrl
                }
            case .toAll:
                url = message.avatarUrl
            }
        }
        if let url = url {
            delegate?.imageViewTapped(self, imageView: avatarImageView, path: url)
        }
    }
    
    func loadAvatar() {
        let block: (String) -> Void = { [self] url in
            if let data = ContactTableViewCell.avatarCache[url] {
                if url.hasSuffix(".gif") {
                    avatarImageView.animatedImage = FLAnimatedImage(gifData: data)
                } else {
                    avatarImageView.image = UIImage(data: data)
                }
            }
        }
        if message.messageSender == .ourself {
            let url = WebSocketManager.shared.myAvatarUrl
            block(url)
        } else if message.option == .toOne {
            if let index = ContactsTableViewController.usersInfos.firstIndex(where: { $0.name == message.senderUsername }) {
                let url = WebSocketManager.shared.url_pre +  ContactsTableViewController.usersInfos[index].avatarUrl
                block(url)
            }
        } else { // 群聊 someoneElse
            let url = message.avatarUrl
            guard !url.isEmpty else { return }
            let isGif = url.hasSuffix(".gif")
            if let data = ContactTableViewCell.avatarCache[url] {
                if isGif {
                    avatarImageView.animatedImage = FLAnimatedImage(gifData: data)
                } else {
                    avatarImageView.image = UIImage(data: data)
                }
            } else {
                let capturedMessage = self.message
                SDWebImageManager.shared.loadImage(with: URL(string: url), options: .avoidDecodeImage, progress: nil) { image, data, _, _, _, _ in
                    guard capturedMessage?.uuid == self.message.uuid else { return }
                    if !isGif, let image = image { // is photo
                        let compressed = WebSocketManager.shared.compressEmojis(image)
                        self.avatarImageView.image = UIImage(data: compressed)
                        ContactTableViewCell.avatarCache[url] = compressed
                    } else { // gif图处理
                        self.avatarImageView.animatedImage = FLAnimatedImage(gifData: data)
                        if let data = data {
                            ContactTableViewCell.avatarCache[url] = data
                        }
                    }

                }
            }
        }
    }
    
    func layoutIndicatorViewAndMainView() {
        guard let targetView = indicationNeighborView else { return }
        switch message.messageSender {
        case .ourself:
            targetView.center = CGPoint(x: contentView.bounds.width - (targetView.bounds.width / 2) - nameLabelStartX - safeAreaInsets.right, y: contentView.center.y)
        case .someoneElse:
            targetView.center = CGPoint(x: targetView.bounds.width / 2 + nameLabelStartX, y: contentView.center.y + (nameLabel.bounds.height + nameLabelStartY) / 2)
            avatarImageView.center = CGPoint(x: avatarMargin + avatarWidth / 2, y: targetView.center.y)
        }
        indicator.center = CGPoint(x: targetView.frame.minX - 30, y: targetView.center.y)
        
    }
    
    
    // 计算高度
    class func height(for message: Message) -> CGFloat {
        let maxSize = CGSize(width: 2*(AppDelegate.shared.navigationController.view.bounds.size.width/3), height: CGFloat.greatestFiniteMagnitude)
        let nameHeight = message.messageSender == .ourself ? 0 : (height(forText: message.senderUsername, fontSize: 10, maxSize: maxSize) + 4 )
        let messageHeight = height(forText: message.message, fontSize: 17, maxSize: maxSize)
        var height: CGFloat
        let screenWidth = AppDelegate.shared.navigationController.view.bounds.width
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
                    let maxWidth = AppDelegate.shared.navigationController.view.bounds.width * 0.8
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

// drop
extension MessageCollectionViewBaseCell {
    func didDrop(imageLink: String, image: UIImage, point: CGPoint, cache: NSCache<NSString, NSData>) {
        let width: CGFloat = MessageCollectionViewBaseCell.emojiWidth
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
            let width = emojiInfo.scale * MessageCollectionViewBaseCell.emojiWidth
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
                    if let pinchGes = self.pinchGes {
                        contentView.removeGestureRecognizer(pinchGes)
                    }
                    self.pinchGes = UIPinchGestureRecognizer(target: self, action: #selector(pinchGes(_:)))
                    contentView.addGestureRecognizer(self.pinchGes!)
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
