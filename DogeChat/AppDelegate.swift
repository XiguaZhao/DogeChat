
import UIKit
import UserNotifications
import PushKit
import CallKit
import Intents
import DogeChatNetwork
import RSAiOSWatchOS
import DogeChatUniversal
import Reachability
import WatchConnectivity

@objc enum SplitVCSide: Int {
    case left, right
}

enum PushAction: String {
    case REPLY_ACTION
    case DO_NOT_DISTURT_ACTION
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    let reachability = try! Reachability()
    var pushWindow: FloatWindow!
    var callWindow: FloatWindow!
    var switcherWindow: FloatWindow!
    var deviceToken: String?
    var pushKitToken: String?
    var launchedByPushAction = false
    var backgroundSessionCompletionHandler: (() -> Void)?
    var notificationManager = NotificationManager.shared
    var socketManager: WebSocketManager! {
        return WebSocketManager.usersToSocketManager[username]
    }
    var username = "" {
        didSet {
            providerDelegate.username = username
        }
    }
    weak var navigationController: UINavigationController?
    var tabBarController: UITabBarController!
    var splitViewController: UISplitViewController!
    var providerDelegate: ProviderDelegate!
    let callManager = CallManager()
    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    var lastAppEnterBackgroundTime = NSDate().timeIntervalSince1970
    weak var contactVC: ContactsTableViewController?
    var isIOS = true
    let splitVCDelegate = SplitViewControllerDelegate()
    var lastUserInterfaceStyle: UIUserInterfaceStyle = .unspecified
    var immersive: Bool {
        fileURLAt(dirName: "customBlur", fileName: userID) != nil || (PlayerManager.shared.isPlaying && UserDefaults.standard.bool(forKey: "immersive"))
    }
    @objc var isForceDarkMode: Bool {
        UserDefaults.standard.bool(forKey: "forceDarkMode") && immersive
    }
    @objc class var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UserDefaults(suiteName: "group.demo.zhaoxiguang")?.set(true, forKey: "hostActive")
        registerPushAction()
        window = UIWindow(frame: UIScreen.main.bounds)
        if #available(iOS 13.0, *) {
            window?.backgroundColor = .systemBackground
        } else {
            window?.backgroundColor = .white
        }
        if UserDefaults.standard.value(forKey: "forceDarkMode") == nil {
            UserDefaults.standard.setValue(true, forKey: "forceDarkMode")
        }
        if #available(iOS 13, *) {
            for session in UIApplication.shared.openSessions {
                if session.stateRestorationActivity == nil {
                    UIApplication.shared.requestSceneSessionDestruction(session, options: nil, errorHandler: nil)
                }
            }
        } else {
            window?.rootViewController = UIStoryboard(name: "main", bundle: .main).instantiateInitialViewController() as? UISplitViewController
            splitViewController = window?.rootViewController as? UISplitViewController
            splitViewController.delegate = splitVCDelegate
            splitViewController.preferredDisplayMode = .allVisible
            tabBarController = splitViewController.viewControllers[0] as? UITabBarController
            window?.rootViewController = splitViewController
            splitViewController.preferredPrimaryColumnWidthFraction = 0.35
            splitViewController.view.backgroundColor = .clear
            window?.makeKeyAndVisible()
            pushWindow = FloatWindow(type: .push, alwayDisplayType: .shouldDismiss, delegate: self)
            callWindow = FloatWindow(type: .alwaysDisplay, alwayDisplayType: .shouldDismiss, delegate: self)
            switcherWindow = FloatWindow(type: .alwaysDisplay, alwayDisplayType: .shouldNotDimiss, delegate: self)
        }
        if #available(iOS 13, *) {} else {
            tabBarController.viewControllers![1].tabBarItem.image = UIImage(named: "music")
        }
        let notificationOptions = launchOptions?[.remoteNotification]
        if let notification = notificationOptions as? [String: AnyObject],
           let aps = notification["aps"] as? [String: AnyObject] {
            notificationManager.processRemoteNotification(aps)
        }
        
        registerNotification()
        voipRegistry.delegate = self
        if #available(macCatalyst 14.0, iOS 12.0, *) {
            voipRegistry.desiredPushTypes = [.voIP]
        }
        #if targetEnvironment(macCatalyst)
        isIOS = false
        #endif
        DispatchQueue.global().async {
            SelectShortcutTVC.updateShortcuts()
        }
        providerDelegate = ProviderDelegate(callManager: callManager, username: username)
        if #available(iOS 13.0, *) {
        } else {
            login()
        }
        if UserDefaults.standard.value(forKey: "immersive") == nil {
            UserDefaults.standard.setValue(true, forKey: "immersive")
        }
        WCSession.default.delegate = SessionDelegate.shared
        WCSession.default.activate()
        NotificationCenter.default.addObserver(forName: .backgroundSessionFinish, object: nil, queue: .main) { [weak self] _ in
            self?.backgroundSessionCompletionHandler?()
        }
        return true
    }
    
    func checkIfShouldRemoveCache() {
        DispatchQueue.main.async {
            let size = MediaLoader.shared.cacheSize.values.reduce(0, +)
            if size / 1024 / 1024 > 50 {
                let average = size / MediaLoader.shared.cache.count
                for (cacheKey, size) in MediaLoader.shared.cacheSize {
                    if size > average {
                        MediaLoader.shared.cache.removeValue(forKey: cacheKey)
                        MediaLoader.shared.cacheSize.removeValue(forKey: cacheKey)
                    }
                }
            }
        }
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        UserDefaults(suiteName: "group.demo.zhaoxiguang")?.set(false, forKey: "hostActive")
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
        
    private func sizeFor(side: SplitVCSide, username: String?, view: UIView? = nil) -> CGSize {
        let splitViewController: UISplitViewController
        if #available(iOS 13.0, *) {
            if let username = username, !username.isEmpty {
                splitViewController = (SceneDelegate.usernameToDelegate[username]?.splitVC)!
            } else if let splitVC = view?.window?.rootViewController as? DogeChatSplitViewController {
                splitViewController = splitVC
            } else {
                return UIScreen.main.bounds.size
            }
        } else {
            splitViewController = self.splitViewController
        }
        let height = splitViewController.view.bounds.height
        if splitViewController.isCollapsed {
            return splitViewController.view.bounds.size
        } else {
            let ratio = splitViewController.preferredPrimaryColumnWidthFraction
            switch side {
            case .left:
                return CGSize(width:ratio * splitViewController.view.bounds.size.width, height: height)
            case .right:
                return CGSize(width: (1 - ratio) * splitViewController.view.bounds.width, height: height)
            }
        }
    }
    
    @objc func widthFor(side: SplitVCSide, username: String?) -> CGFloat {
        return sizeFor(side: side, username: username).width
    }
    
    @objc func heightFor(side: SplitVCSide, username: String?) -> CGFloat {
        return sizeFor(side: side, username: username).height
    }
    
    func login() {
        self.navigationController = self.tabBarController.viewControllers?.first as? UINavigationController
        if let username = UserDefaults.standard.value(forKey: "lastUsername") as? String,
           let password = UserDefaults.standard.value(forKey: "lastPassword") as? String {
            self.username = username
            let socket = WebSocketManager()
            let adapter = WebSocketManagerAdapter(manager: socket, username: username)
            NotificationManager.shared.username = username
            WebSocketManager.usersToSocketManager[username] = socket
            WebSocketManagerAdapter.usernameToAdapter[username] = adapter
            socket.myInfo.username = username
            socket.messageManager.encrypt = EncryptMessage()
            let contactVC = ContactsTableViewController()
            contactVC.navigationItem.title = username
            contactVC.username = username
            contactVC.password = password
            self.contactVC = contactVC
            self.navigationController?.viewControllers = [contactVC]
            contactVC.loginAndConnect()
        } else {
            self.navigationController?.viewControllers = [JoinChatViewController()]
        }
    }
    
    func getContactVC() -> ContactsTableViewController? {
        return (tabBarController.viewControllers?.first as? UINavigationController)?.viewControllers.first as? ContactsTableViewController
    }
    
    func needRelogin() -> Bool {
        guard let socketManager = self.socketManager else { return true }
        let nowTime = Date().timeIntervalSince1970
        return nowTime - socketManager.httpsManager.cookieTime >= 2 * 24 * 60 * 60 // 2天
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        self.backgroundSessionCompletionHandler = completionHandler
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        //通知中心，控制中心，快捷访问都不会触发这里。重新登录的逻辑在这里可能更合适
    }
        
    func applicationWillResignActive(_ application: UIApplication) {
        
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("become active")
        application.applicationIconBadgeNumber = 0
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
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        launchedByPushAction = false
        checkIfShouldRemoveCache()
        print("enter background")
        lastAppEnterBackgroundTime = NSDate().timeIntervalSince1970
        guard !callManager.hasCall() else { return }
        socketManager?.disconnect()
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        tabBarController.selectedViewController = navigationController
        guard let nav = navigationController else { return }
        switch shortcutItem.type {
        case "add":
            if nav.topViewController is SelectShortcutTVC { return }
            nav.pushViewController(SelectShortcutTVC(), animated: true)
        case "contact":
            if !(nav.topViewController is JoinChatViewController) {
                nav.popToRootViewController(animated: true)
            }
            guard let userInfo = shortcutItem.userInfo, let username = userInfo["username"] as? String,
                  let password = userInfo["password"] as? String else { return }
            guard let vc = nav.topViewController as? JoinChatViewController else { return }
            vc.login(username: username, password: password)
        default:
            return
        }
    }
    
    // app 在前台运行中收到通知会调用
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print(userInfo)
        // socket如果断开却没回调通知我的话，就算收到推送也会安静
        socketManager.commonWebSocket.pingWithResult { [weak self] success in
            if !success {
                self?.socketManager.connect()
            }
        }
    }
    
    func registerNotification() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.badge, .sound, .alert]) { (granted, error) in
            if (error == nil && granted) {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications();
                }
            } else {
                print("请求通知权限被拒绝了")
            }
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        self.deviceToken = deviceToken.map { String(format: "%02.2hhx", arguments: [$0]) }.joined()
        print(self.deviceToken!)
    }
        
    // 点击推送通知才会调用
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if PushAction(rawValue: response.actionIdentifier) != nil {
            launchedByPushAction = true
        } else {
            //TODO: 这里可以做自动打开目的地界面
        }
        guard let userInfo = response.notification.request.content.userInfo as? [String: AnyObject],
              let aps = userInfo["aps"] as? [String: AnyObject] else { return }
        notificationManager.username = username
        notificationManager.processRemoteNotification(aps)
        
        switch response.actionIdentifier {
        case "REPLY_ACTION":
            if let textResponse = response as? UNTextInputNotificationResponse {
                notificationManager.actionCompletionHandler = completionHandler
                let input = textResponse.userText
                notificationManager.processReplyAction(replyContent: input)
            }
        case "DO_NOT_DISTURT_ACTION":
            if let username = UserDefaults.standard.value(forKey: "lastUsername") as? String,
               let password = UserDefaults.standard.value(forKey: "lastPassword") as? String {
                socketManager.commonWebSocket.httpRequestsManager.login(username: username, password: password) { res in
                    if res == "登录成功" {
                        self.socketManager.doNotDisturb(for: "", hour: 4) {
                            completionHandler()
                            print("已经调用completionHandler")
                        }
                    } else {
                        completionHandler()
                    }
                }

            }
            break
        default:
            break
        }
    }
            
}

