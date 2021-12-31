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

struct RemoteNotificationInfo {
    var sender: String?
    var senderID: String?
    var content: String?
    var receiverID: String?
    var receiver: String?
}

class NotificationManager: NSObject {
    
    weak var sceneDelegate: SceneDelegate?
    var manager: WebSocketManager? {
        sceneDelegate?.socketManager
    }
    var nowPushInfo: (sender: String, content: String, senderID: String) = ("", "", "")
    var actionCompletionHandler: (() -> Void)?
    var quickReplyMessage: Message?
    var remoteNotificationUsername = ""
    let httpMessage = HttpMessage()
    
    override init() {
        super.init()
        registerNoti()
    }
    
    func registerNoti() {
        NotificationCenter.default.addObserver(self, selector: #selector(quickReplyDone(_:)), name: .quickReplyDone, object: nil)
    }
    
    func nav() -> UINavigationController? {
        return sceneDelegate?.navigationController
    }
    
    @objc func quickReplyDone(_ noti: Notification) {
        sceneDelegate?.socketManager.disconnect()
        if let vc = nav()?.visibleViewController as? ChatRoomViewController {
            if let message = quickReplyMessage {
                vc.insertNewMessageCell([message])
            }
        }
        actionCompletionHandler?()
        actionCompletionHandler = nil
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
        
        if let username = sceneDelegate?.username,
           let data = UserDefaults(suiteName: groupName)?.value(forKey: userInfoKey) as? Data,
           let saved = try? JSONDecoder().decode([AccountInfo].self, from: data),
           let first = saved.first(where: { $0.username == username }) {
            sceneDelegate?.socketManager?.loginAndConnect(username: username, password: first.password) { _success in
                if _success {
                    success()
                } else {
                    fail()
                }
            }
        }
    }
    
    func prepareVoiceChat(caller: String, uuid: UUID) {
        sceneDelegate?.socketManager?.commonWebSocket.pingWithResult { [self] success in
            if !success {
                login {
                } fail: {
                    if let call = sceneDelegate?.callManager.callWithUUID(uuid) {
                        sceneDelegate!.callManager.end(call: call)
                    }
                }
            }
        }

    }
    
    func processReplyAction(replyContent: String) {
        if !self.nowPushInfo.sender.isEmpty {
            let receiver = nowPushInfo.sender
            httpMessage.sendText(replyContent, to: receiver) { [weak self] success, _ in
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
    
}
