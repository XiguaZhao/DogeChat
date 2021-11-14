//
//  NotificationService.swift
//  mynotification
//
//  Created by 赵锡光 on 2021/9/27.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UserNotifications
import PencilKit
import DogeChatUniversal

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    let manager = HttpRequestsManager()
    
    func complete() {
        if let bestAttemptContent = bestAttemptContent {
            contentHandler?(bestAttemptContent)
        }
    }

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        UNUserNotificationCenter.current().getDeliveredNotifications { [self] delivered in
            bestAttemptContent?.badge = NSNumber(value: delivered.count + 1)
            
            if UserDefaults(suiteName: "group.demo.zhaoxiguang")?.bool(forKey: "hostActive") == true {
                complete()
                return
            }
            
            if let aps = request.content.userInfo["aps"] as? [String : Any],
               var path = aps["url"] as? String, !path.isEmpty {
                guard let type = aps["type"] as? String else {
                    complete()
                    return
                }
                if type == "livePhoto" {
                    if let imagePath = path.components(separatedBy: " ").first {
                        path = imagePath
                    }
                }
                let wholePath = "https://121.5.152.193" + path
                if let _ = URL(string: wholePath) {
                    guard !path.hasSuffix(".gif") else {
                        complete()
                        return
                    }
                    if type == "video" {
                        self.bestAttemptContent?.body = "[视频]"                        
                    }
                    if type == "livePhoto" {
                        self.bestAttemptContent?.body = "[Live Photo]"
                    }
                    guard let username = UserDefaults(suiteName: "group.demo.zhaoxiguang")?.value(forKey: "sharedUsername") as? String,
                          let password = UserDefaults(suiteName: "group.demo.zhaoxiguang")?.value(forKey: "sharedPassword") as? String else { return }
                    manager.login(username: username, password: password) { res in
                        guard res == "登录成功", !manager.cookie.isEmpty else { return }
                        MediaLoader.shared.cookie = manager.cookie
                        MediaLoader.shared.requestImage(urlStr: path, type: .voice, syncIfCan: false, completion: { _, data, localURL in
                            var localURL = localURL
#if !targetEnvironment(macCatalyst)
                            if type == "draw" {
                                if #available(iOSApplicationExtension 13.0, *) {
                                    if let data = try? Data(contentsOf: localURL),
                                       let draw = try? PKDrawing(data: data) {
                                        let drawData = draw.image(from: draw.bounds, scale: 1).pngData()
                                        let fileName = localURL.lastPathComponent + ".jpeg"
                                        saveFileToDisk(dirName: drawDir, fileName: fileName, data: drawData!)
                                        if let newLocalURL = fileURLAt(dirName: drawDir, fileName: fileName) {
                                            localURL = newLocalURL
                                        }
                                        self.bestAttemptContent?.body = "[Drawing]"
                                    }
                                }
                            }
#endif
                            if let attachment = try? UNNotificationAttachment(identifier: path, url: localURL, options: nil) {
                                self.bestAttemptContent?.attachments = [attachment]
                            }
                            complete()
                        }, progress: nil)
                    }
                } else {
                    complete()
                }
            } else {
                complete()
            }

        }

        
    }
    
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}

