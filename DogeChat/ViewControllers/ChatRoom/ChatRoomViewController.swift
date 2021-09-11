
import UIKit
import SwiftyJSON
import DogeChatNetwork
import DogeChatUniversal
import PhotosUI

class ChatRoomViewController: DogeChatViewController {
    
    static let numberOfHistory = 10
    static var needRotate = false
    var manager: WebSocketManager {
        if #available(iOS 13.0, *) {
            return socketForUsername(username)
        } else {
            return WebSocketManager.shared
        }
    }
    let tableView = DogeChatTableView()
    let messageInputBar = MessageInputView()
    var messageOption: MessageOption = .toAll
    var friendName = ""
    var pagesAndCurNum = (pages: 1, curNum: 1)
    var originOfInputBar = CGPoint()
    var scrollBottom = true
    var activeSwipeIndexPath: IndexPath?
    var latestPickedImageInfos: [(image: UIImage?, fileUrl: URL, size: CGSize)] = []
    var pickedLivePhotos: [(imageURL: URL, videoURL: URL, size: CGSize, live: PHLivePhoto)] = []
    var pickedVideos: (url: URL, size: CGSize)?
    var voiceInfo: (url: URL, duration: Int)?
    let emojiSelectView = EmojiSelectView()
    var messages = [Message]()
    var messagesUUIDs = Set<String>()
    var activePKView: UIView!
    var drawingIndexPath: IndexPath!
    var username = ""
    var collectionViewTapGesture: UITapGestureRecognizer!
    var friendAvatarUrl = ""
    var dontLayout = false
    weak var contactVC: ContactsTableViewController?
    var hapticInputIndex = 0
    var pan: UIScreenEdgePanGestureRecognizer?
    var needScrollToBottom = false {
        didSet {
            if needScrollToBottom {
                scrollBotton()
            }
        }
    }
    var shouldIgnoreScroll = false
    
    var lastIndexPath: IndexPath {
        return IndexPath(row: messages.count-1, section: 0)
    }
    
    let cache = NSCache<NSString, NSData>()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        hidesBottomBarWhenPushed = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        makeNavBarUI()
        manager.messageManager.messageDelegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(notification:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sendSuccess(notification:)), name: .sendSuccess, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadSuccess(notification:)), name: .uploadSuccess, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveNewMessageNotification(_:)), name: .receiveNewMessage, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(confirmSendPhoto), name: .confirmSendPhoto, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(emojiButtonTapped), name: .emojiButtonTapped, object: messageInputBar)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveEmojiInfoChangedNotification(_:)), name: .emojiInfoChanged, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveHistoryMessages(_:)), name: .receiveHistoryMessages, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(displayHistoryIfNeeded), name: .connected, object: username)
        NotificationCenter.default.addObserver(self, selector: #selector(pasteImageAction(_:)), name: .pasteImage, object: messageInputBar.textView)
        navigationItem.largeTitleDisplayMode = .never
        addRefreshController()
        loadViews()
        layoutViews(size: view.bounds.size)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: true)
        messageInputBar.textView.delegate = self
        UIView.performWithoutAnimation {
            messageInputBar.textView.resignFirstResponder()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        messageInputBar.textView.resignFirstResponder()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppDelegate.shared.navigationController = self.navigationController
        if #available(iOS 13.0, *) {
            (self.view.window?.windowScene?.delegate as? SceneDelegate)?.navigationController = self.navigationController
        }
        scrollBottom = false
        DispatchQueue.main.async {
            self.displayHistoryIfNeeded()
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !dontLayout {
            layoutViews(size: view.bounds.size)
        }
    }
    
    deinit {
        print("chat room VC deinit")
        MessageCollectionViewTextCell.voicePlayer.replaceCurrentItem(with: nil)
//        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    func scrollBotton() {
        if self.needScrollToBottom {
            if !messages.isEmpty {
                tableView.scrollToRow(at: IndexPath(row: messages.count - 1, section: 0), at: .bottom, animated: true)
            }
        }
    }
    
    @objc func displayHistoryIfNeeded() {
        if tableView.contentSize.height < view.bounds.height {
            displayHistory()
        }
    }
    
    @objc func sendSuccess(notification: Notification) {
        let userInfo = notification.userInfo
        guard let message = userInfo?["message"] as? Message,
              let correctId = userInfo?["correctId"] as? Int else {
            return
        }
        guard let index = messages.firstIndex(of: message) else {
            return
        }
        self.messages[index].sendStatus = .success
        self.messages[index].id = correctId
        guard message.receiver == friendName || (message.receiver == "PublicPino" && messageOption == .toAll) else {
            return
        }
        let indexPath = IndexPath(row: index, section: 0)
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.layoutIfNeeded()
            cell.setNeedsLayout()
        } 
    }
    
    @objc func uploadSuccess(notification: Notification) {
        guard let message = notification.userInfo?["message"] as? Message else { return }
        guard let index = messages.firstIndex(of: message) else { return }
        messages[index].sendStatus = .success
        manager.sendWrappedMessage(message)
    }
    
}

