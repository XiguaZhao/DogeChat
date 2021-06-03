//
//  ContactsTableViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/5/27.
//  Copyright © 2020 Xiguang Zhao. All rights reserved.
//

import UIKit
import SwiftyJSON
import YPTransition

class ContactsTableViewController: UITableViewController {
    
    var unreadMessage = [String: Int]()
    var usersInfo = [(name: String, message: Message?, avatarUrl: String?)]()
    var usernames: [String] {
        get {
            return usersInfo.map { $0.name }
        }
        set {
            usersInfo = newValue.map { ($0, nil, nil) }
        }
    }
    var username = ""
    let manager = WebSocketManager.shared
    var barItem = UIBarButtonItem()
    var itemRequest = UIBarButtonItem()
    var selectedIndexPath: IndexPath?
    let cache: NSCache<NSString, NSData> = NSCache()
    static var poppedChatVC: [UIViewController]?
    static var pkDataCache = [String : Data]()
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
                if let index = usernames.firstIndex(of: waitToProcessNotificationUsername) {
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
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "defaultCell")
        tableView.separatorStyle = .none
        NotificationCenter.default.addObserver(self, selector: #selector(receiveNewMessage(notification:)), name: .receiveNewMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sendSuccess(notification:)), name: .sendSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadSuccess(notification:)), name: .uploadSuccess, object: nil)
        setupRefreshControl()
        barItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(presentSearchVC))
        if #available(iOS 13.0, *) {
            itemRequest = UIBarButtonItem(image: UIImage(systemName: "person.badge.plus"), style: .plain, target: self, action: #selector(presentSearchVC))
        } else {
            itemRequest = UIBarButtonItem(title: "新", style: .plain, target: self, action: #selector(presentSearchVC))
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.rightBarButtonItem = barItem
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        manager.messageDelegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationItem.rightBarButtonItem = nil
    }
    
    @objc func presentSearchVC() {
        let vc = SearchViewController()
        vc.username = self.username
        vc.usernames = self.usernames
        vc.delegate = self
        self.present(vc, animated: true)
    }
    
    @objc func refreshContacts() {
        manager.getContacts { [weak self] usernames, error  in
            guard let self = self else { return }
            if error != nil {
                self.navigationItem.title = "获取联系人失败"
                self.refreshControl?.endRefreshing()
                if let password = UserDefaults.standard.value(forKey: "lastPassword") as? String {
                    self.manager.login(username: self.username, password: password) { (result) in
                        if result == "登录成功" {
                            self.refreshContacts()
                        }
                    }
                }
                return
            }
            print(usernames)
            self.refreshControl?.endRefreshing()
            self.usernames = usernames
            self.usernames.insert("群聊", at: 0)
            self.tableView.reloadData()
            self.navigationItem.title = self.username
        }
    }
    
    func setupRefreshControl() {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(refreshContacts), for: .valueChanged)
        self.refreshControl = control
    }
    
    
    deinit {
        manager.messagesGroup.removeAll()
        manager.messagesSingle.removeAll()
        manager.groupUUIDs.removeAll()
        manager.singleUUIDs.removeAll()
        manager.disconnect()
    }
    
