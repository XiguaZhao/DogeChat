
import UIKit
import SwiftyJSON
import DogeChatNetwork
import DogeChatUniversal
import PhotosUI
import FLAnimatedImage

enum ChatRoomSceneType {
    case normal
    case single
}

class ChatRoomViewController: DogeChatViewController, DogeChatVCTableDataSource {
    
    enum ChatRoomPurpose {
        case chat
        case peek
        case referView
        case history
    }
    
    static let numberOfHistory = 10
    var manager: WebSocketManager? {
        return socketForUsername(username)
    }
    var tableView = DogeChatTableView()
    var sceneType: ChatRoomSceneType = .normal
    var purpose = ChatRoomPurpose.chat
    let messageInputBar = MessageInputView()
    var messageOption: MessageOption {
        friend.isGroup ? .toGroup : .toOne
    }
    var groupMembers: [Friend]?
    var friend: Friend! {
        didSet {
            messages = friend.messages
            customTitle = friend.nickName ?? friend.username
            emojiSelectView.friend = friend
            DispatchQueue.main.async {
                self.messageInputBar.atButton.isHidden = !self.friend.isGroup
            }
        }
    }
    var friendName: String {
        friend.username
    }
    var customTitle = "" {
        didSet {
            if !customTitle.isEmpty && self.purpose == .chat {
                navigationItem.title = customTitle
            }
        }
    }
    var imagePickerType: MessageType = .image
    var heightCache = [String : CGFloat]()
    var jumpToUnreadStack: UIStackView!
    let jumpToUnreadButton = UIImageView()
    var jumpToBottomStack: UIStackView!
    let atLabel = UILabel()
    var explictJumpMessageUUID: String?
    let titleLabel = UILabel()
    let titleAvatar = FLAnimatedImageView()
    var pagesAndCurNum = (pages: 1, curNum: 1)
    var activeSwipeIndexPath: IndexPath?
    lazy var messageSender: MessageSender = {
        let sender = MessageSender()
        sender.progressDelegate = self
        sender.referMessageDataSource = self
        sender.manager = self.manager?.httpsManager
        return sender
    }()
    let emojiSelectView = EmojiSelectView()
    var messages = [Message]()
    var messagesUUIDs: Set<String> {
        return Set(self.messages.map{ $0.uuid })
    }
    var activePKView: UIView!
    var drawingIndexPath: IndexPath!
    var friendAvatarUrl: String {
        friend.avatarURL
    }
    var lastViewSize = CGSize.zero
    lazy var lastTextViewContentSize: CGSize = CGSize(width: 0, height: 36)
    weak var contactVC: ContactsTableViewController?
    weak var activeMenuCell: MessageBaseCell?
    var hapticInputIndex = 0
    var pan: UIScreenEdgePanGestureRecognizer?
    var ignoreKeyboardChange = false
    var needScrollToBottom = false {
        didSet {
            if needScrollToBottom {
                scrollBotton()
            }
        }
    }
    
