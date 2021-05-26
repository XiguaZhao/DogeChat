//
//  ProviderDelegate.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/22.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

import CallKit
import AVFoundation
import YPTransition

class ProviderDelegate: NSObject {
    
    private let callManager: CallManager
    private let provider: CXProvider
    
    init(callManager: CallManager) {
        self.callManager = callManager
        self.provider = CXProvider(configuration: ProviderDelegate.providerConfiguration)
        super.init()
        provider.setDelegate(self, queue: nil)
    }
    
    static var providerConfiguration: CXProviderConfiguration = {
        let providerConfiguration = CXProviderConfiguration(localizedName: "DogeChat")
        providerConfiguration.supportsVideo = false
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.generic]
        
        return providerConfiguration
    }()
    
    func reportIncomingCall(uuid: UUID, handle: String, completion: ((Error?) -> Void)?) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        update.hasVideo = false
        print("report")
        provider.reportNewIncomingCall(with: uuid, update: update) { (error) in
            if error == nil {
                let call = Call(uuid: uuid, handle: handle)
                self.callManager.add(call: call)
            }
            completion?(error)
        }
    }

}

extension ProviderDelegate: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        for call in callManager.calls {
            call.end()
        }
        callManager.removeAllCalls()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        startAudio()
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        let call = Call(uuid: action.callUUID, outgoing: true, handle: action.handle.value)
        configureAudioSession()
        
        call.connectedStateChanged = { [weak self, weak call] in
            guard let self = self, let call = call else { return }
            if call.connectedState == .pending {
                self.provider.reportOutgoingCall(with: call.uuid, startedConnectingAt: nil)
            } else if call.connectedState == .complete {
                self.provider.reportOutgoingCall(with: call.uuid, connectedAt: nil)
            }
        }
        call.start { [weak self, weak call] (success) in
            guard let self = self, let call = call else { return }
            
            if success {
                action.fulfill()
                self.callManager.add(call: call)
            } else {
                action.fail()
            }
        }
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print(audioSession.category)
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        DispatchQueue.main.async {
            Recorder.sharedInstance().delegate = WebSocketManagerAdapter.shared
            Recorder.sharedInstance().startRecordAndPlay()
        }
        guard let call = callManager.callWithUUID(action.callUUID) else {
            action.fail()
            return
        }
        configureAudioSession()
        
        call.answer()
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        guard let call = self.callManager.callWithUUID(action.callUUID) else {
            action.fail()
            return
        }
        WebSocketManagerAdapter.shared.readyToSendVideoData = false
        Recorder.sharedInstance().needSendVideo = false
        stopAudio()
        call.end()
        action.fulfill()
        WebSocketManager.shared.nowCallUUID = nil
        if call.rejectBySelf {
            call.cancelBySelf()
        }
        callManager.remove(call: call)
    }
}

