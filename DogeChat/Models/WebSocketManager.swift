//
//  WebSocketManager.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/5/4.
//  Copyright © 2020 Luke Parham. All rights reserved.
//

import Foundation
import SwiftyJSON
import WatchConnectivity
import CoreLocation
import SwiftWebSocket

@objc protocol MessageDelegate: class {
    @objc optional func receiveMessage(_ message: Message, option: String)
    @objc optional func updateOnlineNumber(to newNumber: Int)
    @objc optional func receiveMessages(_ messages: [Message], pages: Int)
    @objc optional func newFriend()
    @objc optional func newFriendRequest()
    @objc func revokeMessage(_ id: Int)
    @objc func revokeSuccess(id: Int)
}

enum MessageOption: String {
    case toAll
    case toOne
}

class WebSocketManager: NSObject {
    
    let session = AFHTTPSessionManager()
    var cookie = ""
    let url_pre = "https://procwq.top/"
    let encrypt = EncryptMessage()
    var maxId: Int {
        get {
            (UserDefaults.standard.value(forKey: "maxID") as? Int) ?? 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "maxID")
        }
    }
    var username = ""
    var socket: WebSocket!
    var toBeUpdatedMessages = [Message]()
    weak var messageDelegate: MessageDelegate?
    var messagesGroup: [Message] = []
    var messagesSingle: [String: [Message]] = [:]
    var notSendMessages = [Message]()
    
    static let shared: WebSocketManager = WebSocketManager()
    
    private override init() {
        session.requestSerializer = AFJSONRequestSerializer()
        super.init()
        WatchSession.shared.wcStatusDelegate = self
        
    }
    
    func login(username: String, password: String, completion: @escaping (String)->Void) {
        let paras = ["username": username, "password": password]
        session.post(url_pre + "auth/login", parameters: paras, headers: nil, progress: nil, success: { (task, response) in
            guard let response = response else { return }
            let json = JSON(response)
            print(json)
            let loginResult = json["message"].stringValue
            if loginResult == "登录成功" {
                self.username = username
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
//        var request = URLRequest(url: URL(string: "wss://47.102.114.94:8080/keyChat")!)
        request.addValue("SESSION="+cookie, forHTTPHeaderField: "Cookie")
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.open()
    }
    
    func disconnect() {
        guard socket != nil else {
            return
        }
        socket.close()
    }
    
    func makeJsonString(for dict: [String: Any]) -> String {
        let jsonData = try! JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
        let jsonStr = String(data: jsonData, encoding: .utf8)!
        return jsonStr
    }
    
    func prepareEncrypt() {
        let publicKey = encrypt.getPublicKey()
        guard !publicKey.isEmpty else { return }
        let paras = ["method": "publicKey", "key": publicKey]
        socket.send(text: makeJsonString(for: paras))
    }
    
    func getContacts(completion: @escaping ([String]) -> Void)  {
        session.get(url_pre + "friendship/getAllFriends", parameters: nil, headers: nil, progress: nil, success: { (task, response) in
            guard let response = response else { return }
            let json = JSON(response)
            guard json["status"].stringValue == "success" else { return }
            var usernames: [String] = []
            let friends = json["friends"].arrayValue
            for friend in friends {
                usernames.append(friend["username"].stringValue)
            }
            self.connect()
            completion(usernames)
        }, failure: { (task, error) in
            if let password = UserDefaults.standard.value(forKey: "lastPassword") as? String {
                self.login(username: self.username, password: password) { (result) in
                    guard result == "登录成功" else { return }
                    self.getContacts { _ in
                        
                    }
                }
            }
        })
    }
    
    func sendMessage(_ content: String, to receiver: String = "", from sender: String = "xigua", option: MessageOption, uuid: String) {
        guard socket.readyState == .open else {
            connect()
            return
        }
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        let paras: [String: Any]
        switch option {
        case .toAll:
            paras = ["method": "sendToAll", "message": content, "receiver": receiver, "sender": sender, "uuid": uuid]
        case .toOne:
            let encryptedContent = encrypt.encryptMessage(content)
            paras = ["method": "NewMessage", "message": ["content": encryptedContent, "receiver": receiver, "sender": sender], "uuid": uuid]
        }
        socket.send(text: makeJsonString(for: paras))
    }
    
    func sendToken(_ token: String?) {
        guard let token = token, token.count > 0 else {
            return
        }
        let params = ["method": "token", "token": token]
        socket.send(text: makeJsonString(for: params))
    }
    
    func resendMessages() {
        for message in self.notSendMessages {
            let option: MessageOption = message.receiver == "" ? .toAll : .toOne
            self.sendMessage(message.message, to: message.receiver, from: message.senderUsername, option: option, uuid: message.uuid)
            print("重发消息: \(message.message)")
        }
    }
    
    //MARK: History Messages
    func getUnreadMessage() {
        let paras: [String: Any] = ["method": "getUnreadMessage", "id": maxId]
        socket.send(text: makeJsonString(for: paras))
    }
    
    func historyMessages(for name: String, pageNum: Int)  {
        let paras: [String: Any] = ["method": "getHistory", "friend": name, "pageNum": pageNum]
        socket.send(text: makeJsonString(for: paras))
    }
    //MARK: Revoke
    func revokeMessage(id: Int) {
        let paras: [String: Any] = ["method": "revokeMessage", "id": id]
        socket.send(text: makeJsonString(for: paras))
    }
}

extension WebSocketManager: WebSocketDelegate  {
    func webSocketOpen() {
        print("websocket已经打开")
        getUnreadMessage()
        sendToken((UIApplication.shared.delegate as! AppDelegate).deviceToken)
        resendMessages()
    }
    
    func webSocketClose(_ code: Int, reason: String, wasClean: Bool) {
        print("websocket已关闭")
        guard UIApplication.shared.applicationState == .active else {
            return
        }
        connect()
    }
    
    func webSocketError(_ error: NSError) {
        print("error:=====\(error)")
        getContacts { (contacts) in
            print("retry")
        }
    }
    
    func webSocketMessageText(_ text: String) {
        print("收到消息")
        print(text)
        parseReceivedMessage(text)
    }
    
    private func parseReceivedMessage(_ jsonString: String) {
        let json = JSON(parseJSON: jsonString)
        let method = json["method"].stringValue
        switch method {
        case "publicKey":
            let key = json["key"].stringValue
            encrypt.key = key
            prepareEncrypt()
        case "sendToAllSuccess":
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            let id = json["id"].intValue
            let uuid = json["uuid"].stringValue
            maxId = max(maxId, id)
            guard let indexOfMessage = messagesGroup.firstIndex(where: { $0.uuid == uuid }) else { return }
            let message = messagesGroup[indexOfMessage]
            NotificationCenter.default.post(name: .sendSuccess, object: nil, userInfo: ["correctId": id, "toAll": true, "message": message])
        case "sendMessageSuccess":
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            let data = json["data"]
            let uuid = json["uuid"].stringValue
            let id = data["messageId"].intValue
            let receiver = data["receiver"].stringValue
            maxId = max(maxId, id)
            guard let indexOfMessage = messagesSingle[receiver]?.firstIndex(where: { $0.uuid == uuid }),
                  let message = messagesSingle[receiver]?[indexOfMessage] else { return }
            NotificationCenter.default.post(name: .sendSuccess, object: nil, userInfo: ["correctId": id, "toAll": false, "message": message])
        case "sendToAll":
            let content = json["message"].stringValue
            let sender = json["sender"].stringValue
            let id = json["id"].intValue
            maxId = max(maxId, id)
            let newMessage = Message(message: content, messageSender: .someoneElse, username: sender, messageType: .text, option: .toAll, id: id)
            messageDelegate?.receiveMessage?(newMessage, option: "toAll")
            messagesGroup.append(newMessage)
            //      notifyWatch(newMessage: newMessage)
            postNotification(message: newMessage)
        case "join":
            let user = json["user"].stringValue
            let number = json["total"].intValue
            messageDelegate?.updateOnlineNumber?(to: number)
            let username = user.components(separatedBy: " ")[0]
            guard username != self.username else {
                return
            }
        case "getUnreadMessage":
            let messages = json["messages"].arrayValue
            for message in messages {
                let id = message["id"].intValue
                maxId = max(maxId, id)
                let username = message["sender"].stringValue
                let newMessage = Message(message: message["content"].stringValue, messageSender: username == self.username ? .ourself : .someoneElse, username: username, messageType: .text, option: .toAll, id: id)
                messageDelegate?.receiveMessage?(newMessage, option: "toAll")
                messagesGroup.append(newMessage)
                postNotification(message: newMessage)
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
                let newMessage = Message(message: decrypted, messageSender: .someoneElse, username: sender, messageType: .text, option: .toOne, id: id, date: date)
                messageDelegate?.receiveMessage?(newMessage, option: "toOne")
                messagesSingle.add(newMessage, for: sender)
                postNotification(message: newMessage)
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
            messageDelegate?.receiveMessages?(result, pages: pages)
        case "revokeMessageSuccess":
            if json["status"].intValue == 200 {
                let id = json["id"].intValue
                messageDelegate?.revokeSuccess(id: id)
            }
        case "revokeMessage":
            let messageId = json["id"].intValue
            messageDelegate?.revokeMessage(messageId)
        case "NewFriend":
            messageDelegate?.newFriend?()
        case "NewFriendRequest":
            messageDelegate?.newFriendRequest?()
        default:
            return
        }
    }
    
    private func postNotification(message: Message) {
        NotificationCenter.default.post(name: .receiveNewMessage, object: message)
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
        session.get(url, parameters: nil, headers: nil, progress: nil, success: { (task, response) in
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
        session.post("\(url_pre)friendRequest/request", parameters: para, headers: nil, progress: nil, success: { (task, response) in
            if let response = response {
                let json = JSON(response)
                let status = json["status"].stringValue
                completion(status)
            }
        }, failure: nil)
    }
    
    func inspectQuery(completion: @escaping (([String], [String], [String])->Void)) {
        session.get("\(url_pre)friendRequest/query/-1", parameters: nil, headers: nil, progress: nil, success: { (task, response) in
            if let response = response {
                let infos = JSON(response).arrayValue
                var names = [String]()
                var requestID = [String]()
                var requestTime = [String]()
                print(infos)
                for info in infos {
                    names.append(info["friendRequester"].stringValue)
                    requestID.append(info["friendRequestId"].stringValue)
                    requestTime.append(info["requestTime"].stringValue)
                }
                completion(names, requestTime, requestID)
            }
        }, failure: nil)
    }
    
    func acceptQuery(requestId: String, complection: @escaping ((String) -> Void)) {
        session.post("\(url_pre)friendRequest/accept/\(requestId)", parameters: nil, headers: nil, progress: nil, success: { (task, response) in
            if let response = response {
                let json = JSON(response)
                complection(json["message"].stringValue)
            }
        }, failure: nil)
    }
    
    //MARK: Sign Up
    func sendValitionCode(to email: String, for purpose: Int, completion: @escaping (String) -> Void) {
        let paras: [String : Any] = ["email": email, "sendFor": purpose]
        session.post(url_pre+"auth/sendCode", parameters: paras, headers: nil, progress: nil, success: { (task, response) in
            guard let data = response else { return }
            print(JSON(data))
            completion(JSON(data)["status"].stringValue)
        }, failure: nil)
    }
    
    func signUp(username: String, password: String, repeatPassword: String, email: String, validationCode: String, completion: @escaping (String) -> Void) {
        let paras = ["username": username, "password": password, "repeatPassword": repeatPassword, "email": email, "validationCode": validationCode]
        var request = URLRequest(url: URL(string: url_pre+"auth/signup")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let jsonData = try! JSONSerialization.data(withJSONObject: paras, options: JSONSerialization.WritingOptions.prettyPrinted)
        request.httpBody = jsonData
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data else { return }
            let json = JSON(data)
            completion(json["status"].stringValue)
        }
        task.resume()
    }
}

