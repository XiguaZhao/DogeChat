//
//  Call.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/22.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

import UIKit
import DogeChatNetwork

enum CallState {
    case connecting
    case active
    case held
    case ended
}

enum ConnectedState {
    case pending
    case complete
}

class Call: NSObject {

    let uuid: UUID
    let outgoing: Bool
    let handle: String
    var rejectBySelf = true
    
    var state: CallState = .ended {
        didSet {
            stateChanged?()
        }
    }
    
    var connectedState: ConnectedState = .pending {
        didSet {
            connectedStateChanged?()
        }
    }
    
    var stateChanged: (() -> Void)?
    var connectedStateChanged: (() -> Void)?
    
    init(uuid: UUID, outgoing: Bool = false, handle: String) {
        self.uuid = uuid
        self.outgoing = outgoing
        self.handle = handle
    }
    
    func start(complection: (( _ success: Bool) -> Void)?) {
        complection?(true)
    }
    
    func answer() {
        WebSocketManager.shared.responseVoiceChat(to: handle, uuid: uuid.uuidString, response: "accept")
        WebSocketManager.shared.nowCallUUID = uuid
        AppDelegate.shared.callWindow.assignValueForAlwaysDisplay(name: handle)
        AppDelegate.shared.switcherWindow.assignValueForAlwaysDisplay(name: "内/外放")
        state = .active
        rejectBySelf = false
    }
    
    func cancelBySelf() {
        WebSocketManager.shared.endCall(uuid: uuid.uuidString, with: handle)
        state = .ended
        rejectBySelf = true
    }
    
    func end() {
        Recorder.sharedInstance().stopRecordAndPlay()
        WebSocketManager.shared.endCall(uuid: uuid.uuidString, with: handle)
        AppDelegate.shared.callWindow.nestedVC.tapped(nil)
        AppDelegate.shared.switcherWindow.isHidden = true
        state = .ended
    }
    
}
