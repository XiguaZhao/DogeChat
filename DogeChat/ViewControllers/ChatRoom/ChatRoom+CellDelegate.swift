//
//  ChatRoomViewController+CellDelegate.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/28.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import Foundation
import DogeChatUniversal
import UIKit
import PencilKit
import DogeChatCommonDefines

extension ChatRoomViewController: MessageTableViewCellDelegate, TransitionFromDataSource, TransitionToDataSource {
    
    func pkViewTapEnabled(_ cell: MessageBaseCell) -> Bool {
        return self.purpose == .chat
    }
    
    func processingMedia(finished: Bool) {
        DispatchQueue.main.async {
            self.navigationItem.title = finished ? self.friendName : NSLocalizedString("processingAndUploadingData", comment: "")
        }
    }
    
    func longPressAvatar(_ cell: MessageBaseCell, ges: UILongPressGestureRecognizer!) {
        if let index = tableView.indexPath(for: cell)?.section {
            let message = messages[index]
            findGroupMember(userID: message.senderUserID) { [weak self] targetMember in
                if let friend = targetMember {
                    self?.atFriends([friend])
                }
            }
        }
    }
    
    func downloadProgressUpdate(progress: Double, messages: [Message]) {
        syncOnMainThread {
            for message in messages {
                if let index = self.messages.firstIndex(where: { $0.uuid == message.uuid }) {
                    let hud = (self.tableView.cellForRow(at: IndexPath(item: 0, section: index)) as? MessageBaseCell)?.progress
                    hud?.isHidden = progress >= 1
                    hud?.setProgress(CGFloat(progress), animated: false)
                }
            }
        }
    }
    
    func downloadSuccess(_ cell: MessageBaseCell?, message: Message) {
        guard let cell = cell, cell.message == message else {
            return
        }
        syncOnMainThread {
            cell.apply(message: message)
            cell.layoutIfNeeded()
            cell.setNeedsLayout()
        }
    }
    
