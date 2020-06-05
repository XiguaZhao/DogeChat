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
  
  var username = "" {
    didSet {
      manager.username = username
    }
  }
    
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
  func sendWasTapped(message: String) {
    guard !message.isEmpty else { return }
    let wrappedMessage = processMessageString(for: message)
    switch messageOption {
    case .toAll:
      manager.messagesGroup.append(wrappedMessage)
    case .toOne:
      manager.messagesSingle.add(wrappedMessage, for: friendName)
    }
    manager.sendMessage(message, to: friendName, from: username, option: messageOption)
//    manager.notifyWatch(newMessage: wrappedMessage)
    insertNewMessageCell(wrappedMessage)
  }
  
  private func processMessageString(for string: String) -> Message {
    return Message(message: string, messageSender: .ourself, username: username, messageType: .text, id: manager.maxId + 1)
  }
}

extension ChatRoomViewController: MessageDelegate {
  func receiveMessage(_ message: Message) {
    insertNewMessageCell(message)
  }
  func updateOnlineNumber(to newNumber: Int) {
    navigationItem.title = "Let's Chat!" + "(\(newNumber)人在线)"
  }
  func receiveMessages(_ messages: [Message], pages: Int) {
    let minId = (self.messages.last?.id) ?? Int.max
    self.pagesAndCurNum.pages = pages
    let filtered = messages.filter { $0.id < minId }
    for message in filtered {
      self.messages.insert(message, at: 0)
      self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
    }
    self.tableView.refreshControl?.endRefreshing()
  }
}

//MARK: Refresh
extension ChatRoomViewController {
  
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
    manager.historyMessages(for: (messageOption == .toAll) ? "chatRoom" : friendName, pageNum: pagesAndCurNum.curNum)
    pagesAndCurNum.curNum += 1
  }
  
}
