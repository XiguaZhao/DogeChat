
import UIKit
import UserNotifications
import PushKit
import CallKit
import Intents
import DogeChatNetwork
import RSAiOSWatchOS
import DogeChatUniversal
import WatchConnectivity
import DogeChatCommonDefines

@objc enum SplitVCSide: Int {
    case left, right
}

enum PushAction: String {
    case REPLY_ACTION
    case DO_NOT_DISTURT_ACTION
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static let mediaBrowserWindow = "mediaBrowserWindow"
    static let chatRoomWindow = "chatRoomWindow"
    
    var window: UIWindow?
    var deviceToken: String?
    var pushKitToken: String?
    var nowCallUUID: UUID?
    var launchedByPushAction = false
    var backgroundSessionCompletionHandler: (() -> Void)?
    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    var lastAppEnterBackgroundTime = NSDate().timeIntervalSince1970
    var backgroundTaskID: UIBackgroundTaskIdentifier?
    weak var remoteNotiDelegate: RemoteNotificationDelegate?
    var macOSBridge: Bridge?
    var latestRemoteNotiInfo: RemoteNotificationInfo? {
        didSet {
            if let latestRemoteNotiInfo = latestRemoteNotiInfo {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .remoteNotiInfoSet, object: latestRemoteNotiInfo)
                }
            }
        }
    }
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
        UserDefaults(suiteName: groupName)?.set(true, forKey: "hostActive")
        registerPushAction()
        moveToContainerIfNeeded()
        if UserDefaults.standard.value(forKey: "forceDarkMode") == nil {
            UserDefaults.standard.setValue(true, forKey: "forceDarkMode")
        }
        if #available(iOS 13.0, *) {
            for session in UIApplication.shared.openSessions {
                if session.stateRestorationActivity == nil {
                    UIApplication.shared.requestSceneSessionDestruction(session, options: nil, errorHandler: { error in
                        print(error)
                    })
                }
            }
        }
        let notificationOptions = launchOptions?[.remoteNotification]
        if let notification = notificationOptions as? [String: AnyObject],
           let aps = notification["aps"] as? [String: AnyObject] {
            if #available(iOS 13.0, *) {
                SceneDelegate.usernameToDelegate.first?.value.notificationManager.processRemoteNotification(aps)
            }
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
            if UserDefaults(suiteName: groupName)?.value(forKey: "sharedUsername") != nil {
                INPreferences.requestSiriAuthorization { status in
                    print("授权状态")
                    print(status)
                }
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundImageChangeNoti(_:)), name: .backgroundImageChanged, object: nil)
        
        if #available(iOS 13, *) {} else {
            AppDelegateUI.shared.makeWindow()
        }
        
        registerMacOSBridge()
        
        return true
    }
    
    @objc func backgroundImageChangeNoti(_ noti: Notification) {
        guard let url = noti.userInfo?["url"] as? String else { return }
        if url.isEmpty {
            deleteFile(dirName: "customBlur", fileName: userID)
            PlayerManager.shared.customImage = nil
            return
        }
        MediaLoader.shared.requestImage(urlStr: url, type: .sticker, completion: { image, data, _ in
            if let data = data {
                saveFileToDisk(dirName: "customBlur", fileName: userID, data: data)
            } else if let image = image {
                saveFileToDisk(dirName: "customBlur", fileName: userID, data: image.jpegData(compressionQuality: 1) ?? Data())
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                PlayerManager.shared.blurSource = .customBlur
                PlayerManager.shared.customImage = image
            }
        }, progress: nil)
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        UserDefaults(suiteName: groupName)?.set(false, forKey: "hostActive")
        if #available(iOS 13.0, *) {
            for sceneDelegate in SceneDelegate.usernameToDelegate.values {
                if let friends = sceneDelegate.contactVC?.friends, !friends.isEmpty, let userID = sceneDelegate.socketManager?.myInfo.userID, !userID.isEmpty {
                    saveFriendsToDisk(friends, userID: userID)
                }
            }
            if let maxID = SceneDelegate.usernameToDelegate.first?.value.socketManager?.messageManager.maxId {
                UserDefaults.standard.set(maxID, forKey: "maxID")
            }
        } else {
            let friends = AppDelegateUI.shared.contactVC.friends
            if !friends.isEmpty {
                saveFriendsToDisk(friends, userID: WebSocketManager.shared.myID)
            }
            UserDefaults.standard.set(WebSocketManager.shared.messageManager.maxId, forKey: "maxID")
        }
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if options.userActivities.first?.title == Self.chatRoomWindow {
            return UISceneConfiguration(name: "ChatRoom", sessionRole: connectingSceneSession.role)
        } else if options.userActivities.first?.title == Self.mediaBrowserWindow {
            return UISceneConfiguration(name: "MediaBrowser", sessionRole: connectingSceneSession.role)
        }
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        AppDelegateUI.shared.enterBackground()
    }
    
                        
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        self.backgroundSessionCompletionHandler = completionHandler
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        //通知中心，控制中心，快捷访问都不会触发这里。重新登录的逻辑在这里可能更合适
        AppDelegateUI.shared.enterForeground()
    }
        
    func applicationWillResignActive(_ application: UIApplication) {
        AppDelegateUI.shared.resignActive()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        application.applicationIconBadgeNumber = 0
    }
    
    #if !targetEnvironment(macCatalyst)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        guard let infos = notification.request.content.userInfo["aps"] as? [String : Any] else {
            completionHandler([])
            return
        }
        registerChannelManager()
        if #available(iOS 16, *), infos["type"] as? String == "intercom" {
            PTChannel.shared.processPTTInviteNotification()
        }
        processRevoke(infos)
        if let delegate = self.remoteNotiDelegate, delegate.shouldPresentRemoteNotification(infos) {
            completionHandler([.alert])
        } else {
            completionHandler([])
        }
    }
    #endif
                
    // app 在前台运行中收到通知会调用
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print(userInfo)
    }
    
    func processRevoke(_ aps: [String : Any]) {
        if let status = aps["messageStatus"] as? Int, status == -1 {
            if let senderID = aps["senderId"] as? String, let receiverID = aps["receiverId"] as? String,
               let isGroup = (aps["isGroup"] as? NSString)?.boolValue, let uuid = aps["uuid"] as? String {
                let revoke = RemoteMessage(isGroup: isGroup, senderID: senderID, receiverID: receiverID, uuid: uuid)
                NotificationCenter.default.post(name: .revokeMessage, object: [revoke])
            }
        }
    }
    
    func registerNotification() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.badge, .sound, .alert]) { (granted, error) in
            if (error == nil && granted) {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
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
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        
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
        if #available(iOS 13.0, *) {
            SceneDelegate.usernameToDelegate.first?.value.notificationManager.processRemoteNotification(aps)
        } else {
            NotificationManager.shared.processRemoteNotification(aps)
        }
        switch response.actionIdentifier {
        case "REPLY_ACTION":
            if let textResponse = response as? UNTextInputNotificationResponse {
                let input = textResponse.userText
                if UIApplication.shared.applicationState != .background, let delegate = self.remoteNotiDelegate, delegate.quickReply(aps, input: input) {
                    completionHandler()
                } else {
                    if let username = getUsernameAndPassword()?.username {
                        if #available(iOS 13.0, *) {
                            if let sceneDelegate = SceneDelegate.usernameToDelegate[username] {
                                sceneDelegate.notificationManager.actionCompletionHandler = completionHandler
                                sceneDelegate.notificationManager.processReplyAction(replyContent: input)
                            }
                        } else {
                            NotificationManager.shared.actionCompletionHandler = completionHandler
                            NotificationManager.shared.processReplyAction(replyContent: textResponse.userText)
                        }
                    }
                }
            }
        case "DO_NOT_DISTURT_ACTION":
            break
        default:
            self.latestRemoteNotiInfo = NotificationManager.getRemoteNotiInfo(aps)
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
        if #available(iOS 13, *) {
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
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print(type)
    }
        
}

// 通知快捷操作
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    private func registerPushAction() {
        guard !isMac() else { return }
        let replyAction = UNTextInputNotificationAction(identifier: "REPLY_ACTION", title: "回复", options: UNNotificationActionOptions(rawValue: 0), textInputButtonTitle: "回复", textInputPlaceholder: "")
//        let doNotDisturbAction = UNNotificationAction(identifier: "DO_NOT_DISTURT_ACTION", title: "勿扰4小时", options: .init(rawValue: 0))
        let categoryForPersonal = UNNotificationCategory(identifier: "MESSAGE", actions: [replyAction], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "", options: .customDismissAction)
        let categoryForPublic = UNNotificationCategory(identifier: "MESSAGE_PUBLICPINO", actions: [replyAction], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "", options: .customDismissAction)
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.setNotificationCategories([categoryForPublic, categoryForPersonal])
        notificationCenter.delegate = self
    }
        
}