extension AppDelegate: PKPushRegistryDelegate {
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let deviceTokenString = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
        print("deviceTokenString \(deviceTokenString)")
        pushKitToken = deviceTokenString
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        print("收到pushkit推送!")
        
        guard let aps = payload.dictionaryPayload["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any],
              let caller = alert["title"] as? String,
              let uuid = alert["uuid"] as? String
              else { return }
        let sender = String(caller)
        print(sender + "打电话来啦")
        let wrappedUUID = UUID(uuidString: uuid)
        let finalUUID = wrappedUUID ?? UUID()
        socketManager.nowCallUUID = finalUUID
        providerDelegate.reportIncomingCall(uuid: finalUUID, handle: sender) { (error) in
            guard error == nil else { return }
            self.notificationManager.prepareVoiceChat(caller: sender, uuid: finalUUID)
        }
        completion()
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print(type)
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if callManager.hasCall() { return false }
        guard let intent = userActivity.interaction?.intent as? INStartAudioCallIntent,
              let name = intent.contacts?.first?.personHandle?.value else { return false }
        let uuid = UUID().uuidString
        return true
    }
    
}

extension AppDelegate: VoiceDelegate {
    func time(toSend data: Data) {
        socketManager.sendVoiceData(data)
    }
}

extension AppDelegate: FloatWindowTouchDelegate {
    func tapPush(_ window: FloatWindow!, sender: String, content: String) {
        self.tabBarController.selectedViewController = navigationController
        if let contactVC = navigationController?.viewControllers.first as? ContactsTableViewController,
           let index = contactVC.usernames.firstIndex(of: sender) {
            contactVC.tableView(contactVC.tableView, didSelectRowAt: IndexPath(row: index, section: 0))
        }
    }
    
