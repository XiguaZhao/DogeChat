//
//  ContactsTableViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/5/27.
//  Copyright © 2020 Luke Parham. All rights reserved.
//

import UIKit
import AudioToolbox

class ContactsTableViewController: UITableViewController {
    
    var usernames = [String]()
    var username = ""
    let manager = WebSocketManager.shared
    var barItem = UIBarButtonItem()
    var itemRequest = UIBarButtonItem()
    var appDelegate: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    var loginSuccess = false {
        didSet {
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
        if self.loginSuccess {
            refreshContacts()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(receiveNewMessage(notification:)), name: .receiveNewMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sendSuccess(notification:)), name: .sendSuccess, object: nil)
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
        manager.getContacts { usernames in
            print(usernames)
            self.refreshControl?.endRefreshing()
            self.usernames = usernames
            self.usernames.insert("群聊", at: 0)
            self.tableView.reloadData()
            self.loginSuccess = true
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
        manager.disconnect()
    }
    
    @objc func receiveNewMessage(notification: Notification) {
        playSound()
        guard let message = notification.object as? Message,
              let height = tableView.cellForRow(at: IndexPath(row: 0, section: 0))?.contentView.frame.height
        else { return }
        if navigationController?.topViewController != self, let indexPath = tableView.indexPathForSelectedRow {
            if usernames[indexPath.row] == message.senderUsername && message.option == .toOne { return }
            if indexPath.row == 0 && message.option == .toAll { return }
        }
        if self.navigationController?.topViewController?.navigationItem.title == message.senderUsername {
            if let chatroomVC = self.navigationController?.topViewController as? ChatRoomViewController,
               chatroomVC.messageOption == message.option {
                return
            }
        }
        let offset: CGFloat = 10
        let adjustedWidth = height - 20
        let origin = offset / 2
        let label = UILabel(frame: CGRect(x: origin, y: origin, width: adjustedWidth, height: adjustedWidth))
        label.layer.cornerRadius = label.frame.height / 2
        label.layer.masksToBounds = true
        label.backgroundColor = .red
        label.textAlignment = .center
        let cell: UITableViewCell? // 不能直接这么使用
        switch message.option {
        case .toAll:
            cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0))
        case .toOne:
            guard let _cell = cellForUsername(message.senderUsername) else { return }
            cell = _cell
        }
        let number = Int((cell?.accessoryView as? UILabel)?.text ?? "0")
        let hh = number ?? 0
        label.text = String(hh + 1)
        cell?.accessoryView = label
    }
    
    func playSound() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        AudioServicesPlaySystemSound(1007)
    }
    
    @objc func sendSuccess(notification: Notification) {
        let userInfo = notification.userInfo
        guard let message = userInfo?["message"] as? Message,
              let correctId = userInfo?["correctId"] as? Int,
              let toAll = userInfo?["toAll"] as? Bool else { return }
        guard let indexToDelete = manager.notSendMessages.firstIndex(where: { $0.uuid == message.uuid }) else {
            return
        }
        manager.notSendMessages.remove(at: indexToDelete)
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
    
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return usernames.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "defaultCell", for: indexPath)
        cell.textLabel?.text = usernames[indexPath.row]
        if self.traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: cell)
        }
        return cell
    }
    
    //MARK: -Table view delegate
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let chatRoomVC = chatroomVC(for: indexPath)
        tableView.cellForRow(at: indexPath)?.accessoryView = nil
        self.navigationController?.setViewControllers([self, chatRoomVC], animated: true)
    }
    
    private func chatroomVC(for indexPath: IndexPath) -> ChatRoomViewController {
        let chatRoomVC = ChatRoomViewController()
        chatRoomVC.username = username
        chatRoomVC.navigationItem.title = usernames[indexPath.row]
        switch indexPath.row {
        case 0:
            chatRoomVC.messages = manager.messagesGroup
        default:
            chatRoomVC.messageOption = .toOne
            let friendName = usernames[indexPath.row]
            chatRoomVC.friendName = friendName
            chatRoomVC.messages = manager.messagesSingle[friendName] ?? []
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
        playSound()
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
