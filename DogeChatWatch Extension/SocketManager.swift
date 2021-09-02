//
//  SocketManager.swift
//  DogeChatWatch Extension
//
//  Created by 赵锡光 on 2021/6/7.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import AFNetworking
import SwiftyJSON
import DogeChatUniversal

class SocketManager: NSObject, URLSessionDelegate, URLSessionWebSocketDelegate {
    static let shared = SocketManager()
    let messageManager = MessageManager()
    let url_pre = "https://121.5.152.193/"
    var socket: URLSessionWebSocketTask!
    var connected = false
    weak var receiveTimer: Timer?
    lazy var session: URLSession = {
        let sesssion = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        return sesssion
    }()
    
    override init() {
        super.init()
    }
    
    func connect() {
        guard !messageManager.cookie.isEmpty else {
            return 
        }
        DispatchQueue.main.async {
            WKExtension.shared().visibleInterfaceController?.setTitle("正在连接....")
        }
        if receiveTimer != nil {
            receiveTimer?.invalidate()
            receiveTimer = nil
        }
        var request = URLRequest(url: URL(string: "wss://121.5.152.193/webSocket")!)
        request.addValue("SESSION="+messageManager.cookie, forHTTPHeaderField: "Cookie")
        self.socket = session.webSocketTask(with: request)
        socket.resume()
        sendKey()
        sendToken()
        onReceive()
    }
    
    func disconnect() {
        receiveTimer?.invalidate()
        receiveTimer = nil
        socket?.cancel(with: .normalClosure, reason: nil)
        connected = false
    }
    
    func sendToken() {
        guard let token = ExtensionDelegate.shared.deviceToken else { return }
        let params = ["method": "token", "token": token]
        send(params: params, failure: nil)
    }
    
    func sendKey() {
        self.connected = true
        guard let paras = messageManager.prepareEncrypt() else { return }
        send(params: paras, failure: nil)
    }
    
    func onReceive() {
        print("call receive")
        socket.receive {[weak self] result in
            print("receive callback")
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .data(_):
                    break
                case .string(let string):
                    print(string)
                    self.processString(str: string)
                    self.onReceive()
                default:
                    break
                }
            case .failure(_):
                break
            }
        }
    }
    
    func setInterfaceControllerTitle() {
        if let vc = WKExtension.shared().visibleInterfaceController {
            if vc is ContactInterfaceController {
                vc.setTitle(messageManager.myName)
            } else if let chatVC = vc as? ChatRoomInterfaceController {
                chatVC.setTitle(chatVC.friendName)
            }
        }
    }
    
    func processString(str: String) {
        let json = JSON(parseJSON: str)
        let method = json["method"].stringValue
        switch method {
        case "publicKey":
            DispatchQueue.main.async {
                self.setInterfaceControllerTitle()
            }
            let key = json["data"].stringValue
            messageManager.encrypt.key = key
            getPublicUnreadMessage()
        case "PublicNewMessage":  // 收到群聊消息
            if let newMessage = messageManager.wrapMessage(messageJSON: json["data"]) {
                processNewMessages([newMessage], isPublic: true)
            }
            NotificationCenter.default.post(name: .playSound, object: nil)
        case "getPublicUnreadMessage": // 群聊未读消息,socket连接上后会获取
            let messages = json["data"].arrayValue
            var newMessages = [Message]()
            for message in messages {
                if let newMessage = messageManager.wrapMessage(messageJSON: message) {
                    newMessages.append(newMessage)
                }
            }
            processNewMessages(newMessages, isPublic: true)
        case "PersonalNewMessage": // 收到私人消息
            let data = json["data"].arrayValue
            var messages = [Message]()
            for msg in data {
                if let newMessage = messageManager.wrapMessage(messageJSON: msg) {
                    messages.append(newMessage)
                }
            }
            processNewMessages(messages, isPublic: false)
        case "getHistory":  // 获取群聊、个人历史记录
            let pages = json["data"]["pages"].intValue
            let messages = json["data"]["records"].arrayValue
            var result = [Message]()
            for message in messages {
                if let newMessage = messageManager.wrapMessage(messageJSON: message, insertPosition: .top) {
                    result.append(newMessage)
                }
            }
            NotificationCenter.default.post(name: .receiveHistoryMessages, object: nil, userInfo: ["messages": result, "pages": pages])
        default:
            break
        }
    }
    
    public func historyMessages(for name: String, pageNum: Int)  {
        let paras: [String: Any] = ["method": "getHistory", "friend": name, "pageNum": pageNum]
        send(params: paras, failure: nil)
    }
    
    public func postNotification(message: Message) {
        NotificationCenter.default.post(name: .receiveNewMessage, object: message)
    }
    
    public func getPublicUnreadMessage() {
        let paras: [String: Any] = ["method": "getPublicUnreadMessage", "id": messageManager.maxId]
        send(params: paras, failure: nil)
    }

    func send(params: [String: Any], failure: ((Error?)->Void)?) {
        let jsonStr = messageManager.makeJsonString(for: params)
        let message = URLSessionWebSocketTask.Message.string(jsonStr)
        self.socket.send(message) { error in
            NotificationCenter.default.post(name: .socketError, object: params)
            failure?(error)
        }

    }
    
    func sendMessage(_ message: Message) {
        let paras = messageManager.sendMessage(message.message, to: message.receiver, from: message.senderUsername, option: message.option, uuid: message.uuid, type: message.messageType.rawValue)
        send(params: paras, failure: nil)
        messageManager.saveSendMessage(message)
    }
    
    func processNewMessages(_ messages: [Message], isPublic: Bool) {
        if messages.isEmpty {
            return
        }
        WKInterfaceDevice.current().play(.success)
        if let chatVC = WKExtension.shared().visibleInterfaceController as? ChatRoomInterfaceController {
            let vcTitle = chatVC.friendName
            if isPublic && vcTitle == "群聊" {
                chatVC.insertMessages(messages)
            } else {
                for message in messages {
                    if message.option == chatVC.messageOption && message.senderUsername == vcTitle {
                        chatVC.insertMessages([message])
                    } else {
                        postNotification(message: message)
                    }
                }
            }
        } else {
            for message in messages {
                postNotification(message: message)
            }
        }
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, credential)
    }
}