    var lastIndexPath: IndexPath {
        return IndexPath(row: messages.count-1, section: 0)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        makeDetailRightBarButton()
        if isPad() {
            if !isMac() {
                NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameChangeNoti(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
            }
        } else if isPhone() {
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(noti:)), name: UIWindow.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(noti:)), name: UIWindow.keyboardWillHideNotification, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(sendSuccess(notification:)), name: .sendSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveNewMessageNotification(_:)), name: .receiveNewMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(confirmSendPhoto), name: .confirmSendPhoto, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(emojiButtonTapped), name: .emojiButtonTapped, object: messageInputBar)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveEmojiInfoChangedNotification(_:)), name: .emojiInfoChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveHistoryMessages(_:)), name: .receiveHistoryMessages, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(connected(_:)), name: .connected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(pasteImageAction(_:)), name: .pasteImage, object: messageInputBar.textView)
        NotificationCenter.default.addObserver(self, selector: #selector(sizeCategoryChange(_:)), name: UIContentSizeCategory.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(forName: .logout, object: username, queue: .main) { [weak self] _ in
            self?.navigationController?.viewControllers = []
        }
        NotificationCenter.default.addObserver(self, selector: #selector(friendChangeAvatar(_:)), name: .friendChangeAvatar, object: nil)
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            if isMac() {
                self?.messageInputBar.textView.becomeFirstResponder()
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(groupInfoChange(noti:)), name: .groupInfoChange, object: username)
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.messageInputBar.textViewResign()
        }
        navigationItem.largeTitleDisplayMode = .never
        addRefreshController()
        loadViews()
        displayHistoryIfNeeded()
        checkMyNameInGroup()
    }
        
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if purpose == .chat {
            navigationController?.setToolbarHidden(!tableView.isEditing, animated: true)
        }
        messageInputBar.textView.delegate = self
        if isMac() {
            messageInputBar.textView.becomeFirstResponder()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        messageInputBar.textView.resignFirstResponder()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 13.0, *) {
            (self.view.window?.windowScene?.delegate as? SceneDelegate)?.navigationController = self.navigationController
        } else {
            AppDelegateUI.shared.navController = self.navigationController
        }
        guard let manager = manager else {
            return
        }
        let userActivity = NSUserActivity(activityType: userActivityID)
        userActivity.title = "ChatRoom"
        let modal = UserActivityModal(friendID: friend.userID, accountInfo: manager.httpsManager.accountInfo)
        if let data = try? JSONEncoder().encode(modal) {
            userActivity.userInfo = ["data": data]
            userActivity.isEligibleForHandoff = true
            self.userActivity = userActivity
            userActivity.becomeCurrent()
        }
        if self.sceneType == .single {
            if #available(iOS 13.0, *) {
                self.view.window?.windowScene?.title = username + "与\(friend.username)"
            }
        }
    }
        
    deinit {
        print("chat room VC deinit")
        MessageAudioCell.voicePlayer.replaceCurrentItem(with: nil)
        PlayerManager.shared.playerTypes.remove(.chatroomImageCell)
        PlayerManager.shared.playerTypes.remove(.chatroomVoiceCell)
    }
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesBegan(presses, with: event)
        if let key = presses.first?.key {
            let keyCode = key.keyCode
            if keyCode == .keyboardUpArrow {
                contactVC?.arrowUp(messageInputBar.textView)
            } else if keyCode == .keyboardDownArrow {
                contactVC?.arrowDown(messageInputBar.textView)
            } else if keyCode == .keyboardV && key.modifierFlags == .command {
                processItemProviders(UIPasteboard.general.itemProviders)
            } else if !messageInputBar.textView.isFirstResponder {
                messageInputBar.textView.becomeFirstResponder()
            }
        }
    }

    func contentHeight() -> CGFloat {
        return heightCache.values.reduce(0, +)
    }
    
    func scrollBotton() {
        if self.needScrollToBottom {
            if messages.count > 1 {
                tableView.scrollToRow(at: IndexPath(row: messages.count - 1, section: 0), at: .bottom, animated: true)
            }
        }
    }
    
    func checkMyNameInGroup() {
        guard let manager = manager, friend is Group else { return }
        if manager.myInfo.nameInGroupsDict?[friend.userID] == nil {
            manager.httpsManager.getGroupMembers(group: friend as! Group) { [self] members in
                for member in members {
                    if member.userID == manager.myInfo.userID, let myNameInGroup = member.nameInGroup {
                        manager.myInfo.nameInGroupsDict?[friend.userID] = myNameInGroup
                    }
                }
            }
        }
    }
    
    @objc func friendChangeAvatar(_ noti: Notification) {
        let friend = noti.userInfo?["friend"] as! Friend
        if friend.userID != self.friend.userID { return }
        self.friend.avatarURL = friend.avatarURL
        for message in self.messages {
            message.avatarUrl = friend.avatarURL
        }
        self.tableView.reloadData()
        if friend is Group {
            updateTitleAvatar()
        }
    }
    
    @objc func connected(_ noti: Notification) {
        guard noti.object as? String == self.username else { return }
        displayHistoryIfNeeded()
    }
    
    func displayHistoryIfNeeded() {
        if tableView.contentSize.height < view.bounds.height * 0.7 {
            if let manager = manager, manager.commonWebSocket.canSend {
                displayHistory()
            }
        }
    }
    
    @objc func sendSuccess(notification: Notification) {
        guard notification.object as? String == self.username else { return }
        let userInfo = notification.userInfo
        guard let message = userInfo?["message"] as? Message, message.friend?.userID == self.friend.userID else {
            return
        }
        if let index = messages.firstIndex(of: message)  {
            messages[index].sendStatus = .success
            messages[index].id = message.id
            let indexPath = IndexPath(row: index, section: 0)
            if let cell = tableView.cellForRow(at: indexPath) as? MessageBaseCell {
                cell.layoutIfNeeded()
                cell.setNeedsLayout()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.tableView.reloadRows(at: [indexPath], with: .none)
                }
            }
        } else {
            insertNewMessageCell([message])
        }
    }
    
}

