//
//  AppDelegate+Common.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/3/4.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatNetwork

extension AppDelegate {
    
    func startBackgroundTask(socket: WebSocketManager?) {
        guard self.backgroundTaskID == nil else { return }
        let block: () -> Void = { [weak self, weak socket] in
            print("任务到期")
            if let id = self?.backgroundTaskID {
                self?.backgroundTaskID = nil
                if UIApplication.shared.applicationState == .background {
                    print("后台，socket断开")
                    socket?.disconnect()
                }
                UIApplication.shared.endBackgroundTask(id)
            }
        }
        self.backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            block()
        }
    }
    
    func registerMacOSBridge() {
        let bundleFileName = "MacOSBridge.bundle"
        guard let bundleURL = Bundle.main.builtInPlugInsURL?.appendingPathComponent(bundleFileName),
        let bundle = Bundle(url: bundleURL) else {
            return
        }
        let className = "MacOSBridge.MacOSBridge"
        guard let bridgeClass = bundle.classNamed(className) as? Bridge.Type else {
            return
        }
        self.macOSBridge = bridgeClass.init()
        self.macOSBridge?.makeGlobalShortcut(with: "D")
        NotificationCenter.default.addObserver(forName: .shortcutChanged, object: nil, queue: nil) { [weak self] note in
            self?.macOSBridge?.makeGlobalShortcut(with: note.object as! String)
        }
    }
    
}
