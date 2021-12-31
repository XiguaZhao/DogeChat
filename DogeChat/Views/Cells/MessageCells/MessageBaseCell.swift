
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

protocol DownloadUploadProgressDelegate: AnyObject {
    func downloadProgressUpdate(progress: Double, messages: [Message])
}

protocol MessageTableViewCellDelegate: DownloadUploadProgressDelegate {
    func mediaViewTapped(_ cell: MessageBaseCell, path: String, isAvatar: Bool)
    func emojiOutBounds(from cell: MessageBaseCell, gesture: UIGestureRecognizer)
    func emojiInfoDidChange(from oldInfo: EmojiInfo?, to newInfo: EmojiInfo?, cell: MessageBaseCell)
    func pkViewTapped(_ cell: MessageBaseCell, pkView: UIView!)
    func avatarDoubleTap(_ cell: MessageBaseCell)
    func sharedTracksTap(_ cell: MessageBaseCell, tracks: [Track])
    func downloadSuccess(_ cell: MessageBaseCell?, message: Message)
    func longPressCell(_ cell: MessageBaseCell, ges: UILongPressGestureRecognizer!)
    func longPressAvatar(_ cell: MessageBaseCell, ges: UILongPressGestureRecognizer!)
    func textCellDoubleTap(_ cell: MessageBaseCell)
    func textCellSingleTap(_ cell: MessageBaseCell)
    func mapViewTap(_ cell: MessageBaseCell, latitude: Double, longitude: Double)
}

protocol ContactDataSource: AnyObject {
    var friends: [Friend] { get }
}

class MessageBaseCell: DogeChatTableViewCell {
    var cookie: String {
        socketForUsername(username)?.cookie ?? ""
    }
    var manager: WebSocketManager? {
        return socketForUsername(username)
    }
    var session: AFHTTPSessionManager? {
        return manager?.commonWebSocket.httpRequestsManager.session
    }
    weak var delegate: MessageTableViewCellDelegate?
    var message: Message!
    var indexPath: IndexPath!
    let nameLabel = UILabel()
    let referView = ReferView(type: .chatRoomCell)
    var isHistory = true
    var tapContentView: UITapGestureRecognizer!
    let indicator = UIActivityIndicatorView()
    var emojis = [EmojiInfo: FLAnimatedImageView]()
    var contentSize: CGSize {
        return self.contentView.bounds.size
    }
    var username = ""
    var activeEmojiView: UIView?
    static let emojiWidth: CGFloat = 130
    static let pkViewHeight: CGFloat = 100
    lazy var longPressGes: UILongPressGestureRecognizer = {
        return UILongPressGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
    }()
    var avatarLongPress: UILongPressGestureRecognizer!
    var indicationNeighborView: UIView? {
        didSet {
            indicationNeighborView?.isUserInteractionEnabled = true
            indicationNeighborView?.addGestureRecognizer(longPressGes)
            addConstraintForReferView()
        }
    }
    var pinchGes: UIPinchGestureRecognizer?
    let avatarImageView = FLAnimatedImageView()
    let avatarDoubleTapGes = UITapGestureRecognizer()
    let avatapSingleTapGes = UITapGestureRecognizer()
    let timeLabel = UILabel()
    var referViewLeading: NSLayoutConstraint?
    var referViewTrailing: NSLayoutConstraint?
    var referViewWidth: NSLayoutConstraint?
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
        avatarLongPress = UILongPressGestureRecognizer(target: self, action: #selector(onAvatarLongPress(_:)))
        avatarImageView.addGestureRecognizer(avatarLongPress)
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
        contentView.addSubview(referView)
        
        indicator.startAnimating()
        indicator.isHidden = true
        progress.isHidden = true
        progress.thicknessRatio = 0.3
        progress.progressTintColor = UIColor(named: "progressCircle")
        progress.bounds = CGRect(x: 0, y: 0, width: 25, height: 25)
        
        referView.cancleButton.setImage(UIImage(named: "reply"), for: .normal)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        cleanEmojis()
        cleanAvatar()
        avatarImageView.image = nil
        avatarImageView.animatedImage = nil
        progress.isHidden = true
        referView.prepareForReuse()
        referViewLeading?.isActive = false
        referViewTrailing?.isActive = false
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.masksToBounds = false
        guard let message = message else { return }
        if message.messageSender == .someoneElse {
            nameLabel.isHidden = false
            nameLabel.sizeToFit()
            nameLabel.frame = CGRect(x: nameLabelStartX, y: nameLabelStartY, width: nameLabel.bounds.width, height: nameLabel.bounds.height)
            indicator.isHidden = true
        } else {
            nameLabel.isHidden = true
            indicator.isHidden = message.sendStatus == .success
            if message.sendStatus == .fail {
                indicator.startAnimating()
            }
        }
        avatarImageView.bounds = CGRect(x: 0, y: 0, width: avatarWidth, height: avatarWidth)
        if message.messageType == .join {
            nameLabel.isHidden = true
        }
        layoutEmojis()
        timeLabel.sizeToFit()
        var timeLabelCenter = contentView.center
        timeLabelCenter.x += (contentView.bounds.width / 2 + 5 + timeLabel.bounds.width / 2)
        timeLabel.center = timeLabelCenter
    }
    
