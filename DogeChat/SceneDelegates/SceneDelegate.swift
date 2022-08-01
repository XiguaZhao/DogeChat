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
import UserNotifications
import Intents
import DogeChatCommonDefines

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
    
    static let lock = NSLock()
    static var usernameToDelegate = [String : SceneDelegate]()
    
    static var activeUserActivity: NSUserActivity?
    static var userActivityModal: UserActivityModal?

    weak var session: UISceneSession?
    weak var scene: UIScene?
    
    var window: UIWindow?
    var pushWindow: FloatWindow!
    var callWindow: FloatWindow!
    var switcherWindow: FloatWindow!
    
    var notificationManager = NotificationManager()
    var providerDelegate: ProviderDelegate!
    let callManager = CallManager()
    var accountInfo: AccountInfo? {
        didSet {
            if let _userID = accountInfo?.userID, !_userID.isEmpty {
                userID = _userID
            }
        }
    }

    var state = SceneState.none
    
    weak var navigationController: UINavigationController!
    
    weak var splitVC: UISplitViewController! {
        return window?.rootViewController as? UISplitViewController
    }
    
    weak var tabbarController: UITabBarController! {
        return splitVC.viewControllers[0] as? UITabBarController
    }
    
    weak var contactVC: ContactsTableViewController?
    var tapFromSystemPhoneInfo: (name: String, uuid: String)?

    var username = ""
    private var password: String?
    var socketManager: WebSocketManager! {
        didSet {
            accountInfo = nil
        }
    }
    var socketAdapter: WebSocketManagerAdapter! {
        didSet {
            socketAdapter.sceneDelegate = self
        }
    }
    var launchedByPushAction = false
    var lastAppEnterBackgroundTime = NSDate().timeIntervalSince1970
    
    deinit {
        print("SceneDelegate Deinit")
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("willConnect")
        self.session = session
        self.scene = scene
        notificationManager.sceneDelegate = self
        providerDelegate = ProviderDelegate(callManager: callManager)
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
        [pushWindow, callWindow, switcherWindow].forEach { $0?.nestedVC.targetView = window }
        callWindow.windowScene = window?.windowScene
        switcherWindow.windowScene = window?.windowScene
        
        if #available(iOS 14, *) {} else {
            tabbarController.viewControllers![1].tabBarItem.image = UIImage(named: "music")
        }
        if let windowScene = scene as? UIWindowScene {
            windowScene.sizeRestrictions?.maximumSize = CGSize(width: 900, height: 1000)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                windowScene.sizeRestrictions?.maximumSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            }
        }
#if TARGET_OS_UIKITFORMAC || targetEnvironment(macCatalyst)
        if let titleBar = window?.windowScene?.titlebar {
            titleBar.titleVisibility = .hidden
            titleBar.toolbar = nil
        }
