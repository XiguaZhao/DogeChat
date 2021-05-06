//
//  WebSocketManager.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/5/4.
//  Copyright © 2020 Xiguang Zhao. All rights reserved.
//

import Foundation
import SwiftyJSON
import WatchConnectivity
import CoreLocation
import AudioToolbox
import YPTransition

@objc protocol MessageDelegate: class {
    @objc optional func updateOnlineNumber(to newNumber: Int)
    @objc optional func receiveMessages(_ messages: [Message], pages: Int)
    @objc optional func newFriend()
    @objc optional func newFriendRequest()
    @objc func revokeMessage(_ id: Int)
    @objc func revokeSuccess(id: Int)
}

//@objc enum MessageOption: Int {
//    case toAll
//    case toOne
//}

class WebSocketManager: NSObject {
    
    let session = AFHTTPSessionManager()
    var cookie = ""
    let url_pre = "https://procwq.top/"
    let encrypt = EncryptMessage()
    var maxId: Int {
        get {
            (UserDefaults.standard.value(forKey: "maxID") as? Int) ?? 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "maxID")
        }
    }
    var myName = ""
    private var _pingTimer: Timer?
    private var _checkNotSendTimer: Timer?
    var socket: SRWebSocket!
    var toBeUpdatedMessages = [Message]()
    weak var messageDelegate: MessageDelegate?
    var messagesGroup: [Message] = []
    var messagesSingle: [String: [Message]] = [:]
    var notSendContent = [NSObject]() // 这个是任何要发送的内容
    var imageDict = [String: Any]()
    var emojiPaths = [String]()
    var connected = false
    var tapFromSystemPhoneInfo: (name: String, uuid: String)?
    var backgroundTasks = [UIBackgroundTaskIdentifier]()
    var nowCallUUID: UUID! {
        didSet {
            print("nowCallUUID set")
        }
    }
    
    static let shared: WebSocketManager = WebSocketManager()
    
    private override init() {
        session.requestSerializer = AFJSONRequestSerializer()
        super.init()
        SDImageCache.shared.config.shouldCacheImagesInMemory = false
    }
    
    func playSound(needSound: Bool = true) {
        if UIApplication.shared.applicationState == .active {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            if needSound {
                AudioServicesPlaySystemSound(1007)
            }
        }
    }
    
    func login(username: String, password: String, completion: @escaping (String)->Void) {
        let paras = ["username": username, "password": password]
        session.post(url_pre + "auth/login", parameters: paras, headers: nil, progress: nil, success: { (task, response) in
            guard let response = response else { return }
            let json = JSON(response)
            print(json)
            let loginResult = json["message"].stringValue
            if loginResult == "登录成功" {
                self.myName = username
                if let responseDetails = task.response as? HTTPURLResponse {
                    let headers = responseDetails.allHeaderFields
                    if let cookieStr = headers["Set-Cookie"] as? String {
                        self.cookie = cookieStr.components(separatedBy: ";")[0].components(separatedBy: "=")[1]
                    }
                }
                completion(loginResult)
            } else {
                completion(loginResult)
            }
        }, failure: { task, error in
            completion("fail")
        })
    }
    
    func pingTimer() -> Timer? {
        if self._pingTimer == nil {
            _pingTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true, block: { [weak self] (_) in
                if self?.socket != nil && self?.socket.readyState == .OPEN {
                    print("发送ping")
                    self?.socket.sendPing(Data())
                }
            })
        }
        return self._pingTimer
    }
    
    func invalidatePingTimer() {
        if _pingTimer == nil { return }
        _pingTimer?.invalidate()
        _pingTimer = nil
    }
    
    func checkNotSendTimer() -> Timer? {
        if self._checkNotSendTimer == nil {
            _pingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { [weak self] (_) in
                if let self = self {
                    self.resendAnyContents()
                }
            })
        }
        return self._checkNotSendTimer
    }
    
    func connect() {
        var request = URLRequest(url: URL(string: "wss://procwq.top/webSocket")!)
        request.addValue("SESSION="+cookie, forHTTPHeaderField: "Cookie")
        if connected {
            return
        }
        socket = SRWebSocket(urlRequest: request)
        socket.delegate = self
        socket.open()
    }
    
    func disconnect() {
        guard socket != nil else {
            return
        }
        socket.close()
    }
    
    func send(_ message: Any!) {
        if socket != nil, socket.readyState == .OPEN {
            socket.send(message)
            print("发送\(message ?? "")")
        } else {
            print("socket未连接 \(message ?? "")")
            if let message = message as? NSObject{
                notSendContent.append(message)
            } else if let message = message as? String {
                notSendContent.append(message as NSString)
            }
            connect()
        }
    }
    
    func makeJsonString(for dict: [String: Any]) -> String {
        let jsonData = try! JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
        let jsonStr = String(data: jsonData, encoding: .utf8)!
        return jsonStr
    }
    
    func prepareEncrypt() {
        let publicKey = encrypt.getPublicKey()
        guard !publicKey.isEmpty else { return }
        let paras = ["method": "publicKey", "key": publicKey]
        send(makeJsonString(for: paras))
    }
    
    func getContacts(completion: @escaping ([String], Error?) -> Void)  {
        session.get(url_pre + "friendship/getAllFriends", parameters: nil, headers: nil, progress: nil, success: { (task, response) in
            guard let response = response else { return }
            let json = JSON(response)
            guard json["status"].stringValue == "success" else {
                return
            }
            var usernames: [String] = []
            let friends = json["friends"].arrayValue
            for friend in friends {
                usernames.append(friend["username"].stringValue)
            }
            self.connect()
            completion(usernames, nil)
        }, failure: { (task, error) in
            completion([], error)
        })
    }
    
    func sendMessage(_ content: String, to receiver: String = "", from sender: String = "xigua", option: MessageOption, uuid: String, type: String = "text") {
        guard socket != nil, socket.readyState == .OPEN else {
            connect()
            return
        }
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        var paras: [String: Any]
        switch option {
        case .toAll:
            paras = ["method": "sendToAll", "message": content, "receiver": receiver, "sender": sender, "uuid": uuid, "type": type]
        case .toOne:
            let encryptedContent = encrypt.encryptMessage(content)
            paras = ["method": "NewMessage", "message": ["content": encryptedContent, "receiver": receiver, "sender": sender], "uuid": uuid, "type": type]
        }
        send(makeJsonString(for: paras))
    }
    
    func sendToken(_ token: String?) {
        guard let token = token, token.count > 0 else {
            return
        }
        let params = ["method": "token", "token": token]
        send(makeJsonString(for: params))
    }
    
    func sendVoipToken(_ token: String?) {
        guard let token = token, token.count > 0 else {
            return
        }
        let params = ["method": "voipToken", "voipToken": token]
        send(makeJsonString(for: params))
        print("发送voip token" + token)
    }
    
    func endCall(uuid: String, with receiver: String) {
        let params = ["method": "endVoiceChat", "sender": myName, "receiver": receiver, "uuid": uuid]
        send(makeJsonString(for: params))
    }
    
    func sendCallRequst(to receiver: String, uuid: String) {
        let params = ["method": "voiceChat", "sender": myName, "receiver": receiver, "uuid": uuid]
        send(makeJsonString(for: params))
        nowCallUUID = UUID(uuidString: uuid)
    }
        
    func resendAnyContents() {
        for (_, _notSentContent) in self.notSendContent.enumerated() {
            if let message = _notSentContent as? Message {
                let option: MessageOption = message.receiver == "" ? .toAll : .toOne
                self.sendMessage(message.message, to: message.receiver, from: message.senderUsername, option: option, uuid: message.uuid)
                print("重发消息: \(message.message)")
            } else if let notSend = _notSentContent as? NSString {
                self.send(notSend as String)
                if let index = self.notSendContent.firstIndex(of: notSend) {
                    self.notSendContent.remove(at: index)
                }
            }
        }
    }
    
    func sortMessages() {
        messagesGroup.sort(by: { $0.id < $1.id })
        for (friendName, _) in messagesSingle {
            messagesSingle[friendName]?.sort(by: { $0.id < $1.id })
        }
    }
    
    func uploadPhoto(imageUrl: URL, message: Message, uploadProgress: @escaping((Progress) -> Void), success: @escaping((URLSessionTask, Any?) -> Void)) {
        let isGif = imageUrl.absoluteString.hasSuffix(".gif")
        session.post(url_pre+"message/uploadImg", parameters: nil, headers: ["Cookie": "SESSION="+cookie]) { (formData) in
            try? formData.appendPart(withFileURL: imageUrl, name: "upload", fileName: (isGif ? "test.gif" : "test.jpeg"), mimeType: (isGif ? "image/gif" : "image/jpeg"))
        } progress: { (progress) in
            uploadProgress(progress)
        } success: { (task, data) in
            success(task, data)
            NotificationCenter.default.post(name: .uploadSuccess, object: nil, userInfo: ["message": message, "data": data ?? [:]])
        } failure: { (task, error) in
            print(error)
        }
    }
    
    func compressEmojis(_ image: UIImage, needBig: Bool = false) -> Data {
        if needBig {
            return image.pngData()!
        }
        let width: CGFloat = 100
        let size = CGSize(width: width, height: image.size.height * (width / image.size.width))
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!.pngData()!
    }
    
    func getCacheImage(from cache: NSCache<NSString, NSData>, path: String, completion: @escaping ((_ image: UIImage?, _ data: Data?) -> Void)) {
        if let data = cache.object(forKey: path as NSString) {
            completion(nil, data as Data)
        } else {
            SDWebImageManager.shared.loadImage(with: URL(string: path), options: .avoidDecodeImage, progress: nil) { (image, data, error, _, _, _) in
                guard error == nil else { return }
                if let data = data {
                    cache.setObject(data as NSData, forKey: path as NSString)
                    completion(image, data)
                }
            }
        }
    }
    
    //MARK: 表情包
    func getEmojis(completion: @escaping ([String]) -> Void) {
        session.get(url_pre+"star/getStar", parameters: nil, headers: ["Cookie": "SESSION="+cookie], progress: nil, success: { (task, response) in
            let json = JSON(response as Any)
            let emojisData = json["data"].arrayValue
            var filePaths = [String]()
            for emojiData in emojisData {
                let id = emojiData["starId"].stringValue
                let path = self.encrypt.decryptMessage(emojiData["content"].stringValue)
                filePaths.append(path)
                EmojiSelectView.emojiPathToId[path] = id
            }
            completion(filePaths)
        }, failure: nil)
    }
    
    func deleteEmoji(_ path: String, completion: @escaping (() -> Void)) {
        if let id = EmojiSelectView.emojiPathToId[path] {
            session.post(url_pre + "star/delStar?starId=\(id)", parameters: nil, headers: nil, progress: nil) { (task, response) in
                guard let response = response else { return }
                if JSON(response)["status"].stringValue == "success" {
                    completion()
                }
            } failure: { (task, error) in
            }
        }
    }
    
    func starAndUploadEmoji(filePath: String, isGif: Bool) {
        let paras = ["content": encrypt.encryptMessage(filePath), "starType": "file"]
        session.post(url_pre+"star/saveStar", parameters: paras, headers: ["Cookie": "SESSION="+cookie], progress: nil) { (task, data) in
            print(JSON(data as Any))
        } failure: { (task, error) in
            
        }
    }
    
    func sendEmojiInfos(_ messages: [Message], receiver: String) {
        for message in messages {
            var infos = [[String: String]]()
            for emojiInfo in message.emojisInfo {
                let singleEmoji = [
                    "path": emojiInfo.imageLink,
                    "locationX": "\(emojiInfo.x)",
                    "locationY": "\(emojiInfo.y)",
                    "scale": "\(emojiInfo.scale)",
                    "rotate": "\(emojiInfo.rotation)",
                    "lastModifiedBy": "\(emojiInfo.lastModifiedBy)"
                ]
                infos.append(singleEmoji)
            }
            let dict = ["method": "emoji", "message": ["receiver": message.receiver == "PublicPino" ? message.receiver : receiver, "sender": myName, "uuid": message.uuid, "emojis": infos]] as [String : Any]
            send(makeJsonString(for: dict))
        }
    }
    
    func processEmojiInfoChanges(json: JSON) {
        let messageJson = json["message"]
        let emojis = messageJson["emojis"].arrayValue
        let uuid = messageJson["uuid"].stringValue
        let receiver = messageJson["receiver"].stringValue
        let sender = messageJson["sender"].stringValue
        var message: Message?
        if receiver == "PublicPino" {
            if let index = messagesGroup.firstIndex(where: { $0.uuid == uuid }) {
                message = messagesGroup[index]
            }
        } else {
            if let index = messagesSingle[sender]?.firstIndex(where: { $0.uuid == uuid }) {
                message = messagesSingle[sender]![index]
            }
        }
        if let message = message {
            processEmojiInfo(emojis, for: message)
            NotificationCenter.default.post(name: .emojiInfoChanged, object: (receiver, sender), userInfo: ["message": message])
        }
    }
    
    func stringToCGFloat(_ str: String) -> CGFloat {
        if let number = NumberFormatter().number(from: str) {
            return CGFloat(truncating: number)
        } else {
            return 0
        }
    }
    
    func processEmojiInfo(_ infos: [JSON], for message: Message) {
        var emojiInfos = [EmojiInfo]()
        for emoji in infos {
            let newInfo = EmojiInfo(x: stringToCGFloat(emoji["locationX"].stringValue), y: stringToCGFloat(emoji["locationY"].stringValue), rotation: stringToCGFloat(emoji["rotate"].stringValue), scale: stringToCGFloat(emoji["scale"].stringValue), imageLink: emoji["path"].stringValue, lastModifiedBy: emoji["lastModifiedBy"].stringValue)
            if message.option == .toOne { // 私聊
                if (newInfo.lastModifiedBy != myName && message.messageSender == .someoneElse) || (message.messageSender == .ourself && newInfo.lastModifiedBy != myName) {
                    newInfo.x = 1 - newInfo.x
                }
            } else { // 群聊
                if (message.messageSender == .ourself && newInfo.lastModifiedBy != myName) || (message.senderUsername == newInfo.lastModifiedBy && message.senderUsername != myName) {
                    newInfo.x = 1 - newInfo.x
                }
            }
            emojiInfos.append(newInfo)
        }
        message.emojisInfo = emojiInfos
    }

    //MARK: History Messages
    func getUnreadMessage() {
        let paras: [String: Any] = ["method": "getUnreadMessage", "id": maxId]
        send(makeJsonString(for: paras))
    }
    
    func historyMessages(for name: String, pageNum: Int)  {
        let paras: [String: Any] = ["method": "getHistory", "friend": name, "pageNum": pageNum]
        send(makeJsonString(for: paras))
    }
    //MARK: Revoke
    func revokeMessage(id: Int) {
        let paras: [String: Any] = ["method": "revokeMessage", "id": id]
        send(makeJsonString(for: paras))
    }
}

