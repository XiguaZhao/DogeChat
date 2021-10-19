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
import WatchConnectivity

var isLogin = false
var url_pre: String {
    SocketManager.shared.messageManager.url_pre
}

typealias ContactInfo = (name: String, avatarUrl: String, latestMessage: Message?)

class ContactInterfaceController: WKInterfaceController {
    
    @IBOutlet weak var table: WKInterfaceTable!
    let manager = SocketManager.shared
    
    var usersInfos: [Friend] = []
    var usernames: [String] {
        usersInfos.map { $0.username } 
    }
    
    var loginCount = 0
    var loginInProgress = false
    
    override func awake(withContext context: Any?) {
        NotificationCenter.default.addObserver(self, selector: #selector(canGetContacts), name: NSNotification.Name("canGetContacts"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateLatestMessage(_:)), name: .updateLatesetMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(getWCSessionMessage(_:)), name: .wcSessionMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: .becomeActive, object: nil)
        NotificationCenter.default.addObserver(forName: .connecting, object: nil, queue: nil) { _ in
            self.setTitle("正在连接...")
        }
        NotificationCenter.default.addObserver(forName: .connected, object: nil, queue: nil) { _ in
            self.setTitle(SocketManager.shared.messageManager.myName)
        }
        login()
    }
        
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }
    
    @objc func willEnterForeground() {
        if !loginInProgress {
            login()
        }
    }
    @IBAction func refreshAction() {
        login()
    }
    
    @objc func canGetContacts() {
        SocketManager.shared.messageManager.getContacts { usersInfos, error in
            self.showContacts(usersInfos)
            SocketManager.shared.connect()
        }
    }
    
    @objc func getWCSessionMessage(_ noti: Notification) {
        guard !isLogin, let info = noti.userInfo as? [String: String],
        let username = info["username"],
        let password = info["password"] else { return }
        login(username: username, password: password)
    }
    
    func login() {
        if let username = UserDefaults.standard.value(forKey: "username") as? String, let password = UserDefaults.standard.value(forKey: "password") as? String {
            login(username: username, password: password)
        } else {
            if WKExtension.shared().visibleInterfaceController is LoginInterfaceController {
                return
            }
            self.pushController(withName: "login", context: nil)
        }
    }
    
    func login(username: String, password: String) {
        self.setTitle("正在登录...")
        isLogin = false
        loginInProgress = true
        SocketManager.shared.messageManager.login(username: username, password: password) { [self] result in
            loginCount += 1
            loginInProgress = false
            guard loginCount <= 6 else { return }
            if result == "登录成功" {
                UserDefaults.standard.setValue(username, forKey: "username")
                UserDefaults.standard.setValue(password, forKey: "password")
                isLogin = true
                loginCount = 0
                if usersInfos.isEmpty {
                    setTitle("获取联系人...")
                    SocketManager.shared.messageManager.getContacts { [weak self] usersInfos, error in
                        guard let self = self else { return }
                        self.showContacts(usersInfos)
                        SocketManager.shared.connect()
                    }
                } else {
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
    
    @objc func updateLatestMessage(_ noti: Notification) {
        guard let message = noti.userInfo?["message"] as? Message else { return }
        let friendName: String
        var needUpdate: Bool = false
        if message.option == .toAll {
            friendName = "群聊"
            let alreadyMax = usersInfos.first?.latestMessage?.id ?? 0
            needUpdate = message.id > alreadyMax
        } else {
            friendName = message.messageSender == .ourself ? message.receiver : message.senderUsername
            if let index = usernames.firstIndex(of: friendName) {
                let max = usersInfos[index].latestMessage?.id ?? 0
                needUpdate = max < message.id
            }
        }
        if needUpdate, let index = self.usernames.firstIndex(of: friendName) {
            self.usersInfos[index].latestMessage = message
            if index != 0 {
                var updateAvatar = false
                if index != 1 {
                    let removed = usersInfos.remove(at: index)
                    table.removeRows(at: IndexSet(integer: index))
                    usersInfos.insert(removed, at: 1)
                    table.insertRows(at: IndexSet(integer: 1), withRowType: "contact")
                    updateAvatar = true
                }
                update(index: 1, updateAvatar: updateAvatar)
            } else {
                update(index: 0, updateAvatar: false)
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
    
    func update(index: Int, updateAvatar: Bool) {
        let info = usersInfos[index]
        if let rowController = table.rowController(at: index) as? ContactsRowController {
            rowController.usernameLabel.setText(info.username)
            rowController.latestMessageLabel.setText(contentForSpecialType(info.latestMessage))
            if updateAvatar {
                updateRowAvatar(friend: usersInfos[index], row: rowController)
            }
        }
    }
    
    func updateRowAvatar(friend: Friend, row: ContactsRowController) {
        let urlStr = friend.avatarURL
        row.usernameLabel.setText(friend.username)
        row.latestMessageLabel.setText(contentForSpecialType(friend.latestMessage));
        if let imageData = imageCahce.object(forKey: urlStr as NSString), let image = UIImage(data: imageData as Data) {
            row.avatarImageView.setImage(image)
        } else {
            ImageLoader.shared.requestImage(urlStr: urlStr, syncIfCan: false, completion: { image, data in
                guard let image = image else { return }
                DispatchQueue.global(qos: .userInteractive).async {
                    let compressedData = compressEmojis(image)
                    syncOnMain {
                        row.avatarImageView.setImageData(compressedData)
                    }
                    imageCahce.setObject(compressedData as NSData, forKey: urlStr as NSString)
                }
            }, progress: nil)
        }
    }
    
    func showContacts(_ usersInfos: [Friend]) {
        self.setTitle(SocketManager.shared.messageManager.myName)
        self.usersInfos = usersInfos
        self.table.setNumberOfRows(usersInfos.count, withRowType: "contact")
        for (index, info) in usersInfos.enumerated() {
            updateRowAvatar(friend: info, row: table.rowController(at: index) as! ContactsRowController)
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
            username = usersInfos[rowIndex].username
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
