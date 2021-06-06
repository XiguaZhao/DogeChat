
import UIKit
import SwiftyJSON
import YPTransition

class ChatRoomViewController: UIViewController {
    
    static let numberOfHistory = 10
    static var needRotate = false
    let manager = WebSocketManager.shared
    let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: ChatRootCollectionViewLayout())
    let messageInputBar = MessageInputView()
    var messageOption: MessageOption = .toAll
    var friendName = ""
    var pagesAndCurNum = (pages: 1, curNum: 1)
    var originOfInputBar = CGPoint()
    var scrollBottom = true
    var latestPickedImageInfo: (image: UIImage?, url: URL)?
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
    var isInsertingHistory = false
    
    var lastIndexPath: IndexPath {
        return IndexPath(row: messages.count-1, section: 0)
    }
    
    let cache = NSCache<NSString, NSData>()
    
    init() {
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manager.messageDelegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(notification:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sendSuccess(notification:)), name: .sendSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadSuccess(notification:)), name: .uploadSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveNewMessageNotification(_:)), name: .receiveNewMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(confirmSendPhoto), name: .confirmSendPhoto, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(emojiButtonTapped), name: .emojiButtonTapped, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveEmojiInfoChangedNotification(_:)), name: .emojiInfoChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveHistoryMessages(_:)), name: .receiveHistoryMessages, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(drawDataDownloadedSuccessNoti(_:)), name: .drawDataDownloadedSuccess, object: nil)
        addRefreshController()
        loadViews()
        configureEmojiView()
        layoutViews(size: view.bounds.size)
        collectionViewTapGesture = UITapGestureRecognizer(target: self, action: #selector(tap))
        collectionView.addGestureRecognizer(collectionViewTapGesture)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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

        guard let index = messages.firstIndex(of: message) else { return }
        messages[index].id = correctId
        messages[index].sendStatus = .success
        guard message.receiver == friendName || (message.receiver == "PublicPino" && friendName.isEmpty) else {
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
extension ChatRoomViewController: MessageInputDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func sendWasTapped(content: String) {
        guard !content.isEmpty else { return }
        let wrappedMessage = processMessageString(for: content)
        manager.notSendContent.append(wrappedMessage)
        insertNewMessageCell([wrappedMessage])
//        manager.sendMessage(content, to: friendName, from: username, option: messageOption, uuid: wrappedMessage.uuid)
        manager.sendWrappedMessage(wrappedMessage)
    }
    
    func addButtonTapped() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        messageInputBar.textView.resignFirstResponder()
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let popover = actionSheet.popoverPresentationController
        popover?.sourceView = messageInputBar.addButton
        popover?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        actionSheet.addAction(UIAlertAction(title: "拍照", style: .default, handler: { [weak self] (action) in
            imagePicker.sourceType = .camera
            imagePicker.cameraCaptureMode = .photo
            self?.present(imagePicker, animated: true, completion: nil)
        }))
        actionSheet.addAction(UIAlertAction(title: "从相册选择", style: .default, handler: { [weak self] (action) in
            self?.messageInputBar.textView.resignFirstResponder()
            self?.present(imagePicker, animated: true) {
                actionSheet.dismiss(animated: true, completion: nil)
            }
        }))
        let startCallAction = { [weak self] in
            guard let self = self else { return }
            let uuid = UUID().uuidString
            self.manager.sendCallRequst(to: self.friendName, uuid: uuid)
            AppDelegate.shared.callManager.startCall(handle: self.friendName, uuid: uuid)
        }
        actionSheet.addAction(UIAlertAction(title: "语音通话", style: .default, handler: {  (action) in
            startCallAction()
        }))
        actionSheet.addAction(UIAlertAction(title: "视频通话", style: .default, handler: { (action) in
            startCallAction()
            Recorder.sharedInstance().needSendVideo = true
        }))
        if #available(iOS 14.0, *) {
            actionSheet.addAction(UIAlertAction(title: "速绘", style: .default, handler: { [weak self] (action) in
                guard let self = self else { return }
                let drawVC = DrawViewController()
                drawVC.pkViewDelegate.dataChangedDelegate = self
                let newMessage = Message(message: "", messageSender: .ourself, receiver: self.friendName, uuid: UUID().uuidString, sender: self.username, messageType: .draw, option: self.messageOption)
                drawVC.message = newMessage
                drawVC.modalPresentationStyle = .fullScreen
                self.drawingIndexPath = IndexPath(item: self.messages.count, section: 0)
                self.navigationController?.present(drawVC, animated: true, completion: nil)
            }))
        }
        actionSheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        present(actionSheet, animated: true, completion: nil)
    }
    
    func sendCallRequest() {
        manager.sendCallRequst(to: friendName, uuid: UUID().uuidString)
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            let data = "hello world".data(using: .utf8)
            self.manager.sendVoiceData(data)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.originalImage] as? UIImage else { return }
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
        let message = Message(message: "", imageURL: imageURL.absoluteString, videoURL: nil, messageSender: .ourself, receiver: friendName, sender: username, messageType: .image, option: messageOption, date: NSDate().description, sendStatus: .fail)
        manager.imageDict[message.uuid] = imageURL
        insertNewMessageCell([message])
        DispatchQueue.main.async { [self] in
            collectionView.scrollToItem(at: IndexPath(row: messages.count-1, section: 0), at: .bottom, animated: true)
        }
        manager.uploadPhoto(imageUrl: imageURL, message: message) { (progress) in
            print(progress.fractionCompleted)
            DispatchQueue.main.async {
                self.updateUploadProgress(progress, message: message)
            }
        } success: { (task, data) in
            let json = JSON(data as Any)
            var filePath = json["filePath"].stringValue
            print(filePath)
            filePath = WebSocketManager.shared.encrypt.decryptMessage(filePath)
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
        return Message(message: string, messageSender: .ourself, receiver: friendName, sender: username, messageType: .text, option: messageOption, id: manager.maxId + 1, sendStatus: .fail)
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
        let message = Message(message: filePath, imageURL: filePath, videoURL: nil, messageSender: .ourself, receiver: friendName, sender: username, messageType: .image, option: messageOption, id: manager.maxId+1, date: Date().description, sendStatus: .fail)
        manager.sendWrappedMessage(message)
        insertNewMessageCell([message])
    }
}

