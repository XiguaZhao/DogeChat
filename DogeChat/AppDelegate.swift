
import UIKit
import UserNotifications
import PushKit
import CallKit
import Intents
import YPTransition
import RSAiOSWatchOS
import DogeChatUniversal


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var pushWindow: FloatWindow!
    var callWindow: FloatWindow!
    var switcherWindow: FloatWindow!
    var deviceToken: String?
    var pushKitToken: String?
    var launchedByPushAction = false
    let notificationManager = NotificationManager.shared
    let socketManager = WebSocketManager.shared
    var navigationController: UINavigationController!
    var tabBarController: UITabBarController!
    var splitViewController: UISplitViewController!
    var providerDelegate: ProviderDelegate!
    let callManager = CallManager()
    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    var lastAppEnterBackgroundTime = NSDate().timeIntervalSince1970
    let webSocketAdapter = WebSocketManagerAdapter.shared
    var isIOS = true
    class var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        registerPushAction()
        window = UIWindow(frame: UIScreen.main.bounds)
        if #available(iOS 13.0, *) {
            window?.backgroundColor = .systemBackground
        } else {
            window?.backgroundColor = .white
        }
        
        splitViewController = UIStoryboard(name: "main", bundle: .main).instantiateInitialViewController() as? UISplitViewController
        splitViewController.preferredDisplayMode = .allVisible
        tabBarController = splitViewController.viewControllers[0] as? UITabBarController
        window?.rootViewController = splitViewController
        splitViewController.preferredPrimaryColumnWidthFraction = 0.35
        if #available(iOS 13.0, *) {
            splitViewController.view.backgroundColor = .systemBackground
        } else {
            splitViewController.view.backgroundColor = .white
        }

        window?.makeKeyAndVisible()
        pushWindow = FloatWindow(type: .push, alwayDisplayType: .shouldDismiss, delegate: self)
        callWindow = FloatWindow(type: .alwaysDisplay, alwayDisplayType: .shouldDismiss, delegate: self)
        switcherWindow = FloatWindow(type: .alwaysDisplay, alwayDisplayType: .shouldNotDimiss, delegate: self)
        
        providerDelegate = ProviderDelegate(callManager: callManager)
        socketManager.messageManager.encrypt = EncryptMessage()
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
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory()) else { return }
            for fileName in files {
                if fileName.isImageOrVideoOrVoice() {
                    try? FileManager.default.removeItem(atPath: NSTemporaryDirectory() + fileName)
                }
            }
        }
        login()
        
