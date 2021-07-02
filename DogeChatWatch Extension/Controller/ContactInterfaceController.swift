//
//  InterfaceController.swift
//  DogeChatWatch Extension
//
//  Created by 赵锡光 on 2021/6/7.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import WatchKit
import Foundation
import DogeChatUniversal

var isLogin = false

typealias ContactInfo = (name: String, avatarUrl: String, latestMessage: Message?)

class ContactInterfaceController: WKInterfaceController {
    
    @IBOutlet weak var table: WKInterfaceTable!
    let manager = SocketManager.shared
    
    var usersInfos: [ContactInfo]!
    var usernames: [String] {
        usersInfos?.map { $0.name } ?? []
    }
    
    override func awake(withContext context: Any?) {
        NotificationCenter.default.addObserver(self, selector: #selector(canGetContacts), name: NSNotification.Name("canGetContacts"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateLatestMessage(_:)), name: .updateLatesetMessage, object: nil)
        // Configure interface objects here.
        var loginCount = 0
        func login(username: String, password: String) {
            self.setTitle("正在登录...")
            isLogin = false
            SocketManager.shared.messageManager.login(username: username, password: password) { [weak self] result in
                loginCount += 1
                guard loginCount <= 6 else { return }
                if result == "登录成功" {
                    isLogin = true
                    self?.setTitle("获取联系人...")
                    SocketManager.shared.messageManager.getContacts { [weak self] usersInfos, error in
                        guard let self = self else { return }
                        self.showContacts(usersInfos)
                        SocketManager.shared.connect()
                    }
                } else {
                    isLogin = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        login(username: username, password: password)
                    }
                }
            }
        }
        if let username = UserDefaults.standard.value(forKey: "username") as? String, let password = UserDefaults.standard.value(forKey: "password") as? String {
            login(username: username, password: password)
        } else {
            self.pushController(withName: "login", context: nil)
        }
    }
        
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }
    
    @objc func canGetContacts() {
        SocketManager.shared.messageManager.getContacts { usersInfos, error in
            self.showContacts(usersInfos)
            SocketManager.shared.connect()
        }
    }
    
    @objc func updateLatestMessage(_ noti: Notification) {
        guard let message = noti.object as? Message else { return }
        let friendName: String
        let needUpdate: Bool
        if message.option == .toAll {
            friendName = "群聊"
            let alreadyMax = manager.messageManager.messagesGroup.map { $0.id }.max() ?? 0
            needUpdate = message.id > alreadyMax
        } else {
            friendName = message.messageSender == .ourself ? message.receiver : message.senderUsername
            needUpdate = (manager.messageManager.messagesSingle[friendName]?.map( { $0.id }).max() ?? 0) < message.id
        }
        if needUpdate, let index = self.usernames.firstIndex(of: friendName) {
            self.usersInfos[index].latestMessage = message
            if index != 0 {
                if index != 1 {
                    let removed = usersInfos.remove(at: index)
                    table.removeRows(at: IndexSet(integer: index))
                    usersInfos.insert(removed, at: 1)
                    table.insertRows(at: IndexSet(integer: 1), withRowType: "contact")
                }
                update(index: 1)
            } else {
                update(index: 0)
            }
            showUnreadCount(message: message)
        }
    }
    
    func showUnreadCount(message: Message) {
        if message.messageSender == .someoneElse {
            var sender = message.senderUsername
            if message.option == .toAll {
                sender = "群聊"
            }
            if let chatVC =  WKExtension.shared().visibleInterfaceController as? ChatRoomInterfaceController {
                if chatVC.messageOption == .toAll && message.option == .toAll {
                    return
                } else if chatVC.messageOption == .toOne && message.senderUsername == chatVC.friendName {
                    return
                }
            }
            if let index = self.usernames.firstIndex(of: sender) {
                if let row = table.rowController(at: index) as? ContactsRowController {
                    row.usernameLabel.setText(usernames[index] + "[新]")
                }
            }
        }
    }
    
    func update(index: Int) {
        let info = usersInfos[index]
        if let rowController = table.rowController(at: index) as? ContactsRowController {
            rowController.usernameLabel.setText(info.name)
            rowController.latestMessageLabel.setText(contentForSpecialType(info.latestMessage))
        }
    }
    
    func showContacts(_ usersInfos: [ContactInfo]) {
        self.setTitle(SocketManager.shared.messageManager.myName)
        self.usersInfos = usersInfos
        self.table.setNumberOfRows(usersInfos.count, withRowType: "contact")
        for (index, info) in usersInfos.enumerated() {
            if let row = self.table.rowController(at: index) as? ContactsRowController {
                row.usernameLabel.setText(info.name)
                row.latestMessageLabel.setText(contentForSpecialType(info.latestMessage));
            }
        }
    }
    
    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        var messages: [Message]
        let username: String
        var messagesUUIDs: Set<String>
        if rowIndex == 0 {
            username = "群聊"
            messages = manager.messageManager.messagesGroup
            messagesUUIDs = manager.messageManager.groupUUIDs
        } else {
            username = usersInfos[rowIndex].name
            messages = manager.messageManager.messagesSingle[username] ?? []
            messagesUUIDs = manager.messageManager.singleUUIDs[username] ?? []
        }
        if messages.count > 10 {
            messages.removeSubrange(0..<messages.count-10)
            messagesUUIDs = Set(messages.map { $0.uuid })
        }
        let context = ["friendName": username, "messages": messages, "messagesUUIDs": messagesUUIDs] as [String : Any]
        self.pushController(withName: "chatroom", context: context)
        if let row = table.rowController(at: rowIndex) as? ContactsRowController {
            row.usernameLabel.setText(usernames[rowIndex])
        }
    }

}