//MARK - Message Input Bar
extension ChatRoomViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
    
    func sendWasTapped(content: String) {
        guard !content.isEmpty else { return }
        playHaptic()
        let wrappedMessage = processMessageString(for: content)
        manager.messageManager.notSendContent.append(wrappedMessage)
        insertNewMessageCell([wrappedMessage])
        manager.sendWrappedMessage(wrappedMessage)
    }
    
    func sendCallRequest() {
        manager.sendCallRequst(to: friendName, uuid: UUID().uuidString)
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            let data = "hello world".data(using: .utf8)
            self.manager.sendVoiceData(data)
        }
    }
    
    func updateUploadProgress(_ progress: Progress, message: Message) {
        let targetCell = tableView.visibleCells.filter { cell in
            guard let cell = cell as? MessageCollectionViewBaseCell else { return false }
            return cell.message.uuid == message.uuid
        }.first
        guard let _ = targetCell as? MessageCollectionViewBaseCell else { return }
    }
    
    private func processMessageString(for string: String) -> Message {
        return Message(message: string, messageSender: .ourself, receiver: friendName, sender: username, messageType: .text, option: messageOption, id: manager.messageManager.maxId + 1, sendStatus: .fail, fontSize: messageInputBar.textView.font!.pointSize)
    }
    
    @objc func emojiButtonTapped() {
        manager.getEmojis { [self] (paths) in
            emojiSelectView.emojis = paths
        }
    }
}

