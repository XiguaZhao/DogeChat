
import UIKit
import YPTransition
import DogeChatUniversal

extension ChatRoomViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard let splitVC = self.splitViewController,
              let contactVC = ((splitVC.viewControllers.first as? UITabBarController)?.viewControllers?.first as? UINavigationController)?.viewControllers.first as? ContactsTableViewController else { return }
        if !splitVC.isCollapsed {
            ContactsTableViewController.poppedChatVC = contactVC.navigationController?.popToRootViewController(animated: false)
            if let popped = ContactsTableViewController.poppedChatVC, popped.count > 0 {
                splitVC.showDetailViewController(UINavigationController(rootViewController: popped[0]), sender: nil)
                return
            }
            if splitVC.viewControllers.count > 1, let chatroomVC = (splitVC.viewControllers[1] as? UINavigationController)?.topViewController as? ChatRoomViewController {
                AppDelegate.shared.navigationController = (splitVC.viewControllers[1] as! UINavigationController)
                DispatchQueue.main.async {
                    chatroomVC.layoutViews(size: size)
                    chatroomVC.collectionView.reloadData()
                }
            }
            ContactsTableViewController.poppedChatVC = nil
        } else {
            if let nc = (splitVC.viewControllers.first as? UITabBarController)?.viewControllers?.first as? UINavigationController {
                AppDelegate.shared.navigationController = nc
            }
        }
    }
        
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if scrollBottom {
            DispatchQueue.main.async {
                guard !self.messages.isEmpty else { return }
                self.collectionView.scrollToItem(at: IndexPath(row: self.messages.count - 1, section: 0), at: .bottom, animated: false)
            }
        }
        return messages.count
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let message = messages[indexPath.row]
        var cellID: String?
        switch message.messageType {
        case .join, .text:
            cellID = MessageCollectionViewTextCell.cellID
        case .image:
            cellID = MessageCollectionViewImageCell.cellID
        case .draw:
            cellID = MessageCollectionViewDrawCell.cellID
        default:
            cellID = nil
        }
        guard let cellID = cellID,
              let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellID, for: indexPath) as? MessageCollectionViewBaseCell else {
            return UICollectionViewCell()
        }
        cell.indexPath = indexPath
        cell.delegate = self
        cell.cache = cache
        cell.contentSize = self.collectionView(collectionView, layout: collectionView.collectionViewLayout, sizeForItemAt: indexPath)
        cell.apply(message: message)
        return cell
    }
        
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: MessageCollectionViewBaseCell.height(for: messages[indexPath.item]))
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == collectionView, scrollView.contentOffset.y == -collectionView.safeAreaInsets.top else {
            return
        }
        if scrollBottom {
            return
        }
        displayHistory()
    }
    
    //MARK: ContextMune
    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let cell = collectionView.cellForItem(at: indexPath) as! MessageCollectionViewBaseCell
        let identifier = "\(indexPath.row)" as NSString
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: nil
        ) { (menuElement) -> UIMenu? in
            let copyAction = UIAction(title: "复制") { (_) in
                if let textCell = cell as? MessageCollectionViewTextCell {
                    let text = textCell.messageLabel.text
                    UIPasteboard.general.string = text
                }
            }
            var revokeAction: UIAction?
            var starEmojiAction: UIAction?
            if self.messages[indexPath.row].messageSender == .ourself && self.messages[indexPath.row].messageType != .join {
                revokeAction = UIAction(title: "撤回") { (_) in
                    self.revoke(indexPath: indexPath)
                }
            }
            if let imageUrl = cell.message.imageURL, cell.message.sendStatus == .success {
                starEmojiAction = UIAction(title: "收藏表情") { (_) in
                    let isGif = imageUrl.hasSuffix(".gif")
                    self.manager.starAndUploadEmoji(filePath: imageUrl, isGif: isGif)
                }
            }
            var children: [UIAction] = [copyAction]
            if revokeAction != nil { children.append(revokeAction!) }
            if starEmojiAction != nil { children.append(starEmojiAction!) }
            let menu = UIMenu(title: "", image: nil, children: children)
            return menu
        }
    }
    
    func insertNewMessageCell(_ messages: [Message], position: InsertPosition = .bottom, index: Int = 0, completion: (()->Void)? = nil) {
        let alreadyUUIDs = self.messagesUUIDs
        let newUUIDs: Set<String> = Set(messages.map { $0.uuid })
        let filteredUUIDs = newUUIDs.subtracting(alreadyUUIDs)
        let filtered = messages.filter { filteredUUIDs.contains($0.uuid)}
        guard !filtered.isEmpty else {
            return
        }
        DispatchQueue.main.async { [self] in
            var indexPaths: [IndexPath] = []
            for message in filtered {
                indexPaths.append(IndexPath(row: self.messages.count, section: 0))
                self.messages.append(message)
                self.messagesUUIDs.insert(message.uuid)
            }
            collectionView.insertItems(at: indexPaths)
            var scrollToBottom = !collectionView.isDragging
            let contentHeight = collectionView.contentSize.height
            if contentHeight - collectionView.contentOffset.y > self.view.bounds.height {
                scrollToBottom = false
            }
            scrollToBottom = scrollToBottom || (messages.count == 1 && messages[0].messageSender == .ourself)
            scrollToBottom = scrollToBottom && (drawingIndexPath == nil)
            if scrollToBottom, let indexPath = indexPaths.last {
                collectionView.scrollToItem(at: indexPath, at: .bottom, animated: true)
            }
            completion?()
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView == collectionView else {
            return
        }
        messageInputBar.textView.resignFirstResponder()
    }
    
    func emojiOutBounds(from cell: MessageCollectionViewBaseCell, gesture: UIGestureRecognizer) {
        let point = gesture.location(in: collectionView)
        guard let oldIndexPath = cell.indexPath else { return }
        guard let newIndexPath = collectionView.indexPathForItem(at: point) else {
            needReload(indexPath: [oldIndexPath])
            return
        }
        if let (_emojiInfo, _messageIndex, _) = cell.getIndex(for: gesture),
           let emojiInfo = _emojiInfo,
           let messageIndex = _messageIndex {
            messages[oldIndexPath.item].emojisInfo.remove(at: messageIndex)
            let newPoint = gesture.location(in: collectionView.cellForItem(at: newIndexPath)?.contentView)
            emojiInfo.x = newPoint.x / UIScreen.main.bounds.width
            emojiInfo.y = newPoint.y / MessageCollectionViewBaseCell.height(for: messages[newIndexPath.item])
            emojiInfo.lastModifiedBy = manager.messageManager.myName
            messages[newIndexPath.item].emojisInfo.append(emojiInfo)
            needReload(indexPath: [newIndexPath, oldIndexPath])
            manager.sendEmojiInfos([messages[oldIndexPath.item], messages[newIndexPath.item]], receiver: friendName)
        }
    }
    
    func emojiInfoDidChange(from oldInfo: EmojiInfo?, to newInfo: EmojiInfo?, cell: MessageCollectionViewBaseCell) {
        if let indexPahth = collectionView.indexPath(for: cell) {
            needReload(indexPath: [indexPahth])
            newInfo?.lastModifiedBy = manager.messageManager.myName
            manager.sendEmojiInfos([messages[indexPahth.item]], receiver: friendName)
        }
    }
    
    func needReload(indexPath: [IndexPath]) {
        collectionView.reloadItems(at: indexPath)
    }
    
    @objc func receiveEmojiInfoChangedNotification(_ noti: Notification) {
        guard let (receiver, sender) = noti.object as? (String, String), let message = noti.userInfo?["message"] as? Message else { return }
        if (receiver == "PublicPino" && navigationItem.title == "群聊") || sender == friendName {
            if let index = messages.firstIndex(of: message) { // 消息存在
                let indexPath = IndexPath(item: index, section: 0)
                collectionView.reloadItems(at: [indexPath])
            } else { // 最好就是加载到这条消息为止
                
            }
        } else { // 弹窗通知
            
        }
    }
}
