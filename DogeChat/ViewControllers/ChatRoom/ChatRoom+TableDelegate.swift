
import UIKit
import DogeChatNetwork
import DogeChatUniversal

extension ChatRoomViewController: UITableViewDataSource, UITableViewDelegate, SelectContactsDelegate {
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if !ChatRoomViewController.needRotate {
            layoutViews(size: view.bounds.size)
            tableView.reloadData()
        }
        self.messageInputBar.textViewResign()
        dontLayout = false
    }
            
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if scrollBottom {
            DispatchQueue.main.async {
                if !self.messages.isEmpty {
                    self.scrollBottom = false
                    self.tableView.scrollToRow(at: IndexPath(row: self.messages.count - 1, section: 0), at: .bottom, animated: false)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.scrollViewDidEndDecelerating(self.tableView)
                    }
                }
            }
        }
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        var cellID: String?
        switch message.messageType {
        case .join, .text, .voice:
            cellID = MessageCollectionViewTextCell.cellID
        case .image, .livePhoto, .video:
            cellID = MessageCollectionViewImageCell.cellID
        case .draw:
            cellID = MessageCollectionViewDrawCell.cellID
        case .track:
            cellID = MessageCollectionViewTrackCell.cellID
        }
        guard let cellID = cellID,
              let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath) as? MessageCollectionViewBaseCell else {
            return UITableViewCell()
        }
        cell.indexPath = indexPath
        cell.delegate = self
        cell.cache = cache
        cell.username = username
        cell.contactDataSource = self.contactVC
        cell.apply(message: message)
        cell.tableView = tableView
        return cell
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? MessageCollectionViewBaseCell)?.cleanEmojis()
        (cell as? MessageCollectionViewImageCell)?.cleanAvatar()
        (cell as? MessageCollectionViewImageCell)?.cleanAnimatedImageView()
        (cell as? DogeChatTableViewCell)?.endDisplayBlock?(cell as! DogeChatTableViewCell, tableView)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? MessageCollectionViewBaseCell)?.addEmojis()
        (cell as? MessageCollectionViewBaseCell)?.loadAvatar()
        (cell as? MessageCollectionViewImageCell)?.loadImageIfNeeded()
        (cell as? DogeChatTableViewCell)?.willDisplayBlock?(cell as! DogeChatTableViewCell, tableView)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return MessageCollectionViewBaseCell.height(for: messages[indexPath.item], username: username)
    }

                
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView == self.tableView else {
            return
        }
        print(scrollView.contentSize)
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let share = UIContextualAction(style: .normal, title: "转发") { [weak self] action, view, handler in
            guard let self = self else { return }
            handler(true)
            self.activeSwipeIndexPath = indexPath
            let contactVC = SelectContactsViewController()
            contactVC.username = self.username
            contactVC.dataSourcea = self.contactVC
            contactVC.modalPresentationStyle = .formSheet
            contactVC.delegate = self
            self.present(contactVC, animated: true)
        }
        let revoke = UIContextualAction(style: .destructive, title: "撤回") { [weak self] action, view, handler in
            guard let self = self else { return }
            self.revoke(message: self.messages[indexPath.row])
            handler(true)
        }
        share.backgroundColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
        let configuration = UISwipeActionsConfiguration(actions: [share, revoke])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let saveEmoji = UIContextualAction(style: .normal, title: "收藏表情") { [weak tableView, weak self] action, view, handler in
            guard let self = self else { return }
            handler(true)
            if let cell = tableView?.cellForRow(at: indexPath) as? MessageCollectionViewImageCell {
                if let imageUrl = cell.message.imageURL, cell.message.sendStatus == .success {
                    let isGif = imageUrl.hasSuffix(".gif")
                    self.manager.starAndUploadEmoji(filePath: imageUrl, isGif: isGif)
                }
            }
        }
        saveEmoji.backgroundColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
        let multiSelection = UIContextualAction(style: .normal, title: "多选") { [weak self] action, view, handler in
            guard let self = self else { return }
            handler(true)
            self.makeMultiSelection(indexPath)
        }
        multiSelection.backgroundColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
        var actions = [multiSelection]
        if messages[indexPath.row].messageType == .image {
            actions.append(saveEmoji)
        }
        if actions.isEmpty {
            return nil
        }
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = true
        return config
    }
        
    //MARK: ContextMune
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let cell = tableView.cellForRow(at: indexPath) as! MessageCollectionViewBaseCell
        let identifier = "\(indexPath.row)" as NSString
        if let cell = cell as? MessageCollectionViewImageCell {
            let convert = tableView.convert(point, to: cell.livePhotoView)
            if cell.livePhotoView.bounds.contains(convert) {
                return nil
            }
        }
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: nil
        ) { [weak self, weak cell] (menuElement) -> UIMenu? in
            guard let self = self, let cell = cell else { return nil }
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
                revokeAction = UIAction(title: "撤回") { [weak self] (_) in
                    guard let self = self else { return }
                    self.revoke(message: self.messages[indexPath.row])
                }
            }
            if let imageUrl = cell.message.imageURL, cell.message.sendStatus == .success {
                starEmojiAction = UIAction(title: "收藏表情") { [weak self] (_) in
                    let isGif = imageUrl.hasSuffix(".gif")
                    self?.manager.starAndUploadEmoji(filePath: imageUrl, isGif: isGif)
                }
            }
            if #available(iOS 14.0, *) {
                if cell.message.messageType == .draw, let pkView = (cell as? MessageCollectionViewDrawCell)?.getPKView() {
                    addBackgroundColorAction = UIAction(title: "添加背景颜色") { _ in
                        pkView.backgroundColor = .lightGray
                    }
                }
            }
            let multiSelect = UIAction(title: "多选") { [weak self] _ in
                guard let self = self else { return }
                self.makeMultiSelection(indexPath)
            }
            var children: [UIAction] = [copyAction, multiSelect]
            if revokeAction != nil { children.append(revokeAction!) }
            if starEmojiAction != nil { children.append(starEmojiAction!) }
            if addBackgroundColorAction != nil { children.append(addBackgroundColorAction!) }
            let menu = UIMenu(title: "", image: nil, children: children)
            return menu
        }
    }
    
    func makeMultiSelection(_ indexPath: IndexPath? = nil) {
        tableView.allowsMultipleSelection = true
        tableView.allowsMultipleSelectionDuringEditing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            self.tableView.setEditing(true, animated: true)
            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            let cancel = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(self.cancelItemAction))
            let share = UIBarButtonItem(title: "转发", style: .plain, target: self, action: #selector(self.didFinishMultiSelection(_:)))
            self.navigationItem.setRightBarButtonItems([cancel, share], animated: true)
        }
    }
    
    @objc func cancelItemAction() {
        activeSwipeIndexPath = nil
        tableView.setEditing(false, animated: true)
        navigationItem.setRightBarButtonItems(nil, animated: true)
        tableView.indexPathsForVisibleRows?.forEach { tableView.deselectRow(at: $0, animated: true) }
    }
        
    @objc func didFinishMultiSelection(_ button: UIBarButtonItem) {
        let selectContactsVC = SelectContactsViewController()
        selectContactsVC.username = username
        selectContactsVC.delegate = self
        selectContactsVC.dataSourcea = self.contactVC
        selectContactsVC.modalPresentationStyle = .popover
        selectContactsVC.preferredContentSize = CGSize(width: 300, height: 400)
        let popover = selectContactsVC.popoverPresentationController
        popover?.barButtonItem = button
        popover?.permittedArrowDirections = .right
        popover?.delegate = self

        present(selectContactsVC, animated: true, completion: nil)
    }
    
    func didSelectContacts(_ contacts: [String], vc: SelectContactsViewController) {
        defer {
            vc.dismiss(animated: true) {
                self.cancelItemAction()
                self.activeSwipeIndexPath = nil
            }
        }
        var selectedIndexPaths: [IndexPath]?
        if let _selectedIndexPaths = tableView.indexPathsForSelectedRows {
            selectedIndexPaths = _selectedIndexPaths
        } else if let _selectedIndexPath = activeSwipeIndexPath {
            selectedIndexPaths = [_selectedIndexPath]
        }
        guard let selectedIndexPaths = selectedIndexPaths else {
            return
        }
        let selectedMessages = selectedIndexPaths.map { self.messages[$0.row].copied() }
        for contact in contacts {
            if contact == friendName {
                continue
            }
            for message in selectedMessages {
                message.uuid = UUID().uuidString
                message.senderUsername = username
                message.receiver = contact
                message.id = maxID + 1
                message.option = contact == "群聊" ? .toAll : .toOne
                WebSocketManager.shared.sendWrappedMessage(message)
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if let cell = centerCell() as? DogeChatTableViewCell {
            callCenterBlock(centerCell: cell)
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            if let cell = centerCell() as? DogeChatTableViewCell {
                callCenterBlock(centerCell: cell)
            }
        }
    }
    
    func callCenterBlock(centerCell: DogeChatTableViewCell) {
        for cell in tableView.visibleCells  {
            if let cell = cell as? DogeChatTableViewCell {
                if cell == centerCell {
                    cell.centerDisplayBlock?(cell, tableView)
                } else {
                    cell.resignCenterBlock?(cell, tableView)
                }
            }
        }
    }
    
    func centerCell() -> UITableViewCell? {
        var middlePoint = tableView.center
        middlePoint.y += tableView.contentOffset.y
        for cell in tableView.visibleCells {
            let convert = tableView.convert(middlePoint, to: cell)
            if cell.bounds.contains(convert) {
                return cell
            }
        }
        return nil
    }
    
    func didCancelSelectContacts(_ vc: SelectContactsViewController) {
        vc.dismiss(animated: true) {
            self.cancelItemAction()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.messageInputBar.textViewResign()
        if !tableView.isEditing {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let should = tableView.isEditing || messageInputBar.isActive
        return should
    }
    

    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView == tableView else {
            return
        }
        if messageInputBar.textView.isFirstResponder {
            messageInputBar.textViewResign()
        }
    }
    
    func needReload(indexPath: [IndexPath]) {
        tableView.reloadRows(at: indexPath, with: .none)
    }
    
    @objc func receiveEmojiInfoChangedNotification(_ noti: Notification) {
        guard let (receiver, sender) = noti.userInfo?["receiverAndSender"] as? (String, String), let message = noti.userInfo?["message"] as? Message else { return }
        if (receiver == "PublicPino" && navigationItem.title == "群聊") || sender == friendName {
            if let index = messages.firstIndex(of: message) { // 消息存在
                let indexPath = IndexPath(item: index, section: 0)
                tableView.reloadRows(at: [indexPath], with: .none)
            } else { // 最好就是加载到这条消息为止
                
            }
        } else { // 弹窗通知
            
        }
    }
}
