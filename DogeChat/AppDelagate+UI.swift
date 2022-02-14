//
//  AppDelagate+UI.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/2.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatUniversal
import DogeChatNetwork
import RSAiOSWatchOS
import DogeChatCommonDefines

protocol RemoteNotificationDelegate: AnyObject {
    func shouldPresentRemoteNotification(_ infos: [String : Any]) -> Bool
    func quickReply(_ infos: [String : Any], input: String) -> Bool
}

class AppDelegateUI {
    
    static let shared = AppDelegateUI()
    
    var username: String {
        WebSocketManager.shared.myName
    }
    weak var tabBarController: UITabBarController! {
        return splitVC.viewControllers.first as? UITabBarController
    }
    weak var splitVC: UISplitViewController!
    weak var navController: UINavigationController!
    weak var contactVC: ContactsTableViewController!
    
    func makeWindow() {
        AppDelegate.shared.window = UIWindow(frame: UIScreen.main.bounds)
        let window = AppDelegate.shared.window
        self.splitVC = UIStoryboard(name: "main", bundle: .main).instantiateInitialViewController() as? UISplitViewController
        window?.rootViewController = self.splitVC
        self.navController = tabBarController.viewControllers?.first as? UINavigationController
        tabBarController.viewControllers?[1].tabBarItem.image = UIImage(named: "music")
        WebSocketManager.shared.messageManager.encrypt = EncryptMessage()
        if let username = UserDefaults(suiteName: groupName)?.value(forKey: "sharedUsername") as? String, let accountInfo = accountInfo(username: username) {
            let contactVC = ContactsTableViewController()
            self.contactVC = contactVC
            if let userID = accountInfo.userID, let friends = getContacts(userID: userID) {
                contactVC.friends = friends
            }
            contactVC.setUsername(accountInfo.username, andPassword: accountInfo.password)
            MediaLoader.shared.cookie = accountInfo.cookieInfo?.cookie
            contactVC.loginAndConnect()
            WebSocketManager.shared.httpsManager.accountInfo = accountInfo
            navController.setViewControllers([contactVC], animated: true)
        } else {
            makeLogininVC()
        }
        NotificationCenter.default.addObserver(forName: .logined, object: nil, queue: .main) { noti in
            MediaLoader.shared.cookie = noti.userInfo?["cookie"] as? String
        }
    }
    
    func makeLogininVC() {
        self.navController.setViewControllers([JoinChatViewController()], animated: true)
    }
    
    func enterBackground() {
        let userID = WebSocketManager.shared.httpsManager.accountInfo.userID
        if let friends = self.contactVC?.friends, let userID = userID, !userID.isEmpty {
            saveFriendsToDisk(friends, userID: userID)
        }
        WebSocketManager.shared.disconnect()
        MediaLoader.shared.checkIfShouldRemoveCache()
    }
    
    func resignActive() {
        UserDefaults.standard.set(WebSocketManager.shared.messageManager.maxId, forKey: "maxID")
    }
    
    func enterForeground() {
        NotificationManager.checkRevokeMessages()
        if let cookie = WebSocketManager.shared.httpsManager.accountInfo.cookieInfo, !cookie.isValid {
            NotificationCenter.default.post(name: .cookieExpire, object: username)
            return
        }
        if !WebSocketManager.shared.connected {
            contactVC?.loginAndConnect()
        }

    }
    
}
