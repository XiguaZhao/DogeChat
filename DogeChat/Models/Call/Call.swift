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
    
    private var manager: WebSocketManager? {
        WebSocketManager.usersToSocketManager.first?.value
    }
    
    init(uuid: UUID, outgoing: Bool = false, handle: String) {
        self.uuid = uuid
        self.outgoing = outgoing
        self.handle = handle
    }
    
    func start(complection: (( _ success: Bool) -> Void)?) {
        complection?(true)
    }
    
    func answer() {
        manager?.responseVoiceChat(to: handle, uuid: uuid.uuidString, response: "accept")
        manager?.nowCallUUID = uuid
        AppDelegate.shared.nowCallUUID = uuid
        SceneDelegate.usernameToDelegate.first?.value.callWindow.assignValueForAlwaysDisplay(name: handle)
        SceneDelegate.usernameToDelegate.first?.value.switcherWindow.assignValueForAlwaysDisplay(name: "内/外放")
        state = .active
        rejectBySelf = false
    }
    
    func cancelBySelf() {
        manager?.endCall(uuid: uuid.uuidString, with: handle)
        state = .ended
        rejectBySelf = true
    }
    
    func end() {
        Recorder.sharedInstance().stopRecordAndPlay()
        manager?.endCall(uuid: uuid.uuidString, with: handle)
        SceneDelegate.usernameToDelegate.first?.value.callWindow.nestedVC.tapped(nil)
        SceneDelegate.usernameToDelegate.first?.value.switcherWindow.isHidden = true
        state = .ended
    }
    
}
