
import UIKit
import AVFoundation
import DogeChatNetwork
import DogeChatUniversal
import PhotosUI
import DACircularProgress

let nameLabelStartX: CGFloat = 40 + 5 + 5
let nameLabelStartY: CGFloat = 10
let avatarWidth: CGFloat = 40
let avatarMargin: CGFloat = 5
var hapticIndex = 0

protocol MessageTableViewCellDelegate: AnyObject {
    func imageViewTapped(_ cell: MessageCollectionViewBaseCell, imageView: FLAnimatedImageView, path: String, isAvatar: Bool)
    func emojiOutBounds(from cell: MessageCollectionViewBaseCell, gesture: UIGestureRecognizer)
    func emojiInfoDidChange(from oldInfo: EmojiInfo?, to newInfo: EmojiInfo?, cell: MessageCollectionViewBaseCell)
    func pkViewTapped(_ cell: MessageCollectionViewBaseCell, pkView: UIView!)
    func avatarDoubleTap(_ cell: MessageCollectionViewBaseCell)
    func sharedTracksTap(_ cell: MessageCollectionViewBaseCell, tracks: [Track])
    func downloadProgressUpdate(progress: Progress, message: Message)
    func downloadSuccess(message: Message)
}

protocol ContactDataSource: AnyObject {
    var usernames: [String] { get }
    var userInfos: [UserInfo] { get }
}

class MessageCollectionViewBaseCell: DogeChatTableViewCell {
    var cookie: String {
        socketForUsername(username).cookie
    }
    var manager: WebSocketManager {
        return socketForUsername(username)
    }
    var session: AFHTTPSessionManager {
        return manager.messageManager.session
    }
    weak var delegate: MessageTableViewCellDelegate?
    var message: Message!
    var indexPath: IndexPath!
    let nameLabel = UILabel()
    var isHistory = true
    var tapContentView: UITapGestureRecognizer!
    let indicator = UIActivityIndicatorView()
    var emojis = [EmojiInfo: FLAnimatedImageView]()
    var contentSize: CGSize {
        return self.contentView.bounds.size
    }
    var username = ""
    var activeEmojiView: UIView?
    static let emojiWidth: CGFloat = 80
    static let pkViewHeight: CGFloat = 100
    var cache: NSCache<NSString, NSData>!
    var indicationNeighborView: UIView?
    var pinchGes: UIPinchGestureRecognizer?
    let avatarImageView = FLAnimatedImageView()
    let avatarDoubleTapGes = UITapGestureRecognizer()
    let avatapSingleTapGes = UITapGestureRecognizer()
    let timeLabel = UILabel()
    weak var contactDataSource: ContactDataSource?
    let progress = DACircularProgressView()
    
    static let textCellIdentifier = "MessageCell"
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        nameLabel.textColor = .lightGray
        nameLabel.font = UIFont(name: "Helvetica", size: 10) 
        clipsToBounds = true
        self.selectionStyle = .blue
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.masksToBounds = true
        avatarImageView.layer.cornerRadius = avatarWidth / 2
        avatapSingleTapGes.addTarget(self, action: #selector(tapAvatarAction(_:)))
        avatarImageView.addGestureRecognizer(avatapSingleTapGes)
        avatarImageView.isUserInteractionEnabled = true
        addDoubleTapForAvatar()
        
        
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.numberOfLines = 2
        timeLabel.adjustsFontSizeToFitWidth = true
        timeLabel.isHidden = true
        
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(indicator)
        contentView.addSubview(timeLabel)
        contentView.addSubview(progress)
        
        indicator.startAnimating()
        progress.isHidden = true
        progress.thicknessRatio = 0.3
        progress.bounds = CGRect(x: 0, y: 0, width: 25, height: 25)
    }
        
