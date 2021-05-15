//
//  CallManager.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/22.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

import CallKit
import YPTransition

class CallManager: NSObject {
    
    var callsChangedHandler: (() -> Void)?
    private let callController = CXCallController()
    
    var calls: [Call] = []
    
    func hasCall() -> Bool {
        return !calls.isEmpty
    }
    
    func callWithUUID(_ uuid: UUID) -> Call? {
        guard let index = calls.firstIndex(where: { $0.uuid == uuid }) else { return nil }
        return calls[index]
    }
    
    func add(call: Call) {
        calls.append(call)
        call.stateChanged = { [weak self] in
            guard let self = self else { return }
            self.callsChangedHandler?()
        }
        callsChangedHandler?()
    }
    
    func remove(call: Call) {
        guard let index = calls.firstIndex(where: { $0.uuid == call.uuid }) else { return }
        calls.remove(at: index)
    }
    
    func removeAllCalls() {
        calls.removeAll()
        callsChangedHandler?()
    }
    
    func startCall(handle: String, uuid: String) {
        guard let uuid = UUID(uuidString: uuid) else { return }
        let handle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.isVideo = false
        AppDelegate.shared.callWindow.assignValueForAlwaysDisplay(name: handle.value)
        let transaction = CXTransaction(action: startCallAction)
        requestTransition(transaction)
    }
    
    func end(call: Call) {
        let endCallAction = CXEndCallAction(call: call.uuid)
        let transaction = CXTransaction(action: endCallAction)
        requestTransition(transaction)
    }

    private func requestTransition(_ transaction: CXTransaction) {
        callController.request(transaction) { (error) in
            if let error = error {
                print("transaction发生错误: \(error)")
            } else {
                print("请求transaction成功")
            }
        }
    }
}
