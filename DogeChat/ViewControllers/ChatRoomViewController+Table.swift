
import UIKit
import YPTransition
import DogeChatUniversal

extension ChatRoomViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        layoutViews(size: view.bounds.size)
        collectionView.reloadData()
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
        case .track:
            cellID = MessageCollectionViewTrackCell.cellID
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
        return CGSize(width: view.bounds.width, height: MessageCollectionViewBaseCell.height(for: messages[indexPath.item]))
    }
        
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? MessageCollectionViewImageCell)?.downloadImageIfNeeded()
        if let cell = cell as? MessageCollectionViewDrawCell {
            if #available(iOS 14.0, *) {
                if cell.getPKView() == nil {
                    cell.addPKView()
                }
            }
            cell.downloadPKDataIfNeeded()
        }
        if let cell = cell as? MessageCollectionViewBaseCell {
            cell.loadAvatar()
            cell.layoutEmojis()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? MessageCollectionViewImageCell)?.animatedImageView.animatedImage = nil
        if let cell = cell as? MessageCollectionViewBaseCell {
            cell.avatarImageView.animatedImage = nil
            for imageView in cell.emojis.values {
                imageView.removeFromSuperview()
            }
        }
        if #available(iOS 14.0, *) {
            if let cell = (cell as? MessageCollectionViewDrawCell) {
                cell.getPKView()?.removeFromSuperview()
                cell.indicationNeighborView = nil
            }
        }
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
            var addBackgroundColorAction: UIAction?
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
            if #available(iOS 14.0, *) {
                if cell.message.messageType == .draw, let pkView = (cell as? MessageCollectionViewDrawCell)?.getPKView() {
                    addBackgroundColorAction = UIAction(title: "添加背景颜色") { _ in
                        pkView.backgroundColor = .lightGray
                    }
                }
            }
            var children: [UIAction] = [copyAction]
            if revokeAction != nil { children.append(revokeAction!) }
            if starEmojiAction != nil { children.append(starEmojiAction!) }
            if addBackgroundColorAction != nil { children.append(addBackgroundColorAction!) }
            let menu = UIMenu(title: "", image: nil, children: children)
            return menu
        }
    }
    
    func insertNewMessageCell(_ messages: [Message], position: InsertPosition = .bottom, index: Int = 0, completion: (()->Void)? = nil) {
        let alreadyUUIDs = self.messagesUUIDs
        let newUUIDs: Set<String> = Set(messages.map { $0.uuid })
        let filteredUUIDs = newUUIDs.subtracting(alreadyUUIDs)
        var filtered = messages.filter { filteredUUIDs.contains($0.uuid)}
        filtered = filtered.filter { message in
            if message.option != self.messageOption {
                return false
            } else if message.option == .toOne {
                if message.messageSender == .ourself {
                    return message.receiver == friendName
                } else {
                    return message.senderUsername == friendName
                }
            } else {
                return true
            }
        }
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
            if contentHeight - collectionView.contentOffset.y > self.view.bounds.height * 2 {
                scrollToBottom = false
            }
            scrollToBottom = scrollToBottom || (messages.count == 1 && messages[0].messageSender == .ourself)
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
