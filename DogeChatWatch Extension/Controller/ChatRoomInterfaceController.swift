//
//  ChatRoomInterfaceController.swift
//  DogeChatWatch Extension
//
//  Created by 赵锡光 on 2021/6/7.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import WatchKit
import DogeChatUniversal

let imageCahce = NSCache<NSString, NSData>()

func syncOnMain(_ block: () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        DispatchQueue.main.sync {
            block()
        }
    }
}

func contentForSpecialType(_ message: Message?) -> String {
    guard let message = message else { return "" }
    switch message.messageType {
    case .text, .join:
        return message.text
    case .image, .livePhoto:
        return "[图片]"
    case .draw:
        return "[速绘]"
    case .video:
        return "[视频]"
    case .track:
        return "[歌曲分享]"
    case .voice:
        return "[语音]"
    }
}

class ChatRoomInterfaceController: WKInterfaceController {
    
    @IBOutlet weak var inputTF: WKInterfaceTextField!
    var input = ""
    @IBAction func inputAction(_ value: NSString?) {
        if let input = value {
            self.input = input as String
            sendAction()
        }
    }
    @IBOutlet weak var table: WKInterfaceTable!
    var friend: Friend! {
        didSet {
            self.setTitle(friendName)
        }
    }
    var isFirstTimeFetch = false
    let manager = SocketManager.shared
    var messages: [Message]!
    var messagesUUIDs: Set<String>! {
        return Set(messages.map { $0.uuid })
    }
    var pagesAndCurNum = (pages: 1, curNum: 1)
    var friendName: String {
        friend.username
    }
    var messageOption: MessageOption {
        friend.isGroup ? .toGroup : .toOne
    }
    let messageRowType = "message"
    static let numberOfHistory = 10
    var emojis = [String]()
    
