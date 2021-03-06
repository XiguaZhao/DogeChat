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
  
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.title = "联系人"
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "defaultCell")
    tableView.separatorStyle = .none
    refreshContacts()
    manager.connect()
    NotificationCenter.default.addObserver(self, selector: #selector(receiveNewMessage(notification:)), name: .receiveNewMessage, object: nil)
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
    manager.messageDelegate = self
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
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
    let offset: CGFloat = 10
    let adjustedWidth = height - 20
    let origin = offset / 2
    let label = UILabel(frame: CGRect(x: origin, y: origin, width: adjustedWidth, height: adjustedWidth))
    label.layer.cornerRadius = label.frame.height / 2
    label.layer.masksToBounds = true
    label.backgroundColor = .red
    label.textAlignment = .center
    let cell: UITableViewCell?
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
    let chatRoomVC = ChatroomVC(for: indexPath)
    tableView.cellForRow(at: indexPath)?.accessoryView = nil
    self.navigationController?.pushViewController(chatRoomVC, animated: true)
  }
  
  private func ChatroomVC(for indexPath: IndexPath) -> ChatRoomViewController {
    let chatRoomVC = ChatRoomViewController()
    chatRoomVC.username = username
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
    let vc = ChatroomVC(for: indexPath)
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
  
  func sendSuccess(uuid: String, correctId: Int) {
    
  }
  
  func addSuccess() {
    refreshContacts()
  }
}
