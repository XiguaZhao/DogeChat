
import UIKit
import YPTransition

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
            let messageBarHeight = self.messageInputBar.bounds.size.height
            let point = CGPoint(x: self.messageInputBar.center.x, y: endFrame.origin.y - messageBarHeight/2.0)
            let shouldDown = endFrame.origin.y == AppDelegate.shared.window?.bounds.height ?? UIScreen.main.bounds.height
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
                    if self.messageInputBar.textView.isFirstResponder || collectionView.indexPathsForVisibleItems.contains(IndexPath(item: max(0, collectionView.numberOfItems(inSection: 0) - 1), section: 0)) {
                        guard collectionView.numberOfItems(inSection: 0) != 0 else { return }
                        collectionView.scrollToItem(at: IndexPath(row: collectionView.numberOfItems(inSection: 0) - 1, section: 0), at: .bottom, animated: false)
                    }
                }
            }
        }
    }
    
    func loadViews() {
        navigationItem.title = (self.messageOption == .toOne) ? friendName : "群聊"
        navigationItem.backBarButtonItem?.title = "Run!"
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.layer.masksToBounds = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.dropDelegate = self
        collectionView.register(MessageCollectionViewTextCell.self, forCellWithReuseIdentifier: MessageCollectionViewTextCell.cellID)
        collectionView.register(MessageCollectionViewImageCell.self, forCellWithReuseIdentifier: MessageCollectionViewImageCell.cellID)
        collectionView.register(MessageCollectionViewDrawCell.self, forCellWithReuseIdentifier: MessageCollectionViewDrawCell.cellID)
        collectionView.register(MessageCollectionViewTrackCell.self, forCellWithReuseIdentifier: MessageCollectionViewTrackCell.cellID)
        collectionView.layer.masksToBounds = true
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

