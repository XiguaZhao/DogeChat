
import UIKit
import SwiftyJSON
import DogeChatNetwork
import DogeChatUniversal
import PhotosUI
import FLAnimatedImage
import PencilKit
import DogeChatCommonDefines

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
    
    enum PickerPurpose {
        case send
        case addEmoji
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
    lazy var groupMembers: [Friend]? = {
        if let group = self.friend as? Group {
            return group.membersDict?.map({$0.value})
        }
        return nil
    }()
    var friend: Friend! {
        didSet {
            messages = friend.messages
            customTitle = friend.nickName ?? friend.username
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
    var pickerPurpose: PickerPurpose = .send
    var addEmojiType: Emoji.AddEmojiType = .favorite
    var heightCache = [String : CGFloat]()
    var jumpToUnreadStack: UIStackView!
    let jumpToUnreadButton = UIImageView()
    var jumpToBottomStack: UIStackView!
    let atLabel = UILabel()
    var explictJumpMessageUUID: String?
    let titleLabel = UILabel()
    let titleAvatar = FLAnimatedImageView()
    let titleAvatarContainer = UIView()
    var pagesAndCurNum = (pages: 1, curNum: 1)
    var activeSwipeIndexPath: IndexPath?
    lazy var messageSender: MessageSender = {
        let sender = MessageSender()
        sender.progressDelegate = self
        sender.referMessageDataSource = self
        sender.manager = self.manager?.httpsManager
        return sender
    }()
    let emojiSelectView = EmojiView()
    var messages = [Message]()
    var messagesUUIDs: Set<String> {
        return Set(self.messages.map{ $0.uuid })
    }
    var activePKView: UIView!
    var friendAvatarUrl: String {
        friend.avatarURL
    }
    var lastViewSize = CGSize.zero
    lazy var lastTextViewHeight: CGFloat = {
        return messageInputBar.textView.frame.height
    }()
    weak var contactVC: ContactsTableViewController?
    weak var activeMenuCell: MessageBaseCell?
    weak var transitionSourceView: UIView!
    weak var transitionToView: UIView!
    weak var transitionToRadiusView: UIView?
    weak var transitionFromCornerRadiusView: UIView?
    var transitionPreferDuration: TimeInterval?
    var transitionPreferDamping: CGFloat?

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
        NotificationCenter.default.addObserver(self, selector: #selector(mediaBrowserPathChange(_:)), name: .mediaBrowserPathChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(friendChangeAvatar(_:)), name: .friendChangeAvatar, object: nil)
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            if isMac() {
                self?.messageInputBar.textView.becomeFirstResponder()
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(playToEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(self, selector: #selector(enterForeground(_:)), name: UIScene.willEnterForegroundNotification, object: nil)
        } else {
            
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
        //上报已读
        DispatchQueue.global().async { [self] in
            if let maxID = self.messages.max(by: { $0.id < $1.id })?.id {
                manager.commonWebSocket.send(makeJsonString(for: ["method" : "readMessage",
                                                                  "userId" : friend.userID,
                                                                  "readId" : maxID]))
            }
        }
    }
        
    deinit {
        print("chat room VC deinit")
        MessageAudioCell.voicePlayer.replaceCurrentItem(with: nil)
        PlayerManager.shared.playerTypes.remove(.chatroomVideoCell)
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
            } else if keyCode == .keyboardEscape {
                if messageInputBar.referView.alpha == 1 {
                    cancleAction(messageInputBar.referView)
                }
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
    
    @available(iOS 13, *)
    @objc func enterForeground(_ noti: Notification) {
        if isPad() && !isMac() {
            scrollToBottomWithoutAnimation()
        }
    }
    
    @objc func friendChangeAvatar(_ noti: Notification) {
        let friend = noti.userInfo?["friend"] as! Friend
        if friend.userID != self.friend.userID { return }
        self.friend.avatarURL = friend.avatarURL
        if !friend.isGroup {
            for message in self.messages {
                message.avatarUrl = friend.avatarURL
            }
            self.tableView.reloadData()
        }
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
                cell.message.sendStatus = .success
                cell.indicator.isHidden = true
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

extension ChatRoomViewController {
    
    @objc func receiveNewMessageNotification(_ notification: Notification) {
        guard notification.object as? String == self.username, let dict = notification.userInfo?["friendDict"] as? [String : [Message]] else {
            debugText("username不匹配noti")
            return
        }
        for (friendID, newMessages) in dict {
            if friendID == self.friend.userID {
                if newMessages.isEmpty {
                    debugText("newMessage为空")
                }
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
        let alreadyMin = self.messages.max(by: { $0.id > $1.id })?.id ?? Int.max
        self.messages.insert(contentsOf: filtered, at: 0)
        if filtered.contains(where: { $0.id > alreadyMin }) {
            self.messages.sort(by: { $0.id < $1.id })
            self.tableView.reloadData()
            return
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
        tableView.reloadRows(at: [indexPath], with: .fade)
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
        emojiSelectView.pageIndicator.isHidden = true
        return true
    }
    
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        showEmojiButton(true)
        return true
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            messageInputBar.sendTapped()
            messageInputBar.textView.font = .systemFont(ofSize: MessageInputView.textViewDefaultFontSize)
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