//MARK - Message Input Bar
extension ChatRoomViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
        
    func updateUploadProgress(_ progress: Progress, message: Message) {
        let targetCell = tableView.visibleCells.filter { cell in
            guard let cell = cell as? MessageBaseCell else { return false }
            return cell.message.uuid == message.uuid
        }.first
        guard let _ = targetCell as? MessageBaseCell else { return }
    }
    
}

extension ChatRoomViewController {
    
    @objc func drawDone() {
        self.navigationItem.rightBarButtonItem = nil
        activePKView?.backgroundColor = .clear
        activePKView?.resignFirstResponder()
        activePKView?.isUserInteractionEnabled = false
        tableView.isScrollEnabled = true
        activePKView = nil
        drawingIndexPath = nil
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
    
}

extension ChatRoomViewController: PKViewChangedDelegate {
    func pkView(_ pkView: PKCanvasView, message: Any?, addNewStroke newStroke: Any) {
        guard #available(iOS 14.0, *), let newStroke = newStroke as? PKStroke else { return }
        print("add new stroke")
        guard let message = message as? Message else { return }
        guard message.needRealTimeDraw else { return }
        let data = PKDrawing(strokes: [newStroke]).dataRepresentation()
        let base64String = data.base64EncodedString()
        manager?.sendRealTimeDrawData(base64String, sender: username, receiver: friendName, uuid: message.uuid, senderID: message.senderUserID, receiverID: message.receiverUserID)
    }
    
    @available(iOS 13.0, *)
    func pkView(_ pkView: PKCanvasView, message: Any?, deleteStrokesIndex: [NSNumber]) {
        print("delete\(deleteStrokesIndex.count)")
        guard let message = message as? Message else { return }
        if message.needRealTimeDraw {
            let indexes = deleteStrokesIndex.map { $0.intValue }
            manager?.sendRealTimeDrawData(indexes, sender: username, receiver: friendName, uuid: message.uuid, senderID: message.senderUserID, receiverID: message.receiverUserID)
        }
    }
    
    @available(iOS 13.0, *)
    func pkViewDidFinishDrawing(_ pkView: PKCanvasView, message: Any?) {
        if let manager = manager, let message = message as? Message {
            message.sendStatus = .fail
            let data = pkView.drawing.dataRepresentation()
            let fileName = UUID().uuidString
            let dir = createDir(name: drawDir)
            let originalURL = dir.appendingPathComponent(fileName)
            saveFileToDisk(dirName: drawDir, fileName: fileName, data: data)
            message.pkLocalURL = originalURL
            if #available(iOS 14.0, *) {
                guard !pkView.drawing.strokes.isEmpty else { return }
            }
            let drawData = pkView.drawing.dataRepresentation()
            let bounds = pkView.drawing.bounds
            let x = Int(bounds.origin.x)
            let y = Int(bounds.origin.y)
            let width = Int(bounds.size.width)
            let height = Int(bounds.size.height)
            message.drawBounds = bounds
            if let index = self.messages.firstIndex(where: { $0.uuid == message.uuid }) {
                tableView.reloadRows(at: [IndexPath(item: index, section: 0)], with: .none)
            }
            insertNewMessageCell([message], forceScrollBottom: true) { [weak self] in
                self?.drawDone()
            }
            manager.uploadData(drawData, path: "message/uploadImg", name: "upload", fileName: "+\(x)+\(y)+\(width)+\(height)", needCookie: true, contentType: "application/octet-stream", params: nil) { task, data in
                guard let data = data else { return }
                let json = JSON(data)
                guard json["status"].stringValue == "success" else {
                    print("上传失败")
                    return
                }
                let filePath = manager.messageManager.encrypt.decryptMessage(json["filePath"].stringValue)
                message.pkDataURL = filePath
                message.text = message.pkDataURL ?? ""
                manager.sendDrawMessage(message)
                DispatchQueue.global().async {
                    let newURL = dir.appendingPathComponent(filePath.components(separatedBy: "/").last!)
                    try? FileManager.default.moveItem(at: originalURL, to: newURL)
                }
            }
        }
    }
    
    @available(iOS 13.0, *)
    func pkViewDidCancelDrawing(_ pkView: PKCanvasView, message: Any?) {
        drawingIndexPath = nil
        if let message = message as? Message {
            if #available(iOS 14.0, *) {
                if (message.pkLocalURL == nil && message.pkDataURL == nil) {
                    revoke(message: message)
                } else {
                    manager?.commonWebSocket.sendWrappedMessage(message)
                }
            }
        }
    }
}

extension ChatRoomViewController {
    
    @objc func receiveNewMessageNotification(_ notification: Notification) {
        guard notification.object as? String == self.username, let dict = notification.userInfo?["friendDict"] as? [String : [Message]] else { return }
        for (friendID, newMessages) in dict {
            if friendID == self.friend.userID {
                insertNewMessageCell(newMessages)
            }
        }
    }
        
    
}

