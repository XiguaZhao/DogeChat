//
//  ContactsTableView.swift
//  DogeChatMac
//
//  Created by 赵锡光 on 2021/6/14.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import AppKit
import DogeChatUniversal
import YPTransition

var usersInfos: [UserInfo] = []

class ContactsTableViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var tableView: NSTableView!
    let manager = WebSocketManager.shared
    let messageManager = WebSocketManager.shared.messageManager
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        messageManager.login(username: "赵锡光", password: "1234567890") { res in
            guard res == "登录成功" else { return }
            WebSocketManager.shared.messageManager.getContacts { usersInfo, error in
                usersInfos = usersInfo
                self.tableView.reloadData()
                WebSocketManager.shared.messageManager.encrypt = Encrypt()
                WebSocketManager.shared.connect()
            }
        }
        
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return usersInfos.count
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let info = usersInfos[row]
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("contact"), owner: nil) as? ContactCell {
            cell.apply(info: info)
            return cell
        }
        return nil
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let friendName = usersInfos[row].name
        let option: MessageOption
        let messages: [Message]
        let messagesUUIDs: Set<String>
        if row == 0 {
            messages = WebSocketManager.shared.messageManager.messagesGroup
            option = .toAll
            messagesUUIDs = WebSocketManager.shared.messageManager.groupUUIDs
        } else {
            messages = WebSocketManager.shared.messageManager.messagesSingle[friendName] ?? []
            option = .toOne
            messagesUUIDs = WebSocketManager.shared.messageManager.singleUUIDs[friendName] ?? []
        }
        if let chatVC = (self.parent as? ViewController)?.chatRoomViewItem.viewController as? ChatRoomViewController {
            chatVC.option = option
            chatVC.messages = messages
            chatVC.messageUUIDs = messagesUUIDs
            chatVC.friendName = friendName
            chatVC.tableView.reloadData()
        }
        return true
    }
    
}

extension NSImageView {
    func makeAspectFill() {
        self.layer = CALayer()
        self.layer!.contentsGravity = CALayerContentsGravity.resizeAspectFill
        self.wantsLayer = true
    }
}
