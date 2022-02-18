//
//  ChatRoom+InsertMessage.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/8/31.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import DogeChatNetwork
import DogeChatUniversal
import SwiftyJSON
import UIKit
import DogeChatCommonDefines

extension ChatRoomViewController: ReferMessageDataSource {
    
    func debugText(_ text: String) {
        if self.username == "赵锡光" {
            self.navigationItem.title = text
        }
    }
    
    func insertNewMessageCell(_ messages: [Message], index: Int = 0, forceScrollBottom: Bool = false, completion: (()->Void)? = nil) {
        guard self.purpose == .chat, !messages.isEmpty else { return }
        let alreadyUUIDs = self.messagesUUIDs
        let newUUIDs: Set<String> = Set(messages.map { $0.uuid })
        let filteredUUIDs = newUUIDs.subtracting(alreadyUUIDs)
        var filtered = messages.filter { filteredUUIDs.contains($0.uuid)}
        filtered = filtered.filter { message in
            if message.option != self.messageOption {
                debugText("option匹配不上")
                return false
            } else {
                let match = message.friend?.userID == self.friend.userID
                if !match {
                    debugText("friendID不匹配")
                }
                return match
            }
        }
        if filtered.isEmpty {
            debugText("过滤后为空数组")
            filtered = messages.filter({ message in
                !self.messages.contains(where: { alreadyMessage in
                    return message.uuid == alreadyMessage.uuid }) && message.friend?.userID == self.friend.userID
            })
            if filtered.isEmpty { return }
        }
        var scrollToBottom = !tableView.isDragging
        let contentHeight = tableView.contentSize.height
        if contentHeight - tableView.contentOffset.y > self.view.bounds.height {
            scrollToBottom = false
        }
        scrollToBottom = scrollToBottom || (messages.count == 1 && messages[0].messageSender == .ourself)
        scrollToBottom = scrollToBottom || forceScrollBottom
        scrollToBottom = scrollToBottom && !(self.navigationController?.visibleViewController is MediaBrowserViewController)
        syncOnMainThread { [weak self] in
            guard let self = self else { return }
            var indexPaths: [IndexPath] = []
            let alreadyMax = self.messages.max(by: { $0.id < $1.id })?.id ?? 0
            for message in filtered {
                indexPaths.append(IndexPath(row: self.messages.count, section: 0))
                self.messages.append(message)
            }
            if filtered.contains(where: { $0.id < alreadyMax }) {
                self.messages.sort(by: { $0.id < $1.id })
                tableView.reloadData()
                completion?()
                return
            }
            UIView.performWithoutAnimation {
                self.tableView.insertRows(at: indexPaths, with: .none)
            }
            needScrollToBottom = scrollToBottom
            if filtered.filter({ !$0.isRead }).map({ MessageBaseCell.height(for: $0, tableViewSize: self.tableView.bounds.size, userID: manager?.myInfo.userID)}).reduce(0, +) > self.tableView.bounds.height {
                self.explictJumpMessageUUID = messages[0].uuid
                self.didStopScroll()
            }
            completion?()
        }
    }
    
    func processMessageString(for string: String, type: MessageType, imageURL: String?, videoURL: String?) -> Message? {
        let message = messageSender.processMessageString(for: string, type: type, friend: self.friend, fontSize: messageInputBar.textView.font?.pointSize ?? 17, imageURL: imageURL, videoURL: videoURL)
        return message
    }
    
    func referMessage() -> Message? {
        if messageInputBar.referView.alpha > 0, let referMessage = messageInputBar.referView.message {
            cancleAction(self.messageInputBar.referView)
            return referMessage
        }
        return nil
    }
    
    static func transferMessages(_ messages: [Message], to friends: [Friend], manager: WebSocketManager?) {
        guard let manager = manager else { return }
        for contact in friends {
            for message in messages {
                let message = message.copied()
                message.uuid = UUID().uuidString
                message.senderUsername = manager.myName
                message.messageSender = .ourself
                message.senderUserID = manager.messageManager.myId
                message.receiver = contact.username
                message.receiverUserID = contact.userID
                message.id = manager.messageManager.maxId + 1
                message.friend = contact
                message.option = contact.isGroup ? .toGroup : .toOne
                manager.commonWebSocket.sendWrappedMessage(message)
            }
        }
    }
    
    func checkReferMessage(_ message: Message) {
        if message.referMessage != nil { return }
        if let referUUID = message.referMessageUUID, let friendID = message.friend?.userID {
            manager?.httpsManager.getMessagesWith(friendID: friendID, uuid: referUUID, pageNum: nil, pageSize: nil)
        }
    }
    
    // TODO: 发送文件的也需要加到未发送数组中（比如别的app拖过来这时候还没连接上）
    
    @objc func confirmSendPhoto() {
        let newMessages = messageSender.confirmSendPhoto(friends: [friend])
        insertNewMessageCell(newMessages, forceScrollBottom: true)
    }
    
    func sendVoice() {
        let messages = messageSender.sendVoice(friends: [friend])
        insertNewMessageCell(messages, forceScrollBottom: true)
    }
    
    func sendVideo() {
        let messages = messageSender.sendVideo(friends: [friend])
        insertNewMessageCell(messages, forceScrollBottom: true)
    }
    
    func sendLivePhotos() {
        let newMessages = messageSender.sendLivePhotos(friends: [friend])
        insertNewMessageCell(newMessages)
    }
    
    func sendWasTapped(content: String) {
        guard !content.isEmpty else { return }
        playHaptic()
        if let wrappedMessage = processMessageString(for: content, type: .text, imageURL: nil, videoURL: nil) {
            insertNewMessageCell([wrappedMessage])
            manager?.commonWebSocket.sendWrappedMessage(wrappedMessage)
        }
    }
    
}

