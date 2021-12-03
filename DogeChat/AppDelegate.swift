
import UIKit
import UserNotifications
import PushKit
import CallKit
import Intents
import DogeChatNetwork
import RSAiOSWatchOS
import DogeChatUniversal
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
    
    var deviceToken: String?
    var pushKitToken: String?
    var nowCallUUID: UUID?
    var launchedByPushAction = false
    var backgroundSessionCompletionHandler: (() -> Void)?
    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    var lastAppEnterBackgroundTime = NSDate().timeIntervalSince1970
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
        UserDefaults(suiteName: "group.dogechat.zhaoxiguang")?.set(true, forKey: "hostActive")
        registerPushAction()
        if UserDefaults.standard.value(forKey: "forceDarkMode") == nil {
            UserDefaults.standard.setValue(true, forKey: "forceDarkMode")
        }
        for session in UIApplication.shared.openSessions {
            if session.stateRestorationActivity == nil {
                UIApplication.shared.requestSceneSessionDestruction(session, options: nil, errorHandler: nil)
            }
        }
        let notificationOptions = launchOptions?[.remoteNotification]
        if let notification = notificationOptions as? [String: AnyObject],
           let aps = notification["aps"] as? [String: AnyObject] {
            SceneDelegate.usernameToDelegate.first?.value.notificationManager.processRemoteNotification(aps)
        }
        
        registerNotification()
        voipRegistry.delegate = self
        if #available(macCatalyst 14.0, iOS 12.0, *) {
            voipRegistry.desiredPushTypes = [.voIP]
        }
        DispatchQueue.global().async {
            SelectShortcutTVC.updateShortcuts()
        }
        if UserDefaults.standard.value(forKey: "immersive") == nil {
            UserDefaults.standard.setValue(true, forKey: "immersive")
        }
        WCSession.default.delegate = SessionDelegate.shared
        WCSession.default.activate()
        NotificationCenter.default.addObserver(forName: .backgroundSessionFinish, object: nil, queue: .main) { [weak self] _ in
            self?.backgroundSessionCompletionHandler?()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if UserDefaults.standard.value(forKey: "lastUsername") != nil {
                INPreferences.requestSiriAuthorization { status in
                    print("授权状态")
                    print(status)
                }
            }
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
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        UserDefaults(suiteName: "group.dogechat.zhaoxiguang")?.set(false, forKey: "hostActive")
    }
    
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
        
    private func sizeFor(side: SplitVCSide, username: String?, view: UIView? = nil) -> CGSize {
        let splitViewController: UISplitViewController
        if let username = username, !username.isEmpty, let sceneDelegate = SceneDelegate.usernameToDelegate[username] {
            splitViewController = sceneDelegate.splitVC
        } else if let splitVC = view?.window?.rootViewController as? DogeChatSplitViewController {
            splitViewController = splitVC
        } else {
            return UIScreen.main.bounds.size
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
    
    @objc func widthFor(side: SplitVCSide, username: String?, view: UIView? = nil) -> CGFloat {
        return sizeFor(side: side, username: username, view: view).width
    }
    
    @objc func heightFor(side: SplitVCSide, username: String?, view: UIView? = nil) -> CGFloat {
        return sizeFor(side: side, username: username, view: view).height
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
        application.applicationIconBadgeNumber = 0
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
        SceneDelegate.usernameToDelegate.first?.value.notificationManager.processRemoteNotification(aps)
        
        switch response.actionIdentifier {
        case "REPLY_ACTION":
            if let textResponse = response as? UNTextInputNotificationResponse {
                SceneDelegate.usernameToDelegate.first?.value.notificationManager.actionCompletionHandler = completionHandler
                let input = textResponse.userText
                SceneDelegate.usernameToDelegate.first?.value.notificationManager.processReplyAction(replyContent: input)
            }
        case "DO_NOT_DISTURT_ACTION":
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
              else {
                  ProviderDelegate(callManager: CallManager()).reportIncomingCall(uuid: UUID(), handle: "未知用户", completion: nil)
                  completion()
                  return
              }
        let sender = String(caller)
        print(sender + "打电话来啦")
        let wrappedUUID = UUID(uuidString: uuid)
        let finalUUID = wrappedUUID ?? UUID()
        self.nowCallUUID = finalUUID
        if let sceneDelegate = SceneDelegate.usernameToDelegate.first?.value {
            sceneDelegate.socketManager?.nowCallUUID = finalUUID
            sceneDelegate.providerDelegate.reportIncomingCall(uuid: finalUUID, handle: sender) { (error) in
                guard error == nil else { return }
                sceneDelegate.notificationManager.prepareVoiceChat(caller: sender, uuid: finalUUID)
            }
        } else {
            ProviderDelegate(callManager: CallManager()).reportIncomingCall(uuid: UUID(), handle: "未知用户", completion: nil)
        }
        completion()
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print(type)
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
