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
    var connectTime = 0
    var lastResponseTimer = Date().timeIntervalSince1970
    weak var receiveTimer: Timer?
    lazy var session: URLSession = {
        let sesssion = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        return sesssion
    }()
    
    override init() {
        super.init()
    }
    
    func connect() {
        syncOnMain {
            _connect()
        }
    }
    
    private func _connect() {
        guard !messageManager.cookie.isEmpty else {
            return
        }
        if receiveTimer != nil {
            receiveTimer?.invalidate()
            receiveTimer = nil
        }
        syncOnMain {
            NotificationCenter.default.post(name: .connecting, object: nil)
        }
        var request = URLRequest(url: URL(string: "wss://121.5.152.193/webSocket?deviceType=3")!)
        request.addValue("SESSION="+messageManager.cookie, forHTTPHeaderField: "Cookie")
        self.socket = session.webSocketTask(with: request)
        socket.resume()
        sendKey()
        sendToken()
        onReceive()
        
        connectTime += 1
        if connectTime > 5 { return }
        let latestRequestTime = Date().timeIntervalSince1970
        var success = false
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            print("connectTimer执行")
            if let self = self {
                if self.lastResponseTimer > latestRequestTime {
                    timer.invalidate()
                    if !success {
                        print("连接成功，关闭定时器")
                        success = true
                        self.connectTime = 0
                    }
                }
            }
        }
        timer.tolerance = 0.2
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            timer.invalidate()
            if !success {
                print("失败，重新连接")
                self.connect()
            }
        }
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
                self.lastResponseTimer = Date().timeIntervalSince1970
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
    
    public func processSendSuccess(_ data: JSON, toAll: Bool) {
        let _ = messageManager.processSendSuccess(data, toAll: toAll)
    }
    
    func processString(str: String) {
        let json = JSON(parseJSON: str)
        let method = json["method"].stringValue
        switch method {
        case "publicKey":
            syncOnMain {
                NotificationCenter.default.post(name: .connected, object: nil)
            }
            let key = json["data"].stringValue
            messageManager.encrypt.key = key
            getPublicUnreadMessage()
        case "sendToAllSuccess":
            let data = json["data"]
            processSendSuccess(data, toAll: true)
        case "sendPersonalMessageSuccess":
            let data = json["data"]
            processSendSuccess(data, toAll: false)
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
                    let friendName = message.messageSender == .ourself ? message.receiver : message.senderUsername
                    if message.option == chatVC.messageOption && friendName == vcTitle {
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