extension WebSocketManager: SRWebSocketDelegate  {
    func webSocketDidOpen(_ webSocket: SRWebSocket!) {
        print("websocket已经打开")
        connected = true
        prepareEncrypt()
        sendToken((UIApplication.shared.delegate as! AppDelegate).deviceToken)
        sendVoipToken(AppDelegate.shared.pushKitToken)
        if let (name, uuid) = tapFromSystemPhoneInfo {
            sendCallRequst(to: name, uuid: uuid)
            AppDelegate.shared.callManager.startCall(handle: name, uuid: uuid)
            tapFromSystemPhoneInfo = nil
        }
        if !AppDelegate.shared.launchedByPushAction {
            self.getEmojis { (paths) in
                self.emojiPaths = paths
            }
        }
        AppDelegate.shared.navigationController.viewControllers.first?.navigationItem.title = "已连接"
        DispatchQueue.main.asyncAfter(deadline: .now()+2) {
            AppDelegate.shared.navigationController.viewControllers.first?.navigationItem.title = self.myName
        }
        pingTimer()?.fire()
        print("开始ping")
    }
    
    func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        print("websocket已关闭: \(String(describing: reason))")
        connected = false
    }
    
    func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
        print("error:=====\(String(describing: error))")
    }
    
    func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        if let message = message as? NSData, message.count > 12 {
            if Recorder.sharedInstance().receivedData == nil {
                Recorder.sharedInstance().receivedData = NSMutableData()
            }
            Recorder.sharedInstance().receivedData?.append(message as Data)
        } else if let text = message as? String {
            print("收到消息")
            print(text)
            parseReceivedMessage(text)
        }
    }
        
    private func parseReceivedMessage(_ jsonString: String) {
        let json = JSON(parseJSON: jsonString)
        let method = json["method"].stringValue
        switch method {
        case "publicKey":
            let key = json["key"].stringValue
            encrypt.key = key
            getUnreadMessage()
            resendAnyContents()
        case "sendToAllSuccess":
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            let id = json["id"].intValue
            let uuid = json["uuid"].stringValue
            maxId = max(maxId, id)
            guard let indexOfMessage = messagesGroup.firstIndex(where: { $0.uuid == uuid }) else { return }
            let message = messagesGroup[indexOfMessage]
            NotificationCenter.default.post(name: .sendSuccess, object: nil, userInfo: ["correctId": id, "toAll": true, "message": message])
        case "sendMessageSuccess":
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            let data = json["data"]
            let uuid = json["uuid"].stringValue
            let id = data["messageId"].intValue
            let receiver = data["receiver"].stringValue
            maxId = max(maxId, id)
            guard let indexOfMessage = messagesSingle[receiver]?.firstIndex(where: { $0.uuid == uuid }),
                  let message = messagesSingle[receiver]?[indexOfMessage] else { return }
            NotificationCenter.default.post(name: .sendSuccess, object: nil, userInfo: ["correctId": id, "toAll": false, "message": message])
        case "sendToAll":  // 收到群聊消息
            let content = json["message"].stringValue
            let sender = json["sender"].stringValue
            let id = json["id"].intValue
            let uuid = json["uuid"].stringValue
            maxId = max(maxId, id)
            let newMessage = wrapMessage(content: content, option: .toAll, sender: sender, receiver: "", id: id, date: "", uuid: uuid)
            messagesGroup.append(newMessage)
            postNotification(message: newMessage)
            playSound()
        case "join":
            let user = json["user"].stringValue
            let number = json["total"].intValue
            messageDelegate?.updateOnlineNumber?(to: number)
            let username = user.components(separatedBy: " ")[0]
            guard username != self.myName else {
                return
            }
        case "getUnreadMessage": // 群聊未读消息,socket连接上后会获取
            let messages = json["messages"].arrayValue
            var newMessages = [Message]()
            for message in messages {
                let id = message["id"].intValue
                maxId = max(maxId, id)
                let sender = message["sender"].stringValue
                let content = message["content"].stringValue
                let uuid = message["uuid"].stringValue
                let newMessage = wrapMessage(content: content, option: .toAll, sender: sender, receiver: myName, id: id, date: "", uuid: uuid)
                messagesGroup.append(newMessage)
                newMessages.append(newMessage)
            }
            if let chatVC = AppDelegate.shared.navigationController.topViewController as? ChatRoomViewController, chatVC.navigationItem.title == "群聊" {
                chatVC.insertNewMessageCell(newMessages)
            } else {
                for message in newMessages {
                    postNotification(message: message)
                }
            }
            if newMessages.count != 0 {
                playSound()
            }
            
        case "NewMessage": // 收到私人消息
            let data = json["data"]["unread_messages"].arrayValue
            var messages = [Message]()
            for msg in data {
                let content = msg["messageContent"].stringValue
                let decrypted = encrypt.decryptMessage(content)
                let sender = msg["messageSender"].stringValue
                let date = msg["messageTime"].stringValue
                let id = msg["messageId"].intValue
                let uuid = msg["uuid"].stringValue
                let newMessage = wrapMessage(content: decrypted, option: .toOne, sender: sender, receiver: myName, id: id, date: date, uuid: uuid)
                messagesSingle.add(newMessage, for: sender)
                messages.append(newMessage)
            }
            if let chatVC = AppDelegate.shared.navigationController.topViewController as? ChatRoomViewController, messages.first?.senderUsername == chatVC.navigationItem.title {
                chatVC.insertNewMessageCell(messages)
                playSound()
            } else {
                for message in messages {
                    postNotification(message: message)
                }
                playSound()
            }
        case "getHistory":  // 获取群聊、个人历史记录
            let pages = json["data"]["pages"].intValue
            let messages = json["data"]["records"].arrayValue
            var result = [Message]()
            for message in messages {
                let id = message["messageId"].intValue
                var content = message["messageContent"].stringValue
                content = encrypt.decryptMessage(content)
                let sender = message["messageSender"].stringValue
                let date = message["messageTime"].stringValue
                let uuid = message["uuid"].stringValue
                let receiver = message["messageReceiver"].stringValue
                let option: MessageOption = (receiver == "PublicPino" ? .toAll : .toOne)
                let newMessage = wrapMessage(content: content, option: option, sender: sender, receiver: receiver, id: id, date: date, uuid: uuid)
                processEmojiInfo(message["emojis"].arrayValue, for: newMessage)
                result.append(newMessage)
            }

            NotificationCenter.default.post(name: .receiveHistoryMessages, object: nil, userInfo: ["messages": result, "pages": pages])
//            messageDelegate?.receiveMessages?(result, pages: pages)
        case "revokeMessageSuccess":
            if json["status"].intValue == 200 {
                let id = json["id"].intValue
                messageDelegate?.revokeSuccess(id: id)
            }
        case "revokeMessage":
            let messageId = json["id"].intValue
            messageDelegate?.revokeMessage(messageId)
        case "NewFriend":
            messageDelegate?.newFriend?()
        case "NewFriendRequest":
            messageDelegate?.newFriendRequest?()
        case "voiceChat":
            let _ = json["sender"].stringValue
            let _ = json["uuid"].stringValue
        case "responseVoiceChat":
            let response = json["response"].stringValue
            let _ = json["uuid"].stringValue
            let _ = json["sender"].stringValue
            if response == "accept" {
                Recorder.sharedInstance().delegate = self
                Recorder.sharedInstance().startRecordAndPlay()
                playSound(needSound: false)
            }
        case "endVoiceChat":
            let _ = json["sender"].stringValue
            let uuid = json["uuid"].stringValue
            Recorder.sharedInstance().stopRecordAndPlay()
            guard let _uuid = UUID(uuidString: uuid),
                  let call = AppDelegate.shared.callManager.callWithUUID(_uuid) else { return }
            AppDelegate.shared.callManager.end(call: call)
        case "emoji":
            processEmojiInfoChanges(json: json)
        default:
            return
        }
    }
    
    func sendVoiceData(_ data: Data!) {
        send(data)
    }
    
    func responseVoiceChat(to sender: String, uuid: String, response: String) {
        let params = ["method": "receiveVoiceChat", "response": response, "sender": myName, "receiver": sender, "uuid": uuid]
        send(makeJsonString(for: params))
        print("发送了response：\(response)")
    }
    
    func wrapMessage(content: String, option: MessageOption, sender: String, receiver: String, id: Int, date: String, uuid: String) -> Message {
        let isImageMessage = content.hasPrefix(url_pre+"/static/image")
        let type: MessageType = isImageMessage ? .image : .text
        return Message(message: (isImageMessage ? "" : content),
                       imageURL: isImageMessage ? content : nil,
                       videoURL: nil,
                       messageSender: (sender == myName ? .ourself : .someoneElse),
                       receiver: receiver,
                       uuid: uuid,
                       sender: sender,
                       messageType: type,
                       option: option,
                       id: id,
                       date: date,
                       sendStatus: (type == .image ? .fail : .success))
    }
    
    private func postNotification(message: Message) {
        NotificationCenter.default.post(name: .receiveNewMessage, object: message)
    }
    
    func notifyWatch(newMessage: Message) {
        var dict = [String: Any]()
        dict["text"] = newMessage.message
        dict["sender"] = (newMessage.messageSender == .ourself) ? "myself" : "others"
        dict["name"] = newMessage.senderUsername
        WatchSession.shared.session.sendMessage(dict, replyHandler: { (_) in
        }, errorHandler: {_ in
            self.toBeUpdatedMessages.append(newMessage)
        })
    }
    
}

