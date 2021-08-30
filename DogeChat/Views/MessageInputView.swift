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
}

var messageBarHeight: CGFloat {
    86 + safeArea.bottom
}

class MessageInputView: DogeChatStaticBlurView {
    weak var delegate: MessageInputDelegate?
    
    static let ratioOfEmojiView: CGFloat = 0.45
    static var becauseEmojiTapped = false
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
    var lastInset: UIEdgeInsets = .zero
    var isActive: Bool {
        return self.frame.minY < AppDelegate.shared.splitViewController.view.bounds.height * 0.8
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
                
        let offset: CGFloat = 12
        let width: CGFloat = 30

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor(red: 200/255, green: 200/255, blue: 200/255, alpha: 0.6).cgColor
        textView.layer.borderWidth = 2
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.returnKeyType = .send
        textView.backgroundColor = .clear
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
            addButton.titleLabel?.text = "+"
            addButton.titleLabel?.textAlignment = .center
            emojiButton.titleLabel?.text = "表情"
            emojiButton.titleLabel?.textAlignment = .center
            upArrowButton.titleLabel?.text = "发送"
            upArrowButton.titleLabel?.textAlignment = .center
            voiceButton.titleLabel?.text = "语音"
            voiceButton.titleLabel?.textAlignment = .center
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
                
        voiceButton.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(width)
        }
        
        cameraButton.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(width)
        }

        photoButton.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(width)
        }

        livePhotoButton.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(width)
        }

        videoButton.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(width)
        }

        drawButton.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(width)
        }
        
        addButton.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(width)
        }

        upArrowButton.isHidden = true
        upArrowButton.mas_makeConstraints { make in
            make?.edges.equalTo()(emojiButton)?.offset()
        }
        
        emojiButton.mas_makeConstraints { make in
            make?.trailing.equalTo()(self)?.offset()(-offset)
            make?.centerY.equalTo()(self.textView)
            make?.width.height().mas_equalTo()(width)
        }
        
    }
    
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        if safeAreaInsets.bottom != .zero {
            setNeedsUpdateConstraints()
        }
    }
    
    override func updateConstraints() {
        
        let offset: CGFloat = 12
        let width: CGFloat = 30

        toolStack.mas_updateConstraints { make in
            make?.leading.equalTo()(self)?.offset()(offset)
            make?.trailing.equalTo()(self)?.offset()(-offset)
            let middle: CGFloat = safeAreaInsets.bottom == 0 ? offset - 5 : offset - 3
            make?.top.equalTo()(textView.mas_bottom)?.offset()(middle)
        }
        
        textView.mas_updateConstraints { make in
            make?.leading.equalTo()(self)?.offset()(offset)
            make?.top.equalTo()(self)?.offset()(offset - 4)
            make?.trailing.equalTo()(emojiButton.mas_leading)?.offset()(-offset)
            let safeAreaBottom = safeAreaInsets.bottom == 0 ? -5 : safeArea.bottom - 14
            make?.bottom.equalTo()(self)?.offset()(-(safeAreaBottom + width + offset * 2 - 6))
        }
        
        super.updateConstraints()
    }
    
    
    @objc func textViewResign() {
        textView.resignFirstResponder()
        if self.frame.maxY == self.superview!.bounds.maxY {
            return
        }
        let screenSize = AppDelegate.shared.window?.bounds.size ?? UIScreen.main.bounds.size
        let userInfo = [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: CGRect(x: 0, y: screenSize.height, width: screenSize.width, height: screenSize.height))]
        NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: self, userInfo: userInfo)
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
        let block = {
            let screenSize = AppDelegate.shared.window?.bounds.size ?? UIScreen.main.bounds.size
            let ratio: CGFloat = MessageInputView.ratioOfEmojiView
            let userInfo = [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: CGRect(x: 0, y: (1-ratio)*screenSize.height, width: screenSize.width, height: ratio*screenSize.height))]
            NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: self, userInfo: userInfo)
        }
        if textView.isFirstResponder {
            MessageInputView.becauseEmojiTapped = true
            self.textView.resignFirstResponder()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .emojiButtonTapped, object: nil)
                block()
            }
        } else {
            NotificationCenter.default.post(name: .emojiButtonTapped, object: nil)
            block()
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

