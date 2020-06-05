//
//  Helper.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/6/3.
//  Copyright © 2020 Luke Parham. All rights reserved.
//

import UIKit

extension ContactsTableViewController {
  func cellForUsername(_ username: String) -> UITableViewCell? {
    guard let index = usernames.lastIndex(of: username) else { return nil }
    return tableView.cellForRow(at: IndexPath(row: index, section: 0))
  }
}

extension Dictionary where Value == [Message] {
  mutating func add (_ element: Message, for key: Key) {
    if self[key] == nil {
      self[key] = [element]
    } else {
      self[key]!.append(element)
    }
  }
}
