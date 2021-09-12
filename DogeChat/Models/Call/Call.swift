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
    let username: String
    
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
    
    private var manager: WebSocketManager! {
        WebSocketManager.usersToSocketManager[username]
    }
    
    init(uuid: UUID, outgoing: Bool = false, handle: String, username: String) {
        self.uuid = uuid
        self.outgoing = outgoing
        self.handle = handle
        self.username = username
    }
    
    func start(complection: (( _ success: Bool) -> Void)?) {
        complection?(true)
    }
    
    func answer() {
        manager.responseVoiceChat(to: handle, uuid: uuid.uuidString, response: "accept")
        manager.nowCallUUID = uuid
        AppDelegate.shared.callWindow.assignValueForAlwaysDisplay(name: handle)
        AppDelegate.shared.switcherWindow.assignValueForAlwaysDisplay(name: "内/外放")
        state = .active
        rejectBySelf = false
    }
    
    func cancelBySelf() {
        manager.endCall(uuid: uuid.uuidString, with: handle)
        state = .ended
        rejectBySelf = true
    }
    
    func end() {
        Recorder.sharedInstance().stopRecordAndPlay()
        manager.endCall(uuid: uuid.uuidString, with: handle)
        AppDelegate.shared.callWindow.nestedVC.tapped(nil)
        AppDelegate.shared.switcherWindow.isHidden = true
        state = .ended
    }
    
}
