//
//  WebSocketManagerAdapter.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/6.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import Foundation
import DogeChatNetwork
import SwiftyJSON
import DogeChatUniversal
import DataCompression
import PencilKit
import DogeChatCommonDefines

func playSound(needSound: Bool = true) {
    if UIApplication.shared.applicationState == .active {
        if needSound {
            AudioServicesPlaySystemSound(1015)
        }
    }
}

class WebSocketManagerAdapter: NSObject {
    
    var username = ""
    weak var sceneDelegate: AnyObject?
    static var shared = WebSocketManagerAdapter(manager: WebSocketManager.shared, username: WebSocketManager.shared.myInfo.username)
    @objc static var usernameToAdapter = [String : WebSocketManagerAdapter]()
    weak var manager: WebSocketManager!
    @objc var readyToSendVideoData = false {
        didSet {
            guard readyToSendVideoData == true else { return }
            DispatchQueue.main.async {
                if #available(iOS 13.0, *) {
                    let vc = VideoChatViewController()
                    vc.username = self.username
                    self.navigationController?.present(vc, animated: true, completion: nil)
                }
            }
        }
    }
    
    var navigationController: UINavigationController? {
        if #available(iOS 13, *) {
            return (sceneDelegate as? SceneDelegate)?.navigationController
        } else {
            return AppDelegateUI.shared.navController
        }
    }
    
    var chatRoom: ChatRoomViewController? {
        if let nav = navigationController {
            for vc in nav.viewControllers {
                if let chatVC = vc as? ChatRoomViewController {
                    return chatVC
                }
            }
        }
        return nil
    }
    
    convenience init(manager: WebSocketManager, username: String) {
        self.init()
        self.manager = manager
        self.username = username
        manager.commonWebSocket.dataDelegate = self
        registerNotification()
    }
    
    override init() {
        super.init()
    }
    
    func registerNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(sendToken(noti:)), name: .sendToken, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(startCall(noti:)), name: .startCall, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(preloadEmojiPaths(noti:)), name: .preloadEmojiPaths, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playSound(_:)), name: .playSound, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(voiceChatAccept(noti:)), name: .voiceChatAccept, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(endVoiceChat(_:)), name: .endVoiceChat, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveRealTimeDrawData(noti:)), name: .receiveRealTimeDrawData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveDrawMessageUpdate(_:)), name: .drawMessageUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveVoiceChatRequestNoti(_:)), name: .receiveVoiceChatRequest, object: nil)
    }
        
    @objc public func playSound(_ noti: Notification) {
        if noti.object as? String != self.username { return }
        var needSound = true
        if let mute = noti.userInfo?["mute"] as? Bool, mute == true {
            needSound = false
        }
        DogeChat.playSound(needSound: needSound)
    }
    
    
    @objc func sendToken(noti: Notification) {
        if noti.object as? String != self.username { return }
        if #available(iOS 13.0, *) {
            if SceneDelegate.usernameToDelegate.count > 1,
               let mainUsername = UserDefaults(suiteName: groupName)?.value(forKey: "mainUsername") as? String,
               mainUsername != self.username {
                return
            }
            manager.commonWebSocket.sendVoipToken(AppDelegate.shared.pushKitToken)
        }
        manager.commonWebSocket.sendToken((UIApplication.shared.delegate as! AppDelegate).deviceToken)
    }
    
    @objc func startCall(noti: Notification) {
        if noti.object as? String != self.username { return }
        let userInfo = noti.userInfo!
        let name = userInfo["name"] as! String
        let uuid = userInfo["uuid"] as! String
        if #available(iOS 13, *) {
            (sceneDelegate as? SceneDelegate)?.callManager.startCall(handle: name, uuid: uuid)
        }
    }
    
    @objc func preloadEmojiPaths(noti: Notification) {
        if noti.object as? String != self.username { return }
        if !AppDelegate.shared.launchedByPushAction {
            manager.getEmojis { _ in
            }
        }
    }
    
    @objc func receiveVoiceChatRequestNoti(_ noti: Notification) {
        if #available(iOS 13, *) {
            if noti.object as? String != self.username { return }
            guard let _
                    = noti.userInfo?["sender"] as? String,
                  let uuid = noti.userInfo?["uuid"] as? String,
                  let finalUUID = UUID(uuidString: uuid)
            else { return }
            AppDelegate.shared.nowCallUUID = finalUUID
            if let sceneDelegate = SceneDelegate.usernameToDelegate.first?.value {
                sceneDelegate.socketManager?.nowCallUUID = finalUUID
//                sceneDelegate.providerDelegate.reportIncomingCall(uuid: finalUUID, handle: sender) { (error) in
//                    guard error == nil else { return }
//                    sceneDelegate.notificationManager.prepareVoiceChat(caller: sender, uuid: finalUUID)
//                }
            }
        }
    }
    
    
    deinit {
        print("adapterDeinit")
    }
    
    @objc func receiveVoiceData(_ noti: Notification) {
        guard let data = noti.object as? Data else { return }
        if Recorder.sharedInstance().receivedData == nil {
            Recorder.sharedInstance().receivedData = NSMutableData()
        }
        Recorder.sharedInstance().receivedData?.append(data)
    }
            
    @objc func voiceChatAccept(noti: Notification) {
        if noti.object as? String != self.username { return }
        Recorder.sharedInstance().delegate = self
        Recorder.sharedInstance().startRecordAndPlay()
    }
    
    @objc func endVoiceChat(_ noti: Notification) {
        if #available(iOS 13, *) {
            if noti.object as? String != self.username { return }
            let userinfo = noti.userInfo!
            let uuid = userinfo["uuid"] as! String
            Recorder.sharedInstance().stopRecordAndPlay()
            if let videoVC = navigationController?.visibleViewController as? VideoChatViewController {
                videoVC.dismiss(animated: true, completion: nil)
            }
            guard let _uuid = UUID(uuidString: uuid),
                  let call = (sceneDelegate as? SceneDelegate)?.callManager.callWithUUID(_uuid) else { return }
            (sceneDelegate as? SceneDelegate)?.callManager.end(call: call)
        }
    }
    
    @objc func receiveDrawMessageUpdate(_ noti: Notification) {
        if noti.object as? String != self.username { return }
        guard let message = noti.userInfo?["message"] as? Message else { return }
        message.cellHeight = 0
        if let chatRoomVC = navigationController?.topViewController as? ChatRoomViewController {
            if let index = chatRoomVC.messages.firstIndex(of: message) {
                chatRoomVC.messages[index] = message
                DispatchQueue.main.async {
                    chatRoomVC.tableView.reloadRows(at: [IndexPath(item: index, section: 0)], with: .none)
                }
            }
        }
    }
    
    func getDrawCell(for message: Message) -> MessageDrawCell? {
        if #available(iOS 13, *) {
            guard let chatVC = SceneDelegate.usernameToDelegate[self.username]?.navigationController.visibleViewController as? ChatRoomViewController else { return nil }
            if let cells = chatVC.tableView.visibleCells as? [MessageBaseCell] {
                if let index = cells.firstIndex(where: { $0.message == message }) {
                    return cells[index] as? MessageDrawCell
                }
            }
        }
        return nil
    }
    
    @objc func receiveRealTimeDrawData(noti: Notification) {
        if #available(iOS 13, *) {
            if noti.object as? String != self.username { return }
            guard let json = noti.userInfo?["json"] as? JSON else { return }
            let uuid = json["uuid"].stringValue
            let _ = json["sender"].stringValue
            guard let targetMessage = manager.messageManager.drawMessages.first(where: { $0.uuid == uuid} ) else { return }
            if let base64Str = json["base64Str"].string {
                guard let strokeData = Data(base64Encoded: base64Str) else { return }
                if let newStroke = (try? PKDrawing(data: strokeData))?.transformed(using: CGAffineTransform(scaleX: targetMessage.drawScale, y: targetMessage.drawScale)) {
                    if let cell = self.getDrawCell(for: targetMessage), let drawView = cell.getPKView() {
                        let wholeNewDrawing = drawView.drawing.appending(newStroke)
                        drawView.drawing = wholeNewDrawing
                        drawView.isScrollEnabled = true
                        let newBounds = wholeNewDrawing.bounds
                        let widthLack = newBounds.maxX > drawView.bounds.maxX
                        let _ = newBounds.maxY > drawView.bounds.maxY
                        if widthLack {
                            cell.getPKView()!.drawing = drawView.drawing.transformed(using: CGAffineTransform(scaleX: 0.8, y: 0.8))
                            targetMessage.drawScale *= 0.8
                        }
                        cell.getPKView()?.scrollRectToVisible(newStroke.bounds, animated: true)
                    }
                }
            }
        }
    }
        
}

extension WebSocketManagerAdapter: VoiceDelegate, WebSocketDataDelegate {
    func didReceiveData(_ data: Data!) {
        guard let data = data.decompress(withAlgorithm: .zlib) else { return }
        let range = NSRange(location: 12, length: 4)
        let typeData: NSData = (data as NSData).subdata(with: range) as NSData
        let type = Recorder.int(with: typeData as Data)
        let lengthData = (data as NSData).subdata(with: NSRange(location: 8, length: 4))
        let length = Recorder.int(with: lengthData)
        if type == 1 { // 视频
            if #available(iOS 13.0, *) {
                if let vc = navigationController?.visibleViewController as? VideoChatViewController {
                    vc.didReceiveVideoData(data)
                }
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
                if UIApplication.shared.applicationState == .active && !navigationController!.visibleViewController!.isKind(of: VideoChatViewController.self) {
                    readyToSendVideoData = true
                    Recorder.sharedInstance().needSendVideo = true
                }
            }
        }
    }
    
    func time(toSend data: Data) {
        print("压缩前\(data)")
        if let compressed = data.compress(withAlgorithm: .zlib) {
            manager.sendVoiceData(compressed)
        }
    }
    
    
}



