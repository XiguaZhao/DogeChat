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
    
    var username = ""
    var manager: WebSocketManager! {
        return WebSocketManager.usersToSocketManager[username]
    }
    static let shared = NotificationManager()
    var nowPushInfo: (sender: String, content: String) = ("", "")
    var actionCompletionHandler: (() -> Void)?
    var quickReplyMessage: Message?
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
    
    convenience init(username: String) {
        self.init()
        self.username = username
    }
    
    private override init() {
        super.init()
        registerNoti()
    }
    
    func registerNoti() {
        NotificationCenter.default.addObserver(self, selector: #selector(quickReplyDone(_:)), name: .quickReplyDone, object: nil)
    }
    
    func nav() -> UINavigationController? {
        if #available(iOS 13, *) {
            return SceneDelegate.usernameToDelegate[username]?.navigationController
        } else {
            return AppDelegate.shared.navigationController
        }
    }
    
    @objc func quickReplyDone(_ noti: Notification) {
        manager.disconnect()
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
              let content = alert["body"] as? String else { return }
        nowPushInfo = (sender, content)
        UIApplication.shared.applicationIconBadgeNumber = 0
        if !AppDelegate.shared.launchedByPushAction {
            remoteNotificationUsername = sender
        }
    }
    
    private func login(success: @escaping (()->Void), fail: @escaping (()->Void)) {
        guard let info = UserDefaults.standard.value(forKey: usernameToPswKey) as? [String : String],
              let password = info[username] else { return }
        manager.messageManager.login(username: username, password: password) { (result) in
            guard result == "登录成功" else {
                fail()
                return
            }
            success()
        }
    }
    
    func prepareVoiceChat(caller: String, uuid: UUID) {
        manager.pingWithResult { [self] success in
            if !success {
                login {
                    self.manager.connect()
                } fail: {
                    if let call = AppDelegate.shared.callManager.callWithUUID(uuid) {
                        AppDelegate.shared.callManager.end(call: call)
                    }
                }
            }
        }

    }
    
    func processReplyAction(replyContent: String) {
        login { [weak self] in
            guard let self = self, self.nowPushInfo.sender.count != 0 else { return }
            let option: MessageOption = self.nowPushInfo.sender == "群聊" ? .toAll : .toOne
            let message = Message(message: replyContent, imageURL: nil, videoURL: nil, messageSender: .ourself, receiver: self.nowPushInfo.sender, uuid: UUID().uuidString, sender: self.manager.messageManager.myName, messageType: .text, option: option, id: .max, sendStatus: .fail, emojisInfo: [])
            self.quickReplyMessage = message
            self.manager.quickReplyUUID = message.uuid
            self.manager.connect()
            self.manager.messageManager.notSendContent.append(message)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if !self.manager.quickReplyUUID.isEmpty {
                    self.actionCompletionHandler?()
                    self.actionCompletionHandler = nil
                }
            }
        } fail: {
            
        }

    }
    
}
