//
//  WebSocketManager.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/5/4.
//  Copyright © 2020 Luke Parham. All rights reserved.
//

import Foundation
import AFNetworking
import SwiftyJSON
import Starscream
import WatchConnectivity

let url_pre = "https://procwq.top/"

protocol MessageDelegate: class {
  func receiveMessage(_ message: Message)
  func updateOnlineNumber(to newNumber: Int)
  func receiveMessages(_ messages: [Message], pages: Int)
}

enum MessageOption {
  case toAll
  case toOne
}

class WebSocketManager: NSObject {
    
  let session = AFHTTPSessionManager()
  var cookie = ""
  let encrypt = EncryptMessage()
  var maxId: Int {
    get {
      UserDefaults.standard.value(forKey: "maxID") as! Int
    }
    set {
      UserDefaults.standard.set(newValue, forKey: "maxID")
    }
  }
  var username = ""
  var socket: WebSocket!
  var toBeUpdatedMessages = [Message]()
  weak var groupDelegate: MessageDelegate?
  weak var singleDelegate: MessageDelegate?
  var messagesGroup: [Message] = []
  var messagesSingle: [String: [Message]] = [:]
  
  static let shared: WebSocketManager = WebSocketManager()
  
  private override init() {
    session.requestSerializer = AFJSONRequestSerializer()
    super.init()
    WatchSession.shared.wcStatusDelegate = self
  }
  
  func login(username: String, password: String, completion: @escaping (String)->Void) {
    let paras = ["username": username, "password": password]
    session.post(url_pre + "auth/login", parameters: paras, progress: nil, success: { (task, response) in
      guard let response = response else { return }
      let json = JSON(response)
      print(json)
      let loginResult = json["message"].stringValue
      if loginResult == "登录成功" {
        if let responseDetails = task.response as? HTTPURLResponse {
          let headers = responseDetails.allHeaderFields
          if self.cookie.isEmpty {
            let cookieStr = headers["Set-Cookie"] as! String
            self.cookie = cookieStr.components(separatedBy: ";")[0].components(separatedBy: "=")[1]
          }
        }
        completion(loginResult)
      } else {
        completion(loginResult)
      }
    }, failure: nil)
  }
  
  func connect() {
    var request = URLRequest(url: URL(string: "wss://procwq.top/webSocket")!)
    request.addValue(cookie, forHTTPHeaderField: "Cookie")
    socket = WebSocket(request: request)
    socket.delegate = self
    socket.connect()
  }
  
  func disconnect() {
    socket.disconnect()
  }
  
  func prepareEncrypt() {
    let publicKey = encrypt.getPublicKey()
    guard !publicKey.isEmpty else { return }
    let paras = ["method": "publicKey", "key": publicKey]
    let jsonData = try! JSONSerialization.data(withJSONObject: paras, options: .prettyPrinted)
    let json = String(data: jsonData, encoding: .utf8)!
    socket.write(string: json) {
      print("已发送公钥")
    }
  }
  
  func getContacts(completion: @escaping ([String]) -> Void)  {
    session.get(url_pre + "friendship/getAllFriends", parameters: nil, progress: nil, success: { (task, response) in
      guard let response = response else { return }
      let json = JSON(response)
      guard json["status"].stringValue == "success" else { return }
      var usernames: [String] = []
      let friends = json["friends"].arrayValue
      for friend in friends {
        usernames.append(friend["username"].stringValue)
      }
      completion(usernames)
    }, failure: nil)
  }
  
  func sendMessage(_ content: String, to receiver: String = "", from sender: String = "xigua", option: MessageOption) {
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
    let paras: [String: Any]
    switch option {
    case .toAll:
      paras = ["method": "sendToAll", "message": content, "receiver": receiver, "sender": sender]
    case .toOne:
      let encryptedContent = encrypt.encryptMessage(content)
      paras = ["method": "NewMessage", "message": ["content": encryptedContent, "receiver": receiver, "sender": sender]]
    }
    let jsonData = try! JSONSerialization.data(withJSONObject: paras, options: .prettyPrinted)
    let json = String(data: jsonData, encoding: .utf8)!
    socket.write(string: json) {
      print("已发送")
    }
  }
  