#endif
    }
    
    func setupNoti() {
        NotificationCenter.default.addObserver(forName: .connected, object: username, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if let (name, uuid) = self.tapFromSystemPhoneInfo {
                self.socketManager.commonWebSocket.sendCallRequst(to: name, uuid: uuid)
                self.socketManager.nowCallUUID = UUID(uuidString: uuid)
                NotificationCenter.default.post(name: .startCall, object: self.username, userInfo: ["name": name, "uuid": uuid])
                self.tapFromSystemPhoneInfo = nil
            }
        }
        NotificationCenter.default.addObserver(forName: .logined, object: nil, queue: .none) { noti in
            MediaLoader.shared.cookie = noti.userInfo?["cookie"] as? String
        }
    }
    
    func loginWithSession(_ session: UISceneSession, scene: UIScene, options: UIScene.ConnectionOptions) {
        if let handOff = options.handoffUserActivityType, handOff == userActivityID {
            state = .handoff
            return
        } else if let siriActivity = options.userActivities.first, siriActivity.activityType == "INSendMessageIntent" {
            state = .siri
            self.scene(scene, continue: siriActivity)
            return
        } else if let userActivity = options.userActivities.first { // 支持多窗口的设备打开的
            if let data = userActivity.userInfo?["data"] as? Data, let modal = try? JSONDecoder().decode(UserActivityModal.self, from: data) {
                let info = modal.accountInfo
                if login(username: info.username, password: info.password, cookie: info.cookieInfo?.cookie) {
                    processReloginOrReConnect()
                    state = .handoff
                } else {
                    makeLoginPage()
                }
            } else if let username = userActivity.userInfo?["username"] as? String,
                      let password = userActivity.userInfo?["password"] as? String {
                if login(username: username, password: password) {
                    processReloginOrReConnect()
                } else {
                    makeLoginPage()
                }
                state = .shortcut
            }

            return
        } else if #available(macCatalyst 14, *), let shortcutItemInfo = options.shortcutItem?.userInfo {
            if let username = shortcutItemInfo["username"] as? String {
                if login(username: username) {
                    processReloginOrReConnect()
                    state = .shortcut
                } else {
                    makeLoginPage()
                }
            }
        } else if let restoreUserActivity = session.stateRestorationActivity, restoreUserActivity.title == "dogechat" {
            if let username = restoreUserActivity.userInfo?["username"] as? String {
                if login(username: username) {
                    processReloginOrReConnect()
                    state = .restoreUserActivity
                } else {
                    makeLoginPage()
                }
            }
            return
        } else if UIApplication.shared.connectedScenes.count == 1,
                  let (username, _) = getUsernameAndPassword() {
            if login(username: username) {
                processReloginOrReConnect()
                state = .autoLoginWhenOneScene
            } else {
                makeLoginPage()
            }
        } else {
            makeLoginPage()
        }
    }
    
    func login(username: String, password: String? = nil, cookie: String? = nil) -> Bool {
        var isValid = false
        let socket = WebSocketManager()
        var accountInfo: AccountInfo?
        if let _accountInfo = DogeChatCommonDefines.accountInfo(username: username) {
            accountInfo = _accountInfo
            if let _password = _accountInfo.password, !_password.isEmpty {
                self.password = _password
                isValid = true
            }
            if let cookie = _accountInfo.cookieInfo, cookie.isValid {
                socket.httpsManager.accountInfo = _accountInfo
                MediaLoader.shared.cookie = cookie.cookie
                isValid = true
            }
        }
        if let password = password, !password.isEmpty {
            self.password = password
            isValid = true
        }
        
        if isValid {
            SceneDelegate.usernameToDelegate[username] = self
            setUsernameAndPassword(username, password)
            let adapter = WebSocketManagerAdapter(manager: socket, username: username)
            WebSocketManager.usersToSocketManager[username] = socket
            WebSocketManagerAdapter.usernameToAdapter[username] = adapter
            socket.myInfo.username = username
            self.socketManager = socket
            self.accountInfo = accountInfo
            self.socketAdapter = adapter
            socket.messageManager.encrypt = EncryptMessage()
            let contactVC = self.makeContactVC(for: username)
            contactVC.setUsername(username, andPassword: password)
            updateUsernames(username)
        }
        return isValid
    }
    
    func makeContactVC(for username: String) -> ContactsTableViewController {
        let vc = ContactsTableViewController()
        self.contactVC = vc
        vc.username = username
        self.socketManager.messageManager.messageDelegate = vc
        navigationController = tabbarController.viewControllers![0] as? UINavigationController
        navigationController.setViewControllers([vc], animated: false)
        return vc
    }
    
    @discardableResult
    func makeLoginPage() -> JoinChatViewController {
        let vc = JoinChatViewController()
        navigationController = tabbarController.viewControllers![0] as? UINavigationController
        navigationController.setViewControllers([vc], animated: false)
        return vc
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        removeSocketForUsername(username)
        for scene in UIApplication.shared.connectedScenes {
            if let chatRoomSceneDelegate = scene.delegate as? ChatRoomSceneDelegate, chatRoomSceneDelegate.username == self.username {
                let option = UIWindowSceneDestructionRequestOptions()
                option.windowDismissalAnimation = .commit
                UIApplication.shared.requestSceneSessionDestruction(scene.session, options: option, errorHandler: nil)
            }
        }
        if let friends = contactVC?.friends, !friends.isEmpty, let userID = self.socketManager?.myInfo.userID, !userID.isEmpty {
            saveFriendsToDisk(friends, userID: userID)
        }
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        if let maxID = socketManager?.messageManager.maxId {
            UserDefaults.standard.set(maxID, forKey: "maxID")
        }
    }
    //3
    func scene(_ scene: UIScene, restoreInteractionStateWith stateRestorationActivity: NSUserActivity) {
    }
    //1
    func scene(_ scene: UIScene, willContinueUserActivityWithType userActivityType: String) {
    }
    
    
        
    func sceneDidEnterBackground(_ scene: UIScene) {
        launchedByPushAction = false
        MediaLoader.shared.checkIfShouldRemoveCache()
        print("enter background")
        UserDefaults(suiteName: groupName)?.set(false, forKey: "hostActive")
        lastAppEnterBackgroundTime = NSDate().timeIntervalSince1970
        guard !callManager.hasCall() else { return }
        if let contactVC = contactVC, contactVC.findChatRoomVCs().filter({ $0.view.window?.windowScene?.delegate is ChatRoomSceneDelegate }).contains(where: { $0.username == self.username }) {
            return
        }
        if let socket = self.socketManager {
            if !isMac() {
                AppDelegate.shared.startBackgroundTask(socket: socket)
//                socket.disconnect()
            }
        }
        if let friends = self.contactVC?.friends, let userID = accountInfo?.userID {
            saveFriendsToDisk(friends, userID: userID)
        }
    }
    //4
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if callManager.hasCall() { return }
        if let intent = userActivity.interaction?.intent as? INStartCallIntent,
              let name = intent.contacts?.first?.personHandle?.value {
            let uuid = UUID().uuidString
            tapFromSystemPhoneInfo = (name, uuid)
        } else if userActivity.title == "ChatRoom" {
            if let data = userActivity.userInfo?["data"] as? Data, let modal = try? JSONDecoder().decode(UserActivityModal.self, from: data) {
                Self.activeUserActivity = userActivity
                Self.userActivityModal = modal
                openNewSceneFor(userActivityModal: modal, userActivity: userActivity, newSceneType: .none)
            }
        }
    }
    
    func openNewSceneFor(userActivityModal: UserActivityModal?, userActivity: NSUserActivity, newSceneType: SceneState) {
        var password: String?
        var username: String?
        if let accountInfo = userActivityModal?.accountInfo{
            username = accountInfo.username
            password = accountInfo.password
            updateAccountInfo(accountInfo)
        }
        if let _username = userActivity.userInfo?["username"] as? String {
            username = _username
        }
        if let _password = userActivity.userInfo?["password"] as? String {
            password = _password
        }

        guard let username = username else {
            return
        }
        if !UIApplication.shared.supportsMultipleScenes {
            SceneDelegate.usernameToDelegate.removeAll()
        }
        if SceneDelegate.usernameToDelegate[username] == nil  {
            if !UIApplication.shared.supportsMultipleScenes || self.socketManager == nil {
                for socket in WebSocketManager.usersToSocketManager.values {
                    socket.disconnect()
                }
                removeSocketForUsername(self.username)
                if login(username: username, password: password) {
                    processReloginOrReConnect()
                }
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
        NotificationManager.checkRevokeMessages()
        UserDefaults(suiteName: groupName)?.set(true, forKey: "hostActive")
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        guard state == .none else {
            state = .none
            return
        }
        self.processReloginOrReConnect()
    }
    
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if let userInfo = shortcutItem.userInfo,
           let username = userInfo["username"] as? String {
            let password = userInfo["password"] as? String
            let cookie = userInfo["cookie"] as? String
            let userActivity = NSUserActivity(activityType: userActivityID)
            userActivity.title = "shortcut"
            userActivity.userInfo = ["username": username,
                                     "password": password as Any,
                                     "cookie": cookie as Any]
            openNewSceneFor(userActivityModal: nil, userActivity: userActivity, newSceneType: .shortcut)
        }
    }
        
    func processReloginOrReConnect() {
        guard let socketManager = self.socketManager else { return }
        DispatchQueue.global().async {
            socketManager.commonWebSocket.sortMessages()
        }
        if callManager.hasCall() {
            return
        }
        if let contactVC = contactVC, contactVC.friends.isEmpty, let userID = self.accountInfo?.userID, let friends = getContacts(userID: userID) {
            contactVC.friends = friends
            socketManager.httpsManager.friends = friends
        }
        if let cookie = self.socketManager?.httpsManager.accountInfo.cookieInfo, !cookie.isValid {
            NotificationCenter.default.post(name: .cookieExpire, object: username)
            return
        }
        if !socketManager.connected {
            socketManager.commonWebSocket.loginAndConnect(username: username, password: password, needContact: (contactVC?.friends.isEmpty ?? true), completion: nil)
        } else {
            contactVC?.pingAndConnectIfNeeded()
        }
    }
    
    func needRelogin() -> Bool {
        guard let socketManager = self.socketManager else { return true }
        if let cookieInfo = self.accountInfo?.cookieInfo, cookieInfo.isValid {
            return false
        }
        let nowTime = Date().timeIntervalSince1970
        return nowTime - socketManager.httpsManager.cookieTime >= cookieDuration
    }
    
    func setUsernameAndPassword(_ username: String, _ password: String?) {
        self.password = password
        self.username = username
    }

}