    func tapAlwaysDisplay(_ window: FloatWindow!, name: String) {
        if window.alwayDisplayType == .shouldDismiss {
            adapterFor(username: username).readyToSendVideoData = false
            Recorder.sharedInstance().needSendVideo = false
            guard let call = callManager.callWithUUID(socketManager.nowCallUUID) else { return }
            call.end()
            callManager.end(call: call)
            #if !targetEnvironment(macCatalyst)
            if let videoVC = self.navigationController?.visibleViewController as? VideoChatViewController {
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

// 通知快捷操作
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    private func registerPushAction() {
        let replyAction = UNTextInputNotificationAction(identifier: "REPLY_ACTION", title: "回复", options: UNNotificationActionOptions(rawValue: 0), textInputButtonTitle: "回复", textInputPlaceholder: "")
//        let doNotDisturbAction = UNNotificationAction(identifier: "DO_NOT_DISTURT_ACTION", title: "勿扰4小时", options: .init(rawValue: 0))
        let categoryForPersonal = UNNotificationCategory(identifier: "MESSAGE", actions: [replyAction], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "", options: .customDismissAction)
        let categoryForPublic = UNNotificationCategory(identifier: "MESSAGE_PUBLICPINO", actions: [replyAction], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "", options: .customDismissAction)
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.setNotificationCategories([categoryForPublic, categoryForPersonal])
        notificationCenter.delegate = self
    }
        
}
