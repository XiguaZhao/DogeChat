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
import YPTransition

protocol MessageInputDelegate: AnyObject {
    func sendWasTapped(content: String)
    func addButtonTapped()
}

class MessageInputView: UIView {
    weak var delegate: MessageInputDelegate?
    
    static let ratioOfEmojiView: CGFloat = 0.45
    static var becauseEmojiTapped = false
    let textView = UITextView()
    let addButton = UIButton()
    let emojiButton = UIButton()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = UIColor(red: 247/255, green: 247/255, blue: 247/255, alpha: 1.0)
        if #available(iOS 13.0, *) {
            backgroundColor = .systemBackground
        }
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.layer.cornerRadius = 4
        textView.layer.borderColor = UIColor(red: 200/255, green: 200/255, blue: 200/255, alpha: 0.6).cgColor
        textView.layer.borderWidth = 1
        textView.font = UIFont.systemFont(ofSize: 18)
        textView.returnKeyType = .send
        
        addButton.translatesAutoresizingMaskIntoConstraints = false
        emojiButton.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *) {
            let largeConfig = UIImage.SymbolConfiguration(pointSize: 140, weight: .bold, scale: .large)
            addButton.setImage(UIImage(systemName: "plus.circle", withConfiguration: largeConfig), for: .normal)
            emojiButton.setImage(UIImage(systemName: "smiley", withConfiguration: largeConfig), for: .normal)
        } else {
            addButton.titleLabel?.text = "+"
            addButton.titleLabel?.textAlignment = .center
            emojiButton.titleLabel?.text = "表情"
            emojiButton.titleLabel?.textAlignment = .center
        }
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        emojiButton.addTarget(self, action: #selector(emojiButtonTapped), for: .touchUpInside)
        addSubview(textView)
        addSubview(addButton)
        addSubview(emojiButton)
        let offset: CGFloat = 10
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: offset),
            textView.trailingAnchor.constraint(equalTo: self.emojiButton.leadingAnchor, constant: -offset),
            textView.topAnchor.constraint(equalTo: self.topAnchor),
            textView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -20)
        ])
        
        NSLayoutConstraint.activate([
            addButton.bottomAnchor.constraint(equalTo: textView.bottomAnchor, constant: -offset+5),
            addButton.leadingAnchor.constraint(equalTo: emojiButton.trailingAnchor, constant: offset),
            addButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -offset-10),
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

