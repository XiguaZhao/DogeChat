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
import Gzip
import DataCompression

func playSound(needSound: Bool = true) {
    if UIApplication.shared.applicationState == .active {
        if needSound {
            AudioServicesPlaySystemSound(1015)
        }
    }
}

class WebSocketManagerAdapter: NSObject {
    
    var username = ""
    weak var sceneDelegate: SceneDelegate?
    @objc static var usernameToAdapter = [String : WebSocketManagerAdapter]()
    weak var manager: WebSocketManager!
    @objc var readyToSendVideoData = false {
        didSet {
            guard readyToSendVideoData == true else { return }
            DispatchQueue.main.async {
                #if !targetEnvironment(macCatalyst)
                let vc = VideoChatViewController()
                vc.username = self.username
                self.navigationController?.present(vc, animated: true, completion: nil)
                #endif
            }
        }
    }
    
    var navigationController: UINavigationController? {
        return (sceneDelegate as? SceneDelegate)?.navigationController
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
        NotificationCenter.default.addObserver(self, selector: #selector(emojiPathsFetched(noti:)), name: .emojiPathsFetched, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(sendToken(noti:)), name: .sendToken, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(startCall(noti:)), name: .startCall, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(preloadEmojiPaths(noti:)), name: .preloadEmojiPaths, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(playSound(_:)), name: .playSound, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(voiceChatAccept(noti:)), name: .voiceChatAccept, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(endVoiceChat(_:)), name: .endVoiceChat, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveRealTimeDrawData(noti:)), name: .receiveRealTimeDrawData, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveDrawMessageUpdate(_:)), name: .drawMessageUpdate, object: username)
    }
        
    @objc public func playSound(_ noti: Notification) {
        var needSound = true
        if let mute = noti.userInfo?["mute"] as? Bool, mute == true {
            needSound = false
        }
        DogeChat.playSound(needSound: needSound)
    }
    
    
    @objc func emojiPathsFetched(noti: Notification) {
        let pathToID = noti.userInfo as! [String : String]
        EmojiSelectView.emojiPathToId = pathToID
    }
    
    @objc func sendToken(noti: Notification) {
        if UIApplication.shared.supportsMultipleScenes,
            let mainUsername = UserDefaults(suiteName: "group.dogechat.zhaoxiguang")?.value(forKey: "mainUsername") as? String,
            mainUsername != self.username {
            return
        }
        manager.commonWebSocket.sendToken((UIApplication.shared.delegate as! AppDelegate).deviceToken)
        manager.commonWebSocket.sendVoipToken(AppDelegate.shared.pushKitToken)
    }
    
    @objc func startCall(noti: Notification) {
        let userInfo = noti.userInfo!
        let name = userInfo["name"] as! String
        let uuid = userInfo["uuid"] as! String
        sceneDelegate?.callManager.startCall(handle: name, uuid: uuid)
    }
    
    @objc func preloadEmojiPaths(noti: Notification) {
        if !AppDelegate.shared.launchedByPushAction {
            manager.getEmojis { (paths) in
                HttpRequestsManager.emojiPaths = paths
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
        Recorder.sharedInstance().delegate = self
        Recorder.sharedInstance().startRecordAndPlay()
    }
    
    @objc func endVoiceChat(_ noti: Notification) {
        let userinfo = noti.userInfo!
        let uuid = userinfo["uuid"] as! String
        Recorder.sharedInstance().stopRecordAndPlay()
        #if !targetEnvironment(macCatalyst)
        if let videoVC = navigationController?.visibleViewController as? VideoChatViewController {
            videoVC.dismiss()
        }
        #endif
        guard let _uuid = UUID(uuidString: uuid),
              let call = sceneDelegate?.callManager.callWithUUID(_uuid) else { return }
        sceneDelegate?.callManager.end(call: call)
    }
    
    @objc func receiveDrawMessageUpdate(_ noti: Notification) {
        guard let message = noti.userInfo?["message"] as? Message else { return }
        message.cellHeight = 0
        if let chatRoomVC = navigationController?.topViewController as? ChatRoomViewController {
            if let index = chatRoomVC.messages.firstIndex(of: message) {
                DispatchQueue.main.async {
                    chatRoomVC.tableView.reloadRows(at: [IndexPath(item: index, section: 0)], with: .none)
                }
            }
        }
    }
    
    func getDrawCell(for message: Message) -> MessageDrawCell? {
        guard let chatVC = SceneDelegate.usernameToDelegate[self.username]?.navigationController.visibleViewController as? ChatRoomViewController else { return nil }
        if let cells = chatVC.tableView.visibleCells as? [MessageBaseCell] {
            if let index = cells.firstIndex(where: { $0.message == message }) {
                return cells[index] as? MessageDrawCell
            }
        }
        return nil
    }
    
    @objc func receiveRealTimeDrawData(noti: Notification) {
        guard let json = noti.userInfo?["json"] as? JSON else { return }
        let uuid = json["uuid"].stringValue
        let _ = json["sender"].stringValue
        guard let targetMessage = manager.messageManager.drawMessages.first(where: { $0.uuid == uuid} ) else { return }
        if let base64Str = json["base64Str"].string {
            guard let strokeData = Data(base64Encoded: base64Str) else { return }
            if let newStroke = (try? PKDrawing(data: strokeData))?.transformed(using: CGAffineTransform(scaleX: targetMessage.drawScale, y: targetMessage.drawScale)) {
                if let cell = self.getDrawCell(for: targetMessage), let drawing = cell.getPKView()?.drawing {
                    let wholeNewDrawing = drawing.appending(newStroke)
                    cell.getPKView()!.drawing = wholeNewDrawing
                    cell.getPKView()?.isScrollEnabled = true
                    let newBounds = wholeNewDrawing.bounds
                    let widthLack = newBounds.maxX > cell.getPKView()!.bounds.maxX
                    let _ = newBounds.maxY > cell.getPKView()!.bounds.maxY
                    if widthLack {
                        cell.getPKView()!.drawing = cell.getPKView()!.drawing.transformed(using: CGAffineTransform(scaleX: 0.8, y: 0.8))
                        targetMessage.drawScale *= 0.8
                    }
                    cell.getPKView()?.scrollRectToVisible(newStroke.bounds, animated: true)
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
            #if !targetEnvironment(macCatalyst)
            if let vc = navigationController?.visibleViewController as? VideoChatViewController {
                vc.didReceiveVideoData(data)
            }
            #endif
        } else if type == 2 { // 音频
            let voiceData = (data as NSData).subdata(with: NSRange(location: 16, length: Int(length)))
            if Recorder.sharedInstance().receivedData == nil {
                Recorder.sharedInstance().receivedData = NSMutableData()
            }
            Recorder.sharedInstance().receivedData?.append(voiceData)
            let videoInfoData = (data as NSData).subdata(with: NSRange(location: 4, length: 4))
            let videoInfo = Recorder.int(with: videoInfoData)
            if videoInfo == 1 { // 说明想要视频
                #if !targetEnvironment(macCatalyst)
                if UIApplication.shared.applicationState == .active && !navigationController!.visibleViewController!.isKind(of: VideoChatViewController.self) {
                    readyToSendVideoData = true
                    Recorder.sharedInstance().needSendVideo = true
                }
                #endif
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

func compressImage(_ image: UIImage, needSave: Bool = true) -> (image: UIImage, fileUrl: URL, size: CGSize) {
    var size = image.size
    let ratio = size.width / size.height
    let width: CGFloat = min(image.size.width / UIScreen.main.scale, UIScreen.main.bounds.width)
    let height = floor(width / ratio)
    size = CGSize(width: width, height: height)
    var result: UIImage!
    DispatchQueue.global().sync {
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        result = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
    }
    let fileUrl = URL(string: "file://" + NSTemporaryDirectory() + UUID().uuidString + ".jpg")!
    if needSave {
        try? result.jpegData(compressionQuality: 0.3)?.write(to: fileUrl)
    }
    return (result, fileUrl, result.size)
}


