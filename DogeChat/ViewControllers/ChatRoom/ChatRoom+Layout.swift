
import UIKit
import DogeChatNetwork
import CoreGraphics

extension ChatRoomViewController {
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.messageInputBar.textViewResign()
    }
    
    @objc func keyboardFrameChangeNoti(_ noti: Notification) {
        keyboardWillChange(notification: noti, shouldDown: false)
    }
    
    @objc func keyboardWillShow(noti: Notification) {
        keyboardWillChange(notification: noti, shouldDown: false)
    }
    
    @objc func keyboardWillHide(noti: Notification) {
        keyboardWillChange(notification: noti, shouldDown: true)
    }
            
    func keyboardWillChange(notification: Notification, shouldDown: Bool) {
        stopScrolling()
        if ignoreKeyboardChange {
            ignoreKeyboardChange = false
            return
        }
        if let userInfo = notification.userInfo {
            var endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)!.cgRectValue
            if let beginFrame = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue, beginFrame == endFrame {
                return
            }
            let height = self.navigationController?.view.bounds.height ?? UIScreen.main.bounds.height
            if !shouldDown && endFrame.minY + endFrame.height != UIScreen.main.bounds.height {
                if isPad() {
                    endFrame = CGRect(x: 0, y: 0.62 * height, width: 0, height: height * 0.38)
                }
            } else if shouldDown {
                endFrame = CGRect(x: 0, y: height, width: 0, height: 100)
            }
            keyboardFrameChange(endFrame, shouldDown: shouldDown)
        }
    }
    
    func keyboardFrameChange(_ endFrame: CGRect, shouldDown: Bool) {
        let additionalOffset: CGFloat = safeArea.bottom / 2
        let messageBarHeight = self.messageInputBar.bounds.height
        var point = CGPoint(x: self.messageInputBar.center.x, y: endFrame.origin.y - messageBarHeight/2.0)
        var bottomInset: CGFloat
        let safeAreaInsetBottom = safeArea.bottom
        if !shouldDown {
            bottomInset = AppDelegate.shared.navigationController!.view.bounds.height - endFrame.minY - safeAreaInsetBottom + messageBarHeight - additionalOffset
        } else {
            bottomInset = messageBarHeight - safeAreaInsetBottom
        }
        if messageInputBar.referView.alpha > 0 {
            bottomInset += ReferView.height
        }
        let inset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        var offsetY = point.y - messageInputBar.center.y
        let duration = 0.25
        point.y += shouldDown ? 0 : additionalOffset
        offsetY += shouldDown ? 0 : additionalOffset
        UIView.animate(withDuration: duration) { [self] in
            self.messageInputBar.center = point
            self.emojiSelectView.frame = CGRect(x: 0, y: messageInputBar.frame.maxY, width: messageInputBar.frame.width, height: self.view.bounds.height - messageInputBar.frame.maxY)
            self.tableView.contentInset = inset
            let contentHeight = contentHeight()
            if !shouldDown && contentHeight > messageInputBar.frame.minY {
                let lastIndexPath = IndexPath(row: messages.count - 1, section: 0)
                if (tableView.indexPathsForVisibleRows ?? []).contains(lastIndexPath) {
                    self.tableView.setContentOffset(CGPoint(x: 0, y: contentHeight - messageInputBar.frame.minY - messageInputBar.topConstraint.constant), animated: false)
                } else {
                    self.tableView.scrollToRow(at: lastIndexPath, at: .bottom, animated: true)
                }
            }
        } completion: { finished in
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if lastViewSize != view.bounds.size {
            layoutViews(size: view.bounds.size)
            lastViewSize = view.bounds.size
        }
    }

    func loadViews() {
        navigationItem.backBarButtonItem?.title = "Run!"
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.dropDelegate = self
        tableView.dragDelegate = self
        tableView.estimatedRowHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        view.addSubview(tableView)
        if !isPeek {
            view.addSubview(messageInputBar)
            view.addSubview(emojiSelectView)
        }

        layoutViews(size: view.bounds.size)
        scrollToBottomWithoutAnimation()
        tableView.register(MessageCollectionViewTextCell.self, forCellReuseIdentifier: MessageCollectionViewTextCell.cellID)
        tableView.register(MessageCollectionViewImageCell.self, forCellReuseIdentifier: MessageCollectionViewImageCell.cellID)
        tableView.register(MessageCollectionViewDrawCell.self, forCellReuseIdentifier: MessageCollectionViewDrawCell.cellID)
        tableView.register(MessageCollectionViewTrackCell.self, forCellReuseIdentifier: MessageCollectionViewTrackCell.cellID)
        tableView.register(MessageCollectionViewLivePhotoCell.self, forCellReuseIdentifier: MessageCollectionViewLivePhotoCell.cellID)
        tableView.register(MessageCollectionViewVideoCell.self, forCellReuseIdentifier: MessageCollectionViewVideoCell.cellID)
        tableView.layer.masksToBounds = true
        
        emojiSelectView.delegate = self
        emojiSelectView.username = username
        
        messageInputBar.delegate = self
        messageInputBar.referView.delegate = self
        
        pan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(panAction(_:)))
        pan?.edges = .right
        pan?.isEnabled = false
        view.addGestureRecognizer(pan!)

    }
    
    func scrollToBottomWithoutAnimation() {
        if !messages.isEmpty {
            for i in (0..<messages.count).reversed() {
                if messages.count - i > 10 {
                    break
                }
                messages[i].syncGetMedia = true //为了让点进来的时候图片直接显示，不然下一个runloop会闪一下
            }
            tableView.reloadData()
            let offset = CGPoint(x: 0, y: CGFloat.greatestFiniteMagnitude)
            tableView.contentOffset = offset
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.scrollViewDidEndDecelerating(self.tableView)
            }
        }
    }
        
    func layoutViews(size: CGSize) {
        let size = view.frame.size
        tableView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        if !isPeek {
            tableView.contentInset = .init(top: 0, left: 0, bottom: messageBarHeight - UIApplication.shared.keyWindow!.safeAreaInsets.bottom, right: 0)
        }
        let barFrame = CGRect(x: 0, y: size.height - messageBarHeight, width: size.width, height: messageBarHeight)
        messageInputBar.frame = barFrame
        
        let emojiViewHeight: CGFloat = MessageInputView.ratioOfEmojiView * view.bounds.height
        emojiSelectView.frame = CGRect(x: 0, y: messageInputBar.frame.maxY, width: size.width, height: emojiViewHeight)
    }
    
    @objc func panAction(_ pan: UIScreenEdgePanGestureRecognizer) {
        let maxOffset: CGFloat = 80
        switch pan.state {
        case .began:
            tableView.layer.masksToBounds = false
            tableView.visibleCells.forEach { ($0 as? MessageCollectionViewBaseCell)?.timeLabel.isHidden = false }
        case .changed:
            let startX = view.bounds.width
            let endX = pan.location(in: view).x
            let offsetX = min(maxOffset, (abs(endX - startX))/1.2)
            tableView.layer.transform = CATransform3DTranslate(CATransform3DIdentity, -offsetX, 0, 0)
        case .ended:
            recoverCollectionViewInset()
        default:
            break
        }
    }
    
    func recoverCollectionViewInset() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
            self.tableView.layer.transform = CATransform3DIdentity
        }, completion: { _ in
            self.tableView.layer.masksToBounds = true
            self.tableView.visibleCells.forEach { ($0 as? MessageCollectionViewBaseCell)?.timeLabel.isHidden = true }
        })
    }
    
    
    func textViewDidChange(_ textView: UITextView) {
        showEmojiButton(textView.text.isEmpty)
        if let markRange = textView.markedTextRange,
           textView.position(from: markRange.start, offset: 0) != nil {
            return
        }
        let oldFrame = messageInputBar.frame
        let newTextViewSize = textView.contentSize
        var heightChanged = newTextViewSize.height - lastTextViewContentSize.height
        var tableViewInset = tableView.contentInset
        if textView.text.isEmpty {
            heightChanged = messageBarHeight - oldFrame.height
        }
        let inputBarHeight = oldFrame.height+heightChanged
        if inputBarHeight > MessageInputView.maxHeight {
            heightChanged = MessageInputView.maxHeight - oldFrame.height
        }
        if inputBarHeight < messageBarHeight {
            heightChanged = messageBarHeight - oldFrame.height
        }
        let finalFrame = CGRect(x: oldFrame.origin.x, y: oldFrame.origin.y-heightChanged, width: oldFrame.width, height: oldFrame.height+heightChanged)
        tableViewInset.bottom += heightChanged
        if heightChanged != 0 || scrollByTextViewChange() {
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.3, animations: { [weak self] in
                    guard let self = self else { return }
                    self.messageInputBar.frame = finalFrame
                    self.tableView.contentInset = tableViewInset
                    self.tableView.contentOffset = CGPoint(x: 0, y: self.tableView.contentSize.height - finalFrame.minY)
                }) { _ in
                    self.updateTextViewOffset()
                }
            }
        } else {
            updateTextViewOffset()
        }
        lastTextViewContentSize = newTextViewSize
    }
    
    func updateTextViewOffset() {
        let textView = self.messageInputBar.textView
        var contentOffset: CGPoint = .zero
        if textView.contentSize.height <= textView.bounds.height {
            contentOffset = .zero
        } else {
            contentOffset.y = textView.contentSize.height - textView.bounds.height
        }
        textView.setContentOffset(contentOffset, animated: true)
    }
    
    func scrollByTextViewChange() -> Bool {
        return messageInputBar.textView.text.isEmpty && messageInputBar.textView.font?.pointSize != MessageInputView.textViewDefaultFontSize
    }
    
    func makeNavBarUI() {
        var total: CGFloat = 0
        for message in messages.reversed() {
            total += MessageCollectionViewBaseCell.height(for: message, username: username)
            if total > tableView.bounds.height - tableView.contentInset.top {
                if let bar = self.navigationController?.navigationBar,
                   let blurView = bar.subviews.first?.subviews.first as? UIVisualEffectView {
                    blurView.alpha = 1
                }
                return
            }
        }
    }
    
    func stopScrolling() {
        let offset = tableView.contentOffset
        tableView.setContentOffset(offset, animated: false)
    }

}

