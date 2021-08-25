//
//  ChatRoomViewController.swift
//  DogeChatMac
//
//  Created by 赵锡光 on 2021/6/15.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import AppKit
import DogeChatUniversal
import DogeChatNetwork

class ChatRoomViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var inputTF: NSTextField!
    
    var pagesAndCurNum = (pages: 1, curNum: 1)
    let numberOfHistory = 10
    var messages: [Message] = []
    var messageUUIDs = Set<String>()
    var friendName = "" {
        didSet {
            if messages.count < 10 {
                displayHistory()
            }
        }
    }
    var option: MessageOption = .toAll
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(receiveHistoryMessages(_:)), name: .receiveHistoryMessages, object: nil)
    }
    
    @objc func receiveHistoryMessages(_ noti: Notification) {
        guard let messages = noti.userInfo?["messages"] as? [Message], let pages = noti.userInfo?["pages"] as? Int else { return }
        self.pagesAndCurNum.pages = pages
        let filtered = messages.filter { !self.messageUUIDs.contains($0.uuid) }.reversed() as [Message]
        let oldIndex = min(self.messages.count, filtered.count)
        self.messages.insert(contentsOf: filtered, at: 0)
        let indexSet = IndexSet(0..<filtered.count)
        tableView.insertRows(at: indexSet, withAnimation: .effectFade)
    }
    
    @objc func displayHistory() {
        guard pagesAndCurNum.curNum <= pagesAndCurNum.pages else {
            return
        }
        pagesAndCurNum.curNum = (self.messages.count / numberOfHistory) + 1
        WebSocketManager.shared.historyMessages(for: (option == .toAll) ? "chatRoom" : friendName, pageNum: pagesAndCurNum.curNum)
        pagesAndCurNum.curNum += 1
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("textMessage"), owner: nil) as? ChatRoomTextCell {
            cell.apply(message: messages[row])
            return cell
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return height(for: messages[row])
    }
}