extension WebSocketManager: WCStatus {
    func wcStatusChangedTo(_ status: Bool) {
        switch status {
        case true:
            //      for message in toBeUpdatedMessages {
            //        notifyWatch(newMessage: message)
            //      }
            toBeUpdatedMessages.removeAll()
        case false:
            print("lost connection, saving")
        }
    }
}

//MARK: Search Users
extension WebSocketManager {
    
    func search(username: String, completion: @escaping (([String])->Void)) {
        var userInfos = [String]()
        guard let url = (url_pre + "user/search/\(username)").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        session.get(url, parameters: nil, headers: nil, progress: nil, success: { (task, response) in
            guard let data = response else { return }
            let json = JSON(data).arrayValue
            for userInfoJson in json {
                userInfos.append(userInfoJson["username"].stringValue)
            }
            completion(userInfos)
        }, failure: nil)
    }
    
    func applyAdd(_ requested: String, from requester: String, completion: @escaping ((String) -> Void)) {
        let para = ["requested": requested, "requester": requester]
        session.post("\(url_pre)friendRequest/request", parameters: para, headers: nil, progress: nil, success: { (task, response) in
            if let response = response {
                let json = JSON(response)
                let status = json["status"].stringValue
                completion(status)
            }
        }, failure: nil)
    }
    
