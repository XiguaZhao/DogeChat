//
//  SceneDelegate.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/9/7.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatNetwork
import DogeChatUniversal
import RSAiOSWatchOS

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    static var count = 0
    
    var window: UIWindow?
    
    var navigationController: UINavigationController!
    
    var splitVC: UISplitViewController! {
        return window?.rootViewController as? UISplitViewController
    }
    let splitVCDelegate = SplitViewControllerDelegate()
    
    var tabbarController: UITabBarController! {
        return splitVC.viewControllers[0] as? UITabBarController
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        SceneDelegate.count += 1
        loginWithSession(session, options: connectionOptions)
    }
    
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        return scene.userActivity
    }
    
    func loginWithSession(_ session: UISceneSession, options: UIScene.ConnectionOptions) {
        if let userActivity = options.userActivities.first ?? session.stateRestorationActivity,
           let username = userActivity.userInfo?["username"] as? String,
           let password = userActivity.userInfo?["password"] as? String {
            let socket = WebSocketManager()
            let adapter = WebSocketManagerAdapter(manager: socket, username: username)
            WebSocketManager.shared.usersToSocketManager[username] = socket
            WebSocketManagerAdapter.shared.usernameToAdapter[username] = adapter
            adapter.sceneDelegate = self
            socket.messageManager.encrypt = EncryptMessage()
            let contactVC = self.makeContactVC(for: username)
            contactVC.password = password
            socket.messageManager.login(username: username, password: password) { res in
                guard res == "登录成功" else { return }
                contactVC.refreshContacts {
                    socket.connect()
                }
            }
        } else {
            _ = makeLoginPage()
        }
        
    }
    
    func makeContactVC(for username: String) -> ContactsTableViewController {
        let vc = ContactsTableViewController()
        vc.username = username
        navigationController = tabbarController.viewControllers![0] as? UINavigationController
        navigationController.pushViewController(vc, animated: false)
        return vc
    }
    
    func makeLoginPage() -> JoinChatViewController {
        let vc = JoinChatViewController()
        navigationController = tabbarController.viewControllers![0] as? UINavigationController
        navigationController.pushViewController(vc, animated: false)
        return vc
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        
    }
    

}

