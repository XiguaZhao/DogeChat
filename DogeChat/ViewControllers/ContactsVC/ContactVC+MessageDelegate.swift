//
//  ContactVC+MessageDelegate.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/23.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatUniversal
import DogeChatCommonDefines

extension ContactsTableViewController: MessageDelegate, ReadMessageDataSource {
    
    func readMessageFriendIDs() -> [String] {
        var res = [String]()
        for chatRoom in findChatRoomVCs() {
            res.append(chatRoom.friend.userID)
        }
        return res
    }
    
    func asyncReconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard UIApplication.shared.applicationState == .active else { return }
            self?.manager?.commonWebSocket.loginAndConnect(username: nil, password: nil)
        }
    }

    func updateOnlineNumber(to newNumber: Int) {
        
    }
        
    func revokeMessage(_ id: Int, senderID: String, receiverID: String) {
        for chatRoom in findChatRoomVCs() {
            chatRoom.revokeMessage(id, senderID: senderID, receiverID: receiverID)
        }
    }
    
    func newFriend() {
        refreshContacts()
    }
    
    func newFriendRequest() {
        playSound()
        if let button = navigationItem.rightBarButtonItem {
            button.makeDot()
        }
    }
    
    
    func revokeSuccess(id: Int, senderID: String, receiverID: String) {
        for chatVC in findChatRoomVCs() {
            chatVC.revokeSuccess(id: id, senderID: senderID, receiverID: receiverID)
        }
    }

    func updateLatestMessages(_ messages: [Message]) {
        syncOnMainThread {
            var friendDict = [String : [Message]]()
            for message in messages {
                if let friendID = message.friend?.userID {
                    friendDict.add(message, for: friendID)
                }
            }
            let sortedDict = friendDict.sorted(by: { first, second in
                return first.value.last?.timestamp ?? 0 > second.value.last?.timestamp ?? 0
            })
            var indexPathsToReload = [IndexPath]()
            var locations = [(from: Int, to: Int)]()
            for friend in sortedDict {
                if let index = self.friends.firstIndex(where: { $0.userID == friend.key }) {
                    indexPathsToReload.append(IndexPath(row: index, section: 0))
                    self.friends[index].latestMessage = friend.value.max(by: { $0.id < $1.id })
                    locations.append((from: index, to: locations.count))
                }
            }
            self.tableView.reloadRows(at: indexPathsToReload, with: .none)
            self.reselectFriend(nil)
            locations.sort(by: { $0.from > $1.from })
            tableView.performBatchUpdates { [self] in
                var removed = Array<Friend?>(repeating: nil, count: locations.count)
                for location in locations {
                    removed[location.to] = self.friends.remove(at: location.from)
                }
                self.friends.insert(contentsOf: removed.compactMap({ $0 }), at: 0)
                for location in locations where location.from != location.to {
                    tableView.moveRow(at: IndexPath(row: location.from, section: 0), to: IndexPath(row: location.to, section: 0))
                }
            } completion: { _ in
                self.reselectFriend(nil)
            }
        }
    }

    func receiveNewMessages(_ messages: [Message], isGroup: Bool) { //打开聊天界面的话，要insert，没有的话要更新红点
        var friendDict = [String : [Message]]()
        for message in messages {
            if let friend = message.friend {
                friendDict.add(message, for: friend.userID)
            } else {
                if self.username == "赵锡光" {
                    self.navigationItem.title = "contactVC中friend为空"
                } else {
                    self.navigationItem.title = "username错误"
                }
            }
        }
        var reloadIndexPaths = [IndexPath]()
        let chatVCs = findChatRoomVCs()
        NotificationCenter.default.post(name: .receiveNewMessage, object: self.manager, userInfo: ["messages" : messages])
        for (friendID, newMessages) in friendDict {
            guard let index = self.friends.firstIndex(where: { $0.userID == friendID }) else { continue }
            reloadIndexPaths.append(IndexPath(row: index, section: 0))
            if !isMac() && !chatVCs.isEmpty && chatVCs.contains(where: { $0.friend.userID == friendID }) {
                unreadMessage[friendID] = (0, false)
            } else {
                let hasNewAt = newMessages.contains(where: { $0.someoneAtMe && !$0.isRead })
                let notReads = newMessages.filter({ !$0.isRead })
                let newCount = notReads.count
                if let already = unreadMessage[friendID] {
                    unreadMessage[friendID] = (already.unreadCount + newCount, already.hasAt || hasNewAt)
                } else {
                    unreadMessage[friendID] = (newCount, hasNewAt)
                }
                if let lastMessage = notReads.last(where: { !$0.isRead && $0.messageSender == .someoneElse }) {
                    makeLocalNotification(message: lastMessage)
                }
            }
        }
        tableView.reloadRows(at: reloadIndexPaths, with: .none)
        
        if messages.contains(where: { !$0.isRead }) {
            playSound()
        }
        reselectFriend(nil)
    }

    
    func readMessageUpdate(friendID: String, messageID: Int) {
        unreadMessage.removeValue(forKey: friendID)
        if let index = friends.firstIndex(where: { $0.userID == friendID }) {
            for message in friends[index].messages where !message.isRead && message.id <= messageID {
                message.isRead = true
            }
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
            reselectFriend(nil)
            for vc in findChatRoomVCs() {
                vc.processJumpToUnreadButton()
            }
        }
    }
    
}
