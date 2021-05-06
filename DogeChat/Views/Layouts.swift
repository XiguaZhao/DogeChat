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

extension ChatRoomViewController {
    @objc func keyboardWillChange(notification: NSNotification) {
        if MessageInputView.becauseEmojiTapped {
            MessageInputView.becauseEmojiTapped = false
            return
        }
        if let userInfo = notification.userInfo {
            let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)!.cgRectValue
            let messageBarHeight = self.messageInputBar.bounds.size.height
            let point = CGPoint(x: self.messageInputBar.center.x, y: endFrame.origin.y - messageBarHeight/2.0)
            let shouldDown = endFrame.origin.y == UIScreen.main.bounds.height
            let inset = UIEdgeInsets(top: 0, left: 0, bottom: shouldDown ? 0 : endFrame.size.height, right: 0)
            let offsetY = point.y - messageInputBar.center.y
            var duration = 0.25
            if let _duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Int, _duration == 0 {
                duration = 0
            }
            UIView.animate(withDuration: duration) { [self] in
                self.messageInputBar.center = point
                self.emojiSelectView.alpha = (shouldDown ? 0 : 1)
                self.emojiSelectView.center = CGPoint(x: self.emojiSelectView.center.x, y: self.emojiSelectView.center.y + offsetY)
                self.collectionView.contentInset = inset
                if !shouldDown {
                    guard collectionView.numberOfItems(inSection: 0) != 0 else { return }
                    collectionView.scrollToItem(at: IndexPath(row: collectionView.numberOfItems(inSection: 0) - 1, section: 0), at: .bottom, animated: false)
                    
                }
            }
        }
    }
    
    func loadViews() {
        navigationItem.title = (self.messageOption == .toOne) ? friendName : "群聊"
        navigationItem.backBarButtonItem?.title = "Run!"
        if #available(iOS 13.0, *) {
            collectionView.backgroundColor = .systemBackground
        } else {
            collectionView.backgroundColor = .white
        }
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.dropDelegate = self
        collectionView.register(MessageCollectionViewCell.self, forCellWithReuseIdentifier: MessageCollectionViewCell.textCellIdentifier)
        view.addSubview(collectionView)
        view.addSubview(messageInputBar)
        
        messageInputBar.delegate = self
    }
    
    func layoutViews(size: CGSize) {
        let size = view.frame.size
        collectionView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height - messageBarHeight)
        messageInputBar.frame = CGRect(x: 0, y: size.height - messageBarHeight, width: size.width, height: messageBarHeight)
        let emojiViewHeight: CGFloat = MessageInputView.ratioOfEmojiView * view.bounds.height
        emojiSelectView.frame = CGRect(x: 0, y: messageInputBar.frame.maxY, width: size.width, height: emojiViewHeight)
        collectionView.contentInset = .zero
    }
    
}

extension JoinChatViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "聊天室"
        
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard)))
        login.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        signUp.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
        
        loadViews()
        
        nameTextField.textColor = .black
        passwordTextField.textColor = .black
        passwordTextField.isSecureTextEntry = true
        login.setTitle("登录", for: .normal)
        signUp.setTitle("注册", for: .normal)
        
        view.addSubview(shadowView)
        view.addSubview(logoImageView)
        view.addSubview(nameTextField)
        view.addSubview(passwordTextField)
        view.addSubview(login)
        view.addSubview(signUp)
    }
    
    func loadViews() {
        view.backgroundColor = UIColor(red: 24/255, green: 180/255, blue: 128/255, alpha: 1.0)
        navigationItem.title = "Doge Chat!"
        
        logoImageView.image = UIImage(named: "doge")
        logoImageView.layer.cornerRadius = 4
        logoImageView.clipsToBounds = true
        
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowRadius = 5
        shadowView.layer.shadowOffset = CGSize(width: 0.0, height: 5.0)
        shadowView.layer.shadowOpacity = 0.5
        shadowView.backgroundColor = UIColor(red: 24/255, green: 180/255, blue: 128/255, alpha: 1.0)
        
        nameTextField.placeholder = "What's your username?"
        nameTextField.backgroundColor = .white
        nameTextField.layer.cornerRadius = 4
        nameTextField.delegate = self
        
        passwordTextField.placeholder = "Input your password"
        passwordTextField.backgroundColor = .white
        passwordTextField.layer.cornerRadius = 4
        passwordTextField.delegate = self
        
        let backItem = UIBarButtonItem()
        backItem.title = "Run!"
        navigationItem.backBarButtonItem = backItem
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        logoImageView.bounds = CGRect(x: 0, y: 0, width: 150, height: 150)
        logoImageView.center = CGPoint(x: view.bounds.size.width/2.0, y: logoImageView.bounds.size.height/2.0 + view.bounds.size.height/4)
        shadowView.frame = logoImageView.frame
        
        nameTextField.bounds = CGRect(x: 0, y: 0, width: view.bounds.size.width - 40, height: 44)
        nameTextField.center = CGPoint(x: view.bounds.size.width/2.0, y: logoImageView.center.y + logoImageView.bounds.size.height/2.0 + 20 + 22)
        
        passwordTextField.bounds = CGRect(x: 0, y: 0, width: view.bounds.size.width - 40, height: 44)
        passwordTextField.center = CGPoint(x: view.bounds.size.width/2.0, y: logoImageView.center.y + logoImageView.bounds.size.height/2.0 + 20 + passwordTextField.frame.height + 50)
        
        login.translatesAutoresizingMaskIntoConstraints = false
        signUp.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            login.centerYAnchor.constraint(equalTo: signUp.centerYAnchor),
            login.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 20),
            login.centerXAnchor.constraint(equalTo: nameTextField.centerXAnchor),
            signUp.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor, constant: -20)
        ])
    }
}

