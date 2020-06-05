//
//  WatchSession.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/5/26.
//  Copyright © 2020 Luke Parham. All rights reserved.
//

import Foundation
import WatchConnectivity

protocol WCStatus: class {
  func wcStatusChangedTo(_ status: Bool)
}

class WatchSession: NSObject, WCSessionDelegate {
  
  static let shared = WatchSession()
  weak var wcStatusDelegate: WCStatus?
  let session: WCSession!
  
  private override init() {
    session = WCSession.isSupported() ? .default : nil
    super.init()
    session.delegate = self
    session.activate()
  }
  
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    switch activationState {
    case .activated:
      print("已激活")
    default:
      print("激活失败")
    }
  }
  
  func sessionDidBecomeInactive(_ session: WCSession) {
    print("inactive")
  }
  
  func sessionDidDeactivate(_ session: WCSession) {
    
  }
  
  func sessionReachabilityDidChange(_ session: WCSession) {
    wcStatusDelegate?.wcStatusChangedTo(session.isReachable)
  }
  
}

