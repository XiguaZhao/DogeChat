import UIKit
import YPTransition

protocol MessageInputDelegate: AnyObject {
    func sendWasTapped(content: String)
    func addButtonTapped()
    func voiceButtonTapped(_ sender: UIButton)
    func textViewFontSizeChange(_ textView: UITextView, oldSize: CGFloat, newSize: CGFloat)
    func textViewFontSizeChangeEnded(_ textView: UITextView)
}

class MessageInputView: DogeChatBlurView {
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.layer.cornerRadius = 4
        textView.layer.borderColor = UIColor(red: 200/255, green: 200/255, blue: 200/255, alpha: 0.6).cgColor
        textView.layer.borderWidth = 1
        textView.font = UIFont.systemFont(ofSize: 18)
        textView.returnKeyType = .send
        textView.backgroundColor = .clear
        addButton.translatesAutoresizingMaskIntoConstraints = false
        emojiButton.translatesAutoresizingMaskIntoConstraints = false
        upArrowButton.translatesAutoresizingMaskIntoConstraints = false
        voiceButton.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *) {
            let largeConfig = UIImage.SymbolConfiguration(pointSize: 140, weight: .bold, scale: .large)
            addButton.setImage(UIImage(systemName: "plus.circle", withConfiguration: largeConfig), for: .normal)
            emojiButton.setImage(UIImage(systemName: "smiley", withConfiguration: largeConfig), for: .normal)
            upArrowButton.setImage(UIImage(systemName: "arrow.up", withConfiguration: largeConfig), for: .normal)
            voiceButton.setImage(UIImage(systemName: "music.mic", withConfiguration: largeConfig), for: .normal)
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
        let pan = UIPanGestureRecognizer(target: self, action: #selector(upArrowTouch(_:)))
        upArrowButton.addGestureRecognizer(pan)
        addSubview(textView)
        addSubview(addButton)
        addSubview(emojiButton)
        addSubview(upArrowButton)
        addSubview(voiceButton)
        
        let offset: CGFloat = 5
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: self.voiceButton.trailingAnchor, constant: offset),
            textView.trailingAnchor.constraint(equalTo: self.emojiButton.leadingAnchor, constant: -offset),
            textView.topAnchor.constraint(equalTo: self.topAnchor),
            textView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -20)
        ])
        
        upArrowButton.isHidden = true
        upArrowButton.mas_makeConstraints { make in
            make?.edges.equalTo()(emojiButton)?.offset()
        }
                
        voiceButton.mas_makeConstraints { [weak self] make in
            make?.leading.equalTo()(self?.mas_leading)
            make?.top.equalTo()(self?.addButton.mas_top)
            make?.bottom.equalTo()(self?.addButton.mas_bottom)
            make?.width.mas_equalTo()(30)
        }
        
        NSLayoutConstraint.activate([
            addButton.bottomAnchor.constraint(equalTo: textView.bottomAnchor, constant: -offset),
            addButton.leadingAnchor.constraint(equalTo: emojiButton.trailingAnchor, constant: offset),
            addButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -offset),
            NSLayoutConstraint(item: addButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 30),
            NSLayoutConstraint(item: addButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 30)
        ])
        
        NSLayoutConstraint.activate([
            emojiButton.leadingAnchor.constraint(equalTo: textView.trailingAnchor, constant: offset),
            emojiButton.topAnchor.constraint(equalTo: addButton.topAnchor),
            emojiButton.bottomAnchor.constraint(equalTo: addButton.bottomAnchor),
            emojiButton.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -offset),
            NSLayoutConstraint(item: emojiButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 30),
            NSLayoutConstraint(item: emojiButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 30)
        ])
        
    }
    
    @objc func textViewResign() {
        textView.resignFirstResponder()
        let screenSize = AppDelegate.shared.window?.bounds.size ?? UIScreen.main.bounds.size
        let userInfo = [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: CGRect(x: 0, y: screenSize.height, width: screenSize.width, height: screenSize.height))]
        NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil, userInfo: userInfo)
    }
    
    @objc func addButtonTapped() {
        delegate?.addButtonTapped()
    }
    
    @objc func voiceButtonTapped(_ sender: UIButton) {
        delegate?.voiceButtonTapped(sender)
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
            NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil, userInfo: userInfo)
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

