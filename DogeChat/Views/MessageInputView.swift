import UIKit
import DogeChatNetwork

enum InputViewToolButtonType {
    case voice
    case camera
    case photo
    case livePhoto
    case video
    case draw
    case add
    case location
    case at
}

protocol MessageInputDelegate: AnyObject {
    func sendWasTapped(content: String)
    func textViewFontSizeChange(_ textView: UITextView, oldSize: CGFloat, newSize: CGFloat)
    func textViewFontSizeChangeEnded(_ textView: UITextView)
    func toolButtonTap(_ button: UIButton, type: InputViewToolButtonType)
    func messageInputBarFrameChange(_ endFrame: CGRect, shouldDown: Bool, ignore: Bool)
}

var messageBarHeight: CGFloat {
    MessageInputView.defaultHeight + safeArea.bottom
}

class MessageInputView: DogeChatStaticBlurView {
    
    enum EmojiButtonStatus {
        case normal
        case pin
    }
    
    weak var delegate: MessageInputDelegate?
    
    static let largeConfig: Any? = {
        if #available(iOS 13.0, *) {
            return UIImage.SymbolConfiguration(pointSize: 150, weight: .bold, scale: .large)
        } else {
            return nil
        }
    }()

    static var maxHeight: CGFloat {
        safeArea.bottom + 186
    }
    static let textViewMaxHeight: CGFloat = 160
    static let defaultHeight: CGFloat = 86
    static let textViewDefaultFontSize: CGFloat = 17
    static let ratioOfEmojiView: CGFloat = 0.45
    static let offset: CGFloat = 12
    let width: CGFloat = 30
    var emojiButtonStatus: EmojiButtonStatus = .normal
    let textView = DogeChatTextView()
    let addButton = UIButton()
    let emojiButton = UIButton()
    let upArrowButton = UIButton()
    let voiceButton = UIButton()
    var beginY: CGFloat = 0
    var frameShouldAnimate = true
    var directionUp = true
    var toolStack: UIStackView!
    let cameraButton = UIButton()
    let photoButton = UIButton()
    let livePhotoButton = UIButton()
    let videoButton = UIButton()
    let drawButton = UIButton()
    let locationButton = UIButton()
    let atButton = UIButton()
    let referView = ReferView(type: .inputView)
    var lastInset: UIEdgeInsets = .zero
    weak var referViewBottomContraint: NSLayoutConstraint!
    var isActive: Bool {
        return textView.isFirstResponder || self.frame.maxY < (self.superview?.bounds.height)!
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
                
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor(red: 200/255, green: 200/255, blue: 200/255, alpha: 0.6).cgColor
        textView.layer.borderWidth = 2
        textView.font = UIFont.systemFont(ofSize: MessageInputView.textViewDefaultFontSize)
        textView.returnKeyType = .send
        textView.backgroundColor = .clear
        referView.translatesAutoresizingMaskIntoConstraints = false
        addButton.translatesAutoresizingMaskIntoConstraints = false
        emojiButton.translatesAutoresizingMaskIntoConstraints = false
        upArrowButton.translatesAutoresizingMaskIntoConstraints = false
        voiceButton.translatesAutoresizingMaskIntoConstraints = false
        recoverEmojiButton()
        if #available(iOS 13, *) {
            let largeConfig = Self.largeConfig as! UIImage.Configuration
            addButton.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: largeConfig), for: .normal)
            locationButton.setImage(UIImage(systemName: "location.circle.fill", withConfiguration: largeConfig), for: .normal)
            upArrowButton.setImage(UIImage(systemName: "arrow.up", withConfiguration: largeConfig), for: .normal)
            voiceButton.setImage(UIImage(systemName: "mic.circle.fill", withConfiguration: largeConfig), for: .normal)
            cameraButton.setImage(UIImage(systemName: "camera.circle.fill", withConfiguration: largeConfig), for: .normal)
            livePhotoButton.setImage(UIImage(systemName: "livephoto", withConfiguration: largeConfig), for: .normal)
            videoButton.setImage(UIImage(systemName: "video.circle.fill", withConfiguration: largeConfig), for: .normal)
            drawButton.setImage(UIImage(systemName: "pencil.circle.fill", withConfiguration: largeConfig), for: .normal)
        } else {
            addButton.setImage(UIImage(named: "add"), for: .normal)
            upArrowButton.setImage(UIImage(named: "arrowUp"), for: .normal)
            voiceButton.setImage(UIImage(named: "voice"), for: .normal)
            cameraButton.setImage(UIImage(named: "camera"), for: .normal)
            livePhotoButton.setImage(UIImage(named: "live"), for: .normal)
            videoButton.setImage(UIImage(named: "video"), for: .normal)
            locationButton.setImage(UIImage(named: "dingwei"), for: .normal)
        }
        if #available(iOS 13, *) {
            photoButton.setImage(UIImage(named: "xiangce"), for: .normal)
        } else {
            photoButton.setImage(UIImage(named: "xiangce-2"), for: .normal)
        }
        
        if #available(iOS 13, *) {} else {
            drawButton.isHidden = true
        }

        if #available(iOS 14, *) {
            atButton.setImage(UIImage(systemName: "at.circle.fill", withConfiguration: Self.largeConfig as? UIImage.Configuration), for: .normal)
        } else {
            atButton.setImage(UIImage(named: "huati"), for: .normal)
        }

        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        emojiButton.addTarget(self, action: #selector(emojiButtonTapped), for: .touchUpInside)
        voiceButton.addTarget(self, action: #selector(voiceButtonTapped(_:)), for: .touchUpInside)
        cameraButton.addTarget(self, action: #selector(cameraButtonTapped(_:)), for: .touchUpInside)
        photoButton.addTarget(self, action: #selector(photoButtonTapped(_:)), for: .touchUpInside)
        livePhotoButton.addTarget(self, action: #selector(livePhotoButtonTapped(_:)), for: .touchUpInside)
        videoButton.addTarget(self, action: #selector(videoButtonTapped(_:)), for: .touchUpInside)
        drawButton.addTarget(self, action: #selector(drawButtonTapped(_:)), for: .touchUpInside)
        locationButton.addTarget(self, action: #selector(locationButtonTapped(_:)), for: .touchUpInside)
        atButton.addTarget(self, action: #selector(atButtonTapped(_:)), for: .touchUpInside)
        
        toolStack = UIStackView(arrangedSubviews: [atButton, voiceButton, cameraButton, photoButton, livePhotoButton, videoButton, drawButton, locationButton, addButton])
        toolStack.alignment = .center
        toolStack.distribution = .equalSpacing
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(upArrowTouch(_:)))
        upArrowButton.addGestureRecognizer(pan)
        addSubview(textView)
        addSubview(emojiButton)
        addSubview(upArrowButton)
        addSubview(toolStack)
        addSubview(referView)
        
        if isMac() {
            drawButton.isHidden = true
        }
        
        referView.alpha = 0
        
        if #available(iOS 13, *) {
            toolStack.arrangedSubviews.forEach { button in
                button.mas_makeConstraints { make in
                    make?.width.height().mas_lessThanOrEqualTo()(button == photoButton ? width - 3 : width)
                }
            }
        } else {
            toolStack.arrangedSubviews.forEach { button in
                (button as? UIButton)?.imageView?.contentMode = .scaleAspectFit
                button.mas_makeConstraints { make in
                    make?.width.height().mas_lessThanOrEqualTo()(width - 5)
                }
            }
        }
                
        
        upArrowButton.isHidden = true
        upArrowButton.mas_makeConstraints { make in
            make?.edges.equalTo()(emojiButton)?.offset()
        }
        
        emojiButton.mas_makeConstraints { make in
            make?.right.equalTo()(self.mas_safeAreaLayoutGuideRight)?.offset()(-Self.offset)
            make?.centerY.equalTo()(self.textView)
            make?.width.height().mas_equalTo()(width)
        }
        
        NSLayoutConstraint.activate([
            referView.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor, constant: Self.offset),
            referView.trailingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.trailingAnchor, constant: -Self.offset),
            referView.heightAnchor.constraint(equalToConstant: ReferView.height)
        ])
        self.referViewBottomContraint = referView.bottomAnchor.constraint(equalTo: self.topAnchor, constant: ReferView.height)
        self.referViewBottomContraint.isActive = true
        
    }
    
    
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        if safeAreaInsets.bottom != .zero {
            setNeedsUpdateConstraints()
        }
    }
    
    override func updateConstraints() {
        
        let width: CGFloat = 30

        toolStack.mas_updateConstraints { make in
            make?.left.equalTo()(self.mas_safeAreaLayoutGuideLeft)?.offset()(Self.offset)
            make?.right.equalTo()(self.mas_safeAreaLayoutGuideRight)?.offset()(-Self.offset)
            let middle: CGFloat = safeAreaInsets.bottom == 0 ? Self.offset - 5 : Self.offset - 3
            make?.top.equalTo()(textView.mas_bottom)?.offset()(middle)
        }
        
        textView.mas_updateConstraints { make in
            make?.left.equalTo()(self.mas_safeAreaLayoutGuideLeft)?.offset()(Self.offset)
            make?.top.equalTo()(self)?.offset()(Self.offset - 4)
            make?.trailing.equalTo()(emojiButton.mas_leading)?.offset()(-Self.offset)
            let safeAreaBottom = safeAreaInsets.bottom == 0 ? -5 : safeArea.bottom - 14
            make?.bottom.equalTo()(self)?.offset()(-(safeAreaBottom + width + Self.offset * 2 - 6))
        }
        
        super.updateConstraints()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let converted = self.convert(point, to: self.referView)
        let inset: CGFloat = -20
        let edgeInsets = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        if self.referView.alpha > 0 {
            if self.referView.cancleButton.frame.inset(by: edgeInsets).contains(converted) {
                return referView.cancleButton
            } else if self.referView.atButton.frame.inset(by: edgeInsets).contains(converted) {
                return referView.atButton
            } else if self.referView.bounds.inset(by: edgeInsets).contains(converted) {
                return referView.stackView
            }
        }
        return super.hitTest(point, with: event)
    }
    
    func frameDown() {
        let height = self.window?.bounds.height ?? UIScreen.main.bounds.height
        let frame = CGRect(x: 0, y: height, width: 0, height: 100)
        delegate?.messageInputBarFrameChange(frame, shouldDown: true, ignore: false)
    }
    
    @objc func textViewResign() {
        textView.resignFirstResponder()
        if self.frame.maxY == self.superview?.bounds.maxY ?? 0 {
            return
        }
        frameDown()
        recoverEmojiButton()
    }
    
    func recoverEmojiButton() {
        var image: UIImage?
        if #available(iOS 13.0, *) {
            image = UIImage(systemName: "smiley.fill", withConfiguration: MessageInputView.largeConfig as? UIImage.Configuration)
        } else {
            image = UIImage(named: "emoji")
        }
        image?.accessibilityIdentifier = "smiley"
        self.emojiButton.setImage(image, for: .normal)
        self.emojiButtonStatus = .normal
    }
    
    @objc func locationButtonTapped(_ sender: UIButton) {
        delegate?.toolButtonTap(sender, type: .location)
    }
    
    @objc func voiceButtonTapped(_ sender: UIButton) {
        delegate?.toolButtonTap(sender, type: .voice)
    }
    
    @objc func photoButtonTapped(_ sender: UIButton) {
        delegate?.toolButtonTap(sender, type: .photo)
    }

    @objc func cameraButtonTapped(_ sender: UIButton) {
        delegate?.toolButtonTap(sender, type: .camera)
    }

    @objc func livePhotoButtonTapped(_ sender: UIButton) {
        delegate?.toolButtonTap(sender, type: .livePhoto)
    }
    
    @objc func videoButtonTapped(_ sender: UIButton) {
        delegate?.toolButtonTap(sender, type: .video)
    }

    @objc func drawButtonTapped(_ sender: UIButton) {
        delegate?.toolButtonTap(sender, type: .draw)
    }

    @objc func addButtonTapped(_ sender: UIButton) {
        delegate?.toolButtonTap(sender, type: .add)
    }
    
    @objc func atButtonTapped(_ sender: UIButton) {
        delegate?.toolButtonTap(sender, type: .at)
    }
    
    @objc func upArrowTouch(_ ges: UIPanGestureRecognizer) {
        switch ges.state {
        case .began:
            beginY = ges.location(in: self.superview).y
            frameShouldAnimate = false
        case .changed:
            let nowY = ges.location(in: self.superview).y
            let offset = (beginY - nowY) / 500
            let oldSize = textView.font!.pointSize
            var newSize = textView.font!.pointSize + offset
            newSize = min(50, newSize)
            newSize = max(7, newSize)
            textView.font = .systemFont(ofSize: newSize)
            delegate?.textViewFontSizeChange(textView, oldSize: oldSize, newSize: newSize)
            let nowDirectionUp = ges.velocity(in: self.superview).y < 0
            if nowDirectionUp != directionUp {
                beginY = nowY
            }
            directionUp = ges.velocity(in: self.superview).y < 0
        case .ended:
            print("end")
            frameShouldAnimate = true
            delegate?.textViewFontSizeChangeEnded(textView)
        default:
            break
        }
    }
    
    @objc func emojiButtonTapped() {
        let block: (Bool) -> Void = { ignore in
            let screenSize = (self.window?.rootViewController)?.view.bounds.size ?? UIScreen.main.bounds.size
            let ratio: CGFloat = MessageInputView.ratioOfEmojiView
            let frame = CGRect(x: 0, y: (1-ratio)*screenSize.height, width: screenSize.width, height: ratio*screenSize.height)
            self.delegate?.messageInputBarFrameChange(frame, shouldDown: false, ignore: ignore)
        }
        if textView.isFirstResponder {
            NotificationCenter.default.post(name: .emojiButtonTapped, object: self)
            block(true)
            
            self.textView.resignFirstResponder()
        } else {
            NotificationCenter.default.post(name: .emojiButtonTapped, object: self)
            block(false)
        }
    }
    
    @objc func sendTapped() {
        if let delegate = delegate, let message = textView.text {
            delegate.sendWasTapped(content:  message)
            textView.text = ""
            textView.delegate?.textViewDidChange?(textView)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let toolStack = self.toolStack else { return }
        let pendings = [cameraButton, locationButton]
        let single: CGFloat = 1.6
        let totalWidth = CGFloat(toolStack.arrangedSubviews.count - pendings.count) * width * single
        let remain = (self.bounds.width - totalWidth) / width
        cameraButton.isHidden = remain < single
        locationButton.isHidden = remain < single * 2
    }
}

