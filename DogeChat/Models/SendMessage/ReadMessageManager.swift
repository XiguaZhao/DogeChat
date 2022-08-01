//
//  ReadMessageManager.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/18.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatCommonDefines
import DogeChatNetwork

protocol ReadMessageDataSource: AnyObject {
    func readMessageFriendIDs() -> [String]
}

class ReadMessageManager {
    
    weak var dataSource: ReadMessageDataSource?
    
    var manager: WebSocketManager? {
        return WebSocketManager.usersToSocketManager[username]
    }
    
    var timer: DispatchSourceTimer?
    var username = ""
    
    func fileTimer() {
        self.timer = DispatchSource.makeTimerSource(queue: .main)
        timer?.schedule(deadline: .now() + 1, repeating: 5, leeway: DispatchTimeInterval.seconds(1))
        timer?.setEventHandler { [weak self] in
            self?.timerChange()
        }
        timer?.resume()
    }
            
    func timerChange() {
        guard let manager = manager, UIApplication.shared.applicationState == .active else {
            return
        }
        if let ids = self.dataSource?.readMessageFriendIDs() {
            for userID in ids {
                if let readID = manager.messageManager.readMessageDict.removeValue(forKey: userID) {
                    manager.commonWebSocket.send(makeJsonString(for: ["method" : "readMessage",
                                                                      "userId" : userID,
                                                                      "readId" : readID]))
                }
            }
        }
    }
    
    deinit {
        timer?.cancel()
    }
    
    var observer: CFRunLoopObserver!
    var activity: CFRunLoopActivity = .entry
    func start() {
        if (observer != nil) {
            return
        }
        let semaphore = DispatchSemaphore(value: 0)
        observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFRunLoopActivity.allActivities.rawValue, true, 0, { observer, _activity in
            self.activity = _activity
            semaphore.signal()
        })
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
        DispatchQueue.global().async {
            while true {
                if #available(iOS 13.0, *) {
                    let st = semaphore.wait(timeout: .now().advanced(by: .milliseconds(50)))
                    if (st == .timedOut) {
                        if self.activity == .beforeSources || self.activity == .afterWaiting {
                            print("kadun")
                        }
                    }
                }
            }
        }
    }
    
}
