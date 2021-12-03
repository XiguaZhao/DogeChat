//
//  ContactsTableViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/5/27.
//  Copyright © 2020 Xiguang Zhao. All rights reserved.
//

import UIKit
import SwiftyJSON
import DogeChatNetwork
import DogeChatUniversal
import Reachability
import WatchConnectivity

class ContactsTableViewController: DogeChatViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDelegate, UITableViewDataSource, DogeChatVCTableDataSource {
    
    var unreadMessage = [String: Int]() {
        didSet {
            let total = unreadMessage.values.reduce(0, +)
            self.navigationItem.title = total > 0 ? "(\(total)未读)" : username
        }
    }
    var friends: [Friend] = []
    var usernames: [String] {
        friends.map { $0.username }
    }
    private var password = ""
    var loginCount = 0
    let avatarImageView = FLAnimatedImageView()
    var manager: WebSocketManager? {
        return socketForUsername(username)
    }
    override var username: String {
        didSet {
            self.navigationItem.title = username
        }
    }
    var nav: UINavigationController? {
        return (self.view.window?.windowScene?.delegate as? SceneDelegate)?.navigationController
    }
    var barItem = UIBarButtonItem()
    var itemRequest = UIBarButtonItem()
    var selectedIndexPath: IndexPath?
    var tableView = DogeChatTableView()
    var titleView: UIView?
    static let pkDataWriteQueue = DispatchQueue(label: "com.zhaoxiguang.dogeChat.pkDataWrite")
    var appDelegate: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    var lastAvatarURL: String?
    var loginSuccess = false {
        didSet {
            if loginSuccess {
                refreshContacts()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .never
        view.addSubview(tableView)
        tableView.mas_makeConstraints { [weak self] make in
            make?.edges.equalTo()(self?.view)
        }
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ContactTableViewCell.self, forCellReuseIdentifier: ContactTableViewCell.cellID)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        NotificationCenter.default.addObserver(self, selector: #selector(uploadSuccess(notification:)), name: .uploadSuccess, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(updateMyAvatar(_:)), name: .updateMyAvatar, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(friendChangeAvatar(_:)), name: .friendChangeAvatar, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(connectingNoti(_:)), name: .connecting, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(connectedNoti(_:)), name: .connected, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(loginingNoti(_:)), name: .logining, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(loginedNoti(_:)), name: .logined, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshContactsNoti(_:)), name: .refreshContacts, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChangeNoti(_:)), name: .reachabilityChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hasUnknownFriendNoti(_:)), name: .hasUnknownFriend, object: username)
        setupRefreshControl()
        barItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(presentSearchVC))
        itemRequest = UIBarButtonItem(image: UIImage(systemName: "person.badge.plus"), style: .plain, target: self, action: #selector(presentSearchVC))
        setupMyAvatar()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .immersive, object: AppDelegate.shared.immersive)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: true)
        navigationItem.rightBarButtonItem = barItem
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        manager?.messageManager.messageDelegate = self
        loadAllTracks(username: username)
        if let visibleIndexPaths = tableView.indexPathsForSelectedRows {
            for indexPath in visibleIndexPaths {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationItem.rightBarButtonItem = nil
        tableView.refreshControl?.endRefreshing()
    }
    
    func setUsername(_ username: String, andPassword password: String) {
        self.username = username
        self.password = password
    }
    
    func processUserActivity() {
        if let userActivity = SceneDelegate.activeUserActivity {
            let userInfo = userActivity.userInfo as! [String : String]
            let username = userInfo["username"]!
            if let manager = manager, username == manager.httpsManager.myName {
                let friendID = userInfo["friendID"]!
                if let index = friends.firstIndex(where: { $0.userID == friendID }) {
                    tableView(tableView, didSelectRowAt: IndexPath(row: index, section: 0))
                    SceneDelegate.activeUserActivity = nil
                }
            } else {
                if let sceneDelegate = SceneDelegate.usernameToDelegate[username] {
                    UIApplication.shared.requestSceneSessionActivation(sceneDelegate.window?.windowScene?.session, userActivity: userActivity, options: nil, errorHandler: nil)
                } else {
                    UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: nil, errorHandler: nil)
                }
                SceneDelegate.activeUserActivity = nil
            }
        }
        
        let userActivity = NSUserActivity(activityType: "com.zhaoxiguang.dogechat")
        userActivity.title = "dogechat"
        userActivity.userInfo = ["username": username, "password": password]
        userActivity.needsSave = true
        self.view.window?.windowScene?.userActivity = userActivity
        self.view.window?.windowScene?.updateUserActivityState(userActivity)
    }
            
    func saveTitleView() {
        if let titleView = self.navigationItem.titleView {
            self.titleView = titleView
        }
    }
    
    func restoreTitleView() {
        if let titleView = self.titleView {
            self.navigationItem.titleView = titleView
        }
    }
    
    @objc func reachabilityChangeNoti(_ noti: Notification) {
        guard let reachability = noti.object as? Reachability, reachability.connection != .unavailable else { return }
    }
    
    @objc func connectingNoti(_ noti: Notification) {
        saveTitleView()
        navigationItem.title = "正在连接..."
        navigationItem.titleView = nil
    }
    
    @objc func connectedNoti(_ noti: Notification) {
        setupMyAvatar()
        navigationItem.title = username
        processUserActivity()
        if let manager = manager, manager.commonWebSocket.connectTime - manager.httpsManager.fetchFriendTime > 20 {
            refreshContacts(completion: nil)
        }
        checkGroupInfos()
    }
    
    @objc func loginingNoti(_ noti: Notification) {
        saveTitleView()
        navigationItem.titleView = nil
        navigationItem.title = "正在登录..."
    }
    
    @objc func loginedNoti(_ noti: Notification) {
        WCSession.default.sendMessage(["username": username, "password": password], replyHandler: nil, errorHandler: nil)
        MediaLoader.shared.cookie = manager?.cookie
        self.view.window?.windowScene?.title = username
    }
    
    @objc func refreshContactsNoti(_ noti: Notification) {
        guard let friends = noti.userInfo?["contacts"] as? [Friend] else { return }
        self.friends = friends
        tableView.reloadData()
        tableView.refreshControl?.endRefreshing()
    }
    
    func processGroup(_ groups: [Group]) {
        var indexPaths = [IndexPath]()
        for group in groups {
            if let index = self.friends.firstIndex(where: { $0.userID == group.userID }) {
                indexPaths.append(IndexPath(row: index, section: 0))
            }
        }
        tableView.reloadRows(at: indexPaths, with: .none)
    }
        
    @objc func presentSearchVC() {
        let vc = SearchViewController()
        vc.username = self.username
        vc.delegate = self
        self.present(vc, animated: true)
    }
    
    func checkGroupInfos() {
        if let group = self.friends.first(where: { $0.isGroup }) as? Group, group.ownerUsername.isEmpty {
            manager?.httpsManager.getGroupList { _ in
            }
        }
    }
    
    func jumpToFriend(_ friend: Friend) {
        if let index = self.friends.firstIndex(of: friend) {
            tableView(self.tableView, didSelectRowAt: IndexPath(row: index, section: 0))
        }
    }
    
    func deleteFriend(_ friend: Friend) {
        if let index = self.friends.firstIndex(of: friend) {
            friends.remove(at: index)
            tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
        }
    }
    
    @objc func refreshContacts(completion: (()->Void)? = nil) {
        manager?.commonWebSocket.httpRequestsManager.getContacts {  _, _  in
            completion?()
        }
    }
    
    @objc func downRefreshAction(_ refreshControl: UIRefreshControl) {
        removeAllMessage()
        manager?.disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loginAndConnect()
        }
    }
    
