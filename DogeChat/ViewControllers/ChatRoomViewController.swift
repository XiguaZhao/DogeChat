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


class ChatRoomViewController: UIViewController {
    
    let manager = WebSocketManager.shared
    let tableView = UITableView()
    let messageInputBar = MessageInputView()
    var messageOption: MessageOption = .toAll
    var friendName = ""
    var pagesAndCurNum = (pages: 1, curNum: 1)
    var originOfInputBar = CGPoint()
    var scrollBottom = true
    var indexPathToInsert: IndexPath?
    
    var messages = [Message]()
    
    var username = ""
    
    var lastIndexPath: IndexPath {
        return IndexPath(row: messages.count-1, section: 0)
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manager.messageDelegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(notification:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sendSuccess(notification:)), name: .sendSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadSuccess(notification:)), name: .uploadSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveNewMessageNotification(_:)), name: .receiveNewMessage, object: nil)
        addRefreshController()
        layoutViews()
        loadViews()
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(tap))
        tableView.addGestureRecognizer(recognizer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        messageInputBar.textView.delegate = self
//        [self.tableView setContentOffset:CGPointMake(0, self.tableView.contentSize.height - self.tableView.frame.size.height) animated:YES];
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        messageInputBar.textView.resignFirstResponder()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollBottom = false
    }
    
    deinit {
        print("chat room VC deinit")
    }
    
    @objc func tap() {
        NotificationCenter.default.post(name: NSNotification.Name.shouldResignFirstResponder, object: nil)
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
        (tableView.cellForRow(at: indexPath) as? MessageTableViewCell)?.indicator.stopAnimating()
        (tableView.cellForRow(at: indexPath) as? MessageTableViewCell)?.indicator.removeFromSuperview()
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
        manager.notSendMessages.append(wrappedMessage)
        insertNewMessageCell(wrappedMessage)
        manager.sendMessage(content, to: friendName, from: username, option: messageOption, uuid: wrappedMessage.uuid)
    }
    
    func addButtonTapped() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "拍照", style: .default, handler: { [weak self] (action) in
            imagePicker.sourceType = .camera
            imagePicker.cameraCaptureMode = .photo
            self?.present(imagePicker, animated: true, completion: nil)
        }))
        actionSheet.addAction(UIAlertAction(title: "从相册选择", style: .default, handler: { [weak self] (action) in
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
        picker.dismiss(animated: true, completion: nil)
        guard let image = info[.originalImage] as? UIImage else { return }
        var isGif = false
        var originalUrl: URL?
        if let originalUrl_ = info[.imageURL] as? URL {
            isGif = originalUrl_.absoluteString.hasSuffix(".gif")
            originalUrl = originalUrl_
        }
        let (_, imageURL) = (isGif ? (nil, originalUrl!) : compressImage(image))
        let message = Message(message: "", imageURL: imageURL.absoluteString, videoURL: nil, messageSender: .ourself, receiver: friendName, sender: username, messageType: .image, option: messageOption, date: NSData().description, sendStatus: .fail)
        manager.imageDict[message.uuid] = imageURL
        insertNewMessageCell(message, invokeNow: true)
        manager.uploadPhoto(imageUrl: imageURL, message: message) { (progress) in
            print(progress.fractionCompleted)
            DispatchQueue.main.async {
                self.updateUploadProgress(progress, message: message)
            }
        } success: { (task, data) in
            
        }

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
        let targetCell = tableView.visibleCells.filter { cell in
            guard let cell = cell as? MessageTableViewCell else { return false }
            return cell.message.uuid == message.uuid
        }.first
        guard let cell = targetCell as? MessageTableViewCell else { return }
        cell.percentIndicator.setProgress(CGFloat(progress.fractionCompleted), animated: true)
        if progress.fractionCompleted == 1 {
            cell.percentIndicator.removeFromSuperview()
        }
    }
    
    private func processMessageString(for string: String) -> Message {
        return Message(message: string, messageSender: .ourself, receiver: friendName, sender: username, messageType: .text, option: messageOption, id: manager.maxId + 1, sendStatus: .fail)
    }
}

extension ChatRoomViewController: MessageTableViewCellDelegate {
    func imageViewTapped(_ cell: MessageTableViewCell, imageView: FLAnimatedImageView) {
        let browser = ImageBrowserViewController()
        browser.cellImageView = imageView
        browser.modalPresentationStyle = .fullScreen
        self.present(browser, animated: true, completion: nil)
    }
}

extension ChatRoomViewController: MessageDelegate {
    
    @objc func receiveNewMessageNotification(_ notification: Notification) {
        guard let message = notification.object as? Message, message.option == messageOption else {
            return
        }
        if message.option == .toOne && message.senderUsername != friendName { return }
        insertNewMessageCell(message, invokeNow: true)
    }
        
    func updateOnlineNumber(to newNumber: Int) {
        guard messageOption == .toAll else { return }
        navigationItem.title = "群聊"// + "(\(newNumber)人在线)"
    }
    
    func receiveMessages(_ messages: [Message], pages: Int) {
        let minId = (self.messages.first?.id) ?? Int.max
        self.pagesAndCurNum.pages = pages
        let filtered = messages.filter { $0.id < minId }
        for message in filtered {
            self.messages.insert(message, at: 0)
            self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
            if messageOption == .toAll {
                manager.messagesGroup.insert(message, at: 0)
            } else {
                manager.messagesSingle.insert(message, at: 0, for: friendName)
            }
        }
        self.tableView.refreshControl?.endRefreshing()
    }
    
    func newFriendRequest() {
        guard let contactVC = navigationController?.viewControllers.filter({ $0 is ContactsTableViewController }).first as? ContactsTableViewController else { return }
        navigationItem.rightBarButtonItem = contactVC.itemRequest
        manager.playSound()
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
        pagesAndCurNum.curNum = (self.messages.count / 10) + 1
        manager.historyMessages(for: (messageOption == .toAll) ? "chatRoom" : friendName, pageNum: pagesAndCurNum.curNum)
        pagesAndCurNum.curNum += 1
    }
    
    //MARK: ContextMune
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let cell = tableView.cellForRow(at: indexPath) as! MessageTableViewCell
        let identifier = "\(indexPath.row)" as NSString
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: nil
        ) { (menuElement) -> UIMenu? in
            let copyAction = UIAction(title: "复制") { (_) in
                let text = cell.messageLabel.text
                UIPasteboard.general.string = text
            }
            var revokeAction: UIAction?
            if self.messages[indexPath.row].messageSender == .ourself && self.messages[indexPath.row].messageType != .join && self.messageOption == .toOne {
                revokeAction = UIAction(title: "撤回") { (_) in
                    self.revoke(indexPath: indexPath)
                }
            }
            let menu = UIMenu(title: "", image: nil, children: (revokeAction == nil) ? [copyAction] : [copyAction, revokeAction!])
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
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
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
        let frameOfTableView = tableView.frame
        if heightChanged != 0 {
            UIView.animate(withDuration: heightChanged != 0 ? 0.25 : 0) {
                self.messageInputBar.frame = CGRect(x: oldFrame.origin.x, y: oldFrame.origin.y-heightChanged, width: oldFrame.width, height: oldFrame.height+heightChanged)
                self.tableView.frame = CGRect(origin: frameOfTableView.origin, size: CGSize(width: frameOfTableView.width, height: frameOfTableView.height-heightChanged))
            } completion: { [self] (_) in
                checkIfShouldInsertNewCell(needScroll: true)
            }
        } else {
            checkIfShouldInsertNewCell()
        }
    }
    
    private func checkIfShouldInsertNewCell(needScroll: Bool = false) {
        guard messages.count > 0 else { return }
        if let indexPath = indexPathToInsert {
            self.tableView.insertRows(at: [indexPath], with: .bottom)
            self.indexPathToInsert = nil
            self.tableView.scrollToRow(at: self.lastIndexPath, at: .bottom, animated: true)
        } else if needScroll {
            self.tableView.scrollToRow(at: self.lastIndexPath, at: .bottom, animated: true)
        }
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
