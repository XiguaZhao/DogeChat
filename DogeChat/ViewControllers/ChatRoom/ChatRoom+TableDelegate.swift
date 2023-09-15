
import UIKit
import DogeChatNetwork
import DogeChatUniversal
import DogeChatCommonDefines

extension ChatRoomViewController: UITableViewDataSource, UITableViewDelegate, SelectContactsDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.messages.count + 1; // 1是用来滚动到底部
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let message = messages.safe_objectAt(indexPath.section) else {
            let cell = tableView.dequeueReusableCell(withIdentifier: NSStringFromClass(UITableViewCell.self), for: indexPath)
            cell.backgroundColor = .clear
            return cell
        }
        var cellID: String?
        switch message.messageType {
        case .text:
            cellID = MessageTextCell.cellID
        case .join:
            cellID = MessageIndicateCell.cellID
        case .voice:
            cellID = MessageAudioCell.audioCellID()
        case .photo, .sticker:
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
        messages.safe_objectAt(indexPath.section)?.isRead = true
        (cell as? DogeChatTableViewCell)?.willDisplayBlock?(cell as! DogeChatTableViewCell, tableView)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == messages.count {
            return 16
        }
        guard let message = messages.safe_objectAt(indexPath.section) else { return 0 }
        let height = MessageBaseCell.height(for: message, tableViewSize: tableView.frame.size, userID: manager?.myInfo.userID)
        updateCachedHeight(uuid: message.uuid, header: nil, row: height)
        return height
    }

    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        return true
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if velocity.y > 1.5 && scrollView.contentSize.height - scrollView.contentOffset.y < scrollView.height {
            self.messageInputBar.textView.becomeFirstResponder()
        }
    }
                
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == tableView else { return }
        let extra: CGFloat = isMac() ? 0 : 50
        let offsetY = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        if offsetY <= extra && !isFetchingHistory {
            if isMac() || !tableView.isDragging {
                displayHistory()
            }
        }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView == self.tableView else {
            return
        }
        didStopScroll()
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let message = messages.safe_objectAt(indexPath.section) else { return nil }
        _ = UIContextualAction(style: .normal, title: localizedString("sendToOthers")) { [weak self] action, view, handler in
            guard let self = self else { return }
            handler(true)
            self.activeSwipeIndexPath = indexPath
            let contactVC = SelectContactsViewController(username: self.username)
            contactVC.modalPresentationStyle = .formSheet
            contactVC.delegate = self
            self.present(contactVC, animated: true)
        }
        _ = UIContextualAction(style: .destructive, title: localizedString("revoke")) { [weak self] action, view, handler in
            guard let self = self else { return }
            self.revoke(message: self.messages[indexPath.section])
            handler(true)
        }
        let at = UIContextualAction(style: .normal, title: "@") { [weak self] action, view, handler in
            guard let _self = self else { return }
            _self.findGroupMember(userID: _self.messages[indexPath.section].senderUserID) { friend in
                if let friend = friend {
                    self?.atFriends([friend])
                }
            }
            handler(true)
        }
        at.backgroundColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
        var actions: [UIContextualAction] = []
        if message.option == .toGroup {
            actions.append(at)
        }
        let configuration = UISwipeActionsConfiguration(actions: actions)
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard self.purpose == .chat, let message = messages.safe_objectAt(indexPath.section) else { return nil }
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
                self.dogechat_referAction(sender: nil)
            }
        }
        referAction.backgroundColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
        var actions = [multiSelection]
        if message.messageType.isImage {
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
        guard let message = messages.safe_objectAt(indexPath.section), let cell = tableView.cellForRow(at: indexPath) as? MessageBaseCell else {
            return nil
        }
        let identifier = "\(indexPath.section)" as NSString
        let actionProvider: ([UIMenuElement]) -> UIMenu? = { [weak self, weak cell] (menuElement) -> UIMenu? in
            guard let self = self, let cell = cell else { return nil }
            self.activeMenuCell = cell
            let copyAction = UIAction(title: localizedString("copy")) { (_) in
                self.makePasteFor(message: self.messages[indexPath.section])
            }
            var revokeAction: UIAction?
            var starMySelfAction: UIAction?
            var starPublicAction: UIAction?
            var addBackgroundColorAction: UIAction?
            var referAction: UIAction?
            var sendToOthersAction: UIAction?
            if self.messages[indexPath.section].messageSender == .ourself && self.messages[indexPath.section].messageType != .join {
                revokeAction = UIAction(title: localizedString("revoke")) { [weak self] (_) in
                    guard let self = self else { return }
                    self.revoke(message: self.messages[indexPath.section])
                }
            }
            if let imageUrl = message.imageURL, message.sendStatus == .success {
                starMySelfAction = UIAction(title: localizedString("saveMySelf")) { [weak self] (_) in
                    self?.manager?.commonWebSocket.starAndUploadEmoji(emoji: Emoji(path: imageUrl, type: Emoji.AddEmojiType.favorite.rawValue))
                }
                starPublicAction = UIAction(title: localizedString("saveCommonUse")) { [weak self] (_) in
                    self?.manager?.commonWebSocket.starAndUploadEmoji(emoji: Emoji(path: imageUrl, type: Emoji.AddEmojiType.common.rawValue))
                }
            }
            if message.messageType == .draw, let pkView = (cell as? MessageDrawCell)?.getPKView() {
                addBackgroundColorAction = UIAction(title: localizedString("addBgcolor")) { _ in
                    pkView.backgroundColor = .lightGray
                }
            }
            if message.messageType != .join {
                referAction = UIAction(title: localizedString("refer")) { [weak self] _ in
                    self?.dogechat_referAction(sender: nil)
                }
                sendToOthersAction = UIAction(title: localizedString("sendToOthers")) { [weak self] _ in
                    self?.dogechat_sendToOthersMenuItemAction(sender: nil)
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
            if starMySelfAction != nil { children.append(starMySelfAction!) }
            if starPublicAction != nil { children.append(starPublicAction!) }
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
            let selectedMessages = selectedIndexPaths.map { self.messages[$0.section] }
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
        self.messageInputBar.textView.selectedRange = NSRange(location: location + NSString(string: append).length, length: 0)
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
        if let uuids = self.tableView.indexPathsForVisibleRows?.compactMap({ self.messages.safe_objectAt($0.section)?.uuid }) {
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
        guard indexPath.section < messages.count else { return false }
        return true
    }
    
    
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView == tableView else {
            return
        }
        if messageInputBar.emojiButtonStatus == .normal {
            if !isMac() {
                messageInputBar.textViewResign()
            }
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
                let indexPath = IndexPath(item: 0, section: index)
                tableView.reloadRows(at: [indexPath], with: .none)
            } else { // 最好就是加载到这条消息为止
                
            }
        } else { // 弹窗通知
            
        }
    }
}
