//
//  InterfaceController.swift
//  ChatWatch Extension
//
//  Created by 赵锡光 on 2020/5/26.
//  Copyright © 2020 Luke Parham. All rights reserved.
//

import WatchKit
import Foundation


class InterfaceController: WKInterfaceController {
  
  @IBOutlet weak var table: WKInterfaceTable!
  var messages: [Message] = []
  
  override func awake(withContext context: Any?) {
    super.awake(withContext: context)
    loadTable()
    WatchSessionManager.shared.messageDelegate = self
  }
  
  func loadTable() {
    table.setNumberOfRows(messages.count, withRowType: "messageRow")
    for i in 0..<table.numberOfRows {
      let message = messages[i]
      if let rowController = (table.rowController(at: i)) as? RowController {
        layoutFor(rowController: rowController, with: message)
      }
    }
  }
  
  func layoutFor(rowController: RowController, with message: Message) {
    rowController.nameLabel.setText(message.username + ":")
    rowController.textLabel.setText(message.text)
    if message.sender == .myself {
      rowController.nameLabel.setHidden(true)
      rowController.textLabel.setHorizontalAlignment(.right)
    }
  }
  
}

extension InterfaceController: MessageDelegate {
  func receiveNewMessage(_ newMessage: Message) {
    messages.append(newMessage)
    let index = messages.count-1
    table.insertRows(at: IndexSet([index]), withRowType: "messageRow")
    if let rowController = table.rowController(at: index) as? RowController {
      layoutFor(rowController: rowController, with: newMessage)
      table.scrollToRow(at: index)
    }
  }
}
