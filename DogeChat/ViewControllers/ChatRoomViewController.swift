/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit


class ChatRoomViewController: UIViewController {
  
  let manager = WebSocketManager.shared
  let tableView = UITableView()
  let messageInputBar = MessageInputView()
  var messageOption: MessageOption = .toAll
  var friendName = ""
  var pagesAndCurNum = (pages: 1, curNum: 1)
  
  var messages = [Message]()
  
  var username = ""
    
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    let recognizer = UITapGestureRecognizer(target: self, action: #selector(tap))
    tableView.addGestureRecognizer(recognizer)
    guard !messages.isEmpty else { return }
    tableView.scrollToRow(at: IndexPath(row: messages.count - 1, section: 0), at: .bottom, animated: true)
  }
  
  deinit {
    print("chat room VC deinit")
  }
  
  @objc func tap() {
    NotificationCenter.default.post(name: NSNotification.Name.shouldResignFirstResponder, object: nil)
  }
}

//MARK - Message Input Bar
extension ChatRoomViewController: MessageInputDelegate {
  func sendWasTapped(content: String) {
    guard !content.isEmpty else { return }
    let wrappedMessage = processMessageString(for: content)
    switch messageOption {
    case .toAll:
      manager.messagesGroup.append(wrappedMessage)
    case .toOne:
      manager.messagesSingle.add(wrappedMessage, for: friendName)
    }
    manager.sendMessage(content, to: friendName, from: username, option: messageOption, uuid: wrappedMessage.uuid)
//    manager.notifyWatch(newMessage: wrappedMessage)
    insertNewMessageCell(wrappedMessage)
  }
  
  private func processMessageString(for string: String) -> Message {
    return Message(message: string, messageSender: .ourself, username: username, messageType: .text, id: manager.maxId + 1, sendStatus: .fail)
  }
}

extension ChatRoomViewController: MessageDelegate {
  
  func sendSuccess(uuid: String, correctId: Int) {
    guard let index = messages.firstIndex(where: { $0.uuid == uuid }) else { return }
    messages[index].id = correctId
    messages[index].sendStatus = .success
    if messageOption == .toAll { //在群聊中join也是一条消息
      let messagesWithoutJoin = messages.filter { $0.messageType != .join }
      guard let indexForAddToManager = messagesWithoutJoin.firstIndex(where: { $0.uuid == uuid }) else { return }
      manager.messagesGroup[indexForAddToManager].id = correctId
      manager.messagesGroup[indexForAddToManager].sendStatus = .success
    } else {
      manager.messagesSingle[friendName]![index].id = correctId
      manager.messagesSingle[friendName]![index].sendStatus = .success
    }
    let indexPath = IndexPath(row: index, section: 0)
    (tableView.cellForRow(at: indexPath) as? MessageTableViewCell)?.indicator.removeFromSuperview()
  }
  
  func receiveMessage(_ message: Message, option: String) {
    if option != messageOption.rawValue  { return }
    if option == "toOne" && message.senderUsername != friendName { return }
    insertNewMessageCell(message)
  }
  
  func updateOnlineNumber(to newNumber: Int) {
    guard messageOption == .toAll else { return }
    navigationItem.title = "Let's Chat!" + "(\(newNumber)人在线)"
  }
  
  func receiveMessages(_ messages: [Message], pages: Int) {
    let minId = (self.messages.first?.id) ?? Int.max
    self.pagesAndCurNum.pages = pages
    let filtered = messages.filter { $0.id < minId }
    for message in filtered {
      self.messages.insert(message, at: 0)
      self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
      if messageOption == .toAll {
        manager.messagesGroup.insert(message, at: 0)
      } else {
        manager.messagesSingle.insert(message, at: 0, for: friendName)
      }
    }
    self.tableView.refreshControl?.endRefreshing()
  }
  
  func newFriendRequest() {
    guard let contactVC = navigationController?.viewControllers.filter({ $0 is ContactsTableViewController }).first as? ContactsTableViewController else { return }
    navigationItem.rightBarButtonItem = contactVC.itemRequest
    contactVC.playSound()
  }
}

extension ChatRoomViewController {
  //MARK: Refresh
  func addRefreshController() {
    let controller = UIRefreshControl()
    controller.addTarget(self, action: #selector(displayHistory), for: .valueChanged)
    tableView.refreshControl = controller
  }
  
  @objc func displayHistory() {
    guard pagesAndCurNum.curNum <= pagesAndCurNum.pages else {
      self.tableView.refreshControl?.endRefreshing()
      return
    }
    pagesAndCurNum.curNum = (self.messages.count / 10) + 1
    manager.historyMessages(for: (messageOption == .toAll) ? "chatRoom" : friendName, pageNum: pagesAndCurNum.curNum)
    pagesAndCurNum.curNum += 1
  }
  
  //MARK: ContextMune
  @available(iOS 13.0, *)
  func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
    let cell = tableView.cellForRow(at: indexPath) as! MessageTableViewCell
    let identifier = "\(indexPath.row)" as NSString
    return UIContextMenuConfiguration(identifier: identifier, previewProvider: nil
    ) { (menuElement) -> UIMenu? in
      let copyAction = UIAction(title: "复制") { (_) in
        let text = cell.messageLabel.text
        UIPasteboard.general.string = text
      }
      var revokeAction: UIAction?
      if self.messages[indexPath.row].messageSender == .ourself && self.messages[indexPath.row].messageType != .join && self.messageOption == .toOne {
        revokeAction = UIAction(title: "撤回") { (_) in
          self.revoke(indexPath: indexPath)
        }
      }
      let menu = UIMenu(title: "", image: nil, children: (revokeAction == nil) ? [copyAction] : [copyAction, revokeAction!])
      return menu
    }
  }
  
  func revoke(indexPath: IndexPath) {
    let id = messages[indexPath.row].id
    manager.revokeMessage(id: id)
  }
  
  func revokeSuccess(id: Int) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    removeMessage(index: index)
  }
  
  func removeMessage(index: Int) {
    messages[index].message = "\(messages[index].senderUsername)撤回了一条消息"
    messages[index].messageType = .join
    let updatedMessage = messages[index]
    switch messageOption {
    case .toAll:
      manager.messagesGroup[index] = updatedMessage
    case .toOne:
      manager.messagesSingle.update(at: index, for: friendName, with: updatedMessage)
    }
    tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
  }
  
  func revokeMessage(_ id: Int) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    removeMessage(index: index)
  }
}
