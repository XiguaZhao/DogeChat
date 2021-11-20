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
    weak var delegate: MessageInputDelegate?
    
    static var maxHeight: CGFloat {
        safeArea.bottom + 186
    }
    static let defaultHeight: CGFloat = 86
    static let textViewDefaultFontSize: CGFloat = 16
    static let ratioOfEmojiView: CGFloat = 0.45
    static let offset: CGFloat = 12
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
    let referView = ReferView(type: .inputView)
    var lastInset: UIEdgeInsets = .zero
    weak var referViewBottomContraint: NSLayoutConstraint!
    var isActive: Bool {
        return textView.isFirstResponder || self.frame.maxY < (self.superview?.bounds.height)!
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
                
        var width: CGFloat = 30

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
        if #available(iOS 13.0, *) {
            let largeConfig = UIImage.SymbolConfiguration(pointSize: 150, weight: .bold, scale: .large)
            addButton.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: largeConfig), for: .normal)
            emojiButton.setImage(UIImage(systemName: "smiley.fill", withConfiguration: largeConfig), for: .normal)
            upArrowButton.setImage(UIImage(systemName: "arrow.up", withConfiguration: largeConfig), for: .normal)
            voiceButton.setImage(UIImage(systemName: "mic.circle.fill", withConfiguration: largeConfig), for: .normal)
            cameraButton.setImage(UIImage(systemName: "camera.circle.fill", withConfiguration: largeConfig), for: .normal)
            photoButton.setImage(UIImage(named: "xiangce"), for: .normal)
            livePhotoButton.setImage(UIImage(systemName: "livephoto", withConfiguration: largeConfig), for: .normal)
            videoButton.setImage(UIImage(systemName: "video.circle.fill", withConfiguration: largeConfig), for: .normal)
            drawButton.setImage(UIImage(systemName: "pencil.circle.fill", withConfiguration: largeConfig), for: .normal)
        } else {
            addButton.setImage(UIImage(named: "add"), for: .normal)
            emojiButton.setImage(UIImage(named: "emoji"), for: .normal)
            upArrowButton.setImage(UIImage(named: "arrowUp"), for: .normal)
            voiceButton.setImage(UIImage(named: "voice"), for: .normal)
            cameraButton.setImage(UIImage(named: "camera"), for: .normal)
            photoButton.setImage(UIImage(named: "album"), for: .normal)
            livePhotoButton.setImage(UIImage(named: "live"), for: .normal)
            videoButton.setImage(UIImage(named: "video"), for: .normal)
            drawButton.setImage(UIImage(named: "pencil"), for: .normal)
        }
                
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        emojiButton.addTarget(self, action: #selector(emojiButtonTapped), for: .touchUpInside)
        voiceButton.addTarget(self, action: #selector(voiceButtonTapped(_:)), for: .touchUpInside)
        cameraButton.addTarget(self, action: #selector(cameraButtonTapped(_:)), for: .touchUpInside)
        photoButton.addTarget(self, action: #selector(photoButtonTapped(_:)), for: .touchUpInside)
        livePhotoButton.addTarget(self, action: #selector(livePhotoButtonTapped(_:)), for: .touchUpInside)
        videoButton.addTarget(self, action: #selector(videoButtonTapped(_:)), for: .touchUpInside)
        drawButton.addTarget(self, action: #selector(drawButtonTapped(_:)), for: .touchUpInside)
        
        toolStack = UIStackView(arrangedSubviews: [voiceButton, cameraButton, photoButton, livePhotoButton, videoButton, drawButton, addButton])
        toolStack.alignment = .center
        toolStack.distribution = .equalSpacing
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(upArrowTouch(_:)))
        upArrowButton.addGestureRecognizer(pan)
        addSubview(textView)
        addSubview(emojiButton)
        addSubview(upArrowButton)
        addSubview(toolStack)
        addSubview(referView)
        
        referView.alpha = 0
        
        if isMac() {
            livePhotoButton.isHidden = true
            videoButton.isHidden = true
            drawButton.isHidden = true
        }
        
        if #available(iOS 13, *) {} else {
            width = 25
        }
             
        toolStack.arrangedSubviews.forEach { button in
            button.mas_makeConstraints { make in
                make?.width.height().mas_lessThanOrEqualTo()(button == photoButton ? width - 3 : width)
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
            referView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: Self.offset),
            referView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -Self.offset),
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
            if self.referView.cancleButton.bounds.inset(by: edgeInsets).contains(converted) {
                return referView.cancleButton
            } else if self.referView.bounds.inset(by: edgeInsets).contains(converted) {
                return referView.stackView
            }
        }
        return super.hitTest(point, with: event)
    }
    
    func frameDown() {
        let screenSize = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.bounds.size ?? UIScreen.main.bounds.size
        let frame = CGRect(x: 0, y: screenSize.height, width: screenSize.width, height: screenSize.height)
        delegate?.messageInputBarFrameChange(frame, shouldDown: true, ignore: false)
    }
    
    @objc func textViewResign() {
        textView.resignFirstResponder()
        if self.frame.maxY == self.superview!.bounds.maxY {
            return
        }
        frameDown()
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
            let screenSize = AppDelegate.shared.navigationController!.view.bounds.size
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
    }
}

