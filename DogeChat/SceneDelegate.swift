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
import Reachability

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    static var usernameToDelegate = [String : SceneDelegate]()
    
    var window: UIWindow?
    
    var navigationController: UINavigationController!
    
    var splitVC: UISplitViewController! {
        return window?.rootViewController as? UISplitViewController
    }
    let splitVCDelegate = SplitViewControllerDelegate()
    
    var tabbarController: UITabBarController! {
        return splitVC.viewControllers[0] as? UITabBarController
    }
    
    weak var contactVC: ContactsTableViewController?
    
    var username = ""
    private var password = ""
    var socketManager: WebSocketManager!
    var socketAdapter: WebSocketManagerAdapter! {
        didSet {
            socketAdapter.sceneDelegate = self
        }
    }
    let callManager = CallManager()
    var launchedByPushAction = false
    var lastAppEnterBackgroundTime = NSDate().timeIntervalSince1970
    let reachability = try! Reachability()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        loginWithSession(session, options: connectionOptions)
        setupReachability()
    }
    
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        return scene.userActivity
    }
    
    func loginWithSession(_ session: UISceneSession, options: UIScene.ConnectionOptions) {
        if let userActivity = options.userActivities.first ?? session.stateRestorationActivity,
           let username = userActivity.userInfo?["username"] as? String,
           let password = userActivity.userInfo?["password"] as? String {
            login(username: username, password: password)
        } else if UIApplication.shared.openSessions.count == 1,
                  let username = UserDefaults.standard.value(forKey: "lastUsername") as? String,
                  let password = UserDefaults.standard.value(forKey: "lastPassword") as? String {
            login(username: username, password: password)
        } else {
            _ = makeLoginPage()
        }
        
    }
    
    func login(username: String, password: String) {
        SceneDelegate.usernameToDelegate[username] = self
        setUsernameAndPassword(username, password)
        AppDelegate.shared.username = username
        let socket = WebSocketManager()
        let adapter = WebSocketManagerAdapter(manager: socket, username: username)
        NotificationManager.shared.username = username
        WebSocketManager.usersToSocketManager[username] = socket
        WebSocketManagerAdapter.usernameToAdapter[username] = adapter
        adapter.registerNotification()
        socket.messageManager.myName = username
        self.socketManager = socket
        self.socketAdapter = adapter
        socket.messageManager.encrypt = EncryptMessage()
        let contactVC = self.makeContactVC(for: username)
        contactVC.password = password
        contactVC.downRefreshAction()
        if let playListVC = (tabbarController.viewControllers![1] as? UINavigationController)?.viewControllers.first as? PlayListViewController {
            playListVC.username = username
        }
        if let setting = (tabbarController.viewControllers![2] as? UINavigationController)?.viewControllers.first as? SettingViewController {
            setting.username = username
        }
        if !splitVC.isCollapsed {
            (splitVC.viewControllers[1] as? DogeChatNavigationController)?.username = username
        }
    }
    
    func makeContactVC(for username: String) -> ContactsTableViewController {
        let vc = ContactsTableViewController()
        self.contactVC = vc
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
        removeSocketForUsername(username)
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        launchedByPushAction = false
        print("enter background")
        lastAppEnterBackgroundTime = NSDate().timeIntervalSince1970
        guard !callManager.hasCall() else { return }
        if let socket = self.socketManager {
            socket.disconnect()
            socket.invalidatePingTimer()
        }
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        print("enter foreground")
        UIApplication.shared.applicationIconBadgeNumber = 0
        processReloginOrReConnect()
    }
    
    func processReloginOrReConnect() {
        guard let socketManager = self.socketManager else { return }
        DispatchQueue.global().async {
            socketManager.sortMessages()
        }
        let shouldReLogin = self.needRelogin()
        if !callManager.hasCall() {
            if socketManager.connected {
                socketManager.disconnect()
            }
            socketManager.connected = false
        }
        if shouldReLogin {
            self.contactVC?.downRefreshAction()
        }
        if (self.navigationController).topViewController?.title == "JoinChatVC" { return }
        guard !socketManager.cookie.isEmpty else {
            return
        }
        if !shouldReLogin && !socketManager.cookie.isEmpty {
            socketManager.connect()
        }
    }
    
    func setupReachability() {
        reachability.whenReachable = { [self] reachable in
            guard let socket = self.socketManager else { return }
            if !socket.messageManager.isLogin {
                contactVC?.downRefreshAction()
            } else {
                socket.connect()
            }
        }
    }

    func needRelogin() -> Bool {
        let nowTime = Date().timeIntervalSince1970
        return nowTime - lastAppEnterBackgroundTime >= 20 * 60
    }
    
    func setUsernameAndPassword(_ username: String, _ password: String) {
        self.password = password
        self.username = username
    }

}