    func addConstraintForReferView() {
        guard let indicationNeighborView = indicationNeighborView else {
            return
        }
        referView.translatesAutoresizingMaskIntoConstraints = false
        referView.topAnchor.constraint(equalTo: indicationNeighborView.bottomAnchor, constant: ReferView.margin).isActive = true
        referView.heightAnchor.constraint(equalToConstant: ReferView.height).isActive = true
        self.referViewWidth = referView.widthAnchor.constraint(equalToConstant: 50)
        self.referViewWidth?.isActive = true
        self.referViewLeading = referView.leadingAnchor.constraint(equalTo: indicationNeighborView.leadingAnchor)
        self.referViewTrailing = referView.trailingAnchor.constraint(equalTo: indicationNeighborView.trailingAnchor)
    }
    
    @objc func onLongPress(_ ges: UILongPressGestureRecognizer) {
        guard ges.state == .ended else { return }
        delegate?.longPressCell(self, ges: ges)
    }
    
    @objc func onAvatarLongPress(_ ges: UILongPressGestureRecognizer) {
        guard ges.state == .ended else { return }
        delegate?.longPressAvatar(self, ges: ges)
    }
    
    func layoutEmojis() {
        guard let manager = manager else {
            return
        }
        for (emojiInfo, imageView) in emojis {
            let emojiSize = sizeFromStr(emojiInfo.imageLink)
            let width = emojiInfo.scale * MessageBaseCell.emojiWidth
            let contentSize = self.contentSize
            var size = CGSize(width: width, height: width)
            if let emojiSize = emojiSize {
                size = CGSize(width: width, height: width / emojiSize.width * emojiSize.height)
            }
            var x = emojiInfo.x
            let y = emojiInfo.y
            let myID = manager.myID
            if message.option == .toOne { // 私聊
                if (emojiInfo.lastModifiedUserId != myID && message.messageSender == .someoneElse) || (message.messageSender == .ourself && emojiInfo.lastModifiedUserId != myID) {
                    x = 1 - x
                }
            } else { // 群聊
                if (message.messageSender == .ourself && emojiInfo.lastModifiedUserId != myID) || (message.senderUserID == emojiInfo.lastModifiedUserId && message.senderUserID != myID) {
                    x = 1 - x
                }
            }

            let origin = CGPoint(x: x * contentSize.width - size.width / 2, y: max(0, y) * contentSize.height - size.height / 2)
            imageView.frame = CGRect(origin: origin, size: size)
            imageView.layer.masksToBounds = true
            imageView.layer.cornerRadius = min(size.width, size.height) / 10
        }
    }
    
    func apply(message: Message) {
        self.message = message
        avatarImageView.isHidden = message.messageType == .join
        referView.isHidden = message.referMessage == nil
        if let refer = message.referMessage {
            referView.apply(message: refer)
        } 
        var name = message.senderUsername
        if let friend = message.friend, !friend.isGroup {
            if let nickname = manager?.friendsDict[message.senderUserID]?.nickName, !nickname.isEmpty {
                name = nickname
            }
        }
        if isHistory {
            name += "   " + (message.date).replacingOccurrences(of: "\n", with: "  ")
        }
        nameLabel.text = name
        avatarDoubleTapGes.isEnabled = message.messageSender == .someoneElse
        referViewLeading?.isActive = message.messageSender == .someoneElse
        referViewTrailing?.isActive = message.messageSender == .ourself
        timeLabel.text = message.date
        loadAvatar()
        addEmojis()
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
        guard let manager = manager else {
            return
        }
        let userID = message.senderUserID
        var url: String?
        if message.messageSender == .ourself {
            url = manager.messageManager.myAvatarUrl
        } else {
            switch message.option {
            case .toOne:
                if let index = contactDataSource?.friends.firstIndex(where: { $0.userID == userID }),
                   let path = contactDataSource?.friends[index].avatarURL {
                    url = WebSocketManager.url_pre + path
                }
            case .toGroup:
                url = message.avatarUrl
            }
        }
        if let url = message.imageLocalPath?.absoluteString ?? url {
            delegate?.mediaViewTapped(self, path: url, isAvatar: true)
        }
    }
    
    
    
