//
//  ChatRoomViewController+CellDelegate.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/28.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatUniversal

extension ChatRoomViewController: MessageTableViewCellDelegate {
    
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
            guard let pkView = pkView as? PKCanvasView else { return }
            let message = messages[drawingIndexPath.item]
            drawVC.message = message
            drawVC.pkView.drawing = pkView.drawing.transformed(using: CGAffineTransform(scaleX: 1/message.pkViewScale, y: 1/message.pkViewScale))
            print(message.pkViewScale)
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
            emojiInfo.y = newPoint.y / MessageCollectionViewBaseCell.height(for: messages[newIndexPath.item])
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

}