extension ChatRoomViewController: EmojiViewDelegate {
    func didSelectEmoji(filePath: String) {
        let message = Message(message: filePath, imageURL: filePath, videoURL: nil, messageSender: .ourself, receiver: friendName, sender: username, messageType: .image, option: messageOption, id: manager.messageManager.maxId+1, sendStatus: .fail)
        manager.sendWrappedMessage(message)
        insertNewMessageCell([message])
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

@available(iOS 14.0, *)
extension ChatRoomViewController: PKViewChangedDelegate {
    func pkView(_ pkView: PKCanvasView, message: Any?, addNewStroke newStroke: PKStroke) {
        print("add new stroke")
        guard let message = message as? Message else { return }
        guard message.needRealTimeDraw else { return }
        let data = PKDrawing(strokes: [newStroke]).dataRepresentation()
        let base64String = data.base64EncodedString()
        manager.sendRealTimeDrawData(base64String, sender: username, receiver: friendName, uuid: message.uuid)
    }
    
    func pkView(_ pkView: PKCanvasView, message: Any?, deleteStrokesIndex: [NSNumber]) {
        print("delete\(deleteStrokesIndex.count)")
        guard let message = message as? Message else { return }
        if message.needRealTimeDraw {
            let indexes = deleteStrokesIndex.map { $0.intValue }
            manager.sendRealTimeDrawData(indexes, sender: username, receiver: friendName, uuid: message.uuid)
        }
    }
    
    func pkViewDidFinishDrawing(_ pkView: PKCanvasView, message: Any?) {
        if let message = message as? Message {
            message.sendStatus = .fail
            let data = pkView.drawing.dataRepresentation()
            let fileName = UUID().uuidString
            let dir = createDir(name: drawDir)
            let originalURL = dir.appendingPathComponent(fileName)
            saveFileToDisk(dirName: drawDir, fileName: fileName, data: data)
            message.pkLocalURL = originalURL
            if let index = self.messages.firstIndex(where: { $0.uuid == message.uuid }) {
                tableView.reloadRows(at: [IndexPath(item: index, section: 0)], with: .none)
            }
            insertNewMessageCell([message], forceScrollBottom: true) { [weak self] in
                self?.drawDone()
            }
            guard !pkView.drawing.strokes.isEmpty else { return }
            let drawData = pkView.drawing.dataRepresentation()
            let bounds = pkView.drawing.bounds
            let x = Int(bounds.origin.x)
            let y = Int(bounds.origin.y)
            let width = Int(bounds.size.width)
            let height = Int(bounds.size.height)
            message.drawBounds = bounds
            manager.uploadData(drawData, path: "message/uploadImg", name: "upload", fileName: "+\(x)+\(y)+\(width)+\(height)", needCookie: true, contentType: "application/octet-stream", params: nil) { [weak self] task, data in
                guard let self = self, let data = data else { return }
                let json = JSON(data)
                guard json["status"].stringValue == "success" else {
                    print("上传失败")
                    return
                }
                let filePath = self.manager.messageManager.encrypt.decryptMessage(json["filePath"].stringValue)
                message.pkDataURL = filePath
                message.message = message.pkDataURL ?? ""
                self.manager.sendDrawMessage(message)
                DispatchQueue.global().async {
                    let newURL = dir.appendingPathComponent(filePath.components(separatedBy: "/").last!)
                    try? FileManager.default.moveItem(at: originalURL, to: newURL)
                }
            }
        }
    }
    
    func pkViewDidCancelDrawing(_ pkView: PKCanvasView, message: Any?) {
        drawingIndexPath = nil
    }
}

extension ChatRoomViewController: MessageDelegate {
    
    @objc func receiveNewMessageNotification(_ notification: Notification) {
        guard let message = notification.userInfo?["message"] as? Message, message.option == messageOption else {
            return
        }
        let newMessageFriendName = message.messageSender == .ourself ? message.receiver : message.senderUsername
        if message.option == .toOne && newMessageFriendName != friendName { return }
        insertNewMessageCell([message], forceScrollBottom: true)
    }
    
    func updateOnlineNumber(to newNumber: Int) {
        guard messageOption == .toAll else { return }
        navigationItem.title = "群聊"// + "(\(newNumber)人在线)"
    }
    
    
    func newFriendRequest() {
        guard let contactVC = navigationController?.viewControllers.filter({ $0 is ContactsTableViewController }).first as? ContactsTableViewController else { return }
        navigationItem.rightBarButtonItem = contactVC.itemRequest
        WebSocketManagerAdapter.shared.playSound()
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
        guard pagesAndCurNum.curNum <= pagesAndCurNum.pages else {
            self.tableView.refreshControl?.endRefreshing()
            return
        }
        navigationItem.title = "正在加载..."
        pagesAndCurNum.curNum = (self.messages.count / ChatRoomViewController.numberOfHistory) + 1
        manager.historyMessages(for: (messageOption == .toAll) ? "chatRoom" : friendName, pageNum: pagesAndCurNum.curNum)
        pagesAndCurNum.curNum += 1
    }
    
    @objc func receiveHistoryMessages(_ noti: Notification) {
        guard navigationController?.visibleViewController == self else { return }
        let empty = self.messages.count < ChatRoomViewController.numberOfHistory
        navigationItem.title = friendName
        guard let messages = noti.userInfo?["messages"] as? [Message], !messages.isEmpty, let pages = noti.userInfo?["pages"] as? Int else { return }
        if messages[0].option != messageOption {
            return
        } else if messageOption == .toOne {
            if (messages[0].messageSender == .ourself && messages[0].receiver != friendName) || (messages[0].messageSender == .someoneElse && messages[0].senderUsername != friendName) {
                return
            }
        }
        self.pagesAndCurNum.pages = pages
        let filtered = messages.filter { !self.messagesUUIDs.contains($0.uuid) }.reversed() as [Message]
        if filtered.isEmpty {
            tableView.refreshControl?.endRefreshing()
        }
        let _ = IndexPath(item: min(self.messages.count, filtered.count), section: 0)
        
        self.messages.insert(contentsOf: filtered, at: 0)
        for message in filtered {
            self.messagesUUIDs.insert(message.uuid)
        }
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
        let id = message.id
        manager.revokeMessage(id: id)
    }
    
    func revokeSuccess(id: Int) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        removeMessage(index: index)
    }
    
    func removeMessage(index: Int) {
        messages[index].message = "\(messages[index].senderUsername)撤回了一条消息"
        messages[index].messageType = .join
        let updatedMessage = messages[index]
        switch messageOption {
        case .toAll:
            manager.messageManager.messagesGroup[index] = updatedMessage
        case .toOne:
            manager.messageManager.messagesSingle.update(at: index, for: friendName, with: updatedMessage)
        }
        let indexPath = IndexPath(row: index, section: 0)
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    func revokeMessage(_ id: Int) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        removeMessage(index: index)
    }
}

extension ChatRoomViewController: UITextViewDelegate {
    
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        showEmojiButton(textView.text.isEmpty)
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
