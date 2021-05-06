/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import SwiftyJSON
import YPTransition

protocol ChatRoomVCDelegate: class {
    
}

class ChatRoomViewController: UIViewController {
    
    static let numberOfHistory = 10
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
    var isAutoGetHistory = false
    var isFirstTimeGetHistory = false
    let messageBarHeight:CGFloat = 60.0
    
    var username = ""
    
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
        addRefreshController()
//        layoutViews(size: view.bounds.size)
        loadViews()
        configureEmojiView()
        layoutViews(size: view.bounds.size)
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(tap))
        collectionView.addGestureRecognizer(recognizer)
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
        collectionView.reloadData()
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
        guard message.receiver == friendName else {
            return
        }
        let indexPath = IndexPath(row: index, section: 0)
        (collectionView.cellForItem(at: indexPath) as? MessageCollectionViewCell)?.indicator.stopAnimating()
        (collectionView.cellForItem(at: indexPath) as? MessageCollectionViewCell)?.indicator.removeFromSuperview()
    }
    
    @objc func uploadSuccess(notification: Notification) {
        guard let message = notification.userInfo?["message"] as? Message else { return }
        guard let index = messages.firstIndex(of: message) else { return }
        messages[index].sendStatus = .success
    }

}

//MARK - Message Input Bar
extension ChatRoomViewController: MessageInputDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func sendWasTapped(content: String) {
        guard !content.isEmpty else { return }
        let wrappedMessage = processMessageString(for: content)
        manager.notSendContent.append(wrappedMessage)
        insertNewMessageCell([wrappedMessage])
        manager.sendMessage(content, to: friendName, from: username, option: messageOption, uuid: wrappedMessage.uuid)
    }
    
    func addButtonTapped() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
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
        actionSheet.addAction(UIAlertAction(title: "语音通话", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            let uuid = UUID().uuidString
            self.manager.sendCallRequst(to: self.friendName, uuid: uuid)
            AppDelegate.shared.callManager.startCall(handle: self.friendName, uuid: uuid)
        }))
        actionSheet.addAction(UIAlertAction(title: "结束语音通话", style: .default, handler: { [weak self] (action) in
            Recorder.sharedInstance().stopRecordAndPlay()
            guard let self = self else { return }
            self.manager.endCall(uuid: self.manager.nowCallUUID.uuidString, with: self.friendName)
            guard let call = AppDelegate.shared.callManager.callWithUUID(self.manager.nowCallUUID) else { return }
            AppDelegate.shared.callManager.end(call: call)
        }))
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
        self.latestPickedImageInfo = (isGif ? (nil, originalUrl!) : compressImage(image))
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
        let message = Message(message: "", imageURL: imageURL.absoluteString, videoURL: nil, messageSender: .ourself, receiver: friendName, sender: username, messageType: .image, option: messageOption, date: NSData().description, sendStatus: .fail)
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
        }
        self.latestPickedImageInfo = nil
    }
    
    func compressImage(_ image: UIImage) -> (image: UIImage, fileUrl: URL) {
        var size = image.size
        let ratio = size.width / size.height
        let width: CGFloat = UIScreen.main.bounds.width
        let height = width / ratio
        size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        let result = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        let fileUrl = URL(string: "file://" + NSTemporaryDirectory() + UUID().uuidString + ".jpg")!
        try? result.jpegData(compressionQuality: 0.3)?.write(to: fileUrl)
        return (result, fileUrl)
    }

    func updateUploadProgress(_ progress: Progress, message: Message) {
        let targetCell = collectionView.visibleCells.filter { cell in
            guard let cell = cell as? MessageCollectionViewCell else { return false }
            return cell.message.uuid == message.uuid
        }.first
        guard let _ = targetCell as? MessageCollectionViewCell else { return }
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
        let message = Message(message: "", imageURL: filePath, videoURL: nil, messageSender: .ourself, receiver: friendName, sender: username, messageType: .image, option: messageOption, id: manager.maxId+1, date: Date().description, sendStatus: .fail)
        manager.sendMessage(filePath, to: friendName, from: username, option: messageOption, uuid: message.uuid, type: "image")
        insertNewMessageCell([message])
    }
}

extension ChatRoomViewController: MessageTableViewCellDelegate {
    func imageViewTapped(_ cell: MessageCollectionViewCell, imageView: FLAnimatedImageView, path: String) {
        let browser = ImageBrowserViewController()
        browser.imagePath = path
        browser.modalPresentationStyle = .fullScreen
        browser.cache = cache
        self.present(browser, animated: true, completion: nil)
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
        let minId = (self.messages.first?.id) ?? Int.max
        self.pagesAndCurNum.pages = pages
        let filtered = messages.filter { $0.id < minId }.reversed() as [Message]
        let oldIndexPath = IndexPath(item: min(self.messages.count, ChatRoomViewController.numberOfHistory), section: 0)
        self.messages.insert(contentsOf: filtered, at: 0)
        let indexPaths = [Int](0..<filtered.count).map{ IndexPath(item: $0, section: 0) }
        UIView.performWithoutAnimation {
            self.collectionView.insertItems(at: indexPaths)
        }
        if messageOption == .toAll {
            manager.messagesGroup.insert(contentsOf: filtered, at: 0)
        } else {
            manager.messagesSingle.insert(filtered, at: 0, for: friendName)
        }
        self.collectionView.refreshControl?.endRefreshing()
        if isAutoGetHistory {
            collectionView.scrollToItem(at: oldIndexPath, at: .top, animated: false)
            isAutoGetHistory = false
        } else if isFirstTimeGetHistory {
            collectionView.scrollToItem(at: IndexPath(item: max(0, self.messages.count-1), section: 0), at: .bottom, animated: true)
        }
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
//        collectionView.refreshControl = controller
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
        let cell = collectionView.cellForItem(at: indexPath) as! MessageCollectionViewCell
        let identifier = "\(indexPath.row)" as NSString
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: nil
        ) { (menuElement) -> UIMenu? in
            let copyAction = UIAction(title: "复制") { (_) in
                let text = cell.messageLabel.text
                UIPasteboard.general.string = text
            }
            var revokeAction: UIAction?
            var starEmojiAction: UIAction?
            if self.messages[indexPath.row].messageSender == .ourself && self.messages[indexPath.row].messageType != .join && self.messageOption == .toOne {
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