  //MARK: History Messages
  func getUnreadMessage() {
    let paras: [String: Any] = ["method": "getUnreadMessage", "id": maxId]
    let jsonData = try! JSONSerialization.data(withJSONObject: paras, options: .prettyPrinted)
    let jsonStr = String(data: jsonData, encoding: .utf8)!
    socket.write(string: jsonStr) {
      print("获取未读消息请求")
    }
  }
  
  func historyMessages(for name: String, pageNum: Int)  {
    let paras: [String: Any] = ["method": "getHistory", "friend": name, "pageNum": pageNum]
    let jsonData = try! JSONSerialization.data(withJSONObject: paras, options: .prettyPrinted)
    let jsonStr = String(data: jsonData, encoding: .utf8)!
    socket.write(string: jsonStr) {
      print("获取历史消息")
    }
  }
    
}

extension WebSocketManager: WebSocketDelegate {
  func didReceive(event: WebSocketEvent, client: WebSocket) {
    switch event {
    case .text(let text):
      print("收到消息")
      print(text)
      parseReceivedMessage(text)
    case .binary(let data):
      print("收到消息")
      let json = try! JSONSerialization.jsonObject(with: data, options: .mutableContainers)
      print(json)
    case .connected(_):
      print("连接socket成功")
      getUnreadMessage()
    case .disconnected(_, _):
      print("socket已断开正在重连")
      connect()
    default:
      return
    }
  }
  
  private func parseReceivedMessage(_ jsonString: String) {
    let json = JSON(parseJSON: jsonString)
    let method = json["method"].stringValue
    var _message: Message?
    switch method {
    case "publicKey":
      let key = json["key"].stringValue
      encrypt.key = key
      prepareEncrypt()
    case "sendToAllSuccess":
      UIApplication.shared.isNetworkActivityIndicatorVisible = false
      maxId = max(maxId, json["id"].intValue)
    case "sendMessageSuccess":
      UIApplication.shared.isNetworkActivityIndicatorVisible = false
      maxId = max(maxId, json["data"]["messageId"].intValue)
    case "sendToAll":
      let content = json["message"].stringValue
      let sender = json["sender"].stringValue
      let id = json["id"].intValue
      maxId = max(maxId, id)
      let newMessage = Message(message: content, messageSender: .someoneElse, username: sender, messageType: .text, option: .toAll, id: id)
      groupDelegate?.receiveMessage(newMessage)
      messagesGroup.append(newMessage)
//      notifyWatch(newMessage: newMessage)
      _message = newMessage
    case "join":
      let user = json["user"].stringValue
      let number = json["total"].intValue
      groupDelegate?.updateOnlineNumber(to: number)
      let username = user.components(separatedBy: " ")[0]
      guard username != self.username else {
        return
      }
      groupDelegate?.receiveMessage(Message(message: user, messageSender: .someoneElse, username: user, messageType: .join))
    case "getUnreadMessage":
      let messages = json["messages"].arrayValue
      for message in messages {
        let id = message["id"].intValue
        maxId = max(maxId, id)
        let username = message["sender"].stringValue
        let newMessage = Message(message: message["content"].stringValue, messageSender: username == self.username ? .ourself : .someoneElse, username: username, messageType: .text, option: .toAll, id: id)
        groupDelegate?.receiveMessage(newMessage)
        messagesGroup.append(newMessage)
        _message = newMessage
//        notifyWatch(newMessage: newMessage)
      }
    case "NewMessage":
      let data = json["data"]["unread_messages"].arrayValue
      for msg in data {
        let content = msg["messageContent"].stringValue
        let decrypted = encrypt.decryptMessage(content)
        let sender = msg["messageSender"].stringValue
        let date = msg["messageTime"].stringValue
        let id = msg["messageId"].intValue
        let newMessage = Message(message: decrypted, messageSender: .someoneElse, username: sender, messageType: .text, date: date, option: .toOne, id: id)
        singleDelegate?.receiveMessage(newMessage)
        messagesSingle.add(newMessage, for: sender)
        _message = newMessage
      }
    case "getHistory":
      let pages = json["data"]["pages"].intValue
      let messages = json["data"]["records"].arrayValue
      var result = [Message]()
      for message in messages {
        let id = message["messageId"].intValue
        var content = message["messageContent"].stringValue
        content = encrypt.decryptMessage(content)
        let sender = message["messageSender"].stringValue
        let _ = message["messageReceiver"].stringValue
        let newMessage = Message(message: content, messageSender: (sender == self.username) ? .ourself : .someoneElse, username: sender, messageType: .text, id: id)
        result.append(newMessage)
      }
      singleDelegate?.receiveMessages(result, pages: pages)
      groupDelegate?.receiveMessages(result, pages: pages)
    default:
      return
    }
    guard let newMessage = _message else { return }
    NotificationCenter.default.post(name: .receiveNewMessage, object: newMessage)
  }
  
