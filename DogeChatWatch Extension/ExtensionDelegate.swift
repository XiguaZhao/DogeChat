//
//  ExtensionDelegate.swift
//  DogeChatWatch Extension
//
//  Created by 赵锡光 on 2021/6/7.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import WatchKit
import DogeChatUniversal
import UserNotifications
import RSAiOSWatchOS

class ExtensionDelegate: NSObject, WKExtensionDelegate, UNUserNotificationCenterDelegate {
    
    static let shared = WKExtension.shared().delegate as! ExtensionDelegate
    var lastEnterBackgroundTime = Date().timeIntervalSince1970
    var deviceToken: String?
    
    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        SocketManager.shared.messageManager.encrypt = EncryptMessage()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.badge, .alert, .sound]) { granted, error in
            if error == nil && granted {
                DispatchQueue.main.async {
                    WKExtension.shared().registerForRemoteNotifications()
                }
            } else {
                print("通知权限被拒绝")
            }
        }
    }
    
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        self.deviceToken = deviceToken.map { String(format: "%02.2hhx", arguments: [$0]) }.joined()
        print(self.deviceToken!)
    }
    
    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        let nowTime = Date().timeIntervalSince1970
        let shouldReLogin = nowTime - lastEnterBackgroundTime >= 20 * 60
        if shouldReLogin {
            if let password = UserDefaults.standard.value(forKey: "password") as? String {
                SocketManager.shared.messageManager.login(username: SocketManager.shared.messageManager.myName, password: password) { res in
                    if res == "登录成功" {
                        SocketManager.shared.connect()
                    }
                }
            }
        } else {
            SocketManager.shared.connect()
        }
    }
    
    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
        lastEnterBackgroundTime = Date().timeIntervalSince1970
        SocketManager.shared.disconnect()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if WKExtension.shared().applicationState == .inactive {
            WKInterfaceDevice.current().play(.success)
        }
        completionHandler([])
    }
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                backgroundTask.setTaskCompletedWithSnapshot(false)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompletedWithSnapshot(false)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompletedWithSnapshot(false)
            case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
                // Be sure to complete the relevant-shortcut task once you're done.
                relevantShortcutTask.setTaskCompletedWithSnapshot(false)
            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
                // Be sure to complete the intent-did-run task once you're done.
                intentDidRunTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
    
}
