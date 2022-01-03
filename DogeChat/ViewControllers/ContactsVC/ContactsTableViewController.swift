//
//  ContactsTableViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/5/27.
//  Copyright © 2020 Xiguang Zhao. All rights reserved.
//

import UIKit
import SwiftyJSON
import DogeChatNetwork
import DogeChatUniversal
import WatchConnectivity
import Foundation

class ContactsTableViewController: DogeChatViewController, UITableViewDelegate, UITableViewDataSource, DogeChatVCTableDataSource {
    
    var unreadMessage = [String: (unreadCount: Int, hasAt: Bool)]() {
        didSet {
            let total = unreadMessage.values.map({$0.unreadCount}).reduce(0, +)
            self.navigationItem.title = total > 0 ? "(\(total)未读)" : username
            self.navigationController?.tabBarItem.badgeValue = total > 0 ? String(total) : nil
        }
    }
    var friends: [Friend] = []
    var usernames: [String] {
        friends.map { $0.username }
    }
    private var password: String?
    var loginCount = 0
    let avatarImageView = FLAnimatedImageView()
    var manager: WebSocketManager? {
        return socketForUsername(username)
    }
    lazy var messageSender: MessageSender = {
        let sender = MessageSender()
        sender.manager = self.manager?.httpsManager
        return sender
    }()
    override var username: String {
        didSet {
            self.navigationItem.title = username
        }
    }
//    var nav: UINavigationController? {
//        if #available(iOS 13.0, *) {
//            return (self.view.window?.windowScene?.delegate as? SceneDelegate)?.navigationController
//        } else {
//            return self.navigationController
//        }
//    }
    var nameLabel = UILabel()
    weak var barItem: UIBarButtonItem!
    var newesetDropIndexPath: IndexPath?
    var selectedFriend: Friend? {
        return (self.splitViewController as? DogeChatSplitViewController)?.findChatRoomVC()?.friend
    }
    var tableView = DogeChatTableView()
    static let pkDataWriteQueue = DispatchQueue(label: "com.zhaoxiguang.dogeChat.pkDataWrite")
    var appDelegate: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    var lastAvatarURL: String?
    var loginSuccess = false {
        didSet {
            if loginSuccess {
                refreshContacts()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        fontSizeScale = getScaleForSizeCategory(UIScreen.main.traitCollection.preferredContentSizeCategory)
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .never
        view.addSubview(tableView)
        tableView.mas_makeConstraints { [weak self] make in
            make?.edges.equalTo()(self?.view)
        }
        tableView.dropDelegate = self
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        tableView.delegate = self
        tableView.dataSource = self
        tableView.dragDelegate = self
        tableView.register(ContactTableViewCell.self, forCellReuseIdentifier: ContactTableViewCell.cellID)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        NotificationCenter.default.addObserver(self, selector: #selector(uploadSuccess(notification:)), name: .uploadSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateMyAvatar(_:)), name: .updateMyAvatar, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(friendChangeAvatar(_:)), name: .friendChangeAvatar, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(connectingNoti(_:)), name: .connecting, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(connectedNoti(_:)), name: .connected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(loginingNoti(_:)), name: .logining, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(loginedNoti(_:)), name: .logined, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshContactsNoti(_:)), name: .refreshContacts, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(processRemoteNoti), name: .remoteNotiInfoSet, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hasUnknownFriendNoti(_:)), name: .hasUnknownFriend, object: nil)
        NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: .main) { noti in
            if let size = noti.userInfo?["UIContentSizeCategoryNewValueKey"] as? UIContentSizeCategory {
                fontSizeScale = getScaleForSizeCategory(size)
            }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(doubleTapBadge), name: NSNotification.Name("doubleTapBadge"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(cookieExpireNoti(_:)), name: .cookieExpire, object: nil)
        setupRefreshControl()
        let barItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(presentSearchVC))
        self.navigationItem.rightBarButtonItem = barItem
        self.barItem = barItem
        setupMyAvatar()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .immersive, object: AppDelegate.shared.immersive)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: true)
        navigationItem.rightBarButtonItem = barItem
        if let splitVC = self.splitViewController, splitVC.isCollapsed {
            deselect()
        } else {
            reselectFriend(nil)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        manager?.messageManager.messageDelegate = self
        loadAllTracks(username: username)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tableView.refreshControl?.endRefreshing()
    }
            
    func setUsername(_ username: String, andPassword password: String?) {
        self.username = username
        self.password = password
    }
    
    func processUserActivity() {
        if #available(iOS 13, *) {
            if let userActivityModal = SceneDelegate.userActivityModal, let userActivity = SceneDelegate.activeUserActivity {
                let username = userActivityModal.accountInfo.username
                if let manager = manager, username == manager.httpsManager.myName {
                    let friendID = userActivityModal.friendID
                    if let index = friends.firstIndex(where: { $0.userID == friendID }) {
                        tableView(tableView, didSelectRowAt: IndexPath(row: index, section: 0))
                        SceneDelegate.activeUserActivity = nil
                        SceneDelegate.userActivityModal = nil
                    }
                } else {
                    if let sceneDelegate = SceneDelegate.usernameToDelegate[username] {
                        UIApplication.shared.requestSceneSessionActivation(sceneDelegate.window?.windowScene?.session, userActivity: userActivity, options: nil, errorHandler: nil)
                    } else {
                        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: nil, errorHandler: nil)
                    }
                    SceneDelegate.activeUserActivity = nil
                    SceneDelegate.userActivityModal = nil
                }
            }
            
            let userActivity = NSUserActivity(activityType: userActivityID)
            userActivity.title = "dogechat"
            userActivity.userInfo = ["username": username,
                                     "password": password as Any,
                                     "cookie": manager?.cookie as Any]
            userActivity.needsSave = true
            self.view.window?.windowScene?.userActivity = userActivity
            self.view.window?.windowScene?.updateUserActivityState(userActivity)
        }
    }
                    
    @objc func reachabilityChangeNoti(_ noti: Notification) {
    }
    
    @objc func connectingNoti(_ noti: Notification) {
        guard noti.object as? String == self.username else { return }
        navigationItem.title = "正在连接..."
        nameLabel.text = navigationItem.title
    }
    
    @objc func connectedNoti(_ noti: Notification) {
        guard noti.object as? String == self.username else { return }
        if !tableView.isEditing {
            setupMyAvatar()
        }
        navigationItem.title = username
        processUserActivity()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.refreshContacts(completion: nil)
            self?.manager?.inspectQuery(completion: { requests in
                let lateset = requests.map({ getTimestampFromStr($0.requestTime) }).max() ?? 0
                if lateset > self?.manager?.httpsManager.accountInfo.lastOpenRequestTime ?? 0 {
                    self?.newFriendRequest()
                }
            })
        }
        manager?.httpsManager.getProfile(nil)
        checkGroupInfos()
        if #available(iOS 13.0, *) {
            self.view.window?.windowScene?.title = username
        }
    }
    
    @objc func loginingNoti(_ noti: Notification) {
        guard noti.object as? String == self.username else { return }
        navigationItem.title = "正在登录..."
        nameLabel.text = navigationItem.title
    }
    
    @objc func loginedNoti(_ noti: Notification) {
        guard noti.object as? String == self.username else { return }
        WCSession.default.sendMessage(["username": username, "password": password as Any], replyHandler: nil, errorHandler: nil)
        MediaLoader.shared.cookie = manager?.cookie
    }
    
    @objc func refreshContactsNoti(_ noti: Notification) {
        guard noti.object as? String == self.username, let friends = noti.userInfo?["contacts"] as? [Friend] else { return }
        self.friends = friends
        tableView.reloadData()
        tableView.refreshControl?.endRefreshing()
        processRemoteNoti()
        reselectFriend(nil)
    }
    
    @objc func doubleTapBadge() {
        unreadMessage.removeAll()
        tableView.reloadData()
        for friend in friends {
            friend.messages.forEach({ $0.isRead = true })
        }
    }
    
    @objc func cookieExpireNoti(_ noti: Notification) {
        guard noti.object as? String == self.username else { return }
        if let manager = manager {
            let accountInfo = manager.httpsManager.accountInfo
            if !self.username.isEmpty, let password = accountInfo.password {
                manager.commonWebSocket.loginAndConnect(username: username, password: password, needContact: true, completion: nil)
                return
            }
        }
        if #available(iOS 13.0, *) {
            SceneDelegate.usernameToDelegate[username]?.makeLoginPage()
        } else {
            
        }
    }
    
    func processGroup(_ groups: [Group]) {
        var indexPaths = [IndexPath]()
        for group in groups {
            if let index = self.friends.firstIndex(where: { $0.userID == group.userID }) {
                indexPaths.append(IndexPath(row: index, section: 0))
            }
        }
        tableView.reloadRows(at: indexPaths, with: .none)
    }
    
    @objc func processRemoteNoti() {
        guard let info = appDelegate.latestRemoteNotiInfo else { return }
        if self.manager?.myInfo.userID == info.receiverID {
            if let friend = self.friends.first(where: { $0.userID == info.senderID }) {
                self.tabBarController?.selectedIndex = 0
                if (self.splitViewController as? DogeChatSplitViewController)?.findChatRoomVC()?.friend != friend {
                    jumpToFriend(friend)
                }
                AppDelegate.shared.latestRemoteNotiInfo = nil
                if #available(iOS 13, *) {
                    if isMac(), let sceneSession = SceneDelegate.usernameToDelegate[username]?.session {
                        let option = UIScene.ActivationRequestOptions()
                        option.requestingScene = self.view.window?.windowScene
                        UIApplication.shared.requestSceneSessionActivation(sceneSession, userActivity: nil, options: option, errorHandler: nil)
                    }
                }
            }
        }
    }
        
    @objc func presentSearchVC() {
        barItem.badgeValue = "0"
        let vc = SearchViewController()
        vc.username = self.username
        vc.delegate = self
        if let split = self.splitViewController, split.isCollapsed {
            let nav = DogeChatNavigationController(rootViewController: vc)
            self.present(nav, animated: true)
        } else {
            self.navigationController?.setViewControllersForSplitVC(vcs: [self, vc])
        }
    }
    
    func checkGroupInfos() {
        if let group = self.friends.first(where: { $0.isGroup }) as? Group, group.ownerUsername.isEmpty {
            manager?.httpsManager.getGroupList { _ in
            }
        }
    }
    
    func jumpToFriend(_ friend: Friend) {
        if let index = self.friends.firstIndex(of: friend) {
            let indexPath = IndexPath(row: index, section: 0)
            tableView(self.tableView, didSelectRowAt: indexPath)
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
    }
    
    func deleteFriend(_ friend: Friend) {
        if let index = self.friends.firstIndex(of: friend) {
            friends.remove(at: index)
            tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
        }
    }
    
    @objc func refreshContacts(completion: (()->Void)? = nil) {
        manager?.commonWebSocket.httpRequestsManager.getContacts {  _, _  in
            completion?()
        }
    }
    
    @objc func downRefreshAction(_ refreshControl: UIRefreshControl) {
        removeAllMessage()
        manager?.disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loginAndConnect()
        }
    }
    
    @objc func hasUnknownFriendNoti(_ noti: Notification) {
        if noti.object as? String == self.username {
            refreshContacts(completion: nil)
        }
    }
    
    func removeAllMessage() {
        manager?.commonWebSocket.httpRequestsManager.friends.removeAll()
        manager?.commonWebSocket.httpRequestsManager.friendDict.removeAll()
    }
    
    @objc func loginAndConnect() {
        if let password = password {
            manager?.loginAndConnect(username: username, password: password)
        } else if let cookieInfo = accountInfo(username: username)?.cookieInfo, cookieInfo.isValid {
            getContactsAndConnect()
        } else {
            if #available(iOS 13.0, *) {
                SceneDelegate.usernameToDelegate[username]?.makeLoginPage()
            } else {
                AppDelegateUI.shared.makeLogininVC()
            }
        }
    }
    
    func getContactsAndConnect() {
        manager?.httpsManager.getContacts() { [weak manager] _, error in
            if error == nil {
                manager?.commonWebSocket.connect()
            }
        }
    }
        
    func setupRefreshControl() {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(downRefreshAction(_:)), for: .valueChanged)
        self.tableView.refreshControl = control
    }
    
    
    deinit {
        print("contactVCDeinit")
    }
    
    func receiveNewMessages(_ messages: [Message], isGroup: Bool) { //打开聊天界面的话，要insert，没有的话要更新红点
        var friendDict = [String : [Message]]()
        for message in messages {
            let friendID = message.friend.userID
            friendDict.add(message, for: friendID)
        }
        var reloadIndexPaths = [IndexPath]()
        let chatVCs = findChatRoomVCs()
        NotificationCenter.default.post(name: .receiveNewMessage, object: username, userInfo: ["friendDict" : friendDict])
        for (friendID, newMessages) in friendDict {
            if let index = self.friends.firstIndex(where: { $0.userID == friendID }) {
                reloadIndexPaths.append(IndexPath(row: index, section: 0))
            }
            if !chatVCs.isEmpty && chatVCs.contains(where: { $0.friend.userID == friendID }) {
                unreadMessage[friendID] = (0, false)
            } else {
                let hasNewAt = newMessages.contains(where: { $0.someoneAtMe })
                let newCount = newMessages.filter({ $0.messageSender == .someoneElse }).count
                if let already = unreadMessage[friendID] {
                    unreadMessage[friendID] = (already.unreadCount + newCount, already.hasAt || hasNewAt)
                } else {
                    unreadMessage[friendID] = (newCount, hasNewAt)
                }
            }
        }
        tableView.reloadRows(at: reloadIndexPaths, with: .none)
        
        if messages.contains(where: { $0.messageSender == .someoneElse }) {
            playSound()
        }

        if isPhone() && (self.tabBarController?.selectedIndex != 0 || self.navigationController?.visibleViewController != self) {
            guard let message = friendDict.first?.value.last, message.messageSender != .ourself else { return }
            let friendID = message.friend.isGroup ? message.receiverUserID : message.senderUserID
            for chatVC in chatVCs {
                if friendID == chatVC.friend.userID {
                    return
                }
            }
            var content = message.option == .toGroup ? "\(message.senderUsername)：" : ""
            content += message.summary()
            if #available(iOS 13.0, *) {
                SceneDelegate.usernameToDelegate[username]?.pushWindow.assignValueForPush(sender: message.friend.username, content: content)
            }
        }
        reselectFriend(nil)
    }
            
    @objc func uploadSuccess(notification: Notification) {
        guard notification.object as? String == self.username,
              let manager = manager,
              let message = notification.userInfo?["message"] as? Message else { return }
        manager.commonWebSocket.sendWrappedMessage(message)
    }
    
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.friends.count
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: ContactTableViewCell!
        syncOnMainThread {
            let friend = self.friends[indexPath.row]
            cell = tableView.dequeueReusableCell(withIdentifier: ContactTableViewCell.cellID, for: indexPath) as? ContactTableViewCell
            cell.apply(friend, hasAt: self.unreadMessage[friend.userID]?.hasAt ?? false)
            cell.delegate = self
            if let number = unreadMessage[self.friends[indexPath.row].userID]?.unreadCount {
                cell.unreadCount = number
            }
        }
        return cell
    }
    
    //MARK: -Table view delegate
        
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing { return }
        unreadMessage[self.friends[indexPath.row].userID] = (0, false)
        let chatRoomVC = chatroomVC(for: indexPath)
        tableView.reloadRows(at: [indexPath], with: .none)
        reselectFriend(friends[indexPath.row])
        self.navigationController?.setViewControllersForSplitVC(vcs: [self, chatRoomVC], firstAnimated: false, secondAnimated: true, animatedIfCollapsed: true)
        unreadMessage[self.friends[indexPath.row].userID]?.unreadCount = 0
    }
    
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let path = self.friends[indexPath.row].avatarURL
        let config =  UIContextMenuConfiguration(identifier: (self.friends[indexPath.row].username as NSString)) {
            [weak self] in
            guard let self = self else { return nil }
            let vc = self.chatroomVC(for: indexPath)
            vc.purpose = .peek
            return vc
        } actionProvider: { (menuElement) -> UIMenu? in
            let avatarElement = UIAction(title: "查看头像") { [weak self] _ in
                guard let self = self else { return }
                self.avatarTapped(nil, path: path)
            }
            var actions = [avatarElement]
            if UIApplication.shared.supportsMultipleScenes {
                actions.append(UIAction(title: "在单独窗口打开") { [weak self] _ in
                    guard let friend = self?.friends[indexPath.row] else { return }
                    let option = UIScene.ActivationRequestOptions()
                    option.requestingScene = self?.view.window?.windowScene
                    UIApplication.shared.requestSceneSessionActivation(nil, userActivity: self?.wrapUserActivity(for: friend), options: option, errorHandler: nil)
                })
            }
            return UIMenu(title: "", image: nil, children: actions)
        }
        return config
    }
    
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        let username = configuration.identifier as! String
        if let index = self.usernames.firstIndex(of: username) {
            self.tableView(tableView, didSelectRowAt: IndexPath(row: index, section: 0))
        }
    }
        
    private func chatroomVC(for indexPath: IndexPath) -> ChatRoomViewController {
        let chatRoomVC = ChatRoomViewController()
        let friend = self.friends[indexPath.row]
        chatRoomVC.username = username
        chatRoomVC.friend = friend
        chatRoomVC.contactVC = self
        return chatRoomVC
    }
    
    func updateLatestMessages(_ messages: [Message]) {
        syncOnMainThread {
            var friendDict = [String : [Message]]()
            for message in messages {
                let friendID = message.friend.userID
                friendDict.add(message, for: friendID)
            }
            let sortedDict = friendDict.sorted(by: { first, second in
                return first.value.last?.timestamp ?? 0 > second.value.last?.timestamp ?? 0
            })
            var indexPathsToReload = [IndexPath]()
            var locations = [(from: Int, to: Int)]()
            for friend in sortedDict {
                if let index = self.friends.firstIndex(where: { $0.userID == friend.key }) {
                    indexPathsToReload.append(IndexPath(row: index, section: 0))
                    self.friends[index].latestMessage = friend.value.last
                    locations.append((from: index, to: locations.count))
                }
            }
            self.tableView.reloadRows(at: indexPathsToReload, with: .none)
            locations.sort(by: { $0.from > $1.from })
            tableView.performBatchUpdates { [self] in
                var removed = Array<Friend?>(repeating: nil, count: locations.count)
                for location in locations {
                    removed[location.to] = self.friends.remove(at: location.from)
                }
                self.friends.insert(contentsOf: removed.compactMap({ $0 }), at: 0)
                for location in locations where location.from != location.to {
                    tableView.moveRow(at: IndexPath(row: location.from, section: 0), to: IndexPath(row: location.to, section: 0))
                }
            } completion: { _ in
                self.reselectFriend(nil)
            }
        }
    }
    
    func reselectFriend(_ friend: Friend?) {
        if let friend = friend ?? selectedFriend {
            if let index = friends.firstIndex(of: friend) {
                tableView.selectRow(at: IndexPath(row: index, section: 0), animated: false, scrollPosition: .none)
            }
        }
    }
    
    func deselect() {
        if let visibleIndexPaths = tableView.indexPathsForSelectedRows {
            for indexPath in visibleIndexPaths {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
        if let selectedFriend = selectedFriend, let index = friends.firstIndex(of: selectedFriend) {
            tableView.deselectRow(at: IndexPath(row: index, section: 0), animated: true)
        }
    }
    
}

extension ContactsTableViewController: MessageDelegate, AddContactDelegate {
    
    func asyncReconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard UIApplication.shared.applicationState == .active else { return }
            self?.manager?.commonWebSocket.loginAndConnect(username: nil, password: nil)
        }
    }

    func updateOnlineNumber(to newNumber: Int) {
        
    }
        
    func findChatRoomVCs() -> [ChatRoomViewController] {
        var chatRooms = [ChatRoomViewController]()
        if let chatRoom = (self.splitViewController as? DogeChatSplitViewController)?.findChatRoomVC() {
            chatRooms.append(chatRoom)
        }
        if #available(iOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                if let chatRoomSceneDelegate = scene.delegate as? ChatRoomSceneDelegate,
                   let chatRoom = chatRoomSceneDelegate.chatRoomVC,
                   chatRoomSceneDelegate.username == self.username {
                    chatRooms.append(chatRoom)
                }
            }
        } 
        return chatRooms
    }
        
    func revokeMessage(_ id: Int, senderID: String, receiverID: String) {
        for chatRoom in findChatRoomVCs() {
            chatRoom.revokeMessage(id, senderID: senderID, receiverID: receiverID)
        }
    }
    
    func newFriend() {
        refreshContacts()
    }
    
    func newFriendRequest() {
        playSound()
        let button = navigationItem.rightBarButtonItem
        button?.badgeValue = "1"
    }
    
    func revokeSuccess(id: Int, senderID: String, receiverID: String) {
        for chatVC in findChatRoomVCs() {
            chatVC.revokeSuccess(id: id, senderID: senderID, receiverID: receiverID)
        }
    }
        
    func addSuccess() {
        refreshContacts()
    }
    
}

