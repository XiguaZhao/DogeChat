//
//  Call.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/22.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

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
        state = .active
    }
    
    func end() {
        state = .ended
    }
    
}
