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
    
    func downloadProgressUpdate(progress: Progress, message: Message) {
        syncOnMainThread {
            if let index = self.messages.firstIndex(where: { $0.uuid == message.uuid }) {
                let hud = (self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? MessageCollectionViewBaseCell)?.progress
                hud?.isHidden = progress.fractionCompleted >= 1
                hud?.setProgress(CGFloat(progress.fractionCompleted), animated: false)
            }
        }
    }
    
    func downloadSuccess(message: Message) {
        syncOnMainThread {
            if let index = self.messages.firstIndex(where: { $0.uuid == message.uuid }) {
                let indexPath = IndexPath(row: index, section: 0)
                if let cell = self.tableView.cellForRow(at: indexPath) as? MessageCollectionViewBaseCell {
                    (cell as? MessageCollectionViewImageCell)?.playNow = true
                    cell.apply(message: message)
                    cell.layoutIfNeeded()
                    cell.setNeedsLayout()
                }
            }
        }
    }
        
    func imageViewTapped(_ cell: MessageCollectionViewBaseCell, imageView: FLAnimatedImageView, path: String, isAvatar: Bool) {
        messageInputBar.textViewResign()
        let browser = ImageBrowserViewController()
        if !isAvatar {
            let paths = (self.messages.filter { $0.messageType == .image }).compactMap { $0.imageLocalPath?.absoluteString ?? $0.imageURL }
            browser.imagePaths = paths
            if let index = paths.firstIndex(of: path) {
                browser.targetIndex = index
            }
        } else {
            browser.imagePaths = [path]
        }
        browser.modalPresentationStyle = .fullScreen
        AppDelegate.shared.navigationController.present(browser, animated: true, completion: nil)
    }

    //MARK: PKView手写
    func pkViewTapped(_ cell: MessageCollectionViewBaseCell, pkView: UIView!) {
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
        if #available(iOS 14.0, *) {

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
    }

    func emojiOutBounds(from cell: MessageCollectionViewBaseCell, gesture: UIGestureRecognizer) {
        let point = gesture.location(in: tableView)
        guard let oldIndexPath = cell.indexPath else { return }
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
            emojiInfo.y = newPoint.y / MessageCollectionViewBaseCell.height(for: messages[newIndexPath.item], username: username)
            emojiInfo.lastModifiedBy = manager.messageManager.myName
            messages[newIndexPath.item].emojisInfo.append(emojiInfo)
            needReload(indexPath: [newIndexPath, oldIndexPath])
            manager.sendEmojiInfos([messages[oldIndexPath.item], messages[newIndexPath.item]], receiver: friendName)
        }
    }
    
    func emojiInfoDidChange(from oldInfo: EmojiInfo?, to newInfo: EmojiInfo?, cell: MessageCollectionViewBaseCell) {
        if let indexPahth = tableView.indexPath(for: cell) {
            needReload(indexPath: [indexPahth])
            newInfo?.lastModifiedBy = manager.messageManager.myName
            manager.sendEmojiInfos([messages[indexPahth.item]], receiver: friendName)
        }
    }
    
    func sharedTracksTap(_ cell: MessageCollectionViewBaseCell, tracks: [Track]) {
        let vc = PlayListViewController()
        vc.username = username
        vc.tracks = tracks
        vc.type = .share
        vc.message = cell.message
        vc.modalPresentationStyle = .popover
        let popover = vc.popoverPresentationController
        popover?.permittedArrowDirections = [.left, .down, .right]
        popover?.delegate = self
        popover?.sourceView = (cell as! MessageCollectionViewTrackCell).playButton
        vc.preferredContentSize = CGSize(width: 350, height: min(400, tracks.count * 60 + 100))
        present(vc, animated: true, completion: nil)
    }
    
    func longPressCell(_ cell: MessageCollectionViewBaseCell, ges: UILongPressGestureRecognizer!) {
        let controller = UIMenuController.shared
        guard let targetView = cell.indicationNeighborView else { return }
        cell.becomeFirstResponder()
        activeMenuCell = cell
        let index = tableView.indexPath(for: cell)!.row
        let message = messages[index]
        let copy = UIMenuItem(title: "复制", action: #selector(copyMenuItemAction(sender:)))
        var items = [copy]
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
        if #available(iOS 13.0, *) {
            controller.showMenu(from: targetView, rect: rect)
        } else {
            controller.setTargetRect(rect, in: targetView)
            controller.setMenuVisible(true, animated: true)
        }
    }
    
    @objc func copyMenuItemAction(sender: UIMenuController) {
        guard let cell = activeMenuCell,
              let index = tableView.indexPath(for: cell)?.row else { return }
        let text = messages[index].message
        UIPasteboard.general.string = text
    }
    
    @objc func revokeMenuItemAction(sender: UIMenuController) {
        guard let cell = activeMenuCell,
              let index = tableView.indexPath(for: cell)?.row else { return }
        revoke(message: messages[index])
    }
    
    @objc func sendToOthersMenuItemAction(sender: UIMenuController) {
        guard let cell = activeMenuCell,
              let indexPath = tableView.indexPath(for: cell) else { return }
        self.activeSwipeIndexPath = indexPath
        let contactVC = SelectContactsViewController()
        contactVC.username = self.username
        contactVC.dataSourcea = self.contactVC
        contactVC.modalPresentationStyle = .formSheet
        contactVC.delegate = self
        self.present(contactVC, animated: true)
    }
    
    @objc func saveEmojiMenuItemAction(sender: UIMenuController) {
        guard let cell = activeMenuCell else { return }
        if let imageUrl = cell.message.imageURL, cell.message.sendStatus == .success {
            let isGif = imageUrl.hasSuffix(".gif")
            self.manager.starAndUploadEmoji(filePath: imageUrl, isGif: isGif)
        }
    }
    
    @objc func multiSeleMenuItemAction(sender: UIMenuController) {
        guard let cell = activeMenuCell,
              let indexPath = tableView.indexPath(for: cell) else { return }
        makeMultiSelection(indexPath)
    }
}
