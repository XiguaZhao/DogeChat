//
//  SceneDelegate.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/9/7.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatNetwork
import DogeChatUniversal
import RSAiOSWatchOS
import Reachability
import UserNotifications
import Intents

enum SceneState {
    case none
    case restoreUserActivity
    case autoLoginWhenOneScene
    case handoff
    case shortcut
    case siri
}

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    static var usernameToDelegate = [String : SceneDelegate]()
    
    static var activeUserActivity: NSUserActivity? 

    var window: UIWindow?
    var pushWindow: FloatWindow!
    var callWindow: FloatWindow!
    var switcherWindow: FloatWindow!
    
    var state = SceneState.none
    
    weak var navigationController: UINavigationController!
    
    weak var splitVC: UISplitViewController! {
        return window?.rootViewController as? UISplitViewController
    }
    
    var tabbarController: UITabBarController! {
        return splitVC.viewControllers[0] as? UITabBarController
    }
    
    weak var contactVC: ContactsTableViewController?
    var tapFromSystemPhoneInfo: (name: String, uuid: String)?

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
    
    deinit {
        print("SceneDelegate Deinit")
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("willConnect")
        setupWindows()
        setupNoti()
        loginWithSession(session, scene: scene, options: connectionOptions)
    }
    
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        return scene.userActivity
    }
    
    func setupWindows() {
        window?.backgroundColor = .systemBackground
        pushWindow = FloatWindow(type: .push, alwayDisplayType: .shouldDismiss, delegate: self)
        callWindow = FloatWindow(type: .alwaysDisplay, alwayDisplayType: .shouldDismiss, delegate: self)
        switcherWindow = FloatWindow(type: .alwaysDisplay, alwayDisplayType: .shouldNotDimiss, delegate: self)
        pushWindow.windowScene = window?.windowScene
        callWindow.windowScene = window?.windowScene
        switcherWindow.windowScene = window?.windowScene
        AppDelegate.shared.callWindow = callWindow
        AppDelegate.shared.pushWindow = pushWindow
        AppDelegate.shared.switcherWindow = switcherWindow
        
        if #available(iOS 14, *) {} else {
            tabbarController.viewControllers![1].tabBarItem.image = UIImage(named: "music")
        }
    }
    
    func setupNoti() {
        NotificationCenter.default.addObserver(forName: .connected, object: username, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if let (name, uuid) = self.tapFromSystemPhoneInfo {
                self.socketManager.commonWebSocket.sendCallRequst(to: name, uuid: uuid)
                NotificationCenter.default.post(name: .startCall, object: self.username, userInfo: ["name": name, "uuid": uuid])
                self.tapFromSystemPhoneInfo = nil
            }
        }
    }
    
    func loginWithSession(_ session: UISceneSession, scene: UIScene, options: UIScene.ConnectionOptions) {
        if let handOff = options.handoffUserActivityType, handOff == "com.zhaoxiguang.dogechat" {
            state = .handoff
            return
        } else if let siriActivity = options.userActivities.first, siriActivity.activityType == "INSendMessageIntent" {
            state = .siri
            self.scene(scene, continue: siriActivity)
            return
        } else if let userActivity = options.userActivities.first { // 支持多窗口的设备打开的
            if let username = userActivity.userInfo?["username"] as? String,
               let password = userActivity.userInfo?["password"] as? String {
                login(username: username, password: password)
                processReloginOrReConnect()
                state = .handoff
            }
            return
        } else if let shortcutItemInfo = options.shortcutItem?.userInfo {
            if let username = shortcutItemInfo["username"] as? String, let password = shortcutItemInfo["password"] as? String {
                login(username: username, password: password)
                processReloginOrReConnect()
                state = .shortcut
            }
        } else if let restoreUserActivity = session.stateRestorationActivity, restoreUserActivity.title == "dogechat" {
            if let username = restoreUserActivity.userInfo?["username"] as? String,
               let password = restoreUserActivity.userInfo?["password"] as? String {
                login(username: username, password: password)
                processReloginOrReConnect()
                state = .restoreUserActivity
            }
            return
        } else if UIApplication.shared.openSessions.count == 1,
                  let username = UserDefaults.standard.value(forKey: "lastUsername") as? String,
                  let password = UserDefaults.standard.value(forKey: "lastPassword") as? String {
            login(username: username, password: password)
            processReloginOrReConnect()
            state = .autoLoginWhenOneScene
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
        socket.myInfo.username = username
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
        navigationController.setViewControllers([vc], animated: false)
        return vc
    }
    
    func makeLoginPage() -> JoinChatViewController {
        let vc = JoinChatViewController()
        navigationController = tabbarController.viewControllers![0] as? UINavigationController
        navigationController.setViewControllers([vc], animated: false)
        return vc
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        removeSocketForUsername(username)
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        
    }
    //3
    func scene(_ scene: UIScene, restoreInteractionStateWith stateRestorationActivity: NSUserActivity) {
    }
    //1
    func scene(_ scene: UIScene, willContinueUserActivityWithType userActivityType: String) {
    }
        
    func sceneDidEnterBackground(_ scene: UIScene) {
        launchedByPushAction = false
        AppDelegate.shared.checkIfShouldRemoveCache()
        print("enter background")
        UserDefaults(suiteName: "group.demo.zhaoxiguang")?.set(false, forKey: "hostActive")
        lastAppEnterBackgroundTime = NSDate().timeIntervalSince1970
        guard !AppDelegate.shared.callManager.hasCall() else { return }
        if let socket = self.socketManager {
            socket.disconnect()
        }
    }
    //4
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if AppDelegate.shared.callManager.hasCall() { return }
        if let intent = userActivity.interaction?.intent as? INStartAudioCallIntent,
              let name = intent.contacts?.first?.personHandle?.value {
            let uuid = UUID().uuidString
            tapFromSystemPhoneInfo = (name, uuid)
        } else if userActivity.title == "ChatRoom" {
            Self.activeUserActivity = userActivity
            if let username = userActivity.userInfo?["username"] as? String,
               let password = userActivity.userInfo?["password"] as? String {
                openNewSceneFor(username: username, password: password, userActivity: userActivity)
            }
        }
    }
    
    func openNewSceneFor(username: String, password: String, userActivity: NSUserActivity) {
        if SceneDelegate.usernameToDelegate[username] == nil  {
            if !UIApplication.shared.supportsMultipleScenes || self.socketManager == nil {
                for socket in WebSocketManager.usersToSocketManager.values {
                    socket.disconnect()
                }
                login(username: username, password: password)
                processReloginOrReConnect()
            } else {
                UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: nil, errorHandler: nil)
            }
        } else {
            SceneDelegate.usernameToDelegate[username]?.contactVC?.processUserActivity()
        }
    }
    //2
    func sceneWillEnterForeground(_ scene: UIScene) {
        print("enter foreground")
        UserDefaults(suiteName: "group.demo.zhaoxiguang")?.set(true, forKey: "hostActive")
        UIApplication.shared.applicationIconBadgeNumber = 0
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        guard state == .none else {
            state = .none
            return
        }
        self.processReloginOrReConnect()
    }
    
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if let userInfo = shortcutItem.userInfo,
           let username = userInfo["username"] as? String,
           let password = userInfo["password"] as? String {
            let userActivity = NSUserActivity(activityType: "com.zhaoxiguang.dogechat")
            userActivity.title = "shortcut"
            userActivity.userInfo = ["username": username, "password": password]
            openNewSceneFor(username: username, password: password, userActivity: userActivity)
        }
    }
        
    func processReloginOrReConnect() {
        guard let socketManager = self.socketManager else { return }
        DispatchQueue.global().async {
            socketManager.commonWebSocket.sortMessages()
        }
        if AppDelegate.shared.callManager.hasCall() {
            return
        }
        if needRelogin() {
            self.contactVC?.loginAndConnect()
        } else {
            socketManager.commonWebSocket.connect()
        }
    }
    
    func needRelogin() -> Bool {
        guard let socketManager = self.socketManager else { return true }
        let nowTime = Date().timeIntervalSince1970
        return nowTime - socketManager.httpsManager.cookieTime >= 2 * 24 * 60 * 60 // 2天
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
            switcherWindow.isHidden = true
            adapterFor(username: username).readyToSendVideoData = false
            Recorder.sharedInstance().needSendVideo = false
            guard let nowCallUUID = socketManager.nowCallUUID, let call = AppDelegate.shared.callManager.callWithUUID(nowCallUUID) else { return }
            call.end()
            AppDelegate.shared.callManager.end(call: call)
            #if !targetEnvironment(macCatalyst)
            if let videoVC = self.navigationController.visibleViewController as? VideoChatViewController {
                videoVC.dismiss()
            }
            #endif
            socketManager.nowCallUUID = nil
        } else {
            if Recorder.sharedInstance().nowRoute == .headphone {
                Recorder.sharedInstance().setRouteToOption(.speaker)
            } else {
                Recorder.sharedInstance().setRouteToOption(.headphone)
            }
        }
    }

}
