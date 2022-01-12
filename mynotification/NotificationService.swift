//
//  NotificationService.swift
//  mynotification
//
//  Created by 赵锡光 on 2021/9/27.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UserNotifications
import PencilKit
import WidgetKit
import DogeChatCommonDefines

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    var loadMedia = false
        
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
            
            processRevoke(request: request, delivered: delivered)
            
            if loadMedia {
                if UserDefaults(suiteName: groupName)?.bool(forKey: "hostActive") == true {
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
                        guard let cookie = UserDefaults(suiteName: groupName)?.value(forKey: "sharedCookie") as? String, !cookie.isEmpty else {
                            complete()
                            return
                        }
                        MediaLoader.shared.cookie = cookie
                        MediaLoader.shared.type = .defaultSession
                        MediaLoader.shared.requestImage(urlStr: path, type: .voice, syncIfCan: false, needCache: false, completion: { _, data, localURL in
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
                    } else {
                        complete()
                    }
                } else {
                    complete()
                }
            }
        }
        
        
    }
    
    func processRevoke(request: UNNotificationRequest, delivered: [UNNotification]) {
        guard let aps = request.content.userInfo["aps"] as? [String : Any] else {
            complete()
            return
        }
        if aps["loadMedia"] != nil {
            self.loadMedia = true
        }
        guard let uuid = aps["uuid"] as? String, let status = aps["messageStatus"] as? Int, status == -1 else {
            if !self.loadMedia {
                complete()
            }
            return
        }
        if let senderID = aps["senderId"] as? String,
           let receiverID = aps["receiverId"] as? String,
           let isGroup = (aps["isGroup"] as? NSString)?.boolValue {
            let revoke = RemoteMessage(isGroup: isGroup, senderID: senderID, receiverID: receiverID, uuid: uuid)
            var newRevokes: [RemoteMessage]
            if let data = UserDefaults(suiteName: groupName)?.value(forKey: "revokedMessages") as? Data, let revokes = try? JSONDecoder().decode([RemoteMessage].self, from: data) {
                newRevokes = revokes + [revoke]
            } else {
                newRevokes = [revoke]
            }
            if let data = try? JSONEncoder().encode(newRevokes) {
                UserDefaults(suiteName: groupName)?.set(data, forKey: "revokedMessages")
            }
        }
        let deliveredUUIDs = delivered.compactMap({ ($0.request.content.userInfo["aps"] as? [String : Any])?["uuid"] as? String })
        if let index = deliveredUUIDs.firstIndex(of: uuid) {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [delivered[index].request.identifier])
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.complete()
            }
        } else {
            complete()
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

