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
import UserNotifications
import Intents

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    static var usernameToDelegate = [String : SceneDelegate]()
    
    var window: UIWindow?
    var pushWindow: FloatWindow!
    var callWindow: FloatWindow!
    var switcherWindow: FloatWindow!

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
    var launchedByPushAction = false
    var lastAppEnterBackgroundTime = NSDate().timeIntervalSince1970
    static let reachability = try! Reachability()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("willConnect")
        setupWindows()
        loginWithSession(session, options: connectionOptions)
        setupReachability()
    }
    
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        return scene.userActivity
    }
    
    func setupWindows() {
        window?.backgroundColor = .systemBackground
        splitVC.view.backgroundColor = .systemBackground
        pushWindow = FloatWindow(type: .push, alwayDisplayType: .shouldDismiss, delegate: self)
        callWindow = FloatWindow(type: .alwaysDisplay, alwayDisplayType: .shouldDismiss, delegate: self)
        switcherWindow = FloatWindow(type: .alwaysDisplay, alwayDisplayType: .shouldNotDimiss, delegate: self)
        pushWindow.windowScene = window?.windowScene
        callWindow.windowScene = window?.windowScene
        switcherWindow.windowScene = window?.windowScene
        AppDelegate.shared.callWindow = callWindow
        AppDelegate.shared.pushWindow = pushWindow
        AppDelegate.shared.switcherWindow = switcherWindow
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
        socket.messageManager.myName = username
        self.socketManager = socket
        self.socketAdapter = adapter
        socket.messageManager.encrypt = EncryptMessage()
        let contactVC = self.makeContactVC(for: username)
        contactVC.password = password
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
        UserDefaults(suiteName: "group.demo.zhaoxiguang")?.set(false, forKey: "hostActive")
        lastAppEnterBackgroundTime = NSDate().timeIntervalSince1970
        guard !AppDelegate.shared.callManager.hasCall() else { return }
        if let socket = self.socketManager {
            socket.disconnect()
            socket.commonWebSocket.invalidatePingTimer()
        }
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if AppDelegate.shared.callManager.hasCall() { return }
        guard let intent = userActivity.interaction?.intent as? INStartAudioCallIntent,
              let name = intent.contacts?.first?.personHandle?.value else { return }
        let uuid = UUID().uuidString
        socketManager.tapFromSystemPhoneInfo = (name, uuid)
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        print("enter foreground")
        UserDefaults(suiteName: "group.demo.zhaoxiguang")?.set(true, forKey: "hostActive")
        UIApplication.shared.applicationIconBadgeNumber = 0
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        processReloginOrReConnect()
    }
    
    func processReloginOrReConnect() {
        guard let socketManager = self.socketManager else { return }
        DispatchQueue.global().async {
            socketManager.commonWebSocket.sortMessages()
        }
        if AppDelegate.shared.callManager.hasCall() {
            return
        }
        self.contactVC?.loginAndConnect()
    }
    
    func setupReachability() {
        Self.reachability.whenReachable = { [self] reachable in
            guard let socket = self.socketManager else { return }
            socket.commonWebSocket.pingWithResult { success in
                if !success {
                    if !socket.messageManager.isLogin {
                        contactVC?.loginAndConnect()
                    } else {
                        socket.connect()
                    }
                }
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

@available(iOS 13.0, *)
extension SceneDelegate: FloatWindowTouchDelegate {
    
    func tapPush(_ window: FloatWindow!, sender: String, content: String) {
        self.tabbarController.selectedViewController = navigationController
        if let contactVC = navigationController.viewControllers.first as? ContactsTableViewController,
           let index = contactVC.usernames.firstIndex(of: sender) {
            contactVC.tableView(contactVC.tableView, didSelectRowAt: IndexPath(row: index, section: 0))
        }
    }
    
    func tapAlwaysDisplay(_ window: FloatWindow!, name: String) {
        if window.alwayDisplayType == .shouldDismiss {
            adapterFor(username: username).readyToSendVideoData = false
            Recorder.sharedInstance().needSendVideo = false
            guard let call = AppDelegate.shared.callManager.callWithUUID(socketManager.nowCallUUID) else { return }
            call.end()
            AppDelegate.shared.callManager.end(call: call)
            #if !targetEnvironment(macCatalyst)
            if let videoVC = self.navigationController.visibleViewController as? VideoChatViewController {
                videoVC.dismiss()
            }
            #endif
            socketManager.nowCallUUID = nil
            switcherWindow.isHidden = true
        } else {
            if Recorder.sharedInstance().nowRoute == .headphone {
                Recorder.sharedInstance().setRouteToOption(.speaker)
            } else {
                Recorder.sharedInstance().setRouteToOption(.headphone)
            }
        }
    }

}