    private func _loadAvatar() {
        guard let manager = manager else {
            return
        }
        let block: (String) -> Void = { [self] url in
            let isGif = url.hasSuffix(".gif")
            let captured = message
            MediaLoader.shared.requestImage(urlStr: url, type: .image, cookie: nil, syncIfCan: false) { image, data, _ in
                guard captured?.uuid == self.message.uuid, let data = data else { return }
                if !isGif { // is photo
                    self.avatarImageView.image = UIImage(data: data)
                } else { // gif图处理
                    self.avatarImageView.animatedImage = FLAnimatedImage(gifData: data)
                }
            } progress: { _ in
            }
        }
        if message.messageSender == .ourself {
            let url = manager.messageManager.myAvatarUrl
            block(url)
        } else {
            let url = message.avatarUrl
            block(url)
        }
    }
    
    func layoutIndicatorViewAndMainView() {
        guard let targetView = indicationNeighborView, message != nil else { return }
        let hasRefer = message.referMessage != nil
        var referWidth = referView.nameLabel.intrinsicContentSize.width + ReferView.margin + MessageInputView.offset + ReferView.height / 2 + 2 * referView.stackView.spacing
        if !referView.messageLabel.isHidden {
            referWidth += referView.messageLabel.intrinsicContentSize.width
        } else {
            referWidth += ReferView.height
        }
        let contentViewWidth = contentView.bounds.width
        switch message.messageSender {
        case .ourself:
            let y: CGFloat = contentView.center.y - (hasRefer ? ReferView.height + ReferView.margin : 0) / 2
            targetView.center = CGPoint(x: contentView.bounds.width - (targetView.bounds.width / 2) - nameLabelStartX, y: y)
            indicator.center = CGPoint(x: targetView.frame.minX - 30, y: targetView.center.y)
            var avatarCenter = targetView.center
            avatarCenter.x = targetView.frame.maxX + avatarMargin + avatarWidth / 2
            avatarImageView.center = avatarCenter
        case .someoneElse:
            let spaceForReferView = hasRefer ? ReferView.height + ReferView.margin : 0
            targetView.center = CGPoint(x: targetView.bounds.width / 2 + nameLabelStartX, y: contentView.center.y + (nameLabel.bounds.height + nameLabelStartY - spaceForReferView) / 2)
            avatarImageView.center = CGPoint(x: avatarMargin + avatarWidth / 2, y: targetView.center.y)
            indicator.center = CGPoint(x: targetView.frame.maxX + 30, y: targetView.center.y)
        }
        progress.center = indicator.center
        if hasRefer {
            referViewWidth?.constant = (referWidth > contentViewWidth * 0.7) ? contentViewWidth * 0.7 : referWidth
        }
    }
    
    
    // 计算高度
    class func height(for message: Message, tableViewSize: CGSize) -> CGFloat {
        let screenWidth = tableViewSize.width
        let screenHeight = tableViewSize.height
        let maxSize = CGSize(width: 2*(screenWidth/3), height: CGFloat.greatestFiniteMagnitude)
        let nameHeight = message.messageSender == .ourself ? 0 : (height(forText: message.senderUsername, fontSize: 10, maxSize: maxSize) + 4 )
        var rowHeight: CGFloat
        let type = message.messageType
        switch type {
        case .join, .text, .voice:
            let text = message.messageType == .voice ? "  " : message.text
            let messageHeight = height(forText: text, fontSize: min(maxFontSize, type == .join ? 10 : message.fontSize * fontSizeScale) + (isMac() ? 3 : 0), maxSize: maxSize)
            rowHeight = nameHeight + messageHeight + 32 + 2 * Label.verticalPadding
            rowHeight = min(rowHeight, maxTextHeight)
        case .image, .livePhoto, .video:
            let minHeight: CGFloat = 35
            if let size = sizeForImageOrVideo(message) {
                let scale: CGFloat = message.messageType == .image ? 0.5 : 0.65
                if screenWidth < screenHeight {
                    let width = max(minHeight, min(screenWidth * scale, size.width))
                    rowHeight = size.height * width / size.width
                } else {
                    rowHeight = max(minHeight, min(screenHeight * scale, size.height))
                }
                message.imageSize = size
                rowHeight += nameHeight + 30
            } else {
                rowHeight = nameHeight + 150
            }
            rowHeight = min(screenHeight * 0.6, rowHeight)
        case .draw:
            rowHeight = nameHeight + pkViewHeight
            let block: (CGRect) -> CGFloat = { bounds in
                let maxWidth = screenWidth * 0.8
                if bounds.maxX > maxWidth {
                    let ratio = maxWidth / bounds.maxX
                    return bounds.height * ratio + nameHeight + bounds.origin.y * ratio + 30
                } else {
                    return nameHeight + bounds.maxY + 30
                }
            }
            if let bounds = message.drawBounds {
                rowHeight = block(bounds)
            } else if let bounds = boundsForDraw(message) {
                rowHeight = block(bounds)
            } else if let pkDrawing = getPKDrawing(message: message) as? PKDrawing {
                let bounds = pkDrawing.bounds
                rowHeight = block(bounds)
            } else {
                rowHeight = 350
            }
        case .track:
            rowHeight = 120
        case .location:
            rowHeight = 300
        }
        var wholeFrame = CGRect(x: 0, y: 0, width: screenWidth, height: max(0, rowHeight))
        for emojiInfo in message.emojisInfo {
            var emojiHeight = emojiWidth
            if let size = sizeFromStr(emojiInfo.imageLink) {
                emojiHeight = size.height * emojiWidth / size.width
            }
            let size = CGSize(width: emojiWidth * emojiInfo.scale, height: emojiHeight * emojiInfo.scale)
            let point = CGPoint(x: screenWidth * emojiInfo.x - size.width / 2, y: rowHeight * emojiInfo.y - size.height / 2)
            let frame = CGRect(origin: point, size: size)
            wholeFrame = wholeFrame.union(frame)
        }
        message.cellHeight = wholeFrame.height
        return wholeFrame.height + ((message.referMessage == nil && message.referMessageUUID == nil) ? 0 : ReferView.height + ReferView.margin)
    }
    
