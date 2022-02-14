//
//  ChatRoom+Emoji.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/14.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import UIKit
import SwiftyJSON
import DogeChatCommonDefines

extension ChatRoomViewController: EmojiViewDelegate {
    
    @objc func emojiButtonTapped() {
        if messageInputBar.emojiButton.image(for: .normal)?.accessibilityIdentifier == "pin" {
            messageInputBar.emojiButtonStatus = .pin
        }
        guard messageInputBar.emojiButtonStatus != .pin else { return }
        self.emojiSelectView.reloadData()
        manager?.getEmojis { [weak self] emojis in
            self?.emojiSelectView.emojis = emojis
        }
        if #available(iOS 13, *) {
            let image = UIImage(systemName: "pin.circle.fill", withConfiguration: MessageInputView.largeConfig as? UIImage.Configuration)
            image?.accessibilityIdentifier = "pin"
            messageInputBar.emojiButton.setImage(image, for: .normal)
        }
        
    }
    
    func emojiSelectViewOnTapAddButton(_ cell: EmojiSelectView) {
        addEmojis(cell: cell)
    }
    
    func emojiSelectViewCellMenus(_ cell: EmojiCollectionViewCell, parentCell: EmojiSelectView) -> [EmojiView.EmojiCellMenuItem] {
        guard let emoji = cell.emoji, let indexPath = emojiSelectView.collectionView.indexPath(for: parentCell) else { return [] }
        var items: [EmojiView.EmojiCellMenuItem] = [.useAsSelfAvatar, .preview]
        if indexPath.item == 0 {
            if var emojis = manager?.httpsManager.emojis, emojis.count > 1 {
                emojis.removeFirst()
                if !emojis.reduce([], +).contains(where: { $0.path == emoji.path }) {
                    items.append(.favorite)
                }
            }
        } else {
            if debugUsers.contains(username), let common = manager?.httpsManager.emojis.first, !common.contains(where: { $0.path == emoji.path }) {
                items.append(.addToCommon)
            }
        }
        if friend.isGroup {
            items.append(.useAsGroupAvatar)
        }
        if #available(iOS 14, *) {
            if indexPath.row == 0 {
                if debugUsers.contains(username) {
                    items.append(.addEmojis)
                }
            } else {
                items.append(.addEmojis)
            }
        }
        if debugUsers.contains(username) || indexPath.item != 0 {
            items.append(.delete)
        }
        return items
    }
    
    func didSelectMenuItem(_ cell: EmojiCollectionViewCell, parentCell: EmojiSelectView, item: EmojiView.EmojiCellMenuItem) {
        switch item {
        case .useAsGroupAvatar:
            useAsGroupAvatar(cell: cell)
        case .useAsSelfAvatar:
            useAsSelfAvatar(cell: cell)
        case .delete:
            deleteEmoji(cell: cell)
        case .addEmojis:
            addEmojis(cell: parentCell)
        case .preview:
            previewGifEmoji(cell: cell)
        case .addToCommon:
            addToCommon(cell: cell)
        case .favorite:
            favoriteEmoji(cell: cell)
        }
    }
    
    func saveEmoji(emoji: Emoji?) {
        guard let emoji = emoji else {
            return
        }
        manager?.commonWebSocket.starAndUploadEmoji(emoji: emoji, completion: { [weak self] success in
            self?.makeAutoAlert(message: success ? "成功" : "失败", detail: nil, showTime: 0.3, completion: nil)
        })
    }
    
    
    func addToCommon(cell: EmojiCollectionViewCell) {
        let emoji = cell.emoji?.copyAndChangeTypeTo(Emoji.AddEmojiType.common.rawValue)
        saveEmoji(emoji: emoji)
    }
    
    func favoriteEmoji(cell: EmojiCollectionViewCell) {
        let emoji = cell.emoji?.copyAndChangeTypeTo(Emoji.AddEmojiType.favorite.rawValue)
        saveEmoji(emoji: emoji)
    }
    
    func previewGifEmoji(cell: EmojiCollectionViewCell) {
        guard let path = cell.emoji?.path else { return }
        let vc = MediaBrowserViewController()
        vc.imagePaths = [path]
        vc.modalPresentationStyle = .popover
        let popover = vc.popoverPresentationController
        popover?.delegate = self
        popover?.sourceView = cell
        if let size = sizeFromStr(path, preferWidth: true, length: 300) {
            vc.preferredContentSize = size
        }
        self.present(vc, animated: true, completion: nil)
    }
    
    func addEmojis(cell: EmojiSelectView) {
        guard let index = emojiSelectView.collectionView.indexPath(for: cell)?.item else { return }
        self.addEmojiType = (index == 0 ? .common : .favorite)
        if #available(iOS 14, *) {
            pickerPurpose = .addEmoji
            var config = PHPickerConfiguration()
            config.filter = PHPickerFilter.any(of: [.images])
            config.selectionLimit = 0
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            self.present(picker, animated: true, completion: nil)
        }
    }
        
    func deleteEmoji(cell: EmojiCollectionViewCell) {
        let confirmAlert = UIAlertController(title: "确认删除？", message: nil, preferredStyle: .alert)
        confirmAlert.addAction(UIAlertAction(title: "确认", style: .default, handler: { [weak self] _ in
            self?.confirmDeleteEmoji(cell: cell)
        }))
        confirmAlert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        self.present(confirmAlert, animated: true, completion: nil)
    }
    
    
    func useAsSelfAvatar(cell: EmojiCollectionViewCell) {
        changeAvatar(cell: cell, append: nil)
    }
    
    func useAsGroupAvatar(cell: EmojiCollectionViewCell) {
        self.changeAvatar(cell: cell, append: "&groupId=\(self.friend.userID)")
    }
    
    
    func didSelectEmoji(emoji: Emoji) {
        if let message = processMessageString(for: emoji.path, type: .image, imageURL: emoji.path, videoURL: nil) {
            insertNewMessageCell([message])
            manager?.commonWebSocket.sendWrappedMessage(message)
        }
    }
    
    func changeAvatar(cell: EmojiCollectionViewCell, append: String? = nil) {
        if let manager = manager {
            var path = ((cell.emoji?.path ?? "") as NSString).replacingOccurrences(of: url_pre, with: "")
            if let append = append {
                path += append
            }
            manager.changeAvatarWithPath(path) { [self] task, data in
                guard let data = data else { return }
                let json = JSON(data)
                if json["status"].stringValue == "success" {
                    if #available(iOS 13.0, *) {
                        SceneDelegate.usernameToDelegate.first?.value.splitVC.makeAutoAlert(message: "成功更换", detail: nil, showTime: 0.5, completion: nil)
                    } else {
                        AppDelegateUI.shared.navController.makeAutoAlert(message: "成功更换", detail: nil, showTime: 0.5, completion: nil)
                    }
                    let avatarURL = json["avatarUrl"].stringValue
                    if append != nil {
                        if let friend = manager.httpsManager.friends.first(where: { $0.userID == self.friend.userID } ) {
                            friend.avatarURL = avatarURL
                            NotificationCenter.default.post(name: .friendChangeAvatar, object: username, userInfo: ["friend": friend])
                        }
                    } else {
                        manager.httpsManager.accountInfo.avatarURL = JSON(data)["avatarUrl"].stringValue
                    }
                }
            }
        }
    }
    
    func confirmDeleteEmoji(cell: EmojiCollectionViewCell) {
        if let manager = manager, let id = cell.emoji?.id {
            manager.deleteEmoji(id: id) { [weak self] success in
                self?.makeAutoAlert(message: success ? "成功" : "失败", detail: nil, showTime: 0.3, completion: nil)
                manager.getEmojis { _ in
                    
                }
            }
        }
    }

}

