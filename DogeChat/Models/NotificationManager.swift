//
//  Notification.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/16.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class NotificationManager: NSObject {
    
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
    
    var voipUsername = ""
    
}
