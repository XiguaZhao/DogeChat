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

class ContactsTableViewController: DogeChatViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDelegate, UITableViewDataSource {
    
    var unreadMessage = [String: Int]()
    var friends: [Friend] = []
    var usernames: [String] {
        friends.map { $0.username }
    }
    var username = ""
    var password = ""
    var loginCount = 0
    let avatarImageView = FLAnimatedImageView()
    var manager: WebSocketManager {
        return socketForUsername(username)
    }
    var diffableDataSource: Any!
    var needUpdate = false
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
    let cache = NSCache<NSString, NSData>()
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
        NotificationCenter.default.addObserver(self, selector: #selector(loginingNoti(_:)), name: .logining, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(loginedNoti(_:)), name: .logined, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshContactsNoti(_:)), name: .refreshContacts, object: username)
        setupRefreshControl()
        barItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(presentSearchVC))
        if #available(iOS 13.0, *) {
            itemRequest = UIBarButtonItem(image: UIImage(systemName: "person.badge.plus"), style: .plain, target: self, action: #selector(presentSearchVC))
        } else {
            itemRequest = UIBarButtonItem(title: "新", style: .plain, target: self, action: #selector(presentSearchVC))
        }
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
        manager.messageManager.messageDelegate = self
        loadAllTracks(username: username)
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
    
    @objc func connectingNoti(_ noti: Notification) {
        saveTitleView()
        navigationItem.title = "正在连接..."
        navigationItem.titleView = nil
    }
    
    @objc func connectedNoti(_ noti: Notification) {
        setupMyAvatar()
        navigationItem.title = username
    }
    
    @objc func loginingNoti(_ noti: Notification) {
        saveTitleView()
        navigationItem.titleView = nil
        navigationItem.title = "正在登录..."
    }
    
    @objc func loginedNoti(_ noti: Notification) {
        WCSession.default.sendMessage(["username": username, "password": password], replyHandler: nil, errorHandler: nil)
    }
    
    @objc func refreshContactsNoti(_ noti: Notification) {
        guard let friends = noti.userInfo?["contacts"] as? [Friend] else { return }
        self.friends = friends
        tableView.reloadData()
        tableView.refreshControl?.endRefreshing()
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
                return
            }
            print(userInfos)
            self.friends = userInfos
            self.tableView.reloadData()
            self.navigationItem.title = self.username
            completion?()
            self.tableView.refreshControl?.endRefreshing()
        }
        #if targetEnvironment(macCatalyst)
        if appDelegate.needRelogin() {
            appDelegate.applicationDidBecomeActive(UIApplication.shared)
        }
        #endif
    }
    
    @objc func downRefreshAction(_ refreshControl: UIRefreshControl) {
        removeAllMessage()
        loginAndConnect()
    }
    
    func removeAllMessage() {
        manager.messageManager.friends.removeAll()
    }
    
    @objc func loginAndConnect() {
        manager.loginAndConnect(username: username, password: password)
    }
    
    func startReachabilityNotifier() {
        if #available(iOS 13.0, *) {
            try? SceneDelegate.reachability.startNotifier()
        }
    }
    
    func setupRefreshControl() {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(downRefreshAction(_:)), for: .valueChanged)
        self.tableView.refreshControl = control
    }
    
    
    deinit {
        manager.messageManager.friends.removeAll()
        manager.disconnect()
        removeSocketForUsername(username)
    }
    
    @objc func receiveNewMessage(notification: Notification) {
        guard let message = notification.userInfo?["message"] as? Message, message.messageSender != .ourself else { return }
        if navigationController?.topViewController != self, let indexPath = tableView.indexPathForSelectedRow {
            if self.usernames[indexPath.row] == message.senderUsername && message.option == .toOne { return }
            if indexPath.row == 0 && message.option == .toGroup { return }
        }
        var index = 0
        if message.option == .toOne {
            let friendName = message.messageSender == .ourself ? message.receiver : message.senderUsername
            index = self.usernames.firstIndex(of: friendName) ?? 0
        }
        let friendName = message.option == .toGroup ? "群聊" : (message.messageSender == .ourself ? message.receiver : message.senderUsername)
        if let visibleVC = nav?.visibleViewController as? ChatRoomViewController,
            visibleVC.navigationItem.title == (message.option == .toGroup ? "群聊" : friendName) {
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
        var content = message.option == .toGroup ? "\(message.senderUsername)：" : ""
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
            if #available(iOS 13, *) {
                SceneDelegate.usernameToDelegate[username]?.pushWindow.assignValueForPush(sender: friendName, content: content)
            } else {
                AppDelegate.shared.pushWindow.assignValueForPush(sender: friendName, content: content)
            }
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
              let correctId = userInfo?["correctId"] as? Int else { return }
        if correctId <= 0 { return }
        for (index, notSent) in manager.messageManager.notSendContent.enumerated() {
            if let notSentMessage = notSent as? Message, notSentMessage.uuid == message.uuid {
                manager.messageManager.notSendContent.remove(at: index)
                break
            }
        }
        let friend = message.friend
        if let index = friend?.messages.firstIndex(of: message) {
            friend?.messages[index].id = correctId
            friend?.messages[index].sendStatus = .success
            NotificationCenter.default.post(name: .updateLatesetMessage, object: username, userInfo: ["message": message])
        }
    }
        
    @objc func uploadSuccess(notification: Notification) {
        guard let message = notification.userInfo?["message"] as? Message,
              let data = notification.userInfo?["data"] else { return }
        var remoteFilePath = JSON(data)["filePath"].stringValue
        remoteFilePath = manager.messageManager.encrypt.decryptMessage(remoteFilePath)
        remoteFilePath = WebSocketManager.url_pre + remoteFilePath
        message.message = remoteFilePath
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
        let cell = tableView.dequeueReusableCell(withIdentifier: ContactTableViewCell.cellID, for: indexPath) as! ContactTableViewCell
        cell.apply(self.friends[indexPath.row])
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
        selectedIndexPath = indexPath
        tableView.cellForRow(at: indexPath)?.accessoryView = nil
        if let splitVC = self.splitViewController, !splitVC.isCollapsed {
            let nav = DogeChatNavigationController(rootViewController: chatRoomVC)
            nav.modalPresentationStyle = .fullScreen
            if #available(iOS 13, *) {
                (view.window?.windowScene?.delegate as? SceneDelegate)?.navigationController = nav
            } else {
                appDelegate.navigationController = nav
            }
            self.showDetailViewController(nav, sender: self)
        } else {
            self.navigationController?.setViewControllers([self, chatRoomVC], animated: true)
            if #available(iOS 13, *) {
                (view.window?.windowScene?.delegate as? SceneDelegate)?.navigationController = self.navigationController
            } else {
                AppDelegate.shared.navigationController = self.navigationController
            }
        }
        unreadMessage[self.usernames[indexPath.row]] = 0
        let total = unreadMessage.values.reduce(0, +)
        self.navigationController?.tabBarItem.badgeValue = total > 0 ? String(total) : nil
    }
    
    @available(iOS 13.0, *)
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
    
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        let username = configuration.identifier as! String
        if let index = self.usernames.firstIndex(of: username) {
            self.tableView(tableView, didSelectRowAt: IndexPath(row: index, section: 0))
        }
    }
    
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, willEndContextMenuInteraction configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        tableView.reloadData()
    }
    
    private func chatroomVC(for indexPath: IndexPath) -> ChatRoomViewController {
        let chatRoomVC = ChatRoomViewController()
        let friend = self.friends[indexPath.row]
        chatRoomVC.friend = friend
        chatRoomVC.username = username
        chatRoomVC.contactVC = self
        chatRoomVC.cache = self.cache
        return chatRoomVC
    }
    
    @objc func updateLatestMessage(_ noti: Notification) {
        guard let message = noti.userInfo?["message"] as? Message else { return }
        let friend = message.friend!
        let needUpdate: Bool = friend.latestMessage?.id ?? 0 < message.id
        if needUpdate, let index = self.friends.firstIndex(of: friend) {
            print("needUpdateContact")
            self.friends[index].latestMessage = message
            // 刷新对应的，把最新的移动到前面
            UIView.performWithoutAnimation {
                self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
            }
            tableView.performBatchUpdates {
                let removed = self.friends.remove(at: index)
                self.friends.insert(removed, at: 0)
                tableView.moveRow(at: IndexPath(row: index, section: 0), to: IndexPath(row: 0, section: 0))
            } completion: { _ in
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
        let needGetHistory = friends[indexPath.row].messages.isEmpty
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
//        let messages = manager.messageManager.messagesSingle
//        guard let index = messages.firstIndex(where: { $0.value.contains(where: {$0.id == id}) }) else { return }
//        let keyValue = messages[index]
//        guard let indexOfMessage = messages[keyValue.key]!.firstIndex(where: {$0.id == id}) else { return }
//        manager.messageManager.messagesSingle[keyValue.key]![indexOfMessage].message = "\(keyValue.key)撤回了一条消息"
//        manager.messageManager.messagesSingle[keyValue.key]![indexOfMessage].messageType = .join
//        self.receiveNewMessage(notification: Notification(name: .receiveNewMessage, object: username, userInfo: ["message": manager.messageManager.messagesSingle[keyValue.key]?[indexOfMessage] as Any]))
    }
    
    func newFriend() {
        refreshContacts()
    }
    
    func newFriendRequest() {
        adapterFor(username: username).playSound()
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
    
    var userInfos: [Friend] {
        return self.friends
    }
    
}