    @objc func hasUnknownFriendNoti(_ noti: Notification) {
        refreshContacts(completion: nil)
    }
    
    func removeAllMessage() {
        manager?.commonWebSocket.httpRequestsManager.friends.removeAll()
        manager?.commonWebSocket.httpRequestsManager.friendDict.removeAll()
    }
    
    @objc func loginAndConnect() {
        manager?.loginAndConnect(username: username, password: password)
    }
        
    func setupRefreshControl() {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(downRefreshAction(_:)), for: .valueChanged)
        self.tableView.refreshControl = control
    }
    
    
    deinit {
        print("contactVCDeinit")
        WebSocketManager.usersToSocketManager[username]?.disconnect()
        removeSocketForUsername(username)
    }
    
    func receiveNewMessages(_ messages: [Message], isGroup: Bool) { //打开聊天界面的话，要insert，没有的话要更新红点
        var friendDict = [String : [Message]]()
        for message in messages {
            let friendID = message.friend.userID
            friendDict.add(message, for: friendID)
        }
        var reloadIndexPaths = [IndexPath]()
        for (friendID, newMessages) in friendDict {
            if let index = self.friends.firstIndex(where: { $0.userID == friendID }) {
                reloadIndexPaths.append(IndexPath(row: index, section: 0))
            }
            if let chatroom = findChatRoomVC(), chatroom.friend.userID == friendID {
                chatroom.insertNewMessageCell(newMessages)
                unreadMessage[friendID] = 0
            } else {
                unreadMessage.updateValue((unreadMessage[friendID] ?? 0) + newMessages.count, forKey: friendID)
            }
        }
        tableView.reloadRows(at: reloadIndexPaths, with: .none)
        let total = unreadMessage.values.reduce(0, +)
        if total > 0 {
            self.navigationController?.tabBarItem.badgeValue = String(total)
        }
        
        if messages.contains(where: { $0.messageSender == .someoneElse }) {
            playSound()
        }

        if isPhone() && self.navigationController?.visibleViewController != self {
            guard let message = friendDict.first?.value.last, message.messageSender != .ourself else { return }
            let chatroom = findChatRoomVC()
            if (message.friend.isGroup ? message.receiverUserID : message.senderUserID) == chatroom?.friend.userID {
                return
            }
            var content = message.option == .toGroup ? "\(message.senderUsername)：" : ""
            switch message.messageType {
            case .text, .join:
                content += message.text
            case .draw:
                content += "[速绘]"
            case .image, .livePhoto:
                content += "[图片]"
            case .video:
                content += "[视频]"
            case .track:
                content += "[歌曲分享]"
            case .voice:
                content += "[语音]"
            }
            SceneDelegate.usernameToDelegate[username]?.pushWindow.assignValueForPush(sender: message.friend.username, content: content)
        }
    }
            
    @objc func uploadSuccess(notification: Notification) {
        guard let manager = manager,
              let message = notification.userInfo?["message"] as? Message,
              let data = notification.userInfo?["data"] else { return }
        var remoteFilePath = JSON(data)["filePath"].stringValue
        remoteFilePath = manager.messageManager.encrypt.decryptMessage(remoteFilePath)
        remoteFilePath = WebSocketManager.url_pre + remoteFilePath
        message.text = remoteFilePath
        manager.commonWebSocket.sendWrappedMessage(message)
    }
    
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.friends.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return ContactTableViewCell.cellHeight
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: ContactTableViewCell!
        syncOnMainThread {
            let friend = self.friends[indexPath.row]
            cell = tableView.dequeueReusableCell(withIdentifier: ContactTableViewCell.cellID, for: indexPath) as? ContactTableViewCell
            cell.manager = self.manager
            cell.apply(friend)
            cell.delegate = self
            if let number = unreadMessage[self.friends[indexPath.row].userID] {
                cell.unreadCount = number
            }
        }
        return cell
    }
    
    //MARK: -Table view delegate
        
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        unreadMessage[self.friends[indexPath.row].userID] = 0
        let chatRoomVC = chatroomVC(for: indexPath)
        selectedIndexPath = indexPath
        tableView.cellForRow(at: indexPath)?.accessoryView?.isHidden = true
        if let splitVC = self.splitViewController, !splitVC.isCollapsed {
            let nav = DogeChatNavigationController(rootViewController: chatRoomVC)
            nav.modalPresentationStyle = .fullScreen
            self.showDetailViewController(nav, sender: self)
        } else {
            self.navigationController?.setViewControllers([self, chatRoomVC], animated: true)
        }
        unreadMessage[self.friends[indexPath.row].userID] = 0
        let total = unreadMessage.values.reduce(0, +)
        self.navigationController?.tabBarItem.badgeValue = total > 0 ? String(total) : nil
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let path = self.friends[indexPath.row].avatarURL
        let config =  UIContextMenuConfiguration(identifier: (self.friends[indexPath.row].username as NSString)) {
            [weak self] in
            guard let self = self else { return nil }
            let vc = self.chatroomVC(for: indexPath)
            vc.isPeek = true
            return vc
        } actionProvider: { (menuElement) -> UIMenu? in
            let avatarElement = UIAction(title: "查看头像") { [weak self] _ in
                guard let self = self else { return }
                self.avatarTapped(nil, path: path)
            }
            return UIMenu(title: "", image: nil, children: [avatarElement])
        }
        return config
    }
    
    func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        let username = configuration.identifier as! String
        if let index = self.usernames.firstIndex(of: username) {
            self.tableView(tableView, didSelectRowAt: IndexPath(row: index, section: 0))
        }
    }
        
    private func chatroomVC(for indexPath: IndexPath) -> ChatRoomViewController {
        let chatRoomVC = ChatRoomViewController()
        let friend = self.friends[indexPath.row]
        chatRoomVC.username = username
        chatRoomVC.friend = friend
        chatRoomVC.contactVC = self
        return chatRoomVC
    }
    
    func updateLatestMessage(_ message: Message) {
        let friend = message.friend!
        let needUpdate: Bool = friend.latestMessage?.id ?? 0 < message.id
        if needUpdate, let index = self.friends.firstIndex(of: friend) {
            print("needUpdateContact")
            self.friends[index].latestMessage = message
            // 刷新对应的，把最新的移动到前面
            UIView.performWithoutAnimation {
                self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                reselectFriend(friend)
            }
            if index != 0 {
                tableView.performBatchUpdates {
                    let removed = self.friends.remove(at: index)
                    self.friends.insert(removed, at: 0)
                    tableView.moveRow(at: IndexPath(row: index, section: 0), to: IndexPath(row: 0, section: 0))
                } completion: { _ in
                    self.reselectFriend(friend)
                }
            }
        }
    }
    
    func reselectFriend(_ friend: Friend) {
        if findChatRoomVC()?.friend == friend, let index = friends.firstIndex(of: friend) {
            tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .none)
        }
    }
    
}

extension ContactsTableViewController: MessageDelegate, AddContactDelegate {
    
    func asyncReconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard UIApplication.shared.applicationState == .active else { return }
            self?.manager?.commonWebSocket.loginAndConnect(username: nil, password: nil)
        }
    }

    func updateOnlineNumber(to newNumber: Int) {
        
    }
        
    func findChatRoomVC() -> ChatRoomViewController? {
        return (self.splitViewController as? DogeChatSplitViewController)?.findChatRoomVC()
    }
        
    func revokeMessage(_ id: Int, senderID: String, receiverID: String) {
        findChatRoomVC()?.revokeMessage(id, senderID: senderID, receiverID: receiverID)
    }
    
    func newFriend() {
        refreshContacts()
    }
    
    func newFriendRequest() {
        playSound()
        navigationItem.rightBarButtonItem = itemRequest
    }
    
    func revokeSuccess(id: Int, senderID: String, receiverID: String) {
        findChatRoomVC()?.revokeSuccess(id: id, senderID: senderID, receiverID: receiverID)
    }
        
    func addSuccess() {
        refreshContacts()
    }
    
}

extension ContactsTableViewController: ContactDataSource {
    
}