    class func height(forText text: String, fontSize: CGFloat, maxSize: CGSize) -> CGFloat {
        var text = text
        var length = MessageTextCell.iosMaxTextLength
        #if targetEnvironment(macCatalyst)
        length = MessageTextCell.macCatalystMaxTextLength
        #endif
        if text.count > length {
            text = (text as NSString).substring(to: length) + "..."
        }
        let fontSize = fontSize
        let font = UIFont(name: "Helvetica", size: fontSize)!
        let attrString = NSAttributedString(string: text, attributes:[.font: font,
                                                                      .paragraphStyle: MessageTextCell.paraStyle
                        ])
        let textHeight = attrString.boundingRect(with: maxSize, options: .usesLineFragmentOrigin, context: nil).size.height
        
        return textHeight
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

// drop
extension MessageBaseCell {
    func didDrop(imageLink: String, image: UIImage, point: CGPoint) {
        playHaptic()
        guard let manager = manager else {
            return
        }
        let emojiInfo = EmojiInfo(x: max(0, point.x/self.contentSize.width), y: max(0, point.y/self.contentSize.height), rotation: 0, scale: 1, imageLink: imageLink, lastModifiedBy: manager.myInfo.username, lastModifiedUserId: manager.myInfo.userID ?? "")
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
            let path = emojiInfo.imageLink
            let displayBlock: (Data) -> Void = { data in
                if path.hasSuffix(".gif") {
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
            MediaLoader.shared.requestImage(urlStr: path, type: .image, syncIfCan: false, completion: { image, data, _ in
                guard self.message == capturedMessage, let data = data else { return }
                displayBlock(data)
            }, progress: nil)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.tableView?.dragInteractionEnabled = true
        }
        if let view = ges.view, let gestures = view.gestureRecognizers {
            activeEmojiView = view
            for gesture in gestures {
                if gesture.isKind(of: UIPanGestureRecognizer.self) {
                    gesture.isEnabled = true
                    self.tableView?.dragInteractionEnabled = false
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
                emojiInfo.x = point.x / self.contentView.frame.width
                emojiInfo.y = point.y / contentSize.height
                delegate?.emojiInfoDidChange(from: copy, to: emojiInfo, cell: self)
            }
        }
    }
    
}