//        INPreferences.requestSiriAuthorization { (status) in
//        }
        return true
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if AppDelegate.isPad() {
            return .all
        } else {
            if #available(iOS 14.0, *) {
                if ChatRoomViewController.needRotate {
                    return .landscape
                } else {
                    if let browser =  navigationController?.visibleViewController as? ImageBrowserViewController {
                        return browser.canRotate ? .all : .portrait
                    }
                    return .portrait
                }
            } else {
                return .portrait
            }
        }
    }
    
    class func isLandscape() -> Bool {
        return UIDevice.current.orientation == .landscapeLeft || UIDevice.current.orientation == .landscapeRight
    }
    
    class func isPad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    func login() {
        self.navigationController = self.tabBarController.viewControllers?.first as? UINavigationController
        if let username = UserDefaults.standard.value(forKey: "lastUsername") as? String,
           let password = UserDefaults.standard.value(forKey: "lastPassword") as? String {
            let contactVC = ContactsTableViewController()
            contactVC.navigationItem.title = username
            contactVC.username = username
            self.navigationController.viewControllers = [contactVC]
            socketManager.messageManager.login(username: username, password: password) { (loginResult) in
                guard loginResult == "登录成功" else { return }
                contactVC.loginSuccess = true
                if AppDelegate.isPad() && !self.splitViewController.isCollapsed {
                    if let _ = (AppDelegate.shared.navigationController.topViewController as? ContactsTableViewController) {
                    }
                    return
                }
            }
        } else {
            self.navigationController.viewControllers = [JoinChatViewController()]
        }
    }
    
    func needRelogin() -> Bool {
        let nowTime = Date().timeIntervalSince1970
        return nowTime - lastAppEnterBackgroundTime >= 20 * 60
    }
        
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("become active")
        application.applicationIconBadgeNumber = 0
        DispatchQueue.global().async {
            WebSocketManager.shared.sortMessages()
        }
        let shouldReLogin = self.needRelogin()
        var reloginCount = 0
        if !callManager.hasCall() {
            if socketManager.connected {
                socketManager.disconnect()
            }
            WebSocketManager.shared.connected = false
        }
        func reloginFunc() {
            reloginCount += 1
            if reloginCount < 5, let password = UserDefaults.standard.value(forKey: "lastPassword") as? String {
                socketManager.messageManager.login(username: socketManager.messageManager.myName, password: password) { (result) in
                    if result == "登录成功" {
                        self.socketManager.connect()
                    } else {
                        reloginFunc()
                    }
                }
            }
        }
        if shouldReLogin {
            reloginFunc()
        }
        if (self.navigationController).topViewController?.title == "JoinChatVC" { return }
        guard !WebSocketManager.shared.messageManager.cookie.isEmpty else {
            return
        }
        if !shouldReLogin {
            WebSocketManager.shared.connect()
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        launchedByPushAction = false
        print("enter background")
        lastAppEnterBackgroundTime = NSDate().timeIntervalSince1970
        guard !callManager.hasCall() else { return }
        socketManager.disconnect()
        WebSocketManager.shared.invalidatePingTimer()
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
        // TODO: 使用过程中收到消息弹窗
    }
        
    // 点击推送通知才会调用
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier.count > 0 { launchedByPushAction = true }
        guard let userInfo = response.notification.request.content.userInfo as? [String: AnyObject],
              let aps = userInfo["aps"] as? [String: AnyObject] else { return }
        notificationManager.processRemoteNotification(aps)
        
        switch response.actionIdentifier {
        case "REPLY_ACTION":
            if let textResponse = response as? UNTextInputNotificationResponse {
                notificationManager.actionCompletionHandler = completionHandler
                let input = textResponse.userText
                notificationManager.processReplyAction(replyContent: input)
            }
        case "DO_NOT_DISTURT_ACTION":
            WebSocketManager.shared.doNotDisturb(for: "", hour: 4) {
                completionHandler()
                print("已经调用completionHandler")
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
        socketManager.tapFromSystemPhoneInfo = (name, uuid)
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
        if let contactVC = navigationController.viewControllers.first as? ContactsTableViewController,
           let index = ContactsTableViewController.usernames.firstIndex(of: sender) {
            contactVC.tableView(contactVC.tableView, didSelectRowAt: IndexPath(row: index, section: 0))
        }
    }
    
    func tapAlwaysDisplay(_ window: FloatWindow!, name: String) {
        if window.alwayDisplayType == .shouldDismiss {
            webSocketAdapter.readyToSendVideoData = false
            Recorder.sharedInstance().needSendVideo = false
            guard let call = callManager.callWithUUID(socketManager.nowCallUUID) else { return }
            call.end()
            callManager.end(call: call)
            #if !targetEnvironment(macCatalyst)
            if let videoVC = self.navigationController.visibleViewController as? VideoChatViewController {
                videoVC.dismiss()
            }
            #endif
            WebSocketManager.shared.nowCallUUID = nil
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
        let doNotDisturbAction = UNNotificationAction(identifier: "DO_NOT_DISTURT_ACTION", title: "勿扰4小时", options: .init(rawValue: 0))
        let categoryForPersonal = UNNotificationCategory(identifier: "MESSAGE", actions: [replyAction], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "", options: .customDismissAction)
        let categoryForPublic = UNNotificationCategory(identifier: "MESSAGE_PUBLICPINO", actions: [replyAction, doNotDisturbAction], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "", options: .customDismissAction)
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.setNotificationCategories([categoryForPublic, categoryForPersonal])
        notificationCenter.delegate = self
    }
        
}