    @objc func receiveNewMessage(notification: Notification) {
        guard let message = notification.object as? Message else { return }
        if navigationController?.topViewController != self, let indexPath = tableView.indexPathForSelectedRow {
            if usernames[indexPath.row] == message.senderUsername && message.option == .toOne { return }
            if indexPath.row == 0 && message.option == .toAll { return }
        }
        var index = 0
        if message.option == .toOne {
            index = usernames.firstIndex(of: message.senderUsername) ?? 0
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
        let content = message.option == .toAll ? "\(message.senderUsername)：\(message.message)" : message.message
        AppDelegate.shared.pushWindow.assignValueForPush(sender: name, content: content)
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
    }
    
    @objc func sendSuccess(notification: Notification) {
        let userInfo = notification.userInfo
        guard let message = userInfo?["message"] as? Message,
              let correctId = userInfo?["correctId"] as? Int,
              let toAll = userInfo?["toAll"] as? Bool else { return }
        if correctId <= 0 { return }
        for (index, notSent) in manager.notSendContent.enumerated() {
            if let notSentMessage = notSent as? Message, notSentMessage.uuid == message.uuid {
                manager.notSendContent.remove(at: index)
                break
            }
        }
        if toAll {
            guard let indexForAddToManager = manager.messagesGroup.firstIndex(of: message) else { return }
            manager.messagesGroup[indexForAddToManager].id = correctId
            manager.messagesGroup[indexForAddToManager].sendStatus = .success
        } else {
            let receiver = message.receiver
            guard let index = manager.messagesSingle[receiver]?.firstIndex(of: message) else { return }
            manager.messagesSingle[receiver]![index].id = correctId
            manager.messagesSingle[receiver]![index].sendStatus = .success
        }
    }
    
    @objc func uploadSuccess(notification: Notification) {
        guard let message = notification.userInfo?["message"] as? Message,
              let data = notification.userInfo?["data"] else { return }
        switch message.option {
        case .toOne:
            guard let index = manager.messagesSingle[message.receiver]?.firstIndex(of: message) else { return }
            manager.messagesSingle[message.receiver]![index].sendStatus = .success
        case .toAll:
            guard let index = manager.messagesGroup.firstIndex(of: message) else { return }
            manager.messagesGroup[index].sendStatus = .success
        }
        var remoteFilePath = JSON(data)["filePath"].stringValue
        remoteFilePath = manager.encrypt.decryptMessage(remoteFilePath)
        remoteFilePath = manager.url_pre + remoteFilePath
        message.message = remoteFilePath
        manager.sendWrappedMessage(message)
    }
    
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return usernames.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "defaultCell", for: indexPath)
        cell.textLabel?.text = usernames[indexPath.row]
        if self.traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: cell)
        }
        let height = self.tableView(tableView, heightForRowAt: indexPath)
        let offset: CGFloat = 10
        let adjustedWidth = height - 20
        let origin = offset / 2
        let label = UILabel(frame: CGRect(x: origin, y: origin, width: adjustedWidth, height: adjustedWidth))
        label.layer.cornerRadius = label.frame.height / 2
        label.layer.masksToBounds = true
        label.backgroundColor = .red
        label.textAlignment = .center
        if let number = unreadMessage[usernames[indexPath.row]], number > 0 {
            label.text = String(number)
            cell.accessoryView = label
        } 
        return cell
    }
    
    //MARK: -Table view delegate
        
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        unreadMessage[usernames[indexPath.row]] = 0
        let chatRoomVC = chatroomVC(for: indexPath)
        selectedIndexPath = indexPath
        tableView.cellForRow(at: indexPath)?.accessoryView = nil
        if let splitVC = self.splitViewController, !splitVC.isCollapsed {
            let nav = self.splitViewController?.viewControllers[1] as? UINavigationController
            nav?.setViewControllers([chatRoomVC], animated: false)
            AppDelegate.shared.navigationController = nav
        } else {
            self.navigationController?.setViewControllers([self, chatRoomVC], animated: true)
            AppDelegate.shared.navigationController = self.navigationController
        }
    }
    
    private func chatroomVC(for indexPath: IndexPath) -> ChatRoomViewController {
        let chatRoomVC = ChatRoomViewController()
        chatRoomVC.username = username
        chatRoomVC.navigationItem.title = usernames[indexPath.row]
        switch indexPath.row {
        case 0:
            chatRoomVC.messages = manager.messagesGroup
            chatRoomVC.friendName = WebSocketManager.PUBLICPINO
            chatRoomVC.messagesUUIDs = WebSocketManager.shared.groupUUIDs
        default:
            chatRoomVC.messageOption = .toOne
            let friendName = usernames[indexPath.row]
            chatRoomVC.friendName = friendName
            chatRoomVC.messages = manager.messagesSingle[friendName] ?? []
            chatRoomVC.messagesUUIDs = manager.singleUUIDs[friendName] ?? Set()
        }
        return chatRoomVC
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
            needGetHistory = manager.messagesGroup.isEmpty
        default:
            needGetHistory = manager.messagesSingle[usernames[indexPath.row]] == nil
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
        let messages = manager.messagesSingle
        guard let index = messages.firstIndex(where: { $0.value.contains(where: {$0.id == id}) }) else { return }
        let keyValue = messages[index]
        guard let indexOfMessage = messages[keyValue.key]!.firstIndex(where: {$0.id == id}) else { return }
        manager.messagesSingle[keyValue.key]![indexOfMessage].message = "\(keyValue.key)撤回了一条消息"
        manager.messagesSingle[keyValue.key]![indexOfMessage].messageType = .join
        self.receiveNewMessage(notification: Notification(name: .receiveNewMessage, object: manager.messagesSingle[keyValue.key]?[indexOfMessage], userInfo: nil))
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
