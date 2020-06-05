//
//  Message.swift
//  ChatWatch Extension
//
//  Created by 赵锡光 on 2020/5/26.
//  Copyright © 2020 Luke Parham. All rights reserved.
//

import Foundation

enum MessageSender {
  case myself
  case others
}

struct Message {
  let username: String
  let text: String
  let sender: MessageSender
}
