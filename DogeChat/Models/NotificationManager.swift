//
//  Notification.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/16.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

import UIKit
import DogeChatNetwork
import DogeChatUniversal
import RSAiOSWatchOS
import DogeChatCommonDefines

struct RemoteNotificationInfo {
    var sender: String?
    var senderID: String?
    var content: String?
    var receiverID: String?
    var receiver: String?
}

class NotificationManager: NSObject {
    
    static let shared = NotificationManager()
    weak var sceneDelegate: AnyObject?
    var manager: WebSocketManager? {
        if #available(iOS 13, *) {
            return (sceneDelegate as? SceneDelegate)?.socketManager
        } else {
            return WebSocketManager.shared
        }
    }
    var nowPushInfo: (sender: String, content: String, senderID: String) = ("", "", "")
    var actionCompletionHandler: (() -> Void)?
    var quickReplyMessage: Message?
    var remoteNotificationUsername = ""
    let httpMessage = HttpMessage()
    
    override init() {
        super.init()
    }
    
    func nav() -> UINavigationController? {
        if #available(iOS 13, *) {
            return (sceneDelegate as? SceneDelegate)?.navigationController
        } else {
            return AppDelegateUI.shared.navController
        }
    }
    
    public static func getRemoteNotiInfo(_ notification: [String: Any]) -> RemoteNotificationInfo {
        var sender: String?
        var content: String?
        var senderID: String?
        var receiverID: String?
        var receiver: String?
        if let alert = notification["alert"] as? [String: Any],
           let _sender = alert["title"] as? String,
           let _content = alert["body"] as? String,
           let _senderID = notification["senderId"] as? String {
            sender = _sender
            content = _content
            senderID = _senderID
            if let _receiverID = notification["receiverId"] as? String {
                receiverID = _receiverID
            }
            if let _receiver = notification["receiver"] as? String {
                receiver = _receiver
            }
        }
        return RemoteNotificationInfo(sender: sender, senderID: senderID, content: content, receiverID: receiverID, receiver: receiver)
    }

    public func processRemoteNotification(_ notification: [String: Any]) {
        let processed = Self.getRemoteNotiInfo(notification)
        guard let sender = processed.sender,
              let content = processed.content,
              let senderID = processed.senderID else { return }
        nowPushInfo = (sender, content, senderID)
        UIApplication.shared.applicationIconBadgeNumber = 0
        if !AppDelegate.shared.launchedByPushAction {
            remoteNotificationUsername = sender
        }
    }
    
    private func login(success: @escaping (()->Void), fail: @escaping (()->Void)) {
        
        if let username = manager?.myName,
           let data = UserDefaults(suiteName: groupName)?.value(forKey: userInfoKey) as? Data,
           let saved = try? JSONDecoder().decode([AccountInfo].self, from: data),
           let first = saved.first(where: { $0.username == username }) {
            manager?.loginAndConnect(username: username, password: first.password) { _success in
                if _success {
                    success()
                } else {
                    fail()
                }
            }
        }
    }
    
    func prepareVoiceChat(caller: String, uuid: UUID) {
        if #available(iOS 13, *) {
            manager?.commonWebSocket.pingWithResult { [self] success in
                if !success {
                    login {
                    } fail: {
                        if let call = (sceneDelegate as? SceneDelegate)?.callManager.callWithUUID(uuid) {
                            (sceneDelegate as? SceneDelegate)?.callManager.end(call: call)
                        }
                    }
                }
            }
        }
    }
    
    func processReplyAction(replyContent: String) {
        if !self.nowPushInfo.sender.isEmpty {
            let receiver = nowPushInfo.sender
            httpMessage.sendText(replyContent, to: receiver, userID: nowPushInfo.senderID) { [weak self] success, _ in
                if success {
                    print("快捷回复成功")
                } else {
                    print("快捷回复失败")
                }
                self?.actionCompletionHandler?()
                self?.actionCompletionHandler = nil
            }
        }
    }
    
    static func checkRevokeMessages() {
        if let data = UserDefaults(suiteName: groupName)?.value(forKey: "revokedMessages") as? Data,
           let revokes = try? JSONDecoder().decode([RemoteMessage].self, from: data) {
            NotificationCenter.default.post(name: .revokeMessage, object: revokes)
            UserDefaults(suiteName: groupName)?.set(nil, forKey: "revokedMessages")
        }
    }
    
}
