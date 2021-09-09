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

var url_pre: String {
    WebSocketManager.shared.url_pre
}

var session: AFHTTPSessionManager {
    WebSocketManager.shared.messageManager.session
}

var isLogin: Bool {
    WebSocketManager.shared.messageManager.isLogin
}

class ContactsTableViewController: DogeChatViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDelegate, UITableViewDataSource {
    
    var unreadMessage = [String: Int]()
    var usersInfos = [(name: String, avatarUrl: String, latestMessage: Message?)]()
    var usernames: [String] {
        usersInfos.map { $0.name }
    }
    var username = ""
    var password = ""
    let avatarImageView = FLAnimatedImageView()
    var manager: WebSocketManager {
        if #available(iOS 13.0, *) {
            return socketForUsername(username)
        } else {
            return WebSocketManager.shared
        }
    }
    var nav: UINavigationController? {
        if #available(iOS 13.0, *) {
            return (self.view.window?.windowScene?.delegate as? SceneDelegate)?.navigationController
        } else {
            return AppDelegate.shared.navigationController
        }
    }
    var barItem = UIBarButtonItem()
    var itemRequest = UIBarButtonItem()
    var selectedIndexPath: IndexPath?
    let tableView = DogeChatTableView()
    var titleView: UIView?
    static let pkDataWriteQueue = DispatchQueue(label: "com.zhaoxiguang.dogeChat.pkDataWrite")
    var appDelegate: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
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
        NotificationCenter.default.addObserver(self, selector: #selector(receiveNewMessage(notification:)), name: .receiveNewMessage, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(sendSuccess(notification:)), name: .sendSuccess, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadSuccess(notification:)), name: .uploadSuccess, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(updateLatestMessage(_:)), name: .updateLatesetMessage, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(updateMyAvatar(_:)), name: .updateMyAvatar, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(friendChangeAvatar(_:)), name: .friendChangeAvatar, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(connectingNoti(_:)), name: .connecting, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(connectedNoti(_:)), name: .connected, object: username)
        setupRefreshControl()
        barItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(presentSearchVC))
        if #available(iOS 13.0, *) {
            itemRequest = UIBarButtonItem(image: UIImage(systemName: "person.badge.plus"), style: .plain, target: self, action: #selector(presentSearchVC))
        } else {
            itemRequest = UIBarButtonItem(title: "新", style: .plain, target: self, action: #selector(presentSearchVC))
        }
        setupMyAvatar()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let url = fileURLAt(dirName: "customBlur", fileName: userID),
               let data = try? Data(contentsOf: url) {
                PlayerManager.shared.blurSource = .customBlur
                PlayerManager.shared.customImage = UIImage(data: data)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: true)
        navigationItem.rightBarButtonItem = barItem
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        manager.messageManager.messageDelegate = self
        loadAllTracks()
        miniPlayerView.processHidden(for: self)
        if #available(iOS 13.0, *) {
            let userActivity = NSUserActivity(activityType: "com.zhaoxiguang.dogechat")
            userActivity.title = "dogechat"
            userActivity.userInfo = ["username": username, "password": password]
            self.view.window?.windowScene?.userActivity = userActivity
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationItem.rightBarButtonItem = nil
    }
    
    @objc func connectingNoti(_ noti: Notification) {
        self.titleView = self.navigationItem.titleView
        navigationItem.title = "正在连接..."
        navigationItem.titleView = nil
    }
    
    @objc func connectedNoti(_ noti: Notification) {
        setupMyAvatar()
        navigationItem.title = username
    }
        
    @objc func presentSearchVC() {
        let vc = SearchViewController()
        vc.username = self.username
        vc.usernames = usernames
        vc.delegate = self
        self.present(vc, animated: true)
    }
    
    @objc func refreshContacts(completion: (()->Void)? = nil) {
        manager.messageManager.getContacts { [weak self] userInfos, error  in
            guard let self = self else { return }
            if error != nil {
                self.navigationItem.title = "获取联系人失败"
                self.tableView.refreshControl?.endRefreshing()
                return
            }
            print(userInfos)
            self.tableView.refreshControl?.endRefreshing()
            self.usersInfos = userInfos
            self.tableView.reloadData()
            self.navigationItem.title = self.username
            completion?()
        }
        #if targetEnvironment(macCatalyst)
        if appDelegate.needRelogin() {
            appDelegate.applicationDidBecomeActive(UIApplication.shared)
        }
        #endif
    }
    
    @objc func downRefreshAction() {
        manager.messageManager.login(username: username, password: password) { res in
            self.tableView.refreshControl?.endRefreshing()
            if res == "登录成功" {
                self.manager.messageManager.getContacts { userinfos, error in
                    if error == nil {
                        self.usersInfos = userinfos
                        self.tableView.reloadData()
                        self.manager.connect()
                    }
                }
            }
        }
    }
    
    func setupRefreshControl() {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(downRefreshAction), for: .valueChanged)
        self.tableView.refreshControl = control
    }
    
    
    deinit {
        manager.messageManager.messagesGroup.removeAll()
        manager.messageManager.messagesSingle.removeAll()
        manager.messageManager.groupUUIDs.removeAll()
        manager.messageManager.singleUUIDs.removeAll()
        manager.disconnect()
    }
    
    @objc func receiveNewMessage(notification: Notification) {
        guard let message = notification.userInfo?["message"] as? Message, message.messageSender != .ourself else { return }
        if navigationController?.topViewController != self, let indexPath = tableView.indexPathForSelectedRow {
            if self.usernames[indexPath.row] == message.senderUsername && message.option == .toOne { return }
            if indexPath.row == 0 && message.option == .toAll { return }
        }
        var index = 0
        if message.option == .toOne {
            let friendName = message.messageSender == .ourself ? message.receiver : message.senderUsername
            index = self.usernames.firstIndex(of: friendName) ?? 0
        }
        let friendName = (message.messageSender == .ourself ? message.receiver : message.senderUsername)
        if let visibleVC = nav?.visibleViewController as? ChatRoomViewController,
            visibleVC.navigationItem.title == (message.option == .toAll ? "群聊" : friendName) {
            if visibleVC.messageOption == message.option {
                unreadMessage[(index == 0 ? "群聊" : message.senderUsername)] = 0
                tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                return
            }
        }
        if message.option == .toOne {
            if let originalNumber = unreadMessage[friendName] {
                unreadMessage[friendName] = originalNumber + 1
            } else {
                unreadMessage[friendName] = 1
            }
        } else {
            unreadMessage["群聊"] = (unreadMessage["群聊"] ?? 0) + 1
        }
        let name = message.option == .toAll ? "群聊" : message.senderUsername
        var content = message.option == .toAll ? "\(message.senderUsername)：" : ""
        switch message.messageType {
        case .text, .join:
            content += message.message
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
        if !(navigationController?.visibleViewController is ContactsTableViewController) && isPhone() {
            AppDelegate.shared.pushWindow.assignValueForPush(sender: name, content: content)
        }
        if tableView.numberOfRows(inSection: 0) != 0 {
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        }
        let total = unreadMessage.values.reduce(0, +)
        self.navigationController?.tabBarItem.badgeValue = String(total)
    }
    
    @objc func sendSuccess(notification: Notification) {
        let userInfo = notification.userInfo
        guard let message = userInfo?["message"] as? Message,
              let correctId = userInfo?["correctId"] as? Int,
              let toAll = userInfo?["toAll"] as? Bool else { return }
        if correctId <= 0 { return }
        for (index, notSent) in manager.messageManager.notSendContent.enumerated() {
            if let notSentMessage = notSent as? Message, notSentMessage.uuid == message.uuid {
                manager.messageManager.notSendContent.remove(at: index)
                break
            }
        }
        if toAll {
            guard let indexForAddToManager = manager.messageManager.messagesGroup.firstIndex(of: message) else { return }
            manager.messageManager.messagesGroup[indexForAddToManager].id = correctId
            manager.messageManager.messagesGroup[indexForAddToManager].sendStatus = .success
        } else {
            let receiver = message.receiver
            guard let index = manager.messageManager.messagesSingle[receiver]?.firstIndex(of: message) else { return }
            manager.messageManager.messagesSingle[receiver]![index].id = correctId
            manager.messageManager.messagesSingle[receiver]![index].sendStatus = .success
        }
        NotificationCenter.default.post(name: .updateLatesetMessage, object: username, userInfo: ["message": message])
    }
        
    @objc func uploadSuccess(notification: Notification) {
        guard let message = notification.userInfo?["message"] as? Message,
              let data = notification.userInfo?["data"] else { return }
        switch message.option {
        case .toOne:
            guard let index = manager.messageManager.messagesSingle[message.receiver]?.firstIndex(of: message) else { return }
            manager.messageManager.messagesSingle[message.receiver]![index].sendStatus = .success
        case .toAll:
            guard let index = manager.messageManager.messagesGroup.firstIndex(of: message) else { return }
            manager.messageManager.messagesGroup[index].sendStatus = .success
        }
        var remoteFilePath = JSON(data)["filePath"].stringValue
        remoteFilePath = manager.messageManager.encrypt.decryptMessage(remoteFilePath)
        remoteFilePath = manager.url_pre + remoteFilePath
        message.message = remoteFilePath
        manager.sendWrappedMessage(message)
    }
    
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.usersInfos.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return ContactTableViewCell.cellHeight
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ContactTableViewCell.cellID, for: indexPath) as! ContactTableViewCell
        cell.apply(self.usersInfos[indexPath.row])
        cell.delegate = self
        let height = self.tableView(tableView, heightForRowAt: indexPath)
        let offset: CGFloat = 10
        let adjustedWidth = height - 30
        let origin = offset / 2
        let label = UILabel(frame: CGRect(x: origin, y: origin, width: adjustedWidth, height: adjustedWidth))
        label.layer.cornerRadius = label.frame.height / 2
        label.layer.masksToBounds = true
        label.backgroundColor = .red
        label.textAlignment = .center
        if let number = unreadMessage[self.usernames[indexPath.row]], number > 0 {
            label.text = String(number)
            cell.accessoryView = label
        }  else {
            cell.accessoryView = nil
        }
        return cell
    }
    
    //MARK: -Table view delegate
        
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        unreadMessage[self.usernames[indexPath.row]] = 0
        tableView.deselectRow(at: indexPath, animated: true)
        let chatRoomVC = chatroomVC(for: indexPath)
        chatRoomVC.contactVC = self
        selectedIndexPath = indexPath
        tableView.cellForRow(at: indexPath)?.accessoryView = nil
        if let splitVC = self.splitViewController, !splitVC.isCollapsed {
            let nav = DogeChatNavigationController(rootViewController: chatRoomVC)
            nav.modalPresentationStyle = .fullScreen
            appDelegate.navigationController = nav
            self.showDetailViewController(nav, sender: self)
        } else {
            self.navigationController?.setViewControllers([self, chatRoomVC], animated: true)
            AppDelegate.shared.navigationController = self.navigationController
        }
        unreadMessage[self.usernames[indexPath.row]] = 0
        let total = unreadMessage.values.reduce(0, +)
        self.navigationController?.tabBarItem.badgeValue = total > 0 ? String(total) : nil
    }
    
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let path = self.usersInfos[indexPath.row].avatarUrl
        return .init(identifier: (self.usersInfos[indexPath.row].name as NSString)) { [weak self] in
            guard let self = self else { return nil }
            let vc = self.chatroomVC(for: indexPath)
            return vc
        } actionProvider: { (menuElement) -> UIMenu? in
            let avatarElement = UIAction(title: "查看头像") { [weak self] _ in
                guard let self = self else { return }
                self.avatarTapped(nil, path: path)
            }
            return UIMenu(title: "", image: nil, children: [avatarElement])
        }
    }
    
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        let username = configuration.identifier as! String
        if let index = self.usernames.firstIndex(of: username) {
            self.tableView(tableView, didSelectRowAt: IndexPath(row: index, section: 0))
        }
    }
    
    private func chatroomVC(for indexPath: IndexPath) -> ChatRoomViewController {
        let chatRoomVC = ChatRoomViewController()
        chatRoomVC.username = username
        chatRoomVC.navigationItem.title = self.usernames[indexPath.row]
        switch indexPath.row {
        case 0:
            chatRoomVC.messages = manager.messageManager.messagesGroup
            chatRoomVC.friendName = "群聊"
            chatRoomVC.messagesUUIDs = manager.messageManager.groupUUIDs
        default:
            chatRoomVC.messageOption = .toOne
            let friendName = self.usernames[indexPath.row]
            chatRoomVC.friendName = friendName
            chatRoomVC.messages = manager.messageManager.messagesSingle[friendName] ?? []
            chatRoomVC.messagesUUIDs = manager.messageManager.singleUUIDs[friendName] ?? Set()
            chatRoomVC.friendAvatarUrl = manager.url_pre + self.usersInfos[indexPath.row].avatarUrl
        }
        return chatRoomVC
    }
    
    @objc func updateLatestMessage(_ noti: Notification) {
        guard let message = noti.userInfo?["message"] as? Message else { return }
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
            // 刷新对应的，把最新的移动到前面
            UIView.performWithoutAnimation {
                self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
            }
            if index != 0 {
                tableView.performBatchUpdates {
                    let removed = self.usersInfos.remove(at: index)
                    self.usersInfos.insert(removed, at: 1)
                    tableView.moveRow(at: IndexPath(row: index, section: 0), to: IndexPath(row: 1, section: 0))
                } completion: { _ in
                }
            }
        }
    }
    
}