    func inspectQuery(completion: @escaping (([String], [String], [String])->Void)) {
        session.get("\(url_pre)friendRequest/query/-1", parameters: nil, headers: nil, progress: nil, success: { (task, response) in
            if let response = response {
                let infos = JSON(response).arrayValue
                var names = [String]()
                var requestID = [String]()
                var requestTime = [String]()
                print(infos)
                for info in infos {
                    names.append(info["friendRequester"].stringValue)
                    requestID.append(info["friendRequestId"].stringValue)
                    requestTime.append(info["requestTime"].stringValue)
                }
                completion(names, requestTime, requestID)
            }
        }, failure: nil)
    }
    
    func acceptQuery(requestId: String, complection: @escaping ((String) -> Void)) {
        session.post("\(url_pre)friendRequest/accept/\(requestId)", parameters: nil, headers: nil, progress: nil, success: { (task, response) in
            if let response = response {
                let json = JSON(response)
                complection(json["message"].stringValue)
            }
        }, failure: nil)
    }
    
    //MARK: Sign Up
    func sendValitionCode(to email: String, for purpose: Int, completion: @escaping (String) -> Void) {
        let paras: [String : Any] = ["email": email, "sendFor": purpose]
        session.post(url_pre+"auth/sendCode", parameters: paras, headers: nil, progress: nil, success: { (task, response) in
            guard let data = response else { return }
            print(JSON(data))
            completion(JSON(data)["status"].stringValue)
        }, failure: nil)
    }
    
    func signUp(username: String, password: String, repeatPassword: String, email: String, validationCode: String, completion: @escaping (String) -> Void) {
        let paras = ["username": username, "password": password, "repeatPassword": repeatPassword, "email": email, "validationCode": validationCode]
        var request = URLRequest(url: URL(string: url_pre+"auth/signup")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let jsonData = try! JSONSerialization.data(withJSONObject: paras, options: JSONSerialization.WritingOptions.prettyPrinted)
        request.httpBody = jsonData
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data else { return }
            let json = JSON(data)
            completion(json["status"].stringValue)
        }
        task.resume()
    }
}

extension WebSocketManager: VoiceDelegate {
    func time(toSend data: Data) {
        sendVoiceData(data)
    }
}