    override func prepareForReuse() {
        super.prepareForReuse()
        cleanEmojis()
        avatarImageView.image = nil
        avatarImageView.animatedImage = nil
        progress.isHidden = true
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
            indicator.isHidden = message.sendStatus == .success
            if message.sendStatus == .fail {
                indicator.startAnimating()
            }
            avatarImageView.frame = CGRect(x: 0, y: 0, width: avatarWidth, height: avatarWidth)
            avatarImageView.center = CGPoint(x: contentView.bounds.width - avatarImageView.bounds.width / 2 - avatarMargin, y: contentView.center.y)
        }
        if message.messageType == .join {
            nameLabel.isHidden = true
        }
        layoutEmojis()
        timeLabel.sizeToFit()
        var timeLabelCenter = contentView.center
        timeLabelCenter.x += (contentView.bounds.width / 2 + 5 + timeLabel.bounds.width / 2)
        timeLabel.center = timeLabelCenter
    }
    
    func layoutEmojis() {
        for (emojiInfo, imageView) in emojis {
            let emojiSize = MessageCollectionViewBaseCell.sizeFromStr(emojiInfo.imageLink)
            let width = emojiInfo.scale * MessageCollectionViewBaseCell.emojiWidth
            let contentSize = self.contentSize
            var size = CGSize(width: width, height: width)
            if let emojiSize = emojiSize {
                size = CGSize(width: width, height: width / emojiSize.width * emojiSize.height)
            }
            let origin = CGPoint(x: emojiInfo.x * contentSize.width - size.width / 2, y: max(0, emojiInfo.y) * contentSize.height - size.height / 2)
            imageView.frame = CGRect(origin: origin, size: size)
            imageView.layer.masksToBounds = true
            imageView.layer.cornerRadius = min(size.width, size.height) / 10
        }
    }
    
    func apply(message: Message) {
        self.message = message
        nameLabel.text = message.senderUsername
        if isHistory {
            nameLabel.text = message.senderUsername + "   " + (message.date).replacingOccurrences(of: "\n", with: "  ")
        }
        avatarDoubleTapGes.isEnabled = message.messageSender == .someoneElse
        timeLabel.text = message.date
//        loadAvatar()
//        addEmojis()
    }
    
    func cleanEmojis() {
        for emojiView in emojis.values {
            emojiView.removeFromSuperview()
        }
        emojis.removeAll()
    }
    
    func cleanAvatar() {
        self.avatarImageView.animatedImage = nil
        self.avatarImageView.image = nil
    }
    
    public func loadAvatar() {
        self._loadAvatar()
    }
    
    @objc func tapAvatarAction(_ ges: UITapGestureRecognizer) {
        let username = message.senderUsername
        var url: String?
        if message.messageSender == .ourself {
            url = WebSocketManager.shared.messageManager.myAvatarUrl
        } else {
            switch message.option {
            case .toOne:
                if let index = contactDataSource?.usernames.firstIndex(of: username),
                   let path = contactDataSource?.userInfos[index].avatarUrl {
                    url = WebSocketManager.shared.url_pre + path
                }
            case .toAll:
                url = message.avatarUrl
            }
        }
        if let url = message.imageLocalPath?.absoluteString ?? url {
            delegate?.imageViewTapped(self, imageView: avatarImageView, path: url, isAvatar: true)
        }
    }
    
    
    
    private func _loadAvatar() {
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
            let url = manager.messageManager.myAvatarUrl
            block(url)
        } else if message.option == .toOne {
            if let index = contactDataSource?.userInfos.firstIndex(where: { $0.name == message.senderUsername }),
               let path = contactDataSource?.userInfos[index].avatarUrl {
                let url = WebSocketManager.shared.url_pre + path
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
                SDWebImageManager.shared.loadImage(with: URL(string: url), options: [.avoidDecodeImage, .allowInvalidSSLCertificates], progress: nil) { [weak self] image, data, _, _, _, _ in
                    guard let self = self, capturedMessage?.uuid == self.message.uuid else { return }
                    if !isGif, let image = image { // is photo
                        let compressed = WebSocketManager.shared.messageManager.compressEmojis(image)
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
            indicator.center = CGPoint(x: targetView.frame.minX - 30, y: targetView.center.y)
        case .someoneElse:
            targetView.center = CGPoint(x: targetView.bounds.width / 2 + nameLabelStartX, y: contentView.center.y + (nameLabel.bounds.height + nameLabelStartY) / 2)
            avatarImageView.center = CGPoint(x: avatarMargin + avatarWidth / 2, y: targetView.center.y)
            indicator.center = CGPoint(x: targetView.frame.maxX + 30, y: targetView.center.y)
        }
        progress.center = indicator.center
    }
    
    
    // 计算高度
    class func height(for message: Message, username: String) -> CGFloat {
        let maxSize = CGSize(width: 2*(AppDelegate.shared.widthFor(side: .right, username: username)/3), height: CGFloat.greatestFiniteMagnitude)
        let nameHeight = message.messageSender == .ourself ? 0 : (height(forText: message.senderUsername, fontSize: 10, maxSize: maxSize) + 4 )
        let messageHeight = height(forText: message.message, fontSize: message.fontSize, maxSize: maxSize)
        var height: CGFloat
        let screenWidth = AppDelegate.shared.widthFor(side: .right, username: username)
        let screenHeight = AppDelegate.shared.heightFor(side: .right, username: username)
        switch message.messageType {
        case .join, .text, .voice:
            height = nameHeight + messageHeight + 32 + 16
        case .image, .livePhoto, .video:
            if let size = sizeForImageOrVideo(message) {
                let scale: CGFloat = message.messageType == .image ? 0.5 : 0.65
                if screenWidth < screenHeight {
                    let width = min(screenWidth * scale, size.width)
                    height = size.height * width / size.width + nameHeight + 30
                } else {
                    height = min(screenHeight * scale, size.height) + nameHeight + 30
                    
                }
                message.imageSize = size
            } else {
                height = nameHeight + 150
            }
        case .draw:
            if  #available(iOS 14.0, *) {
                height = nameHeight + pkViewHeight
                let block: (CGRect) -> CGFloat = { bounds in
                    let maxWidth = screenWidth * 0.8
                    if bounds.maxX > maxWidth {
                        let ratio = maxWidth / bounds.maxX
                        return bounds.height * ratio + nameHeight + bounds.origin.y * ratio + 30
                    } else {
                        return nameHeight + bounds.maxY + 30
                    }
                }
                if let pkDrawing = getPKDrawing(message: message) as? PKDrawing {
                    let bounds = pkDrawing.bounds
                    height = block(bounds)
                } else if let bounds = message.drawBounds {
                    height = block(bounds)
                } else if let bounds = boundsForDraw(message) {
                    height = block(bounds)
                } else {
                    height = 350
                }
            } else {
                height = 0
            }
        case .track:
            height = 120
        }
        var wholeFrame = CGRect(x: 0, y: 0, width: screenWidth, height: max(0, height))
        for emojiInfo in message.emojisInfo {
            let size = CGSize(width: emojiWidth * emojiInfo.scale, height: emojiWidth * emojiInfo.scale)
            let point = CGPoint(x: screenWidth * emojiInfo.x - size.width / 2, y: height * emojiInfo.y - size.height / 2)
            let frame = CGRect(origin: point, size: size)
            wholeFrame = wholeFrame.union(frame)
        }
        message.cellHeight = wholeFrame.height
        return wholeFrame.height
    }
    
    class func boundsForDraw(_ message: Message) -> CGRect? {
        if let str = message.pkDataURL {
            var components = str.components(separatedBy: "+")
            if components.count >= 4 {
                let height = Int(components.removeLast())!
                let width = Int(components.removeLast())!
                let y = Int(components.removeLast())!
                let x = Int(components.removeLast())!
                return CGRect(x: x, y: y, width: width, height: height)
            }
        }
        return nil
    }
    
    class func sizeForImageOrVideo(_ message: Message) -> CGSize? {
        if message.imageSize != .zero {
            return message.imageSize
        }
        var _str: String?
        if message.imageURL != nil {
            _str = message.imageURL
        } else if message.videoURL != nil {
            _str = message.videoURL
        }
        guard let str = _str else { return nil }
        return sizeFromStr(str)
    }
    
    class func sizeFromStr(_ str: String) -> CGSize? {
        var str = str as NSString
        str = str.replacingOccurrences(of: ".jpeg", with: "") as NSString
        str = str.replacingOccurrences(of: ".gif", with: "") as NSString
        str = str.replacingOccurrences(of: ".mov", with: "") as NSString
        var components = str.components(separatedBy: "+")
        if components.count >= 2, let height = Int(components.removeLast()), let width = Int(components.removeLast()) {
            return CGSize(width: width, height: height)
        }
        return nil
    }
    
    class func height(forText text: String, fontSize: CGFloat, maxSize: CGSize) -> CGFloat {
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
        playHaptic()
        let emojiInfo = EmojiInfo(x: max(0, point.x/self.contentSize.width), y: max(0, point.y/self.contentSize.height), rotation: 0, scale: 1, imageLink: imageLink, lastModifiedBy: WebSocketManager.shared.messageManager.myName)
        message.emojisInfo.append(emojiInfo)
        delegate?.emojiInfoDidChange(from: nil, to: emojiInfo, cell: self)
    }
    
    func addEmojis() {
        for emojiInfo in message.emojisInfo {
            let capturedMessage = message
            let imageView = FLAnimatedImageView()
            imageView.contentMode = .scaleAspectFit
            contentView.addSubview(imageView)
            contentView.bringSubviewToFront(imageView)
            emojis[emojiInfo] = imageView
            getCacheImage(from: cache, path: emojiInfo.imageLink) { [weak self] (image, data) in
                guard let self = self, self.message == capturedMessage else {
                    return
                }
                if let data = data {
                    if emojiInfo.imageLink.hasSuffix(".gif") {
                        DispatchQueue.global().async {
                            let image = FLAnimatedImage(gifData: data)
                            DispatchQueue.main.async {
                                imageView.animatedImage = image
                            }
                        }
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
        playHaptic()
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
                playHaptic()
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
        hapticIndex += 1
        var intensity = min(scale, 1)
        intensity = max(0.4, scale)
        if hapticIndex % 8 == 0 { playHaptic(intensity) }
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
        playHaptic()
        if !contentView.bounds.contains(point) { //超出当前cell了，要更换indexPath了
            delegate?.emojiOutBounds(from: self, gesture: ges)
        } else {
            if let (_emojiInfo, _, _) = getIndex(for: ges),
               let emojiInfo = _emojiInfo {
                guard let copy = emojiInfo.copy() as? EmojiInfo else { return }
                emojiInfo.x = point.x / AppDelegate.shared.widthFor(side: .right, username: username)
                emojiInfo.y = point.y / contentSize.height
                delegate?.emojiInfoDidChange(from: copy, to: emojiInfo, cell: self)
            }
        }
    }
    
}
