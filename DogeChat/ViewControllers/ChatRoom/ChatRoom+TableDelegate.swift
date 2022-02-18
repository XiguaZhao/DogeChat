
import UIKit
import DogeChatNetwork
import DogeChatUniversal
import DogeChatCommonDefines

extension ChatRoomViewController: UITableViewDataSource, UITableViewDelegate, SelectContactsDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        var cellID: String?
        switch message.messageType {
        case .join, .text:
            cellID = MessageTextCell.cellID
        case .voice:
            cellID = MessageAudioCell.audioCellID()
        case .image:
            cellID = MessageImageCell.cellID
        case .livePhoto:
            cellID = MessageLivePhotoCell.cellID
        case .video:
            cellID = MessageVideoCell.cellID
        case .draw:
            cellID = MessageDrawCell.cellID
        case .track:
            cellID = MessageTrackCell.cellID
        case .location:
            cellID = MessageLocationCell.cellID
        }
        guard let cellID = cellID,
              let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath) as? MessageBaseCell else {
            return UITableViewCell()
        }
        cell.referView.delegate = self
        cell.indexPath = indexPath
        cell.delegate = self
        cell.username = username
        cell.contactDataSource = self.contactVC
        cell.tableView = tableView
        cell.apply(message: message)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? DogeChatTableViewCell)?.endDisplayBlock?(cell as! DogeChatTableViewCell, tableView)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? MessageBaseCell {
            cell.message?.isRead = true
        }
        (cell as? DogeChatTableViewCell)?.willDisplayBlock?(cell as! DogeChatTableViewCell, tableView)
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let height = MessageBaseCell.height(for: messages[indexPath.item], tableViewSize: tableView.frame.size, userID: manager?.myInfo.userID)
        heightCache[messages[indexPath.row].uuid] = height
        return height
    }
    
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        return true
    }

                
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView == self.tableView else {
            return
        }
        didStopScroll()
        print(scrollView.contentSize)
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let share = UIContextualAction(style: .normal, title: localizedString("sendToOthers")) { [weak self] action, view, handler in
            guard let self = self else { return }
            handler(true)
            self.activeSwipeIndexPath = indexPath
            let contactVC = SelectContactsViewController(username: self.username)
            contactVC.modalPresentationStyle = .formSheet
            contactVC.delegate = self
            self.present(contactVC, animated: true)
        }
        let revoke = UIContextualAction(style: .destructive, title: localizedString("revoke")) { [weak self] action, view, handler in
            guard let self = self else { return }
            self.revoke(message: self.messages[indexPath.row])
            handler(true)
        }
        share.backgroundColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
        var actions = [share]
        if messages[indexPath.item].messageSender == .ourself {
            actions.append(revoke)
        }
        let configuration = UISwipeActionsConfiguration(actions: actions)
        configuration.performsFirstActionWithFullSwipe = true
        return nil
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard self.purpose == .chat else { return nil }
        let saveEmoji = UIContextualAction(style: .normal, title: localizedString("saveMySelf")) { [weak tableView, weak self] action, view, handler in
            guard let self = self else { return }
            handler(true)
            if let cell = tableView?.cellForRow(at: indexPath) as? MessageImageCell {
                if let imageUrl = cell.message.imageURL, cell.message.sendStatus == .success {
                    self.manager?.commonWebSocket.starAndUploadEmoji(emoji: Emoji(path: imageUrl, type: Emoji.AddEmojiType.favorite.rawValue))
                }
            }
        }
        saveEmoji.backgroundColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
        let multiSelection = UIContextualAction(style: .normal, title: localizedString("multiSelect")) { [weak self] action, view, handler in
            guard let self = self else { return }
            handler(true)
            self.makeMultiSelection(indexPath)
        }
        multiSelection.backgroundColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
        let referAction = UIContextualAction(style: .normal, title: localizedString("refer")) { [weak self, weak tableView] action, view, handler in
            guard let self = self else { return }
            handler(true)
            if let cell = tableView?.cellForRow(at: indexPath) as? MessageBaseCell {
                self.activeMenuCell = cell
                self.referAction(sender: nil)
            }
        }
        referAction.backgroundColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
        var actions = [multiSelection]
        if messages[indexPath.row].messageType == .image {
            actions.append(saveEmoji)
        }
        actions = [referAction]
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = true
        return config
    }
        
    //MARK: ContextMune
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let cell = tableView.cellForRow(at: indexPath) as! MessageBaseCell
        let identifier = "\(indexPath.row)" as NSString
        let actionProvider: ([UIMenuElement]) -> UIMenu? = { [weak self, weak cell] (menuElement) -> UIMenu? in
            guard let self = self, let cell = cell else { return nil }
            self.activeMenuCell = cell
            let copyAction = UIAction(title: localizedString("copy")) { (_) in
                self.makePasteFor(message: self.messages[indexPath.row])
            }
            var revokeAction: UIAction?
            var starEmojiAction: UIAction?
            var addBackgroundColorAction: UIAction?
            var referAction: UIAction?
            var sendToOthersAction: UIAction?
            if self.messages[indexPath.row].messageSender == .ourself && self.messages[indexPath.row].messageType != .join {
                revokeAction = UIAction(title: localizedString("revoke")) { [weak self] (_) in
                    guard let self = self else { return }
                    self.revoke(message: self.messages[indexPath.row])
                }
            }
            if let imageUrl = cell.message.imageURL, cell.message.sendStatus == .success {
                starEmojiAction = UIAction(title: localizedString("saveMySelf")) { [weak self] (_) in
                    self?.manager?.commonWebSocket.starAndUploadEmoji(emoji: Emoji(path: imageUrl, type: Emoji.AddEmojiType.favorite.rawValue))
                }
            }
            if cell.message.messageType == .draw, let pkView = (cell as? MessageDrawCell)?.getPKView() {
                addBackgroundColorAction = UIAction(title: localizedString("addBgcolor")) { _ in
                    pkView.backgroundColor = .lightGray
                }
            }
            if cell.message.messageType != .join {
                referAction = UIAction(title: localizedString("refer")) { [weak self] _ in
                    self?.referAction(sender: nil)
                }
                sendToOthersAction = UIAction(title: localizedString("sendToOthers")) { [weak self] _ in
                    self?.sendToOthersMenuItemAction(sender: nil)
                }
            }
            let multiSelect = UIAction(title: localizedString("multiSelect")) { [weak self] _ in
                guard let self = self else { return }
                self.makeMultiSelection(indexPath)
            }
            var children: [UIAction] = [copyAction, multiSelect]
            if let referAction = referAction {
                children.append(referAction)
            }
            if let sendToOthersAction = sendToOthersAction {
                children.append(sendToOthersAction)
            }
            if revokeAction != nil { children.append(revokeAction!) }
            if starEmojiAction != nil { children.append(starEmojiAction!) }
            if addBackgroundColorAction != nil { children.append(addBackgroundColorAction!) }
            let menu = UIMenu(title: "", image: nil, children: children)
            return menu
        }
        if !isMac() {
            if let text = (cell as? MessageTextCell)?.messageLabel.text, let textURL = text.webUrlify() {
                return UIContextMenuConfiguration(identifier: identifier, previewProvider: {
                    let safariVC = WebViewController()
                    safariVC.apply(url: textURL)
                    return safariVC
                }, actionProvider: actionProvider)
            }
            return nil
        }
        if let cell = cell as? MessageLivePhotoCell {
            let convert = tableView.convert(point, to: cell.livePhotoView)
            if cell.livePhotoView.bounds.contains(convert) {
                return nil
            }
        }
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: nil, actionProvider: actionProvider)
    }
    
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        if let vc = animator.previewViewController {
            DispatchQueue.main.async {
                self.splitViewController?.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    func makeMultiSelection(_ indexPath: IndexPath? = nil) {
        tableView.allowsMultipleSelection = true
        tableView.allowsMultipleSelectionDuringEditing = true
        self.tableView.setEditing(true, animated: true)
        self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        setupToolBar()
    }
    
    @objc func cancelItemAction() {
        activeSwipeIndexPath = nil
        tableView.setEditing(false, animated: true)
        tableView.indexPathsForVisibleRows?.forEach { tableView.deselectRow(at: $0, animated: true) }
        recoverInputBar()
    }
        
    @objc func didFinishMultiSelection(_ button: UIBarButtonItem) {
        let selectContactsVC = SelectContactsViewController(username: username)
        selectContactsVC.delegate = self
        selectContactsVC.modalPresentationStyle = .popover
        selectContactsVC.preferredContentSize = CGSize(width: 300, height: 400)
        let popover = selectContactsVC.popoverPresentationController
        popover?.barButtonItem = button
        popover?.permittedArrowDirections = .right
        popover?.delegate = self
        
        present(selectContactsVC, animated: true, completion: nil)
    }
    
    func didSelectContacts(_ contacts: [Friend], vc: SelectContactsViewController) {
        defer {
            self.cancelItemAction()
            self.activeSwipeIndexPath = nil
        }
        switch vc.type {
        case .all:
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
            Self.transferMessages(selectedMessages, to: contacts, manager: self.manager)
            self.makeAutoAlert(message: localizedString("alreadySendToOthers"), detail: contacts.map({$0.username}).joined(separator: "、"), showTime: 1, completion: nil)
        case .group:
            atFriends(contacts)
        }
    }
    
    func didFetchContacts(_ contacts: [Friend], vc: SelectContactsViewController) {
        self.groupMembers = contacts
    }
    
    func atFriends(_ contacts: [Friend]) {
        let location = messageInputBar.textView.selectedRange.location
        var append = ""
        for contact in contacts {
            let username = contact.nameInGroup ?? contact.username
            self.messageSender.at[username] = contact.userID
            append += "@\(username)"
        }
        var originalText = self.messageInputBar.textView.text ?? ""
        let index = String.Index.init(utf16Offset: location, in: originalText)
        originalText.insert(contentsOf: append, at: index)
        self.messageInputBar.textView.text = originalText
        self.textViewDidChange(self.messageInputBar.textView)
        DispatchQueue.main.async {
            self.messageInputBar.textView.becomeFirstResponder()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if let cell = centerCell() as? DogeChatTableViewCell {
            callCenterBlock(centerCell: cell)
        }
        didStopScroll()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.decelerate()
            didStopScroll()
            if let cell = centerCell() as? DogeChatTableViewCell {
                callCenterBlock(centerCell: cell)
            }
        }
    }
    
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        didStopScroll()
    }
    

    
    func decelerate() {
        if let uuids = self.tableView.indexPathsForVisibleRows?.map({ self.messages[$0.row].uuid }) {
            if uuids.contains(self.explictJumpMessageUUID ?? "") {
                self.explictJumpMessageUUID = nil
            }
        }
    }
    
    func didStopScroll() {
        processJumpToUnreadButton()
        processJumpToBottomButton()
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
//        let should = tableView.isEditing || messageInputBar.isActive
//        return should
        return true
    }
    

    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView == tableView else {
            return
        }
        if messageInputBar.emojiButtonStatus == .normal {
            messageInputBar.textViewResign()
        }
        if #available(iOS 13.0, *) {
            UIMenuController.shared.hideMenu()
        } else {
            UIMenuController.shared.setMenuVisible(false, animated: true)
        }
    }
    
    func needReload(indexPath: [IndexPath]) {
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
    @objc func receiveEmojiInfoChangedNotification(_ noti: Notification) {
        guard noti.object as? String == self.username else { return }
        guard let (_, _, friend) = noti.userInfo?["receiverAndSender"] as? (String, String, Friend), let message = noti.userInfo?["message"] as? Message else { return }
        if friend.userID == self.friend.userID {
            if let index = messages.firstIndex(of: message) { // 消息存在
                let indexPath = IndexPath(item: index, section: 0)
                tableView.reloadRows(at: [indexPath], with: .none)
            } else { // 最好就是加载到这条消息为止
                
            }
        } else { // 弹窗通知
            
        }
    }
}
