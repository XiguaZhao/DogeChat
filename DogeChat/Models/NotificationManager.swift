//
//  Notification.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/16.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class NotificationManager: NSObject {
    
    let manager = WebSocketManager.shared
    static let shared = NotificationManager()
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
    }
    
    public func processRemoteNotification(_ notification: [String: AnyObject]) {
        guard let alert = notification["alert"] as? [String: AnyObject],
              let sender = alert["title"] as? String,
              let _ = alert["body"] as? String else { return }
        remoteNotificationUsername = sender
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    
    func prepareVoiceChat(caller: String, uuid: UUID) {
        guard let username = UserDefaults.standard.value(forKey: "lastUsername") as? String,
              let password = UserDefaults.standard.value(forKey: "lastPassword") as? String else { return }
        manager.login(username: username, password: password) { (result) in
            guard result == "登录成功" else {
                if let call = AppDelegate.shared.callManager.callWithUUID(uuid) {
                    AppDelegate.shared.callManager.end(call: call)
                }
                return
            }
            self.manager.connect()
        }
    }
    
}
