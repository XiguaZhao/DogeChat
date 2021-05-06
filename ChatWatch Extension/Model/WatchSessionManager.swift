//
//  WatchSessionManager.swift
//  ChatWatch Extension
//
//  Created by 赵锡光 on 2020/5/26.
//  Copyright © 2020 Xiguang Zhao. All rights reserved.
//

import WatchKit
import WatchConnectivity

protocol MessageDelegate: class {
  func receiveNewMessage(_ newMessage: Message)
}

class WatchSessionManager: NSObject, WCSessionDelegate {
  
  static let shared = WatchSessionManager()
  private let session: WCSession
  weak var messageDelegate: MessageDelegate?
  private override init() {
    session = WCSession.default
    super.init()
    session.delegate = self
    session.activate()
  }
  
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if activationState == .activated { print("activated") }
  }
  
  func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
    guard let text = message["text"] as? String, let sender: MessageSender = (message["sender"] as! String == "myself") ? .myself : .others, let name = message["name"] as? String else { return }
    let newMessage = Message(username: name, text: text, sender: sender)
    messageDelegate?.receiveNewMessage(newMessage)
  }
}