    func mapViewTap(_ cell: MessageBaseCell, latitude: Double, longitude: Double) {
        let vc = LocationVC()
        vc.apply(name: (cell as! MessageLocationCell).locationLabel.text ?? "", latitude: latitude, longitude: longitude, avatarURL: friend.avatarURL)
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func textCellDoubleTap(_ cell: MessageBaseCell) {
        if let text = cell.message?.text {
            let vc = TextBrowerVC()
            vc.setText(text)
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func textCellSingleTap(_ cell: MessageBaseCell) {
        if let text = cell.message?.text {
            guard let textURL = text.webUrlify() else { return }
            if let url = URL(string: textURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
        
    func mediaViewTapped(_ cell: MessageBaseCell, path: String, isAvatar: Bool) {
        if path.isEmpty { return }
        messageInputBar.textViewResign()
        let paths: [String]
        var targetIndex = 0
        var firstURLString: String?
        if !isAvatar {
            let messages = (self.messages.filter { !$0.text.isEmpty && ($0.messageType.isImage || $0.messageType == .livePhoto || $0.messageType == .video) })
            paths = messages.compactMap { $0.text.isEmpty ? nil : $0.text }
            if let index = self.tableView.indexPath(for: cell)?.section {
                targetIndex = messages.firstIndex(of: self.messages[index]) ?? 0
            } else if let index = paths.firstIndex(of: path) {
                targetIndex = index
            }
            if cell.message.messageType == .photo || cell.message.messageType == .sticker {
                firstURLString = path
            }
        } else {
            paths = [path]
            firstURLString = path
        }
        let makeBrowser = {
            let browser = MediaBrowserViewController()
            browser.customData = self.tableView.indexPath(for:cell)?.section
            browser.imagePaths = paths
            browser.targetIndex = targetIndex
            browser.purpose = isAvatar ? .avatar : .normal
            browser.modalPresentationStyle = .fullScreen
            return browser
        }
        if !isMac(),
           let targetView = isAvatar ? cell.avatarImageView : (cell as? MessageImageKindCell)?.container.subviews.first,
           let targetContainerView = isAvatar ? cell.avatarContainer : (cell as? MessageImageKindCell)?.container {
            if let firstURLString = firstURLString {
                MediaLoader.shared.requestImage(urlStr: firstURLString, type: .photo, syncIfCan: true, imageWidth: .original) { [self] image, _, _ in
                    DogeChatTransitionManager.shared.fromDataSource = self
                    DogeChatTransitionManager.shared.toDataSource = self
                    let imageView = UIImageView(image: image)
                    imageView.frame = targetView.convert(targetView.bounds, to: nil)
                    self.transitionSourceView = imageView
                    self.transitionToView = targetView
                    self.transitionToRadiusView = targetContainerView
                    self.transitionFromCornerRadiusView = targetContainerView
                    let browser = makeBrowser()
                    browser.transitioningDelegate = DogeChatTransitionManager.shared
                    self.present(browser, animated: true, completion: nil)
                }
            } else {
                let browser = makeBrowser()
                self.present(browser, animated: true, completion: nil)
            }

        } else {
            if #available(iOS 13.0, *) {
                let option = UIScene.ActivationRequestOptions()
                option.requestingScene = self.view.window?.windowScene
                UIApplication.shared.requestSceneSessionActivation(nil, userActivity: ChatRoomViewController.wrapMediaBrowserUserActivity(paths: paths, targetIndex: targetIndex, purpose: isAvatar ? .avatar : .normal), options: option, errorHandler: nil)
            }
        }
    }
    
    @objc func mediaBrowserPathChange(_ noti: Notification) {
        guard !isMac(), let vc = noti.object as? MediaBrowserViewController,
        let userInfo = noti.userInfo,
        let targetIndex = userInfo["targetIndex"] as? Int,
        let path = userInfo["path"] as? String,
        let purpose = userInfo["purpose"] as? MediaVCPurpose else { return }
        if purpose == .normal {
            let mediaMessages = (self.messages.filter { $0.messageType.isImage || $0.messageType == .livePhoto || $0.messageType == .video })
            var index: Int?
            if mediaMessages.count > targetIndex {
                index = self.messages.firstIndex(of: mediaMessages[targetIndex])
            } else {
                index = self.messages.firstIndex(where: { $0.text == path })
            }
            if let index = index  {
                let indexPath = IndexPath(item: 0, section: index)
                if let cell = self.tableView.cellForRow(at: indexPath) as? MessageImageKindCell {
                    let container = cell.container
                    let converted = container.convert(container.bounds, to: self.view)
                    if converted.intersects(self.navigationController?.navigationBar.frame ?? CGRect.zero) || converted.intersects(messageInputBar.frame) {
//                        self.tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
                    }
                    self.transitionToView = container.subviews.first
                    self.transitionToRadiusView = container
                } else {
//                    tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
                    DispatchQueue.main.async { [self] in
                        if let cell = tableView.cellForRow(at: indexPath) as? MessageImageKindCell {
                            self.transitionToView = cell.container.subviews.first
                            self.transitionToRadiusView = cell.container
                        }
                    }
                }
            }
        } else {
            var target: MessageBaseCell?
            if let index = vc.customData as? Int {
                if let cell = tableView.cellForRow(at: IndexPath(item: 0, section: index)) as? MessageBaseCell {
                    target = cell
                } else {
                    let cells = tableView.visibleCells as! [MessageBaseCell]
                    if let _target = cells.first(where: { $0.message.avatarUrl == path }) {
                        target = _target
                    }
                }
            }
            if let target = target {
                self.transitionToView = target.avatarImageView
                self.transitionToRadiusView = target.avatarContainer
            }
        }
    }
    
    static func wrapMediaBrowserUserActivity(paths: [String]?, url: String? = nil, targetIndex: Int? = 0, purpose: MediaVCPurpose) -> NSUserActivity {
        let userActivity = NSUserActivity(activityType: userActivityID)
        userActivity.title = AppDelegate.mediaBrowserWindow
        var userInfo = [String: Any]()
        if let paths = paths {
            userInfo["paths"] = paths
        }
        if let targetIndex = targetIndex {
            userInfo["index"] = targetIndex
        }
        if let url = url {
            userInfo["url"] = url
        }
        userInfo["purpose"] = purpose.rawValue
        userActivity.userInfo = userInfo
        return userActivity
    }

    //MARK: PKView手写
    func pkViewTapped(_ cell: MessageBaseCell, pkView: UIView!) {
        if #available(iOS 13, *) {
            if messageInputBar.isActive {
//                messageInputBar.textViewResign()
                return
            }
            if let lastActive = activePKView {
                lastActive.isUserInteractionEnabled = false
                lastActive.resignFirstResponder()
            }
            activePKView = pkView
            guard let indexPath = tableView.indexPath(for: cell) else {
                return
            }

            let drawVC = DrawViewController()
            drawVC.username = username
            guard let pkView = pkView as? PKCanvasView else { return }
            let message = messages[indexPath.item]
            drawVC.message = message
            drawVC.pkView.drawing = pkView.drawing.transformed(using: CGAffineTransform(scaleX: 1/message.drawScale, y: 1/message.drawScale))
            drawVC.pkViewDelegate.dataChangeDelegate = self
            drawVC.modalPresentationStyle = .fullScreen
            drawVC.chatRoomVC = self
            self.navigationController?.present(drawVC, animated: true, completion: nil)
        }
    }

    func emojiOutBounds(from cell: MessageBaseCell, gesture: UIGestureRecognizer) {
        let point = gesture.location(in: tableView)
        guard let manager = manager, let oldIndexPath = cell.indexPath else { return }
        guard let newIndexPath = tableView.indexPathForRow(at: point) else {
            needReload(indexPath: [oldIndexPath])
            return
        }
        if let (_emojiInfo, _messageIndex, _) = cell.getIndex(for: gesture),
           let emojiInfo = _emojiInfo,
           let messageIndex = _messageIndex {
            messages[oldIndexPath.item].emojisInfo.remove(at: messageIndex)
            let newPoint = gesture.location(in: tableView.cellForRow(at: newIndexPath)?.contentView)
            emojiInfo.x = newPoint.x / UIScreen.main.bounds.width
            emojiInfo.y = newPoint.y / MessageBaseCell.height(for: messages[newIndexPath.item], tableViewSize: tableView.frame.size, userID: manager.myInfo.userID)
            emojiInfo.lastModifiedBy = manager.messageManager.myName
            emojiInfo.lastModifiedUserId = manager.myInfo.userID ?? ""
            messages[newIndexPath.item].emojisInfo.append(emojiInfo)
            needReload(indexPath: [newIndexPath, oldIndexPath])
            manager.sendEmojiInfos([messages[oldIndexPath.item], messages[newIndexPath.item]])
        }
    }
    
    func emojiInfoDidChange(from oldInfo: EmojiInfo?, to newInfo: EmojiInfo?, cell: MessageBaseCell) {
        if let manager = manager, let indexPahth = tableView.indexPath(for: cell) {
            needReload(indexPath: [indexPahth])
            newInfo?.lastModifiedBy = manager.myName
            newInfo?.lastModifiedUserId = manager.myInfo.userID ?? ""
            manager.sendEmojiInfos([messages[indexPahth.item]])
        }
    }
    
    @objc func playToEnd(_ noti: Notification) {
        guard let _index = MessageAudioCell.index else { return }
        tableView.reloadRows(at: [IndexPath(item: 0, section: _index)], with: .none)
        var nextIndex: Int?
        for (index, message) in self.messages.enumerated() {
            if index > _index && message.messageType == .voice {
                nextIndex = index
                break
            }
        }
        if let nextIndex = nextIndex {
            let message = self.messages[nextIndex]
            if let path = message.voiceURL, let url = fileURLAt(dirName: voiceDir, fileName: path.fileName) {
                let player = MessageAudioCell.voicePlayer
                let item = AVPlayerItem(url: url)
                player.replaceCurrentItem(with: item)
                player.seek(to: .zero)
                player.play()
                message.isPlaying = true
                MessageAudioCell.index = nextIndex
            }
        } else {
            MessageAudioCell.index = nil
            MessageAudioCell.isPlaying = false
        }
        return
    }
    
    func sharedTracksTap(_ cell: MessageBaseCell, tracks: [Track]) {
        let vc = PlayListViewController()
        vc.username = username
        vc.tracks = tracks
        vc.type = .share
        vc.message = cell.message
        vc.modalPresentationStyle = .popover
        let popover = vc.popoverPresentationController
        popover?.permittedArrowDirections = [.left, .down, .right]
        popover?.delegate = self
        popover?.sourceView = (cell as! MessageTrackCell).playButton
        vc.preferredContentSize = CGSize(width: 350, height: min(400, tracks.count * 60 + 100))
        present(vc, animated: true, completion: nil)
    }
    
    func longPressCell(_ cell: MessageBaseCell, ges: UILongPressGestureRecognizer!) {
        guard purpose == .chat, ges.state == .ended, cell.message.messageType != .join else { return }
        let controller = UIMenuController.shared
        guard let targetView = cell.indicationNeighborView else { return }
        activeMenuCell = cell
        let index = tableView.indexPath(for: cell)!.section
        let message = messages[index]
        let copy = UIMenuItem(title: localizedString("copy"), action: #selector(dogechat_copyMenuItemAction(sender:)))
        let refer = UIMenuItem(title: localizedString("refer"), action: #selector(dogechat_referAction(sender:)))
        var items = [copy, refer]
        let sendToOthers = UIMenuItem(title: localizedString("sendToOthers"), action: #selector(dogechat_sendToOthersMenuItemAction(sender:)))
        items.append(sendToOthers)
        if message.messageSender == .ourself {
            let revoke = UIMenuItem(title: localizedString("revoke"), action: #selector(dogechat_revokeMenuItemAction(sender:)))
            items.append(revoke)
        }
        if message.messageType.isImage {
            let saveEmoji = UIMenuItem(title: localizedString("saveMySelf"), action: #selector(dogechat_saveEmojiMenuItemAction(sender:)))
            items.append(saveEmoji)
            if debugUsers.contains(self.username) {
                items.append(UIMenuItem(title: localizedString("saveCommonUse"), action: #selector(dogechat_saveEmojiCommonMenuItemAction(sender:))))
            }
        }
        let multiSele = UIMenuItem(title: localizedString("multiSelect"), action: #selector(dogechat_multiSeleMenuItemAction(sender:)))
        items.append(multiSele)
        controller.menuItems = items
        let rect = targetView.convert(targetView.bounds, to: self.view)
        messageInputBar.textView.ignoreActions = true
        self.becomeFirstResponder()
        if #available(iOS 13.0, *) {
            controller.showMenu(from: self.view, rect: rect)
        } else {
            controller.setTargetRect(rect, in: self.view)
            controller.setMenuVisible(true, animated: true)
        }
        messageInputBar.textView.ignoreActions = false
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if NSStringFromSelector(action).hasPrefix("dogechat") {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
    func menuItemDone() {
        UIMenuController.shared.menuItems = nil
        activeMenuCell?.resignFirstResponder()
    }
    
    @objc func dogechat_copyMenuItemAction(sender: UIMenuController) {
        menuItemDone()
        guard let cell = activeMenuCell,
              let index = tableView.indexPath(for: cell)?.section else { return }
        let message = messages[index]
        makePasteFor(message: message)
    }
    
    func makePasteFor(message: Message) {
        if let index = self.messages.firstIndex(of: message) {
            let items = wrapItemsWithIndexPath(IndexPath(item: 0, section: index))
            UIPasteboard.general.itemProviders = items.map({ $0.itemProvider })
        }
    }
    
    @objc func dogechat_revokeMenuItemAction(sender: UIMenuController) {
        menuItemDone()
        guard let cell = activeMenuCell,
              let index = tableView.indexPath(for: cell)?.section else { return }
        revoke(message: messages[index])
    }
    
    @objc func dogechat_sendToOthersMenuItemAction(sender: UIMenuController?) {
        menuItemDone()
        guard let cell = activeMenuCell,
              let indexPath = tableView.indexPath(for: cell) else { return }
        self.activeSwipeIndexPath = indexPath
        let contactVC = SelectContactsViewController(username: username)
        contactVC.modalPresentationStyle = .formSheet
        contactVC.delegate = self
        self.present(contactVC, animated: true)
    }
    
    @objc func dogechat_saveEmojiMenuItemAction(sender: UIMenuController) {
        menuItemDone()
        guard let cell = activeMenuCell else { return }
        if let imageUrl = cell.message.imageURL, cell.message.sendStatus == .success {
            let emoji  = Emoji(path: imageUrl, type: Emoji.AddEmojiType.favorite.rawValue)
            saveEmoji(emoji)
        }
    }
    
    @objc func dogechat_saveEmojiCommonMenuItemAction(sender: UIMenuController) {
        menuItemDone()
        guard let cell = activeMenuCell else { return }
        if let imageUrl = cell.message.imageURL, cell.message.sendStatus == .success {
            let emoji = Emoji(path: imageUrl, type: Emoji.AddEmojiType.common.rawValue)
            saveEmoji(emoji)
        }
    }
    
    func saveEmoji(_ emoji: Emoji) {
        self.manager?.commonWebSocket.starAndUploadEmoji(emoji: emoji) { success in
            self.makeAutoAlert(message: success ? localizedString("success") : localizedString("fail"), detail: nil, showTime: 0.2, completion: nil)
        }
    }
    
    @objc func dogechat_multiSeleMenuItemAction(sender: UIMenuController) {
        menuItemDone()
        guard let cell = activeMenuCell,
              let indexPath = tableView.indexPath(for: cell) else { return }
        makeMultiSelection(indexPath)
    }
}
