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

class NotificationManager: NSObject {
    
    weak var sceneDelegate: SceneDelegate?
    var manager: WebSocketManager? {
        sceneDelegate?.socketManager
    }
    
    var nowPushInfo: (sender: String, content: String, senderID: String) = ("", "", "")
    var actionCompletionHandler: (() -> Void)?
    var quickReplyMessage: Message?
    var remoteNotificationUsername = ""
        
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
        print("快捷回复完成，调用completionHandler")
    }

    public func processRemoteNotification(_ notification: [String: AnyObject]) {
        guard let alert = notification["alert"] as? [String: AnyObject],
              let sender = alert["title"] as? String,
              let content = alert["body"] as? String,
              let senderID = notification["senderId"] as? String else { return }
        nowPushInfo = (sender, content, senderID)
        UIApplication.shared.applicationIconBadgeNumber = 0
        if !AppDelegate.shared.launchedByPushAction {
            remoteNotificationUsername = sender
        }
    }
    
    private func login(success: @escaping (()->Void), fail: @escaping (()->Void)) {
        guard let username = sceneDelegate?.username, let info = UserDefaults.standard.value(forKey: usernameToPswKey) as? [String : String],
              let password = info[username] else { return }
        sceneDelegate?.socketManager?.loginAndConnect(username: username, password: password) { _success in
            if _success {
                success()
            } else {
                fail()
            }
        }
    }
    
    func prepareVoiceChat(caller: String, uuid: UUID) {
        sceneDelegate?.socketManager?.commonWebSocket.pingWithResult { [self] success in
            if !success {
                login {
                    self.sceneDelegate?.socketManager?.connect()
                } fail: {
                    if let call = sceneDelegate?.callManager.callWithUUID(uuid) {
                        sceneDelegate!.callManager.end(call: call)
                    }
                }
            }
        }

    }
    
    func processReplyAction(replyContent: String) {
        login { [self] in
            guard self.nowPushInfo.sender.count != 0, let manager = self.manager else { return }
            guard let friend = manager.messageManager.friends.first(where: { $0.userID == self.nowPushInfo.senderID }) else { return }
            let message = Message(message: replyContent, friend: friend, imageURL: nil, videoURL: nil, messageSender: .ourself, receiver: self.nowPushInfo.sender, receiverUserID: nowPushInfo.senderID, uuid: UUID().uuidString, sender: manager.messageManager.myName, senderUserID: manager.messageManager.myId, messageType: .text, sendStatus: .fail, emojisInfo: [])
            self.quickReplyMessage = message
            manager.quickReplyUUID = message.uuid
            manager.commonWebSocket.sendWrappedMessage(message)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if !manager.quickReplyUUID.isEmpty {
                    self.actionCompletionHandler?()
                    self.actionCompletionHandler = nil
                }
            }
        } fail: {
            
        }

    }
    
}