    override func awake(withContext context: Any?) {
        self.setTitle("awake")
        guard let context = context as? [String: Any],
              let friend = context["friend"] as? Friend,
              let messages = context["messages"] as? [Message],
              let _ = context["messagesUUIDs"] as? Set<String> else { return }
        self.friend = friend
        self.messages = messages
        NotificationCenter.default.addObserver(self, selector: #selector(receiveHistory(noti:)), name: .receiveHistoryMessages, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectEmojiAction(_:)), name: .selectEmoji, object: nil)
        NotificationCenter.default.addObserver(forName: .connecting, object: nil, queue: nil) { [weak self] _ in
            self?.setTitle("正在连接...")
        }
        NotificationCenter.default.addObserver(forName: .connected, object: nil, queue: nil) { [weak self] _ in
            self?.setTitle(SocketManager.shared.messageManager.myName)
        }
        SocketManager.shared.httpManager.getEmoji { emojis in
            self.emojis = emojis
        }
        if messages.isEmpty {
            isFirstTimeFetch = true
            displayHistory()
        } else {
            showAlreadyMessages()
            if messages.count < 10 {
                isFirstTimeFetch = true
                displayHistory()
            }
        }
    }
    
    override func willDisappear() {
        super.willDisappear()
    }
    
    override func didAppear() {
        super.didAppear()
        let userActivity = NSUserActivity(activityType: "com.zhaoxiguang.dogechat")
        userActivity.title = "ChatRoom"
        userActivity.userInfo = ["username": manager.commonSocket.myName,
                                 "password": manager.messageManager.getPassword(),
                                 "friendID": friend.userID]
        userActivity.isEligibleForHandoff = true
        userActivity.requiredUserInfoKeys = ["username", "password", "friendID"]
        userActivity.becomeCurrent()
        self.update(userActivity)
    }
    
    func showAlreadyMessages() {
        table.insertRows(at: IndexSet(0..<messages.count), withRowType: messageRowType)
        insertAlreadyAndHistoryMessages(messages, oldIndex: 0, toBottom: true)
    }
    
    @IBAction func sendAction() {
        guard !input.isEmpty else { return }
        inputTF.setText(nil)
        let message = Message(message: input, friend: friend, messageSender: .ourself, receiver: friendName, receiverUserID: friend.userID, sender: SocketManager.shared.messageManager.myName, senderUserID: SocketManager.shared.messageManager.myId, messageType: .text, id: 0)
        insertMessages([message])
        SocketManager.shared.sendMessage(message)
    }
    
    @objc func selectEmojiAction(_ noti: Notification) {
        let path = noti.object as! String
        let message = Message(message: path, friend: friend, messageSender: .ourself, receiver: friendName, receiverUserID: friend.userID, sender: SocketManager.shared.messageManager.myName, senderUserID: SocketManager.shared.messageManager.myId, messageType: .image)
        message.imageURL = path
        insertMessages([message])
        SocketManager.shared.sendMessage(message)
    }
    
    @objc func receiveHistory(noti: Notification) {
        guard let messages = noti.userInfo?["messages"] as? [Message], let pages = noti.userInfo?["pages"] as? Int else { return }
        self.pagesAndCurNum.pages = pages
        let filtered = messages.filter { !self.messagesUUIDs.contains($0.uuid) }.reversed() as [Message]
        let oldIndex = min(self.messages.count, filtered.count)
        self.messages.insert(contentsOf: filtered, at: 0)
        let indexSet = IndexSet(0..<filtered.count)
        self.table.insertRows(at: indexSet, withRowType: messageRowType)
        insertAlreadyAndHistoryMessages(filtered, oldIndex: oldIndex, toBottom: false)
    }
        
    func insertMessages(_ messages: [Message]) {
        let alreadyCount = self.messages.count
        let messages = messages.filter({ !messagesUUIDs.contains($0.uuid) })
        let newCount = alreadyCount + messages.count
        table.insertRows(at: IndexSet(alreadyCount..<newCount), withRowType: messageRowType)
        for (index, newMessage) in messages.enumerated() {
            showNameAndContent(message: newMessage, index: index + alreadyCount)
        }
        table.scrollToRow(at: newCount-1)
        self.messages.append(contentsOf: messages)
    }
    
    func showNameAndContent(message: Message, index: Int) {
        if let messageRow = table.rowController(at: index) as? MessageRow {
            if message.messageSender == .ourself {
                messageRow.nameLabel.setHidden(true)
                messageRow.messageLabel.setHorizontalAlignment(.right)
                messageRow.image.setHorizontalAlignment(.right)
            } else {
                messageRow.nameLabel.setText(message.senderUsername)
            }
            if message.messageType == .image, let url = message.imageURL as NSString? {
                messageRow.messageLabel.setHidden(true)
                messageRow.image.setHidden(false)
                let width = WKInterfaceDevice.current().screenBounds.width - 20
                messageRow.image.setWidth(width)
                if let imageData = imageCahce.object(forKey: url), let image = UIImage(data: imageData as Data) {
                    messageRow.image.setImage(image)
                    messageRow.image.setHeight(width / image.size.width * image.size.height)
                } else {
                    if let size = sizeForImageOrVideo(message) {
                        let height = width/size.width * size.height
                        messageRow.image.setHeight(height)
                    }
                    MediaLoader.shared.requestImage(urlStr: url_pre + (url as String), type: .image, syncIfCan: false, completion: { image, data, _ in
                        guard let image = image else { return }
                        let compressedData = compressEmojis(image)
                        messageRow.image?.setHeight(width/image.size.width * image.size.height)
                        messageRow.image?.setImageData(compressedData)
                        imageCahce.setObject(compressedData as NSData, forKey: url)
                    }, progress: nil)
                }
            } else {
                messageRow.messageLabel.setHidden(false)
                messageRow.image.setHidden(true)
                messageRow.messageLabel.setText(contentForSpecialType(message))
            }
        }
    }
        
    func insertAlreadyAndHistoryMessages(_ messages: [Message], oldIndex: Int, toBottom: Bool) {
        for (index, message) in messages.enumerated() {
            showNameAndContent(message: message, index: index)
        }
        if isFirstTimeFetch || toBottom {
            if self.messages.count > 0 {
                self.table.scrollToRow(at: self.messages.count - 1)
            }
            isFirstTimeFetch = false
        } else {
            self.table.scrollToRow(at: oldIndex)
        }
    }
    
    
    @objc func displayHistory() {
        guard pagesAndCurNum.curNum <= pagesAndCurNum.pages else {
            return
        }
        pagesAndCurNum.curNum = (self.messages.count / ChatRoomInterfaceController.numberOfHistory) + 1
        manager.commonSocket.historyMessages(for: friend, pageNum: pagesAndCurNum.curNum)
        pagesAndCurNum.curNum += 1
    }
    
    @IBAction func emojiAction() {
        self.presentController(withName: "emoji", context: emojis.isEmpty ? HttpRequestsManager.emojiPaths : emojis)
    }
    
    
    override func interfaceOffsetDidScrollToTop() {
        super.interfaceOffsetDidScrollToTop()
        displayHistory()
    }
    
}