//MARK: 3D TOUCH
extension ContactsTableViewController: UIViewControllerPreviewingDelegate {
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let cell = previewingContext.sourceView as? UITableViewCell,
              let indexPath = tableView.indexPath(for: cell) else { return nil }
        let vc = chatroomVC(for: indexPath)
        let needGetHistory: Bool
        switch indexPath.row {
        case 0:
            needGetHistory = manager.messageManager.messagesGroup.isEmpty
        default:
            needGetHistory = manager.messageManager.messagesSingle[self.usernames[indexPath.row]] == nil
        }
        if needGetHistory { vc.displayHistory() }
        return vc
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        (previewingContext.sourceView as? UITableViewCell)?.accessoryView = nil
        navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
}

extension ContactsTableViewController: MessageDelegate, AddContactDelegate {
    func revokeMessage(_ id: Int) {
        let messages = manager.messageManager.messagesSingle
        guard let index = messages.firstIndex(where: { $0.value.contains(where: {$0.id == id}) }) else { return }
        let keyValue = messages[index]
        guard let indexOfMessage = messages[keyValue.key]!.firstIndex(where: {$0.id == id}) else { return }
        manager.messageManager.messagesSingle[keyValue.key]![indexOfMessage].message = "\(keyValue.key)撤回了一条消息"
        manager.messageManager.messagesSingle[keyValue.key]![indexOfMessage].messageType = .join
        self.receiveNewMessage(notification: Notification(name: .receiveNewMessage, object: username, userInfo: ["message": manager.messageManager.messagesSingle[keyValue.key]?[indexOfMessage] as Any]))
    }
    
    func newFriend() {
        refreshContacts()
    }
    
    func newFriendRequest() {
        WebSocketManagerAdapter.shared.playSound()
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = itemRequest
        }
    }
    
    func revokeSuccess(id: Int) {
        
    }
        
    func addSuccess() {
        refreshContacts()
    }
}

extension ContactsTableViewController: ContactDataSource {
    
    var userInfos: [UserInfo] {
        return self.usersInfos
    }
    
}
