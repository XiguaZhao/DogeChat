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

extension ChatRoomViewController: MessageTableViewCellDelegate {
    
    func longPressAvatar(_ cell: MessageBaseCell, ges: UILongPressGestureRecognizer!) {
        guard let group = self.friend as? Group, let manager = self.manager else { return }
        if let index = tableView.indexPath(for: cell)?.row {
            let message = messages[index]
            if let friend = self.groupMembers?.first(where: { $0.userID == message.senderUserID }) {
                atFriends([friend])
            } else {
                manager.httpsManager.getGroupMembers(group: group) { [weak self] members in
                    guard let self = self else { return }
                    self.groupMembers = members
                    if let friend = members.first(where: { $0.userID == message.senderUserID }) {
                        self.atFriends([friend])
                    }
                }
            }
        }
    }
    
    func downloadProgressUpdate(progress: Double, messages: [Message]) {
        syncOnMainThread {
            for message in messages {
                if let index = self.messages.firstIndex(where: { $0.uuid == message.uuid }) {
                    let hud = (self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? MessageBaseCell)?.progress
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
            if isPad() {
                if !isMac() {
                    let userActivity = wrapMediaBrowserUserActivity(paths: nil, url: textURL, targetIndex: nil)
                    let option = UIScene.ActivationRequestOptions()
                    option.requestingScene = self.view.window?.windowScene
                    UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: option, errorHandler: nil)
                } else {
                    if let url = URL(string: textURL) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            } else if isPhone() {
                let vc = WebViewController()
                vc.apply(url: textURL)
                self.navigationController?.present(vc, animated: true, completion: nil)
            }
        }
    }
        
    func mediaViewTapped(_ cell: MessageBaseCell, path: String, isAvatar: Bool) {
        messageInputBar.textViewResign()
        let browser = MediaBrowserViewController()
        let paths: [String]
        var targetIndex = 0
        if !isAvatar {
            paths = (self.messages.filter { $0.messageType == .image || $0.messageType == .livePhoto || $0.messageType == .video }).map { $0.text }
            browser.imagePaths = paths
            if let index = paths.firstIndex(of: path) {
                browser.targetIndex = index
                targetIndex = index
            }
        } else {
            paths = [path]
            browser.imagePaths = [path]
        }
        browser.modalPresentationStyle = .fullScreen
        if !isMac() {
            self.navigationController?.present(browser, animated: true, completion: nil)
        } else {
            let option = UIScene.ActivationRequestOptions()
            option.requestingScene = self.view.window?.windowScene
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: self.wrapMediaBrowserUserActivity(paths: paths, targetIndex: targetIndex), options: option, errorHandler: nil)
        }
    }
    
    func wrapMediaBrowserUserActivity(paths: [String]?, url: String? = nil, targetIndex: Int? = 0) -> NSUserActivity {
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
        userActivity.userInfo = userInfo
        return userActivity
    }

    //MARK: PKView手写
    func pkViewTapped(_ cell: MessageBaseCell, pkView: UIView!) {
        if messageInputBar.isActive {
            messageInputBar.textViewResign()
            return
        }
        if let lastActive = activePKView {
            lastActive.isUserInteractionEnabled = false
            lastActive.resignFirstResponder()
        }
        activePKView = pkView
        if let indexPath = tableView.indexPath(for: cell) {
            drawingIndexPath = indexPath
        }

        let drawVC = DrawViewController()
        drawVC.username = username
        guard let pkView = pkView as? PKCanvasView else { return }
        let message = messages[drawingIndexPath.item]
        drawVC.message = message
        drawVC.pkView.drawing = pkView.drawing.transformed(using: CGAffineTransform(scaleX: 1/message.drawScale, y: 1/message.drawScale))
        drawVC.pkViewDelegate.dataChangedDelegate = self
        drawVC.modalPresentationStyle = .fullScreen
        drawVC.chatRoomVC = self
        self.navigationController?.present(drawVC, animated: true, completion: nil)
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
            emojiInfo.y = newPoint.y / MessageBaseCell.height(for: messages[newIndexPath.item], tableViewSize: tableView.frame.size)
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
        guard ges.state == .ended, cell.message.messageType != .join else { return }
        let controller = UIMenuController.shared
        guard let targetView = cell.indicationNeighborView else { return }
        if !messageInputBar.textView.isFirstResponder {
            cell.becomeFirstResponder()
        }
        activeMenuCell = cell
        let index = tableView.indexPath(for: cell)!.row
        let message = messages[index]
        let copy = UIMenuItem(title: "复制", action: #selector(copyMenuItemAction(sender:)))
        let refer = UIMenuItem(title: "引用", action: #selector(referAction(sender:)))
        var items = [copy, refer]
        let sendToOthers = UIMenuItem(title: "转发", action: #selector(sendToOthersMenuItemAction(sender:)))
        items.append(sendToOthers)
        if message.messageSender == .ourself {
            let revoke = UIMenuItem(title: "撤回", action: #selector(revokeMenuItemAction(sender:)))
            items.append(revoke)
        }
        if message.messageType == .image {
            let saveEmoji = UIMenuItem(title: "收藏表情", action: #selector(saveEmojiMenuItemAction(sender:)))
            items.append(saveEmoji)
        }
        let multiSele = UIMenuItem(title: "多选", action: #selector(multiSeleMenuItemAction(sender:)))
        items.append(multiSele)
        controller.menuItems = items
        let rect = CGRect(x: targetView.bounds.width/2, y: 5, width: 0, height: 0)
        messageInputBar.textView.ignoreActions = true
        controller.showMenu(from: targetView, rect: rect)
        messageInputBar.textView.ignoreActions = false
    }
    
    func menuItemDone() {
        UIMenuController.shared.menuItems = nil
        activeMenuCell?.resignFirstResponder()
    }
    
    @objc func copyMenuItemAction(sender: UIMenuController) {
        menuItemDone()
        guard let cell = activeMenuCell,
              let index = tableView.indexPath(for: cell)?.row else { return }
        let text = messages[index].text
        UIPasteboard.general.string = text
    }
    
    @objc func revokeMenuItemAction(sender: UIMenuController) {
        menuItemDone()
        guard let cell = activeMenuCell,
              let index = tableView.indexPath(for: cell)?.row else { return }
        revoke(message: messages[index])
    }
    
    @objc func sendToOthersMenuItemAction(sender: UIMenuController?) {
        menuItemDone()
        guard let cell = activeMenuCell,
              let indexPath = tableView.indexPath(for: cell) else { return }
        self.activeSwipeIndexPath = indexPath
        let contactVC = SelectContactsViewController(username: username)
        contactVC.modalPresentationStyle = .formSheet
        contactVC.delegate = self
        self.present(contactVC, animated: true)
    }
    
    @objc func saveEmojiMenuItemAction(sender: UIMenuController) {
        menuItemDone()
        guard let cell = activeMenuCell else { return }
        if let imageUrl = cell.message.imageURL, cell.message.sendStatus == .success {
            let isGif = imageUrl.hasSuffix(".gif")
            self.manager?.starAndUploadEmoji(filePath: imageUrl, isGif: isGif)
        }
    }
    
    @objc func multiSeleMenuItemAction(sender: UIMenuController) {
        menuItemDone()
        guard let cell = activeMenuCell,
              let indexPath = tableView.indexPath(for: cell) else { return }
        makeMultiSelection(indexPath)
    }
}
