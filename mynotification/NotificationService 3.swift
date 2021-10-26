//
//  NotificationService.swift
//  mynotification
//
//  Created by 赵锡光 on 2021/9/27.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UserNotifications
import PencilKit

class NotificationService: UNNotificationServiceExtension, URLSessionDelegate {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    lazy var session: URLSession = {
        let sesssion = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        return sesssion
    }()
    
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
                if let url = URL(string: wholePath) {
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
                    let task = session.dataTask(with: url) { data, response, error in
                        if let data = data {
                            var finalData: Data? = data
                            var ext = url.pathExtension
#if !targetEnvironment(macCatalyst)
                            if type == "draw" {
                                if #available(iOSApplicationExtension 13.0, *) {
                                    if let draw = try? PKDrawing(data: data) {
                                        finalData = draw.image(from: draw.bounds, scale: 1).pngData()
                                        ext = "jpeg"
                                        self.bestAttemptContent?.body = "[Drawing]"
                                    }
                                }
                            }
#endif
                            if let finalData = finalData  {
                                let fileUrl = URL(string: "file://" + NSTemporaryDirectory() + UUID().uuidString + ".\(ext)")!
                                try? finalData.write(to: fileUrl)
                                if let attachment = try? UNNotificationAttachment(identifier: path, url: fileUrl, options: nil) {
                                    self.bestAttemptContent?.attachments = [attachment]
                                }
                            } else {
                                complete()
                                return
                            }
                        }
                        complete()
                    }
                    task.resume()
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

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, credential)
    }
    

}

