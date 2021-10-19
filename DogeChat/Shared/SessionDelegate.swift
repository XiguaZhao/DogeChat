//
//  WCSessionDelegate.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/10/15.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import WatchConnectivity

class SessionDelegate: NSObject, WCSessionDelegate {
    
    static let shared = SessionDelegate()
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        
    }
    #endif
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        NotificationCenter.default.post(name: .wcSessionMessage, object: nil, userInfo: message)
    }
    
}
