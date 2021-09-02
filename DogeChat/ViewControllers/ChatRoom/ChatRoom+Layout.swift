
import UIKit
import DogeChatNetwork

extension ChatRoomViewController {
    @objc func keyboardWillChange(notification: NSNotification) {
        if MessageInputView.becauseEmojiTapped && AppDelegate.shared.isIOS {
            MessageInputView.becauseEmojiTapped = false
            return
        }
        if let userInfo = notification.userInfo {
            var endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)!.cgRectValue
            if endFrame.height < 50 {
                endFrame = CGRect(x: 0, y: AppDelegate.shared.window!.bounds.height, width: UIScreen.main.bounds.width, height: 0)
            }
            let additionalOffset: CGFloat = safeArea.bottom / 2
            let messageBarHeight = self.messageInputBar.bounds.height
            var point = CGPoint(x: self.messageInputBar.center.x, y: endFrame.origin.y - messageBarHeight/2.0)
            let shouldDown = endFrame.origin.y == AppDelegate.shared.window?.bounds.height ?? UIScreen.main.bounds.height
            let bottomInset: CGFloat
            let safeAreaInsetBottom = safeArea.bottom
            if !shouldDown {
                bottomInset = AppDelegate.shared.navigationController.view.bounds.height - endFrame.minY - safeAreaInsetBottom + messageBarHeight - additionalOffset
            } else {
                bottomInset = messageBarHeight - safeAreaInsetBottom
            }
            let inset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
            var offsetY = point.y - messageInputBar.center.y
            var duration = 0.25
            if let _duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Int, _duration == 0 {
                duration = 0
            }
            if !shouldDown {
                dontLayout = true
                tableView.setContentOffset(tableView.contentOffset, animated: false)
            }
            point.y += shouldDown ? 0 : additionalOffset
            offsetY += shouldDown ? 0 : additionalOffset
            UIView.animate(withDuration: duration) { [self] in
                self.messageInputBar.center = point
                self.emojiSelectView.alpha = (shouldDown ? 0 : 1)
                self.emojiSelectView.center = CGPoint(x: self.emojiSelectView.center.x, y: self.emojiSelectView.center.y + offsetY)
                self.tableView.contentInset = inset
                if !shouldDown {
                    if self.messageInputBar.textView.isFirstResponder || (tableView.indexPathsForVisibleRows ?? []).contains(IndexPath(item: max(0, tableView.numberOfRows(inSection: 0) - 1), section: 0)) {
                        if let visibles = self.tableView.indexPathsForVisibleRows, !self.messages.isEmpty, visibles.contains(IndexPath(row: self.messages.count - 1, section: 0)), self.tableView.contentOffset.y > 0 {
                            self.tableView.contentOffset = CGPoint(x: 0, y: self.tableView.contentSize.height - self.tableView.bounds.height + inset.bottom + safeArea.bottom)
                        } else {
                            self.needScrollToBottom = true
                        }
                    }
                }
            } completion: { finished in
                self.dontLayout = !shouldDown || !self.messageInputBar.textView.text.isEmpty
            }
        }
    }
    
    func loadViews() {
        navigationItem.title = (self.messageOption == .toOne) ? friendName : "群聊"
        navigationItem.backBarButtonItem?.title = "Run!"
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.dropDelegate = self
        tableView.register(MessageCollectionViewTextCell.self, forCellReuseIdentifier: MessageCollectionViewTextCell.cellID)
        tableView.register(MessageCollectionViewImageCell.self, forCellReuseIdentifier: MessageCollectionViewImageCell.cellID)
        tableView.register(MessageCollectionViewDrawCell.self, forCellReuseIdentifier: MessageCollectionViewDrawCell.cellID)
        tableView.register(MessageCollectionViewTrackCell.self, forCellReuseIdentifier: MessageCollectionViewTrackCell.cellID)
        tableView.layer.masksToBounds = true
        
        emojiSelectView.delegate = self

        view.addSubview(tableView)
        view.addSubview(messageInputBar)
        view.addSubview(emojiSelectView)

        messageInputBar.delegate = self
        
        pan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(panAction(_:)))
        pan?.edges = .right
        view.addGestureRecognizer(pan!)

    }
        
    func layoutViews(size: CGSize) {
        let size = view.frame.size
        tableView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        tableView.contentInset = .init(top: 0, left: 0, bottom: messageBarHeight - UIApplication.shared.keyWindow!.safeAreaInsets.bottom, right: 0)
        messageInputBar.frame = CGRect(x: 0, y: size.height - messageBarHeight, width: size.width, height: messageBarHeight)
        
        let emojiViewHeight: CGFloat = MessageInputView.ratioOfEmojiView * view.bounds.height
        emojiSelectView.frame = CGRect(x: 0, y: messageInputBar.frame.maxY, width: size.width, height: emojiViewHeight)
    }
    
    @objc func panAction(_ pan: UIScreenEdgePanGestureRecognizer) {
        let maxOffset: CGFloat = 80
        dontLayout = true
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
            dontLayout = false
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
        dontLayout = true
        showEmojiButton(textView.text.isEmpty)
        let oldFrame = messageInputBar.frame
        let textHeight = textView.contentSize.height
        let lineHeight = (textView.text as NSString).size(withAttributes: textView.typingAttributes).height
        let lineCount = Int(textHeight / lineHeight)
        let oldLineCount = Int((oldFrame.height - (safeArea.bottom + 46)) / lineHeight)
        let lineCountChanged = lineCount - oldLineCount
        var heightChanged = CGFloat(lineCountChanged) * lineHeight
        var tableViewInset = tableView.contentInset
        if textView.text.isEmpty {
            heightChanged = messageBarHeight - oldFrame.height
        }
        tableViewInset.bottom += heightChanged
        if heightChanged != 0 {
            self.shouldIgnoreScroll = true
            UIView.animate(withDuration:  0.2 ) { [weak self] in
                guard let self = self else { return }
                self.messageInputBar.frame = CGRect(x: oldFrame.origin.x, y: oldFrame.origin.y-heightChanged, width: oldFrame.width, height: oldFrame.height+heightChanged)
                self.tableView.contentInset = tableViewInset
            } completion: { [weak self] (finish) in
                self?.needScrollToBottom = true
                if textView.text.isEmpty {
                    textView.font = .systemFont(ofSize: 18)
                }
            }
        }
    }

}

