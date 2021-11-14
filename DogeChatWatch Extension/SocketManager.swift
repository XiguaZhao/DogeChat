//
//  SocketManager.swift
//  DogeChatWatch Extension
//
//  Created by 赵锡光 on 2021/6/7.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import Foundation
import AFNetworking
import SwiftyJSON
import DogeChatUniversal

class SocketManager: NSObject, URLSessionDelegate, URLSessionWebSocketDelegate, DCWebSocketProtocol {
    
    
    static let shared = SocketManager()
    var commonSocket: DogeChatWebSocket!
    let url_pre = "https://121.5.152.193/"
    var socket: URLSessionWebSocketTask!
    var messageManager: MessageManager {
        commonSocket.messageManager
    }
    var httpManager: HttpRequestsManager {
        commonSocket.httpRequestsManager
    }
    private var latestResponseTime = Date().timeIntervalSince1970 {
        didSet {
            commonSocket.latestResponseTime = latestResponseTime
        }
    }
    private var latestConnectTime = Date().timeIntervalSince1970 {
        didSet {
            commonSocket.latestConnectTime = latestConnectTime
        }
    }
    var connected: Bool {
        get {
            commonSocket.connected
        }
        set {
            commonSocket.connected = newValue
        }
    }
    var connectTime = 0
    lazy var session: URLSession = {
        let sesssion = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        return sesssion
    }()
    
    override init() {
        super.init()
        commonSocket = DogeChatWebSocket(socketProtocol: self)
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
        var request = URLRequest(url: URL(string: "wss://121.5.152.193/webSocket?deviceType=3")!)
        request.addValue("SESSION="+messageManager.cookie, forHTTPHeaderField: "Cookie")
        self.socket = session.webSocketTask(with: request)
        socket.resume()
    }
    
    func disconnect() {
        socket?.cancel(with: .normalClosure, reason: nil)
        connected = false
        commonSocket.invalidatePingTimer()
    }
    
    func sendToken() {
        guard let token = ExtensionDelegate.shared.deviceToken else { return }
        commonSocket.sendToken(token)
    }
        
    func onReceive() {
        print("call receive")
        socket.receive {[weak self] result in
            print("receive callback")
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.latestResponseTime = Date().timeIntervalSince1970
                switch message {
                case .data(_):
                    break
                case .string(let string):
                    print(string)
                    self.commonSocket.parseReceivedMessage(string)
                    self.onReceive()
                default:
                    break
                }
            case .failure(_):
                break
            }
        }
    }
                
    public func postNotification(message: Message) {
        NotificationCenter.default.post(name: .receiveNewMessage, object: message)
    }
    
    func sendText(_ text: String) {
        let message = URLSessionWebSocketTask.Message.string(text)
        self.socket.send(message) { _ in
        }
    }
    
    func sendData(_ data: Data) {
        
    }
    
        
    func sendMessage(_ message: Message) {
        commonSocket.sendWrappedMessage(message)
    }
        
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("手表webSocket已打开")
        self.connected = true
        commonSocket.prepareEncrypt()
        self.latestConnectTime = Date().timeIntervalSince1970
        sendToken()
        onReceive()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("手表websocket已关闭")
        self.connected = false
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, credential)
    }
}
