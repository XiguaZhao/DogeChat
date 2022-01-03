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

class AppDelegateUI {
    
    static let shared = AppDelegateUI()
    
    var username = ""
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
            contactVC.setUsername(accountInfo.username, andPassword: accountInfo.password)
            MediaLoader.shared.cookie = accountInfo.cookieInfo?.cookie
            contactVC.loginAndConnect()
            WebSocketManager.shared.httpsManager.accountInfo = accountInfo
            navController.setViewControllers([contactVC], animated: true)
        } else {
            makeLogininVC()
        }
    }
    
    func makeLogininVC() {
        self.navController.setViewControllers([JoinChatViewController()], animated: true)
    }
    
}
