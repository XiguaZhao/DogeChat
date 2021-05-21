//
//  WebSocketManagerAdapter.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/6.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import YPTransition

class WebSocketManagerAdapter: NSObject {
    
    @objc static let shared = WebSocketManagerAdapter()
    let manager = WebSocketManager.shared
    @objc var readyToSendVideoData = false {
        didSet {
            guard readyToSendVideoData == true else { return }
            DispatchQueue.main.async {
                AppDelegate.shared.navigationController.present(VideoChatViewController(), animated: true, completion: nil)
            }
        }
    }
        
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(emojiPathsFetched(noti:)), name: .emojiPathsFetched, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sendToken), name: .sendToken, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(startCall(noti:)), name: .startCall, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(preloadEmojiPaths), name: .preloadEmojiPaths, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveVoiceData(_:)), name: .receiveVoiceData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveUnreadMessage(_:)), name: .receiveUnreadMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playSound(_:)), name: .playSound, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(voiceChatAccept), name: .voiceChatAccept, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(endVoiceChat(_:)), name: .endVoiceChat, object: nil)
        manager.dataDelegate = self
    }
    
    @objc public func playSound(_ noti: Notification) {
        var needSound = true
        if let sound = noti.object as? Bool, sound == false {
            needSound = false
        }
        playSound(needSound: needSound)
    }
    
    public func playSound(needSound: Bool = true) {
        if UIApplication.shared.applicationState == .active {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            if needSound {
                AudioServicesPlaySystemSound(1007)
            }
        }
    }
    
    @objc func emojiPathsFetched(noti: Notification) {
        let userInfo = noti.userInfo!
        let id = userInfo["id"] as! String
        let path = userInfo["path"] as! String
        EmojiSelectView.emojiPathToId[path] = id
    }
    
    @objc func sendToken() {
        manager.sendToken((UIApplication.shared.delegate as! AppDelegate).deviceToken)
        manager.sendVoipToken(AppDelegate.shared.pushKitToken)
    }
    
    @objc func startCall(noti: Notification) {
        let userInfo = noti.userInfo!
        let name = userInfo["name"] as! String
        let uuid = userInfo["uuid"] as! String
        AppDelegate.shared.callManager.startCall(handle: name, uuid: uuid)
    }
    
    @objc func preloadEmojiPaths() {
        if !AppDelegate.shared.launchedByPushAction {
            manager.getEmojis { [weak self] (paths) in
                self?.manager.emojiPaths = paths
            }
        }
    }
    
    @objc func receiveVoiceData(_ noti: Notification) {
        guard let data = noti.object as? Data else { return }
        if Recorder.sharedInstance().receivedData == nil {
            Recorder.sharedInstance().receivedData = NSMutableData()
        }
        Recorder.sharedInstance().receivedData?.append(data)
    }
    
    @objc func receiveUnreadMessage(_ noti: Notification) {
        let userInfo = noti.userInfo!
        let newMessages = userInfo["messages"] as! [Message]
        let isPublic = userInfo["isPublic"] as! Bool
        if let chatVC = AppDelegate.shared.navigationController.topViewController as? ChatRoomViewController, chatVC.navigationItem.title == (isPublic ? "群聊" : newMessages.first?.senderUsername) {
            chatVC.insertNewMessageCell(newMessages)
        } else {
            for message in newMessages {
                manager.postNotification(message: message)
            }
        }
        if newMessages.count != 0 {
            playSound()
        }
    }
    
    @objc func voiceChatAccept() {
        Recorder.sharedInstance().delegate = self
        Recorder.sharedInstance().startRecordAndPlay()
    }
    
    @objc func endVoiceChat(_ noti: Notification) {
        let userinfo = noti.userInfo!
        let uuid = userinfo["uuid"] as! String
        Recorder.sharedInstance().stopRecordAndPlay()
        if let videoVC = AppDelegate.shared.navigationController.visibleViewController as? VideoChatViewController {
            videoVC.dismiss()
        }
        guard let _uuid = UUID(uuidString: uuid),
              let call = AppDelegate.shared.callManager.callWithUUID(_uuid) else { return }
        AppDelegate.shared.callManager.end(call: call)
    }
}

extension WebSocketManagerAdapter: VoiceDelegate, WebSocketDataDelegate {
    func didReceiveData(_ data: Data!) {
        let range = NSRange(location: 12, length: 4)
        let typeData: NSData = (data as NSData).subdata(with: range) as NSData
        let type = Recorder.int(with: typeData as Data)
        let lengthData = (data as NSData).subdata(with: NSRange(location: 8, length: 4))
        let length = Recorder.int(with: lengthData)
        if type == 1 { // 视频
            if let vc = AppDelegate.shared.navigationController.visibleViewController as? VideoChatViewController {
                vc.didReceiveVideoData(data)
            }
        } else if type == 2 { // 音频
            let voiceData = (data as NSData).subdata(with: NSRange(location: 16, length: Int(length)))
            if Recorder.sharedInstance().receivedData == nil {
                Recorder.sharedInstance().receivedData = NSMutableData()
            }
            Recorder.sharedInstance().receivedData?.append(voiceData)
            let videoInfoData = (data as NSData).subdata(with: NSRange(location: 4, length: 4))
            let videoInfo = Recorder.int(with: videoInfoData)
            if videoInfo == 1 { // 说明想要视频
                if UIApplication.shared.applicationState == .active && !AppDelegate.shared.navigationController.visibleViewController!.isKind(of: VideoChatViewController.self) {
                    readyToSendVideoData = true
                    Recorder.sharedInstance().needSendVideo = true
                }
            }
        }
    }
    
    func time(toSend data: Data) {
        manager.sendVoiceData(data)
    }
}