@available(iOS 13.0, *)
extension SceneDelegate: FloatWindowTouchDelegate {
    
    func tapPush(_ window: FloatWindow!, sender: String, content: String) {
        self.tabbarController.selectedIndex = 0
        if let contactVC = self.contactVC, let friend = contactVC.friends.first(where: { $0.username == sender }) {
            contactVC.jumpToFriend(friend)
        }
    }
    
    func tapAlwaysDisplay(_ window: FloatWindow!, name: String) {
        if window.alwayDisplayType == .shouldDismiss {
            switcherWindow.isHidden = true
            adapterFor(username: username).readyToSendVideoData = false
            Recorder.sharedInstance().needSendVideo = false
            guard let nowCallUUID = socketManager.nowCallUUID, let call = callManager.callWithUUID(nowCallUUID) else { return }
            call.end()
            callManager.end(call: call)
            if let videoVC = self.navigationController.visibleViewController as? VideoChatViewController {
                videoVC.dismiss(animated: true)
            }
            socketManager.nowCallUUID = nil
            AppDelegate.shared.nowCallUUID = nil
        } else {
            if Recorder.sharedInstance().nowRoute == .headphone {
                Recorder.sharedInstance().setRouteToOption(.speaker)
            } else {
                Recorder.sharedInstance().setRouteToOption(.headphone)
            }
        }
    }

}
