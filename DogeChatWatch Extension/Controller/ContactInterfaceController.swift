//
//  InterfaceController.swift
//  DogeChatWatch Extension
//
//  Created by 赵锡光 on 2021/6/7.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import WatchKit
import Foundation
import DogeChatUniversal
import WatchConnectivity
import DogeChatCommonDefines

var isLogin = false
var url_pre: String {
    SocketManager.shared.messageManager.url_pre
}

class ContactInterfaceController: WKInterfaceController {
    
    static var shared: ContactInterfaceController!
    
    @IBOutlet weak var table: WKInterfaceTable!
    let manager = SocketManager.shared
    var username: String = ""
    var friends: [Friend] = []
    var usernames: [String] {
        friends.map { $0.username }
    }
    
    var loginCount = 0
    
    override func awake(withContext context: Any?) {
        ExtensionDelegate.shared.contactVC = self
        Self.shared = self
        NotificationCenter.default.addObserver(self, selector: #selector(canGetContacts), name: NSNotification.Name("canGetContacts"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(getWCSessionMessage(_:)), name: .wcSessionMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: .becomeActive, object: nil)
        NotificationCenter.default.addObserver(forName: .connecting, object: nil, queue: .main) { [weak self] _ in
            self?.setTitle("正在连接...")
        }
        NotificationCenter.default.addObserver(forName: .connected, object: nil, queue: .main) { [weak self] _ in
            self?.setTitle(self?.username)
        }
        NotificationCenter.default.addObserver(forName: .logining, object: nil, queue: .main) { [weak self] _ in
            self?.setTitle("正在登录...")
            isLogin = false
        }
        NotificationCenter.default.addObserver(forName: .logined, object: nil, queue: .main) { _ in
            isLogin = true
        }
        NotificationCenter.default.addObserver(forName: .friendListChange, object: nil, queue: .main) { [weak self] _ in
            self?.showContacts(SocketManager.shared.commonSocket.httpRequestsManager.friends)
        }
        NotificationCenter.default.addObserver(forName: .refreshingContacts, object: nil, queue: .main) { [weak self] _ in
            self?.setTitle("获取联系人...")
        }
        NotificationCenter.default.addObserver(self, selector: #selector(refreshContactNoti(_:)), name: .refreshContacts, object: nil)
        NotificationCenter.default.addObserver(forName: .hasUnknownFriend, object: nil, queue: .main) { [weak self] _ in
            self?.canGetContacts()
        }
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        SocketManager.shared.messageManager.messageDelegate = self
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }
    
    @objc func willEnterForeground() {
        login()
    }
    @IBAction func refreshAction() {
        login()
    }
    
    @objc func canGetContacts() {
        SocketManager.shared.httpManager.getContacts { usersInfos, error in
            self.showContacts(usersInfos)
            SocketManager.shared.connect()
        }
    }
    
    @objc func refreshContactNoti(_ noti: Notification) {
        guard let friends = noti.userInfo?["contacts"] as? [Friend] else { return }
        self.showContacts(friends)
    }
    
    @objc func getWCSessionMessage(_ noti: Notification) {
        guard let info = noti.userInfo as? [String: String],
              let username = info["username"],
              let password = info["password"] else { return }
        if !isLogin {
            login(username: username, password: password)
        } else {
            if username != UserDefaults.standard.value(forKey: "username") as? String || password != UserDefaults.standard.value(forKey: "password") as? String {
                login(username: username, password: password)
            }
        }
    }
    
    func login() {
        var isValid = false
        var password: String?
        if let username = UserDefaults.standard.value(forKey: "username") as? String {
            if let accountInfo = accountInfo(username: username) {
                if let cookie = accountInfo.cookieInfo, cookie.isValid {
                    isValid = true
                } else if let _password = accountInfo.password {
                    password = _password
                    isValid = true
                }
                let userID = accountInfo.userID ?? SocketManager.shared.httpManager.myId
                if self.friends.isEmpty, !userID.isEmpty, let friends = getContacts(userID: userID) {
                    SocketManager.shared.httpManager.friends = friends
                    self.showContacts(friends)
                    SocketManager.shared.httpManager.getContacts(completion: nil)
                    SocketManager.shared.connect()
                }
            }
            if isValid {
                login(username: username, password: password)
            } else {
                pushController(withName: "login", context: nil)
            }
        } else {
            pushController(withName: "login", context: nil)
        }
    }
    
    func needRelogin() -> Bool {
        let nowTime = Date().timeIntervalSince1970
        return nowTime - SocketManager.shared.commonSocket.httpRequestsManager.cookieTime >= cookieDuration // 2天
    }
    
    func login(username: String, password: String?) {
        self.username = username
        SocketManager.shared.commonSocket.loginAndConnect(username: username, password: password, needContact: friends.isEmpty) { success in
            if success {
                UserDefaults.standard.set(username, forKey: "username")
                UserDefaults.standard.set(password, forKey: "password")
            }
        }
    }
    
    func showUnreadCount(message: Message) {
        if message.messageSender == .someoneElse {
            var sender = message.senderUsername
            if message.option == .toGroup {
                sender = "群聊"
            }
            if let chatVC =  WKExtension.shared().visibleInterfaceController as? ChatRoomInterfaceController {
                if chatVC.messageOption == .toGroup && message.option == .toGroup {
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
        let info = friends[index]
        if let rowController = table.rowController(at: index) as? ContactsRowController {
            rowController.usernameLabel.setText(info.username)
            rowController.latestMessageLabel.setText(contentForSpecialType(info.latestMessage))
            if updateAvatar {
                updateRowAvatar(friend: friends[index], row: rowController)
            }
        }
    }
    
    func updateRowAvatar(friend: Friend, row: ContactsRowController) {
        let urlStr = friend.avatarURL
        row.usernameLabel.setText(friend.username)
        let text = contentForSpecialType(friend.latestMessage) ?? friend.getLatestMessageStr()
        row.latestMessageLabel.setText(text);
        MediaLoader.shared.requestImage(urlStr: urlStr, type: .image, syncIfCan: false, imageWidth: .width40, needStaticGif: true, completion: { image, data, _ in
            row.avatarImageView?.setImageData(data)
        }, progress: nil)
    }
    
    func showContacts(_ usersInfos: [Friend]) {
        self.setTitle(self.username)
        self.friends = usersInfos
        self.table.setNumberOfRows(usersInfos.count, withRowType: "contact")
        for (index, info) in usersInfos.enumerated() {
            updateRowAvatar(friend: info, row: table.rowController(at: index) as! ContactsRowController)
        }
    }
    
    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        let friend = friends[rowIndex]
        var messages = friend.messages
        var messagesUUIDs: Set<String> = friend.messageUUIDs
        if messages.count > 50 {
            messages.removeSubrange(0..<messages.count-50)
            messagesUUIDs = Set(messages.map { $0.uuid })
        }
        let context = ["friend": friend, "messages": messages, "messagesUUIDs": messagesUUIDs] as [String : Any]
        self.pushController(withName: "chatroom", context: context)
        if let row = table.rowController(at: rowIndex) as? ContactsRowController {
            row.usernameLabel.setText(usernames[rowIndex])
        }
    }
    
}

extension ContactInterfaceController: MessageDelegate {
    func readMessageUpdate(friendID: String, messageID: Int) {
        
    }
    
    func asyncReconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self, WKExtension.shared().applicationState == .active else { return }
            if self.needRelogin() {
                SocketManager.shared.commonSocket.loginAndConnect(username: nil, password: nil)
            } else {
                SocketManager.shared.commonSocket.connect()
            }
        }
    }
    
    func updateOnlineNumber(to newNumber: Int) {
        
    }
    
    func newFriend() {
        
    }
    
    func newFriendRequest() {
        
    }
    
    func revokeMessage(_ id: Int, senderID: String, receiverID: String) {
        
    }
    
    func revokeSuccess(id: Int, senderID: String, receiverID: String) {
        
    }
    
    func updateLatestMessages(_ messages: [Message]) {
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
                self.friends[index].latestMessage = friend.value.last
                locations.append((from: index, to: locations.count))
            }
        }
        locations.sort(by: { $0.from > $1.from })
        let removals = IndexSet(locations.map { $0.from })
        let insertions = IndexSet(locations.map { $0.to })
        var removed = Array<Friend?>(repeating: nil, count: locations.count)
        for location in locations {
            removed[location.to] = self.friends.remove(at: location.from)
        }
        self.friends.insert(contentsOf: removed.compactMap({ $0 }), at: 0)
        table.removeRows(at: removals)
        table.insertRows(at: insertions, withRowType: "contact")
        for insertion in insertions {
            update(index: insertion, updateAvatar: true)
        }
    }
    
    func receiveNewMessages(_ messages: [Message], isGroup: Bool) {
        if messages.isEmpty {
            return
        }
        var friendDict = [String : [Message]]()
        for message in messages {
            if let friendID = message.friend?.userID {
                friendDict.add(message, for: friendID)
            }
        }
        for (friendID, newMessages) in friendDict {
            if let index = self.friends.firstIndex(where: { $0.userID == friendID }) {
                if let row = table.rowController(at: index) as? ContactsRowController {
                    row.usernameLabel.setText(friends[index].username + "[未读\(newMessages.count)]")
                }
            }
            if let chatroom = WKExtension.shared().visibleInterfaceController as? ChatRoomInterfaceController, chatroom.friend.userID == friendID {
                chatroom.insertMessages(newMessages)
            }
        }
        if messages.contains(where: { $0.messageSender == .someoneElse }) {
            WKInterfaceDevice.current().play(.click)
        }
        
    }
    
    
}
