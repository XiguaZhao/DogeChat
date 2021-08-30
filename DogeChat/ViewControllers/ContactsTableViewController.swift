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
    static var usersInfos = [(name: String, avatarUrl: String, latestMessage: Message?)]()
    static var usernames: [String] {
        usersInfos.map { $0.name }
    }
    var username = ""
    let avatarImageView = FLAnimatedImageView()
    let manager = WebSocketManager.shared
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
            let waitToProcessNotificationUsername = NotificationManager.shared.remoteNotificationUsername
            if loginSuccess && waitToProcessNotificationUsername != ""{
                if let index = ContactsTableViewController.usernames.firstIndex(of: waitToProcessNotificationUsername) {
                    if self.navigationController?.topViewController?.navigationItem.title == waitToProcessNotificationUsername {
                        return
                    }
                    appDelegate.tabBarController.selectedViewController = appDelegate.navigationController
                    tableView(self.tableView, didSelectRowAt: IndexPath(row: index, section: 0))
                    NotificationManager.shared.remoteNotificationUsername = ""
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .never
        view.addSubview(tableView)
        tableView.mas_makeConstraints { make in
            make?.edges.equalTo()(self.view)
        }
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ContactTableViewCell.self, forCellReuseIdentifier: ContactTableViewCell.cellID)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        NotificationCenter.default.addObserver(self, selector: #selector(receiveNewMessage(notification:)), name: .receiveNewMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sendSuccess(notification:)), name: .sendSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadSuccess(notification:)), name: .uploadSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateLatestMessage(_:)), name: .updateLatesetMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateMyAvatar(_:)), name: .updateMyAvatar, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(friendChangeAvatar(_:)), name: .friendChangeAvatar, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(connectingNoti(_:)), name: .connecting, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(connectedNoti(_:)), name: .connected, object: nil)
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
        navigationItem.title = myName
    }
        
    @objc func presentSearchVC() {
        let vc = SearchViewController()
        vc.username = self.username
        vc.usernames = ContactsTableViewController.usernames
        vc.delegate = self
        self.present(vc, animated: true)
    }
    
    @objc func refreshContacts() {
        manager.messageManager.getContacts { [weak self] userInfos, error  in
            guard let self = self else { return }
            if error != nil {
                self.navigationItem.title = "获取联系人失败"
                self.tableView.refreshControl?.endRefreshing()
                return
            }
            print(userInfos)
            self.tableView.refreshControl?.endRefreshing()
            ContactsTableViewController.usersInfos = userInfos
            self.tableView.reloadData()
            self.navigationItem.title = self.username
        }
        #if targetEnvironment(macCatalyst)
        if appDelegate.needRelogin() {
            appDelegate.applicationDidBecomeActive(UIApplication.shared)
        }
        #endif
    }
    
    @objc func downRefreshAction() {
        WebSocketManager.shared.messageManager.login(username: myName, password: myPassWord) { res in
            self.tableView.refreshControl?.endRefreshing()
            if res == "登录成功" {
                WebSocketManager.shared.messageManager.getContacts { userinfos, error in
                    if error == nil {
                        ContactsTableViewController.usersInfos = userinfos
                        self.tableView.reloadData()
                    }
                }
                WebSocketManager.shared.connect()
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
        guard let message = notification.object as? Message else { return }
        if navigationController?.topViewController != self, let indexPath = tableView.indexPathForSelectedRow {
            if ContactsTableViewController.usernames[indexPath.row] == message.senderUsername && message.option == .toOne { return }
            if indexPath.row == 0 && message.option == .toAll { return }
        }
        var index = 0
        if message.option == .toOne {
            index = ContactsTableViewController.usernames.firstIndex(of: message.senderUsername) ?? 0
        }
        if self.navigationController?.topViewController?.navigationItem.title == (message.receiver == "" ? "群聊" : message.senderUsername) {
            if let chatroomVC = self.navigationController?.topViewController as? ChatRoomViewController,
               chatroomVC.messageOption == message.option {
                unreadMessage[(index == 0 ? "群聊" : message.senderUsername)] = 0
                tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                return
            }
        }
        if message.option == .toOne {
            if let originalNumber = unreadMessage[message.senderUsername] {
                unreadMessage[message.senderUsername] = originalNumber + 1
            } else {
                unreadMessage[message.senderUsername] = 1
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
        if !(AppDelegate.shared.navigationController.visibleViewController is ContactsTableViewController) {
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
        NotificationCenter.default.post(name: .updateLatesetMessage, object: message)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
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
        return ContactsTableViewController.usersInfos.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return ContactTableViewCell.cellHeight
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ContactTableViewCell.cellID, for: indexPath) as! ContactTableViewCell
        cell.apply(ContactsTableViewController.usersInfos[indexPath.row])
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
        if let number = unreadMessage[ContactsTableViewController.usernames[indexPath.row]], number > 0 {
            label.text = String(number)
            cell.accessoryView = label
        }  else {
            cell.accessoryView = nil
        }
        return cell
    }
    
    //MARK: -Table view delegate
        
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        unreadMessage[ContactsTableViewController.usernames[indexPath.row]] = 0
        tableView.deselectRow(at: indexPath, animated: true)
        let chatRoomVC = chatroomVC(for: indexPath)
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
        unreadMessage[ContactsTableViewController.usernames[indexPath.row]] = 0
        let total = unreadMessage.values.reduce(0, +)
        self.navigationController?.tabBarItem.badgeValue = total > 0 ? String(total) : nil
    }
    
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let path = ContactsTableViewController.usersInfos[indexPath.row].avatarUrl
        return .init(identifier: (ContactsTableViewController.usersInfos[indexPath.row].name as NSString)) { [weak self] in
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
        if let index = ContactsTableViewController.usernames.firstIndex(of: username) {
            self.tableView(tableView, didSelectRowAt: IndexPath(row: index, section: 0))
        }
    }
    
    private func chatroomVC(for indexPath: IndexPath) -> ChatRoomViewController {
        let chatRoomVC = ChatRoomViewController()
        chatRoomVC.username = username
        chatRoomVC.navigationItem.title = ContactsTableViewController.usernames[indexPath.row]
        switch indexPath.row {
        case 0:
            chatRoomVC.messages = manager.messageManager.messagesGroup
            chatRoomVC.friendName = "群聊"
            chatRoomVC.messagesUUIDs = WebSocketManager.shared.messageManager.groupUUIDs
        default:
            chatRoomVC.messageOption = .toOne
            let friendName = ContactsTableViewController.usernames[indexPath.row]
            chatRoomVC.friendName = friendName
            chatRoomVC.messages = manager.messageManager.messagesSingle[friendName] ?? []
            chatRoomVC.messagesUUIDs = manager.messageManager.singleUUIDs[friendName] ?? Set()
            chatRoomVC.friendAvatarUrl = manager.url_pre + ContactsTableViewController.usersInfos[indexPath.row].avatarUrl
        }
        return chatRoomVC
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
        if needUpdate, let index = ContactsTableViewController.usernames.firstIndex(of: friendName) {
            ContactsTableViewController.usersInfos[index].latestMessage = message
            // 刷新对应的，把最新的移动到前面
            UIView.performWithoutAnimation {
                self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
            }
            if index != 0 {
                tableView.performBatchUpdates {
                    let removed = ContactsTableViewController.usersInfos.remove(at: index)
                    ContactsTableViewController.usersInfos.insert(removed, at: 1)
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
            needGetHistory = manager.messageManager.messagesSingle[ContactsTableViewController.usernames[indexPath.row]] == nil
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
        self.receiveNewMessage(notification: Notification(name: .receiveNewMessage, object: manager.messageManager.messagesSingle[keyValue.key]?[indexOfMessage], userInfo: nil))
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
