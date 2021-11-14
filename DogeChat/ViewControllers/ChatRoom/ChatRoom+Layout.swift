
import UIKit
import DogeChatNetwork

extension ChatRoomViewController {
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.messageInputBar.textViewResign()
    }
            
    @objc func keyboardWillChange(notification: NSNotification) {
        stopScrolling()
        if let userInfo = notification.userInfo {
            var endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)!.cgRectValue
            if let beginFrame = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue, beginFrame == endFrame {
                return
            }
            if isKeyboardAnimating {
                return
            }
            var shouldDown = !messageInputBar.textView.isActive
            if let up = notification.object as? Bool {
                shouldDown = !up
            }
            let height = self.navigationController?.view.bounds.height ?? 0
            if !shouldDown && endFrame.minY + endFrame.height != UIScreen.main.bounds.height {
                endFrame = CGRect(x: 0, y: 0.62 * height, width: 0, height: height * 0.38)
            } else if shouldDown {
                endFrame = CGRect(x: 0, y: height, width: 0, height: 100)
            }
            let additionalOffset: CGFloat = safeArea.bottom / 2
            let messageBarHeight = self.messageInputBar.bounds.height
            var point = CGPoint(x: self.messageInputBar.center.x, y: endFrame.origin.y - messageBarHeight/2.0)
            let bottomInset: CGFloat
            let safeAreaInsetBottom = safeArea.bottom
            if !shouldDown {
                bottomInset = AppDelegate.shared.navigationController!.view.bounds.height - endFrame.minY - safeAreaInsetBottom + messageBarHeight - additionalOffset
            } else {
                bottomInset = messageBarHeight - safeAreaInsetBottom
            }
            let inset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
            var offsetY = point.y - messageInputBar.center.y
            let duration = 0.25
            point.y += shouldDown ? 0 : additionalOffset
            offsetY += shouldDown ? 0 : additionalOffset
            isKeyboardAnimating = true
            UIView.animate(withDuration: duration) { [self] in
                self.messageInputBar.center = point
                self.emojiSelectView.alpha = (shouldDown ? 0 : 1)
                self.emojiSelectView.center = CGPoint(x: self.emojiSelectView.center.x, y: self.emojiSelectView.center.y + offsetY)
                self.tableView.contentInset = inset
                let contentHeight = contentHeight()
                if !shouldDown && contentHeight > messageInputBar.frame.minY {
                    self.tableView.contentOffset = CGPoint(x: 0, y: contentHeight - messageInputBar.frame.minY)
                }
            } completion: { finished in
                self.isKeyboardAnimating = false
            }
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
        layoutViews(size: view.bounds.size)
        scrollToBottomWithoutAnimation()
        tableView.register(MessageCollectionViewTextCell.self, forCellReuseIdentifier: MessageCollectionViewTextCell.cellID)
        tableView.register(MessageCollectionViewImageCell.self, forCellReuseIdentifier: MessageCollectionViewImageCell.cellID)
        tableView.register(MessageCollectionViewDrawCell.self, forCellReuseIdentifier: MessageCollectionViewDrawCell.cellID)
        tableView.register(MessageCollectionViewTrackCell.self, forCellReuseIdentifier: MessageCollectionViewTrackCell.cellID)
        tableView.layer.masksToBounds = true
        
        emojiSelectView.delegate = self
        emojiSelectView.username = username
        
        view.addSubview(tableView)
        if !isPeek {
            view.addSubview(messageInputBar)
            view.addSubview(emojiSelectView)
        }

        messageInputBar.delegate = self
        
        pan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(panAction(_:)))
        pan?.edges = .right
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
            let navigationBarHeight = navigationController?.navigationBar.bounds.height ?? 0
            let statusBarHeight = UIApplication.shared.statusBarFrame.height
            let offset = CGPoint(x: 0, y: tableView.contentSize.height - tableView.bounds.height + (isPeek ? 0 : messageInputBar.frame.height) + navigationBarHeight + (isPeek ? 0 : statusBarHeight))
            if isPeek {
                DispatchQueue.main.async { [self] in
                    tableView.contentOffset = CGPoint(x: 0, y: tableView.contentSize.height - tableView.bounds.height + (isPeek ? 0 : messageInputBar.frame.height) + navigationBarHeight + (isPeek ? 0 : statusBarHeight))
                }
            } else {
                tableView.contentOffset = offset
            }
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
        let finalFrame = CGRect(x: oldFrame.origin.x, y: oldFrame.origin.y-heightChanged, width: oldFrame.width, height: oldFrame.height+heightChanged)
        tableViewInset.bottom += heightChanged
        if heightChanged != 0 || scrollByTextViewChange() {
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.3) { [weak self] in
                    guard let self = self else { return }
                    self.messageInputBar.frame = finalFrame
                    self.tableView.contentInset = tableViewInset
                    self.tableView.contentOffset = CGPoint(x: 0, y: self.tableView.contentSize.height - finalFrame.minY)
                }
            }
        }
    }
    
    func scrollByTextViewChange() -> Bool {
        return messageInputBar.textView.text.isEmpty && messageInputBar.textView.font?.pointSize != 18
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

