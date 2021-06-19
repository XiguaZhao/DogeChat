//
//  Notification.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/16.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

import UIKit
import YPTransition
import DogeChatUniversal

class NotificationManager: NSObject {
    
    let manager = WebSocketManager.shared
    static let shared = NotificationManager()
    var nowPushInfo: (sender: String, content: String) = ("", "")
    var actionCompletionHandler: (() -> Void)?
    var remoteNotificationUsername = "" {
        didSet {
            if remoteNotificationUsername != "" {
                var contactVC: ContactsTableViewController?
                guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                      let nav = appDelegate.navigationController else { return }
                for vc in nav.viewControllers {
                    if vc.isKind(of: ContactsTableViewController.self) {
                        contactVC = (vc as! ContactsTableViewController)
                        break
                    }
                }
                guard let contactViewController = contactVC else { return }
                let success = contactViewController.loginSuccess
                contactViewController.loginSuccess = success
            }
        }
    }
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(quickReplyDone(_:)), name: .quickReplyDone, object: nil)
    }
    
    @objc func quickReplyDone(_ noti: Notification) {
        WebSocketManager.shared.disconnect()
        actionCompletionHandler?()
        actionCompletionHandler = nil
        print("快捷回复完成，调用completionHandler")
    }

    public func processRemoteNotification(_ notification: [String: AnyObject]) {
        guard let alert = notification["alert"] as? [String: AnyObject],
              let sender = alert["title"] as? String,
              let content = alert["body"] as? String else { return }
        nowPushInfo = (sender, content)
        UIApplication.shared.applicationIconBadgeNumber = 0
        if !AppDelegate.shared.launchedByPushAction {
            remoteNotificationUsername = sender
        }
    }
    
    private func login(success: @escaping (()->Void), fail: @escaping (()->Void)) {
        guard let username = UserDefaults.standard.value(forKey: "lastUsername") as? String,
              let password = UserDefaults.standard.value(forKey: "lastPassword") as? String else { return }
        manager.messageManager.login(username: username, password: password) { (result) in
            guard result == "登录成功" else {
                fail()
                return
            }
            success()
        }
    }
    
    func prepareVoiceChat(caller: String, uuid: UUID) {
        login {
            WebSocketManager.shared.connect()
        } fail: {
            if let call = AppDelegate.shared.callManager.callWithUUID(uuid) {
                AppDelegate.shared.callManager.end(call: call)
            }
        }

    }
    
    func processReplyAction(replyContent: String) {
        login { [weak self] in
            guard let self = self, self.nowPushInfo.sender.count != 0 else { return }
            let option: MessageOption = self.nowPushInfo.sender == "群聊" ? .toAll : .toOne
            let message = Message(message: replyContent, imageURL: nil, videoURL: nil, messageSender: .ourself, receiver: self.nowPushInfo.sender, uuid: UUID().uuidString, sender: WebSocketManager.shared.messageManager.myName, messageType: .text, option: option, id: .max, sendStatus: .fail, emojisInfo: [])
            WebSocketManager.shared.quickReplyUUID = message.uuid
            WebSocketManager.shared.connect()
            WebSocketManager.shared.messageManager.notSendContent.append(message)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if !WebSocketManager.shared.quickReplyUUID.isEmpty {
                    self.actionCompletionHandler?()
                    self.actionCompletionHandler = nil
                }
            }
        } fail: {
            
        }

    }
    
}