extension ContactsTableViewController: ContactDataSource {
    
}

extension ContactsTableViewController: UITableViewDragDelegate {
        
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let itemProvider = NSItemProvider(object: wrapUserActivity(for: self.friends[indexPath.row]))
        let item = UIDragItem(itemProvider: itemProvider)
        return [item]
    }
    
    func wrapUserActivity(for friend: Friend) -> NSUserActivity {
        let userActivity = NSUserActivity(activityType: userActivityID)
        userActivity.title = AppDelegate.chatRoomWindow
        userActivity.userInfo = ["friendID": friend.userID,
                                 "username": self.username]
        return userActivity
    }
    
}

extension ContactsTableViewController {
    func arrowUp(_ textView: DogeChatTextView) {
        if textView.text.isEmpty {
            toLastFriend()
        }
    }
    
    func arrowDown(_ textView: DogeChatTextView) {
        if textView.text.isEmpty {
            toNextFriend()
        }
    }
    
    func toNextFriend() {
        if let selectedFriend = selectedFriend, let index = friends.firstIndex(of: selectedFriend) {
            if index + 1 < friends.count {
                jumpToFriend(friends[index + 1])
            }
        }
    }
    
    func toLastFriend() {
        if let selectedFriend = selectedFriend, let index = friends.firstIndex(of: selectedFriend) {
            if index - 1 >= 0 {
                jumpToFriend(friends[index - 1])
            }
        }
    }

}