  func notifyWatch(newMessage: Message) {
    var dict = [String: Any]()
    dict["text"] = newMessage.message
    dict["sender"] = (newMessage.messageSender == .ourself) ? "myself" : "others"
    dict["name"] = newMessage.senderUsername
    WatchSession.shared.session.sendMessage(dict, replyHandler: { (_) in
    }, errorHandler: {_ in
      self.toBeUpdatedMessages.append(newMessage)
    })
  }
  
}

extension WebSocketManager: WCStatus {
  func wcStatusChangedTo(_ status: Bool) {
    switch status {
    case true:
//      for message in toBeUpdatedMessages {
//        notifyWatch(newMessage: message)
//      }
      toBeUpdatedMessages.removeAll()
    case false:
      print("lost connection, saving")
    }
  }
}

//MARK: Search Users
extension WebSocketManager {
  
  func search(username: String, completion: @escaping (([String])->Void)) {
    var userInfos = [String]()
    guard let url = (url_pre + "user/search/\(username)").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
    session.get(url, parameters: nil, progress: nil, success: { (task, response) in
      guard let data = response else { return }
      let json = JSON(data).arrayValue
      for userInfoJson in json {
        userInfos.append(userInfoJson["username"].stringValue)
      }
      completion(userInfos)
    }, failure: nil)
  }
  
  func applyAdd(_ requested: String, from requester: String, completion: @escaping ((String) -> Void)) {
    let para = ["requested": requested, "requester": requester]
    session.post("\(url_pre)friendRequest/request", parameters: para, progress: nil, success: { (task, response) in
        if let response = response {
            let json = JSON(response)
            let status = json["status"].stringValue
            completion(status)
        }
    }, failure: nil)
  }
  
  func inspectQuery(completion: @escaping (([String], [String])->Void)) {
    session.get("\(url_pre)friendRequest/query/-1", parameters: nil, progress: nil, success: { (task, response) in
      if let response = response {
        let infos = JSON(response).arrayValue
        var result = [String]()
        var requestID = [String]()
        print(infos)
        for info in infos {
          var singleInfo = ""
          singleInfo += info["friendRequester"].stringValue
          singleInfo += (" " + info["requestTime"].stringValue)
          requestID.append(info["friendRequestId"].stringValue)
          result.append(singleInfo)
        }
        completion(result, requestID)
      }
    }, failure: nil)
  }
  
  func acceptQuery(requestId: String, complection: @escaping ((String) -> Void)) {
    session.post("\(url_pre)friendRequest/accept/\(requestId)", parameters: nil, progress: nil, success: { (task, response) in
      if let response = response {
        let json = JSON(response)
        complection(json["message"].stringValue)
      }
    }, failure: nil)
  }

}

