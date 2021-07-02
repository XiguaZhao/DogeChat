
import UIKit
import SwiftyJSON
import YPTransition
import DogeChatUniversal
import PhotosUI

func playHaptic(_ intensity: CGFloat = 1) {
    if #available(iOS 13.0, *) {
        HapticManager.shared.playHapticTransient(time: 0, intensity: Float(intensity), sharpness: 1)
    }
}

class ChatRoomViewController: DogeChatViewController {
    
    static let numberOfHistory = 10
    static var needRotate = false
    let manager = WebSocketManager.shared
    let collectionView = DogeChatBaseCollectionView(frame: CGRect.zero, collectionViewLayout: ChatRootCollectionViewLayout())
    let messageInputBar = MessageInputView()
    var messageOption: MessageOption = .toAll
    var friendName = ""
    var pagesAndCurNum = (pages: 1, curNum: 1)
    var originOfInputBar = CGPoint()
    var scrollBottom = true
    var latestPickedImageInfo: (image: UIImage?, fileUrl: URL)?
    let emojiSelectView = EmojiSelectView()
    var messages = [Message]()
    var messagesUUIDs = Set<String>()
    var isFirstTimeGetHistory = false
    let messageBarHeight:CGFloat = 60.0
    var activePKView: UIView!
    var drawingIndexPath: IndexPath!
    var username = ""
    var collectionViewTapGesture: UITapGestureRecognizer!
    var friendAvatarUrl = ""
    var isFetchingHistory = false
    var hapticInputIndex = 0
    var pan: UIScreenEdgePanGestureRecognizer?
    
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
        manager.messageManager.messageDelegate = self
        messageInputBar.vc = self
        emojiSelectView.vc = self
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(notification:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sendSuccess(notification:)), name: .sendSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadSuccess(notification:)), name: .uploadSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveNewMessageNotification(_:)), name: .receiveNewMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(confirmSendPhoto), name: .confirmSendPhoto, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(emojiButtonTapped), name: .emojiButtonTapped, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveEmojiInfoChangedNotification(_:)), name: .emojiInfoChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveHistoryMessages(_:)), name: .receiveHistoryMessages, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(drawDataDownloadedSuccessNoti(_:)), name: .drawDataDownloadedSuccess, object: nil)
        navigationItem.largeTitleDisplayMode = .never
        addRefreshController()
        loadViews()
        configureEmojiView()
        layoutViews(size: view.bounds.size)
        collectionViewTapGesture = UITapGestureRecognizer(target: self, action: #selector(tap))
        collectionView.addGestureRecognizer(collectionViewTapGesture)
        pan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(panAction(_:)))
        pan?.edges = .right
        view.addGestureRecognizer(pan!)
    }
    
    @objc func panAction(_ pan: UIScreenEdgePanGestureRecognizer) {
        let maxOffset: CGFloat = 80
        switch pan.state {
        case .began:
            collectionView.layer.masksToBounds = false
        case .changed:
            let startX = view.bounds.width
            let endX = pan.location(in: view).x
            let offsetX = min(maxOffset, (abs(endX - startX))/1.2)
            collectionView.layer.transform = CATransform3DTranslate(CATransform3DIdentity, -offsetX, 0, 0)
        case .ended:
            recoverCollectionViewInset()
        default:
            break
        }
    }
    
    func recoverCollectionViewInset() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
            self.collectionView.layer.transform = CATransform3DIdentity
        }, completion: { _ in
            self.collectionView.layer.masksToBounds = true
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: true)
        messageInputBar.textView.delegate = self
        UIView.performWithoutAnimation {
            messageInputBar.textView.resignFirstResponder()
            collectionView.contentInset = .zero
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        messageInputBar.textView.resignFirstResponder()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        layoutViews(size: view.bounds.size)
        DispatchQueue.main.async { [self] in
            scrollBottom = false
            if collectionView.contentSize.height < view.bounds.height {
                displayHistory()
                isFirstTimeGetHistory = true
            }
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }
    
            
    deinit {
        print("chat room VC deinit")
    }
    
    @objc func tap() {
        messageInputBar.textViewResign()
    }
        
    @objc func sendSuccess(notification: Notification) {
        let userInfo = notification.userInfo
        guard let message = userInfo?["message"] as? Message,
              let correctId = userInfo?["correctId"] as? Int else { return }

        guard let index = messages.firstIndex(where: {message.id == $0.id}) else { return }
        messages[index].id = correctId
        messages[index].sendStatus = .success
        guard message.receiver == friendName || (message.receiver == "PublicPino" && messageOption == .toAll) else {
            return
        }
        let indexPath = IndexPath(row: index, section: 0)
        if let indicator = (collectionView.cellForItem(at: indexPath) as? MessageCollectionViewBaseCell)?.indicator {
            indicator.stopAnimating()
            indicator.removeFromSuperview()
        } else {
            collectionView.reloadItems(at: [indexPath])
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
    @available(iOS 14, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        for result in results {
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let image = object as? UIImage {
                    self?.latestPickedImageInfo = WebSocketManagerAdapter.shared.compressImage(image)
                    self?.confirmSendPhoto()
                }
            }
        }
    }
    
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
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.originalImage] as? UIImage else {
            picker.dismiss(animated: true, completion: nil)
            return
        }
        var isGif = false
        var originalUrl: URL?
        if let originalUrl_ = info[.imageURL] as? URL {
            isGif = originalUrl_.absoluteString.hasSuffix(".gif")
            originalUrl = originalUrl_
        }
        self.latestPickedImageInfo = (isGif ? (nil, originalUrl!) : WebSocketManagerAdapter.shared.compressImage(image))
        picker.dismiss(animated: true) {
            guard !isGif else {
                self.confirmSendPhoto()
                return
            }
            let vc = ImageConfirmViewController()
            if let image = self.latestPickedImageInfo?.image {
                vc.image = image
            } else {
                vc.image = image
            }
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @objc func confirmSendPhoto() {
        guard let (_, imageURL) = self.latestPickedImageInfo else { return }
        let message = Message(message: "", imageURL: imageURL.absoluteString, videoURL: nil, messageSender: .ourself, receiver: friendName, sender: username, messageType: .image, option: messageOption, sendStatus: .fail)
        manager.messageManager.imageDict[message.uuid] = imageURL
        insertNewMessageCell([message])
        DispatchQueue.main.async { [self] in
            collectionView.scrollToItem(at: IndexPath(row: messages.count-1, section: 0), at: .bottom, animated: true)
        }
        manager.uploadPhoto(imageUrl: imageURL, message: message) { (progress) in
        } success: { (task, data) in
            let json = JSON(data as Any)
            var filePath = json["filePath"].stringValue
            print(filePath)
            filePath = WebSocketManager.shared.messageManager.encrypt.decryptMessage(filePath)
            message.imageURL = WebSocketManager.shared.url_pre + filePath
            message.message = message.imageURL ?? ""
        }
        self.latestPickedImageInfo = nil
    }
    

    func updateUploadProgress(_ progress: Progress, message: Message) {
        let targetCell = collectionView.visibleCells.filter { cell in
            guard let cell = cell as? MessageCollectionViewBaseCell else { return false }
            return cell.message.uuid == message.uuid
        }.first
        guard let _ = targetCell as? MessageCollectionViewBaseCell else { return }
    }
    
    private func processMessageString(for string: String) -> Message {
        return Message(message: string, messageSender: .ourself, receiver: friendName, sender: username, messageType: .text, option: messageOption, id: manager.messageManager.maxId + 1, sendStatus: .fail, fontSize: messageInputBar.textView.font!.pointSize)
    }
    
    private func configureEmojiView() {
        emojiSelectView.delegate = self
        view.addSubview(emojiSelectView)
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
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if !AppDelegate.isPad() {
            return .portrait
        }
        return .all
    }
    
    
    
    
    @objc func drawDone() {
        self.navigationItem.rightBarButtonItem = nil
        activePKView?.backgroundColor = .clear
        activePKView?.resignFirstResponder()
        activePKView?.isUserInteractionEnabled = false
        collectionView.isScrollEnabled = true
        collectionViewTapGesture.isEnabled = true
        activePKView = nil
        if let drawingIndexPath = drawingIndexPath {
            collectionView.reloadItems(at: [drawingIndexPath])
            collectionView.scrollToItem(at: drawingIndexPath, at: .bottom, animated: true)
        }
        drawingIndexPath = nil
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
    
    @objc func drawDataDownloadedSuccessNoti(_ noti: Notification) {
        guard let message = noti.object as? Message else { return }
        if let index = self.messages.firstIndex(of: message) {
            let indexPath = IndexPath(item: index, section: 0)
            UIView.performWithoutAnimation {
                self.collectionView.reloadItems(at: [indexPath])
            }
        }
    }
    
}

@available(iOS 14.0, *)
extension ChatRoomViewController: PKViewChangedDelegate {
    func pkView(_ pkView: PKCanvasView, message: Any?, addNewStroke newStroke: PKStroke) {
        print("add new stroke")
        guard let message = message as? Message else { return }
        message.isDrawing = true
        guard message.needRealTimeDraw else { return }
        let data = PKDrawing(strokes: [newStroke]).dataRepresentation()
        let base64String = data.base64EncodedString()
        WebSocketManager.shared.sendRealTimeDrawData(base64String, sender: username, receiver: friendName, uuid: message.uuid)
    }
    
    func pkView(_ pkView: PKCanvasView, message: Any?, deleteStrokesIndex: [NSNumber]) {
        print("delete\(deleteStrokesIndex.count)")
        guard let message = message as? Message else { return }
        message.isDrawing = true
        if message.needRealTimeDraw {
            let indexes = deleteStrokesIndex.map { $0.intValue }
            WebSocketManager.shared.sendRealTimeDrawData(indexes, sender: username, receiver: friendName, uuid: message.uuid)
        }
    }
    
    func pkViewDidFinishDrawing(_ pkView: PKCanvasView, message: Any?) {
        if let message = message as? Message {
            message.pkDrawing = pkView.drawing
            message.sendStatus = .fail
            if let index = self.messages.firstIndex(where: { $0.uuid == message.uuid }) {
                collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            }
            insertNewMessageCell([message]) { [weak self] in
                self?.drawDone()
            }
            guard !pkView.drawing.strokes.isEmpty else { return }
            let drawData = pkView.drawing.dataRepresentation()
            WebSocketManager.shared.uploadData(drawData, path: "message/uploadImg", name: "upload", fileName: "", needCookie: false, contentType: "application/octet-stream", params: nil) { [weak self] task, data in
                guard let _ = self, let data = data else { return }
                let json = JSON(data)
                guard json["status"].stringValue == "success" else {
                    print("上传失败")
                    return
                }
                let filePath = WebSocketManager.shared.messageManager.encrypt.decryptMessage(json["filePath"].stringValue)
                message.pkDataURL = WebSocketManager.shared.url_pre + filePath
                message.message = message.pkDataURL ?? ""
                WebSocketManager.shared.sendDrawMessage(message)
                ContactsTableViewController.pkDataCache[message.pkDataURL!] = drawData 
                message.isDrawing = false
            }
        }
    }
    
    func pkViewDidCancelDrawing(_ pkView: PKCanvasView, message: Any?) {
        drawingIndexPath = nil
    }
}

extension ChatRoomViewController: MessageDelegate {
    
    @objc func receiveNewMessageNotification(_ notification: Notification) {
        guard let message = notification.object as? Message, message.option == messageOption else {
            return
        }
        if message.option == .toOne && message.senderUsername != friendName { return }
        insertNewMessageCell([message])
    }
        
    func updateOnlineNumber(to newNumber: Int) {
        guard messageOption == .toAll else { return }
        navigationItem.title = "群聊"// + "(\(newNumber)人在线)"
    }
    
    @objc func receiveHistoryMessages(_ noti: Notification) {
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
        let oldIndexPath = IndexPath(item: min(self.messages.count, filtered.count), section: 0)
        
        self.messages.insert(contentsOf: filtered, at: 0)
        for message in filtered {
            self.messagesUUIDs.insert(message.uuid)
        }
        let indexPaths = [Int](0..<filtered.count).map{ IndexPath(item: $0, section: 0) }
        UIView.performWithoutAnimation {
            self.collectionView.insertItems(at: indexPaths)
        }
        if !self.isFirstTimeGetHistory {
            self.collectionView.scrollToItem(at: oldIndexPath, at: .top, animated: false)
        }
        else {
            collectionView.scrollToItem(at: IndexPath(item: max(0, self.messages.count-1), section: 0), at: .bottom, animated: true)
            isFirstTimeGetHistory = false
        }

        self.collectionView.refreshControl?.endRefreshing()
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
        //collectionView.refreshControl = controller
    }
    
    @objc func displayHistory() {
        guard pagesAndCurNum.curNum <= pagesAndCurNum.pages else {
            self.collectionView.refreshControl?.endRefreshing()
            return
        }
        navigationItem.title = "正在加载..."
        pagesAndCurNum.curNum = (self.messages.count / ChatRoomViewController.numberOfHistory) + 1
        manager.historyMessages(for: (messageOption == .toAll) ? "chatRoom" : friendName, pageNum: pagesAndCurNum.curNum)
        pagesAndCurNum.curNum += 1
        isFetchingHistory = true
    }
    
    func revoke(indexPath: IndexPath) {
        let id = messages[indexPath.row].id
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
        collectionView.reloadItems(at: [IndexPath(row: index, section: 0)])
    }
    
    func revokeMessage(_ id: Int) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        removeMessage(index: index)
    }
}

extension ChatRoomViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        showEmojiButton(textView.text.isEmpty)
        let oldFrame = messageInputBar.frame
        let textHeight = textView.contentSize.height
        let lineHeight = (textView.text as NSString).size(withAttributes: textView.typingAttributes).height
        let lineCount = Int(textHeight / lineHeight)
        let oldLineCount = Int((oldFrame.height - 20) / lineHeight)
        let lineCountChanged = lineCount - oldLineCount
        var heightChanged = CGFloat(lineCountChanged) * lineHeight
        let frameOfTableView = collectionView.frame
        if textView.text.isEmpty {
            heightChanged = messageBarHeight - oldFrame.height
        }
        if textView.text.isEmpty {
            textView.font = .systemFont(ofSize: 18)
        }
        if heightChanged != 0 {
            UIView.animate(withDuration:  0.25 ) {
                self.messageInputBar.frame = CGRect(x: oldFrame.origin.x, y: oldFrame.origin.y-heightChanged, width: oldFrame.width, height: oldFrame.height+heightChanged)
                self.collectionView.frame = CGRect(origin: frameOfTableView.origin, size: CGSize(width: frameOfTableView.width, height: frameOfTableView.height-heightChanged))
            } completion: { [self] (_) in
                guard collectionView.numberOfItems(inSection: 0) > 0 else { return }
                collectionView.scrollToItem(at: IndexPath(row: collectionView.numberOfItems(inSection: 0)-1, section: 0), at: .bottom, animated: true)
            }
        } 
    }
    
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
