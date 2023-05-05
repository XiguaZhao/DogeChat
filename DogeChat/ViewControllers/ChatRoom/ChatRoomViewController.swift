
import UIKit
import SwiftyJSON
import DogeChatNetwork
import DogeChatUniversal
import PhotosUI
import FLAnimatedImage
import PencilKit
import DogeChatCommonDefines
import MJRefresh

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
        
    var manager: WebSocketManager? {
        return socketForUsername(username)
    }
    var tableView = DogeChatTableView(frame: .zero, style: .grouped)
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
    var imagePickerType: MessageType = .sticker
    var pickerPurpose: PickerPurpose = .send
    var addEmojiType: Emoji.AddEmojiType = .favorite
    var heightCache = [String : (header: CGFloat, row: CGFloat)]()
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
    var isFetchingHistory = false
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
    var transitionSourceView: UIView!
    var transitionToView: UIView!
    weak var transitionToRadiusView: UIView?
    weak var transitionFromCornerRadiusView: UIView?
    var transitionPreferDuration: TimeInterval?
    var transitionPreferDamping: CGFloat?

    var hapticInputIndex = 0
    var pan: UIScreenEdgePanGestureRecognizer?
    var ignoreKeyboardChange = false
    
    var lastIndexPath: IndexPath {
        return IndexPath(row: 0, section: messages.count-1)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        hidesBottomBarWhenPushed = true
        registerNotifications()
        registerUpdateTime()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        makeDetailRightBarButton()
        navigationItem.largeTitleDisplayMode = .never
//        addRefreshController()
        loadViews()
        displayHistoryIfNeeded()
        checkMyNameInGroup()
    }
    
    func registerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(sendSuccess(notification:)), name: .sendSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveNewMessageNotification(_:)), name: .receiveNewMessage, object: self.manager)
        NotificationCenter.default.addObserver(self, selector: #selector(confirmSendPhoto), name: .confirmSendPhoto, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(emojiButtonTapped), name: .emojiButtonTapped, object: messageInputBar)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveEmojiInfoChangedNotification(_:)), name: .emojiInfoChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receiveHistoryMessages(_:)), name: .receiveHistoryMessages, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(connected(_:)), name: .connected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(pasteImageAction(_:)), name: .pasteImage, object: messageInputBar.textView)
        NotificationCenter.default.addObserver(forName: .logout, object: username, queue: .main) { [weak self] _ in
            self?.navigationController?.viewControllers = []
        }
        NotificationCenter.default.addObserver(self, selector: #selector(mediaBrowserPathChange(_:)), name: .mediaBrowserPathChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(friendChangeAvatar(_:)), name: .friendChangeAvatar, object: nil)
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.tableView.reloadData()
            if isMac() {
                self.messageInputBar.textView.becomeFirstResponder()
            } else {
                self.messageInputBar.activeWhenEnterBackground = false
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playToEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(self, selector: #selector(enterForeground(_:)), name: UIScene.willEnterForegroundNotification, object: nil)
        } else {
            
        }
        NotificationCenter.default.addObserver(self, selector: #selector(groupInfoChange(noti:)), name: .groupInfoChange, object: username)
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
        if messageInputBar.observingKeyboard {
            messageInputBar.textViewResign()
            if isPad() {
                if !isMac() {
                    NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
                }
            } else if isPhone() {
                NotificationCenter.default.removeObserver(self, name: UIWindow.keyboardWillShowNotification, object: nil)
                NotificationCenter.default.removeObserver(self, name: UIWindow.keyboardWillHideNotification, object: nil)
                NotificationCenter.default.removeObserver(self, name: UIWindow.keyboardDidShowNotification, object: nil)
            }
            messageInputBar.observingKeyboard = false
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.friend.messages.forEach({ $0.isRead = true })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !messageInputBar.observingKeyboard {
            if isPad() {
                if !isMac() {
                    NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameChangeNoti(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
                }
            } else if isPhone() {
                NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(noti:)), name: UIWindow.keyboardWillShowNotification, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(noti:)), name: UIWindow.keyboardWillHideNotification, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(noti:)), name: UIWindow.keyboardDidShowNotification, object: nil)
            }
            messageInputBar.observingKeyboard = true
        }
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
            if keyCode == .keyboardEscape {
            } else if !messageInputBar.textView.isFirstResponder {
                messageInputBar.textView.becomeFirstResponder()
            }
        }
    }
    
    override var keyCommands: [UIKeyCommand]? {
        var arr = super.keyCommands ?? []
        arr.append(UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: UIKeyModifierFlags(), action: #selector(escapeCommand)))
        return arr
    }
    
    @objc func escapeCommand() {
        if messageInputBar.isActive {
            messageInputBar.textViewResign()
        } else if messageInputBar.referView.alpha == 1 {
            cancleAction(messageInputBar.referView)
        }
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        if let key = presses.first?.key {
            let keyCode = key.keyCode
            if keyCode == .keyboardUpArrow {
                contactVC?.arrowUp(messageInputBar.textView)
            } else if keyCode == .keyboardDownArrow {
                contactVC?.arrowDown(messageInputBar.textView)
            } else if keyCode == .keyboardV && key.modifierFlags == .command {
                processItemProviders(UIPasteboard.general.itemProviders)
            }
        }
    }
    

    func contentHeight() -> CGFloat {
        return self.tableView.contentSize.height
//        return heightCache.values.reduce(0) { partialResult, heights in
//            return partialResult + heights.header + heights.row
//        }
    }
    
    func updateCachedHeight(uuid: String, header: CGFloat?, row: CGFloat?) {
        if heightCache[uuid] == nil {
            heightCache[uuid] = (header ?? 0, row ?? 0)
        } else {
            if let row = row {
                heightCache[uuid]?.row = row
            }
            if let header = header {
                heightCache[uuid]?.header = header
            }
        }
    }
    
    func scrollBottom(animated: Bool = false) {
        if messages.count > 1 {
            tableView.scrollToRow(at: IndexPath(row: 0, section: messages.count - 1), at: .bottom, animated: animated)
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
    
    @objc func didEnterBackground() {
        if !isMac() {
            messageInputBar.activeWhenEnterBackground = messageInputBar.textView.isFirstResponder
            messageInputBar.textView.resignFirstResponder()
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
            let indexPath = IndexPath(row: 0, section: index)
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
    
    func shouldShowTimeForMessage(_ message: Message) -> Bool {
        return secondsFromLastShowTimeMessage(message) > TimeHeader.secondThreshold || distanceFromLastShowTime(message: message).distance > TimeHeader.countThreshold
    }

}

private var MessageShowTimeKey: UInt8 = 0

extension Message {
    @objc var showTime: Bool {
        get {
            return (objc_getAssociatedObject(self, &MessageShowTimeKey) as? NSNumber)?.boolValue ?? false
        }
        set {
            objc_setAssociatedObject(self, &MessageShowTimeKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

extension ChatRoomViewController {
    
    @objc func receiveNewMessageNotification(_ notification: Notification) {
        let messages = notification.userInfo?["messages"] as! [Message]
        let filter = messages.filter({ $0.friend?.userID == self.friend.userID })
        insertNewMessageCell(filter)
        print(">>>>>>>>>>>>>>>")
        print(self.customTitle, filter.count)
    }
        
    
}

extension ChatRoomViewController {
    //MARK: Refresh
    func addRefreshController() {
        if isMac() {
            let controller = UIRefreshControl()
            controller.addTarget(self, action: #selector(displayHistory), for: .valueChanged)
            tableView.refreshControl = controller
        }
    }
    
    @objc func displayHistory() {
        isFetchingHistory = true
        customTitle = localizedString("loading")
        pagesAndCurNum.curNum = (self.messages.count / numberOfHistory) + 1
        manager?.historyMessages(for: friend, pageNum: pagesAndCurNum.curNum, pageSize: numberOfHistory)
        pagesAndCurNum.curNum += 1
        tableView.mj_header?.endRefreshing()
    }
    
    @objc func receiveHistoryMessages(_ noti: Notification) {
        defer {
            tableView.refreshControl?.endRefreshing()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isFetchingHistory = false
            }
        }
        guard noti.object as? String == self.username else { return }
        if purpose == .chat && self.navigationController?.visibleViewController != self { return }
        var empty = true
        let tempHeight = contentHeight()
        
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
        let oldStateEmpty = self.messages.isEmpty
        if !oldStateEmpty {
            tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
        }
        self.messages.insert(contentsOf: filtered, at: 0)
        if filtered.contains(where: { $0.id > alreadyMin }) {
            self.messages.sort(by: { $0.id < $1.id })
            self.tableView.reloadData()
            return
        }
        let indexPaths = [Int](0..<filtered.count).map{ IndexPath(item: 0, section: $0) }
        var myselfIndexPaths = [IndexPath]()
        var othersIndexPaths = [IndexPath]()
        for (index, indexPath) in indexPaths.enumerated() {
            if filtered[index].messageSender == .ourself {
                myselfIndexPaths.append(indexPath)
            } else {
                othersIndexPaths.append(indexPath)
            }
        }
        if oldStateEmpty {
            let myIndexSet = IndexSet(myselfIndexPaths.map { $0.section })
            let othersIndexSet = IndexSet(othersIndexPaths.map { $0.section })
            tableView.performBatchUpdates {
                self.tableView.insertSections(myIndexSet, with: .right)
                self.tableView.insertSections(othersIndexSet, with: .left)
            } completion: { _ in
                self.isFetchingHistory = true
                if empty && !indexPaths.isEmpty{
                    self.tableView.scrollToRow(at: IndexPath(row: 0, section: self.tableView.numberOfSections - 1), at: .bottom, animated: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                        guard let self = self else { return }
                        self.scrollViewDidEndDecelerating(self.tableView)
                        self.isFetchingHistory = false
                    }
                } else {
                    self.tableView.refreshControl?.endRefreshing()
                    self.isFetchingHistory = false
                }
            }
        } else {
            let indexSet = IndexSet(indexPaths.map{$0.section})
            UIView.setAnimationsEnabled(false)
            tableView.beginUpdates()
            tableView.insertSections(indexSet, with: .none)
            tableView.endUpdates()
            UIView.setAnimationsEnabled(true)
            tableView.scrollToRow(at: IndexPath(row: 0, section: indexPaths.last!.section + 1), at: .top, animated: false)
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
        message.text = String.localizedStringWithFormat(localizedString("someoneRecallMessage"), message.senderUsername)
        message.messageType = .join
        message.referMessage = nil
        message.referMessageUUID = nil
        let indexPath = IndexPath(row: 0, section: index)
        tableView.reloadRows(at: [indexPath], with: .fade)
    }
    
    func revokeMessage(_ id: Int, senderID: String, receiverID: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        removeMessage(index: index)
    }
}

extension ChatRoomViewController {
        
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
