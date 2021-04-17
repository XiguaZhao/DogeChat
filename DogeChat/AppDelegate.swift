/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import UserNotifications
import PushKit
import CallKit
import Intents

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    var window: UIWindow?
    var pushWindow: FloatWindow!
    var callWindow: FloatWindow!
    var deviceToken: String?
    var pushKitToken: String?
    let notificationManager = NotificationManager.shared
    let socketManager = WebSocketManager.shared
    var navigationController: UINavigationController!
    var tabBarController: UITabBarController!
    var splitViewController: UISplitViewController!
    var providerDelegate: ProviderDelegate!
    let callManager = CallManager()
    let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    var lastAppEnterBackgroundTime = NSDate().timeIntervalSince1970
    class var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)
        if #available(iOS 13.0, *) {
            window?.backgroundColor = .systemBackground
        } else {
            window?.backgroundColor = .white
        }
        
        splitViewController = UIStoryboard(name: "main", bundle: .main).instantiateInitialViewController() as? UISplitViewController
        splitViewController.preferredDisplayMode = .allVisible
        tabBarController = splitViewController.viewControllers[0] as? UITabBarController
        splitViewController.preferredPrimaryColumnWidthFraction = 0.35
        if #available(iOS 13.0, *) {
            splitViewController.view.backgroundColor = .systemBackground
        } else {
            splitViewController.view.backgroundColor = .white
        }
        window?.rootViewController = splitViewController

        window?.makeKeyAndVisible()
        pushWindow = FloatWindow(type: .push, delegate: self)
        callWindow = FloatWindow(type: .alwaysDisplay, delegate: self)
        
        providerDelegate = ProviderDelegate(callManager: callManager)
                
        let notificationOptions = launchOptions?[.remoteNotification]
        if let notification = notificationOptions as? [String: AnyObject],
           let aps = notification["aps"] as? [String: AnyObject] {
            notificationManager.processRemoteNotification(aps)
        }
        
        registerNotification()
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
        
        DispatchQueue.global().async {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory()) else { return }
            for fileName in files {
                if fileName.hasSuffix(".gif") || fileName.hasSuffix(".png") || fileName.hasSuffix(".jpg") || fileName.hasSuffix("jpeg") {
                    try? FileManager.default.removeItem(atPath: NSTemporaryDirectory() + fileName)
                }
            }
        }
        login()
        return true
    }
    
//    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
//        if AppDelegate.isPad() {
//            return .all
//        } else {
//            return .portrait
//        }
//    }
    
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
            self.navigationController.viewControllers = [contactVC]
            socketManager.login(username: username, password: password) { (loginResult) in
                guard loginResult == "登录成功" else { return }
                contactVC.loginSuccess = true
                contactVC.username = username
                if AppDelegate.isPad() && !self.splitViewController.isCollapsed {
                    if let contactVC = (AppDelegate.shared.navigationController.topViewController as? ContactsTableViewController) {
                    }
                    return
                }
//                self.socketManager.connect()
            }
        } else {
            self.navigationController.viewControllers = [JoinChatViewController()]
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        let nowTime = Date().timeIntervalSince1970
        let shouldReLogin = nowTime - lastAppEnterBackgroundTime >= 20 * 60
        if shouldReLogin, let password = UserDefaults.standard.value(forKey: "lastPassword") as? String {
            socketManager.login(username: socketManager.myName, password: password) { (result) in
                guard result == "登录成功" else { return }
                self.socketManager.connect()
            }
        }
        if (self.navigationController).topViewController?.title == "JoinChatVC" { return }
        guard !WebSocketManager.shared.cookie.isEmpty else { return }
        if !shouldReLogin {
            WebSocketManager.shared.connect()
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        AppDelegate.shared.navigationController.topViewController?.navigationItem.title = "background"

        lastAppEnterBackgroundTime = NSDate().timeIntervalSince1970
        guard !callManager.hasCall() else { return }
        socketManager.disconnect()

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
        center .requestAuthorization(options: [.badge, .sound, .alert]) { (granted, error) in
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
        guard let userInfo = response.notification.request.content.userInfo as? [String: AnyObject],
              let aps = userInfo["aps"] as? [String: AnyObject] else { return }
        notificationManager.processRemoteNotification(aps)
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
           let index = contactVC.usernames.firstIndex(of: sender) {
            contactVC.tableView(contactVC.tableView, didSelectRowAt: IndexPath(row: index, section: 0))
        }
    }
    
    func tapAlwaysDisplay(_ window: FloatWindow!, name: String) {
        guard let call = callManager.callWithUUID(socketManager.nowCallUUID) else { return }
        call.end()
        callManager.end(call: call)
    }
}