extension ChatRoomViewController: MessageTableViewCellDelegate {
    func imageViewTapped(_ cell: MessageCollectionViewBaseCell, imageView: FLAnimatedImageView, path: String) {
        let browser = ImageBrowserViewController()
        browser.imagePath = path
        browser.modalPresentationStyle = .fullScreen
        browser.cache = cache
        AppDelegate.shared.navigationController.present(browser, animated: true, completion: nil)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if !AppDelegate.isPad() {
            return .portrait
        }
        return .all
    }
    
    
    
    //MARK: PKView手写
    func pkViewTapped(_ cell: MessageCollectionViewBaseCell, pkView: UIView!) {
        if let lastActive = activePKView {
            lastActive.isUserInteractionEnabled = false
            lastActive.resignFirstResponder()
        }
        activePKView = pkView
        if let indexPath = collectionView.indexPath(for: cell) {
            drawingIndexPath = indexPath
        }
        if #available(iOS 14.0, *) {

            let drawVC = DrawViewController()
            guard let pkView = pkView as? PKCanvasView else { return }
            let message = messages[drawingIndexPath.item]
            drawVC.message = message
            drawVC.pkView.drawing = pkView.drawing.transformed(using: CGAffineTransform(scaleX: 1/message.pkViewScale, y: 1/message.pkViewScale))
            print(message.pkViewScale)
            drawVC.pkViewDelegate.dataChangedDelegate = self
            drawVC.modalPresentationStyle = .fullScreen
            self.navigationController?.present(drawVC, animated: true, completion: nil)
        }
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
                let filePath = WebSocketManager.shared.encrypt.decryptMessage(json["filePath"].stringValue)
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
        guard let messages = noti.userInfo?["messages"] as? [Message], let pages = noti.userInfo?["pages"] as? Int else { return }
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
        pagesAndCurNum.curNum = (self.messages.count / ChatRoomViewController.numberOfHistory) + 1
        manager.historyMessages(for: (messageOption == .toAll) ? "chatRoom" : friendName, pageNum: pagesAndCurNum.curNum)
        pagesAndCurNum.curNum += 1
    }
    
    //MARK: ContextMune
    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let cell = collectionView.cellForItem(at: indexPath) as! MessageCollectionViewBaseCell
        let identifier = "\(indexPath.row)" as NSString
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: nil
        ) { (menuElement) -> UIMenu? in
            let copyAction = UIAction(title: "复制") { (_) in
                if let textCell = cell as? MessageCollectionViewTextCell {
                    let text = textCell.messageLabel.text
                    UIPasteboard.general.string = text
                }
            }
            var revokeAction: UIAction?
            var starEmojiAction: UIAction?
            if self.messages[indexPath.row].messageSender == .ourself && self.messages[indexPath.row].messageType != .join {
                revokeAction = UIAction(title: "撤回") { (_) in
                    self.revoke(indexPath: indexPath)
                }
            }
            if let imageUrl = cell.message.imageURL {
                starEmojiAction = UIAction(title: "收藏表情") { (_) in
                    let isGif = imageUrl.hasSuffix(".gif")
                    self.manager.starAndUploadEmoji(filePath: imageUrl, isGif: isGif)
                }
            }
            var children: [UIAction] = [copyAction]
            if revokeAction != nil { children.append(revokeAction!) }
            if starEmojiAction != nil { children.append(starEmojiAction!) }
            let menu = UIMenu(title: "", image: nil, children: children)
            return menu
        }
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
            manager.messagesGroup[index] = updatedMessage
        case .toOne:
            manager.messagesSingle.update(at: index, for: friendName, with: updatedMessage)
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
        let oldFrame = messageInputBar.frame
        let textHeight = textView.contentSize.height
        let lineHeight = (textView.text as NSString).size(withAttributes: textView.typingAttributes).height
        let lineCount = Int(textHeight / lineHeight)
        let oldLineCount = Int((oldFrame.height - 20) / lineHeight)
        let lineCountChanged = lineCount - oldLineCount
        let heightChanged = CGFloat(lineCountChanged) * lineHeight
        let frameOfTableView = collectionView.frame
        if heightChanged != 0 {
            UIView.animate(withDuration: heightChanged != 0 ? 0.25 : 0) {
                self.messageInputBar.frame = CGRect(x: oldFrame.origin.x, y: oldFrame.origin.y-heightChanged, width: oldFrame.width, height: oldFrame.height+heightChanged)
                self.collectionView.frame = CGRect(origin: frameOfTableView.origin, size: CGSize(width: frameOfTableView.width, height: frameOfTableView.height-heightChanged))
            } completion: { [self] (_) in
                guard collectionView.numberOfItems(inSection: 0) > 0 else { return }
                collectionView.scrollToItem(at: IndexPath(row: collectionView.numberOfItems(inSection: 0)-1, section: 0), at: .bottom, animated: true)
            }
        } 
    }
    
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        return true
    }
    
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        return true
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            messageInputBar.sendTapped()
            return false
        }
        return true
    }
}
