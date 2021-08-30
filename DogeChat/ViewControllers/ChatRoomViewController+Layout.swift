
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
                        guard tableView.numberOfRows(inSection: 0) != 0 else { return }
                        tableView.scrollToRow(at: IndexPath(row: tableView.numberOfRows(inSection: 0) - 1, section: 0), at: .bottom, animated: false)
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
        view.addSubview(tableView)
        view.addSubview(messageInputBar)
        
        messageInputBar.delegate = self
    }
    
    func layoutViews(size: CGSize) {
        let size = view.frame.size
        tableView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        tableView.contentInset = .init(top: 0, left: 0, bottom: messageBarHeight - UIApplication.shared.keyWindow!.safeAreaInsets.bottom, right: 0)
        messageInputBar.frame = CGRect(x: 0, y: size.height - messageBarHeight, width: size.width, height: messageBarHeight)
        
        let emojiViewHeight: CGFloat = MessageInputView.ratioOfEmojiView * view.bounds.height
        emojiSelectView.frame = CGRect(x: 0, y: messageInputBar.frame.maxY, width: size.width, height: emojiViewHeight)
    }
    
}