extension ChatRoomViewController {
    //MARK: Refresh
    func addRefreshController() {
        let controller = UIRefreshControl()
        controller.addTarget(self, action: #selector(displayHistory), for: .valueChanged)
        tableView.refreshControl = controller
    }
    
    @objc func displayHistory() {
        customTitle = "正在加载..."
        pagesAndCurNum.curNum = (self.messages.count / ChatRoomViewController.numberOfHistory) + 1
        manager?.historyMessages(for: friend, pageNum: pagesAndCurNum.curNum)
        pagesAndCurNum.curNum += 1
    }
    
    @objc func receiveHistoryMessages(_ noti: Notification) {
        defer {
            tableView.refreshControl?.endRefreshing()
        }
        guard noti.object as? String == self.username else { return }
        if purpose == .chat && self.navigationController?.visibleViewController != self { return }
        var empty = true
        var tempHeight: CGFloat = 0
        for message in self.messages.reversed() {
            tempHeight += self.heightCache[message.uuid] ?? 0
            if tempHeight >= tableView.bounds.height * 0.7 {
                empty = false
                break
            }
        }
        customTitle = friend.nickName ?? friendName
        guard let messages = noti.userInfo?["messages"] as? [Message], !messages.isEmpty, let pages = noti.userInfo?["pages"] as? Int else { return }
        if messages[0].option != messageOption {
            return
        } else if messageOption == .toOne {
            if (messages[0].messageSender == .ourself && messages[0].receiverUserID != friend.userID) || (messages[0].messageSender == .someoneElse && messages[0].senderUserID != friend.userID) {
                return
            }
        }
        self.pagesAndCurNum.pages = pages
        let filtered = messages.filter { !self.messagesUUIDs.contains($0.uuid) }.reversed() as [Message]
        if filtered.isEmpty {
            tableView.refreshControl?.endRefreshing()
            return
        }
        
        self.messages.insert(contentsOf: filtered, at: 0)
        let indexPaths = [Int](0..<filtered.count).map{ IndexPath(item: $0, section: 0) }
        var myselfIndexPaths = [IndexPath]()
        var othersIndexPaths = [IndexPath]()
        for (index, indexPath) in indexPaths.enumerated() {
            if filtered[index].messageSender == .ourself {
                myselfIndexPaths.append(indexPath)
            } else {
                othersIndexPaths.append(indexPath)
            }
        }
        tableView.performBatchUpdates {
            self.tableView.insertRows(at: myselfIndexPaths, with: .right)
            self.tableView.insertRows(at: othersIndexPaths, with: .left)
        } completion: { _ in
            if empty && !indexPaths.isEmpty{
                self.tableView.scrollToRow(at: IndexPath(row: self.tableView.numberOfRows(inSection: 0) - 1, section: 0), at: .bottom, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    guard let self = self else { return }
                    self.scrollViewDidEndDecelerating(self.tableView)
                }
            } else {
                self.tableView.refreshControl?.endRefreshing()
            }
        }
    }
    
    
    func revoke(message: Message) {
        manager?.revokeMessage(message)
    }
    
    func revokeSuccess(id: Int, senderID: String, receiverID: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        removeMessage(index: index)
    }
    
    func removeMessage(index: Int) {
        let message = self.messages[index]
        message.text = "\(message.senderUsername)撤回了一条消息"
        message.messageType = .join
        message.referMessage = nil
        message.referMessageUUID = nil
        let indexPath = IndexPath(row: index, section: 0)
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    func revokeMessage(_ id: Int, senderID: String, receiverID: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        removeMessage(index: index)
    }
}

extension ChatRoomViewController: UITextViewDelegate {
        
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        showEmojiButton(textView.text.isEmpty)
        messageInputBar.recoverEmojiButton()
        return true
    }
    
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        showEmojiButton(true)
        return true
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            messageInputBar.sendTapped()
            return false
        }
        return true
    }
    
    func showEmojiButton(_ show: Bool) {
        if messageInputBar.emojiButton.isHidden == !show {
            return
        }
        let arrowButton = messageInputBar.upArrowButton
        let emojiButton = messageInputBar.emojiButton
        arrowButton.isHidden = false
        emojiButton.isHidden = false
        UIView.animate(withDuration: 0.2) {
            arrowButton.alpha = show ? 0 : 1
            emojiButton.alpha = show ? 1 : 0
        } completion: { _ in
            arrowButton.isHidden = show
            emojiButton.isHidden = !show
        }
        
    }
}
