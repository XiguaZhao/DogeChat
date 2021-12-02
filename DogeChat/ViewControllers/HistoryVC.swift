//
//  HistoryVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/9/1.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatUniversal
import DogeChatNetwork
import MJRefresh

enum HistoryVCType {
    case history
    case referView
}

class HistoryVC: DogeChatViewController, DogeChatVCTableDataSource {
    
    enum Section {
        case main
    }
    
    var type: HistoryVCType = .history
    var friend: Friend!
    var messages = [Message]()
    var uuids = Set<String>()
    var tableView = DogeChatTableView()
    var dataSource: UITableViewDiffableDataSource<Section, Message>!
    let slider = UISlider()
    let progressLabel = UILabel()
    var stack: UIStackView!
    weak var contactDataSource: ContactDataSource?
    var isFooter = false
    var totalPages = 0 {
        didSet {
            progressLabel.text = "\(nowPage)/\(totalPages)"
        }
    }
    var nowPage = 0 {
        didSet {
            progressLabel.text = "\(nowPage)/\(totalPages)"
            slider.value = Float(nowPage)
        }
    }
    var upNowPage = 1
    var downNowPage = 1
    var manager: WebSocketManager! {
        if username.isEmpty {
            username = (self.splitViewController as? DogeChatSplitViewController)?.findContactVC()?.username ?? ""
        }
        return WebSocketManager.usersToSocketManager[username]
    }
    
    convenience init(type: HistoryVCType, username: String) {
        self.init()
        self.type = type
        self.username = username
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        manager.needInsertWhenWrap = false
                
        view.addSubview(tableView)
        
        tableView.delegate = self
        configDataSource()        
        

        if type == .history {
            navigationItem.title = friend.username + "的历史记录"
            let header = UIRefreshControl()
            header.addTarget(self, action: #selector(refreshHeaderAction), for: .valueChanged)
            tableView.refreshControl = header
            
            NotificationCenter.default.addObserver(self, selector: #selector(receiveHistory(_:)), name: .receiveHistoryMessages, object: username)

            nowPage = 1
            requestPage(1)
                        
            let leftLabel = UILabel()
            leftLabel.text = "最新"
            stack = UIStackView(arrangedSubviews: [leftLabel, slider, progressLabel])
            stack.spacing = 15
            slider.minimumValue = 1
            slider.isContinuous = false
            slider.addTarget(self, action: #selector(sliderAction(_:)), for: .valueChanged)

            self.navigationController?.setToolbarHidden(false, animated: true)
            self.setToolbarItems([UIBarButtonItem(customView: stack)], animated: true)

        } else {
            navigationItem.title = "消息详情"
            updateSnapshot()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stack?.removeFromSuperview()
    }
        
    override func viewDidLayoutSubviews() {
        tableView.frame = view.bounds
    }
    
    deinit {
        manager.needInsertWhenWrap = true
    }
    
    private func configRefresh() {
        let footer = MJRefreshAutoStateFooter(refreshingTarget: self, refreshingAction: #selector(refreshFooterAction))
        tableView.mj_footer = footer
    }
    
    private func configDataSource() {
        tableView.register(MessageTextCell.self, forCellReuseIdentifier: MessageTextCell.cellID)
        tableView.register(MessageImageCell.self, forCellReuseIdentifier: MessageImageCell.cellID)
        tableView.register(MessageDrawCell.self, forCellReuseIdentifier: MessageDrawCell.cellID)
        tableView.register(MessageTrackCell.self, forCellReuseIdentifier: MessageTrackCell.cellID)
        tableView.register(MessageLivePhotoCell.self, forCellReuseIdentifier: MessageLivePhotoCell.cellID)
        tableView.register(MessageVideoCell.self, forCellReuseIdentifier: MessageVideoCell.cellID)
        dataSource = UITableViewDiffableDataSource<Section, Message>(tableView: tableView) { [weak self] tableView, indexPath, message in
            let id: String
            switch message.messageType {
            case .text, .join, .voice:
                id = MessageTextCell.cellID
            case .image:
                id = MessageImageCell.cellID
            case .livePhoto:
                id = MessageLivePhotoCell.cellID
            case .video:
                id = MessageVideoCell.cellID
            case .draw:
                id = MessageDrawCell.cellID
            case .track:
                id = MessageTrackCell.cellID
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: id, for: indexPath) as! MessageBaseCell
            cell.contactDataSource = self?.contactDataSource
            cell.indexPath = indexPath
            cell.tableView = tableView
            cell.isHistory = true
            cell.delegate = self
            cell.username = self!.username
            cell.apply(message: message)
            return cell
        }
    }
    
    @objc func receiveHistory(_ noti: Notification) {
        guard var messages = noti.userInfo?["messages"] as? [Message], !messages.isEmpty,
              let pages = noti.userInfo?["pages"] as? Int,
              let current = noti.userInfo?["current"] as? Int else { return }
        messages = (messages.filter { !uuids.contains($0.uuid) }).reversed()
        self.totalPages = pages
        self.nowPage = current
        messages.forEach { $0.page = current }
        slider.maximumValue = Float(pages)
        if isFooter {
            print(messages.map { $0.id })
            self.messages.append(contentsOf: messages)
        } else {
            print(messages.map { $0.id })
            self.messages.insert(contentsOf: messages, at: 0)
        }
        messages.forEach { uuids.insert($0.uuid) }
        updateSnapshot()
        tableView.mj_footer?.endRefreshing()
        tableView.refreshControl?.endRefreshing()
    }
    
    func updateSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Message>()
        snapshot.appendSections([.main])
        snapshot.appendItems(messages)
        dataSource.apply(snapshot, animatingDifferences: true) {
            
        }
    }
    
    @objc func sliderAction(_ slider: UISlider) {
        print(slider.state)
        messages.removeAll()
        uuids.removeAll()
        nowPage = Int(slider.value)
        downNowPage = nowPage
        upNowPage = nowPage
        requestPage(nowPage)
        if tableView.mj_footer == nil {
            configRefresh()
        }
    }
    
    
    func requestPage(_ page: Int) {
        socketForUsername(username).historyMessages(for: friend, pageNum: page)
    }
    
    @objc func refreshFooterAction() {
        isFooter = true
        if downNowPage > 1 {
            downNowPage -= 1
            nowPage = downNowPage
            requestPage(nowPage)
        } else {
            tableView.mj_footer?.endRefreshing()
        }
    }
    
    @objc func refreshHeaderAction() {
        isFooter = false
        if upNowPage < totalPages {
            upNowPage += 1
            nowPage = upNowPage
            requestPage(nowPage)
        } else {
            tableView.refreshControl?.endRefreshing()
        }
    }
    
}

extension HistoryVC: UITableViewDelegate, MessageTableViewCellDelegate {
    
    func mediaViewTapped(_ cell: MessageBaseCell, path: String, isAvatar: Bool) {
        let browser = MediaBrowserViewController()
        if !isAvatar {
            let paths = (self.messages.filter { $0.messageType == .image || $0.messageType == .livePhoto || $0.messageType == .video }).map { $0.text }
            browser.imagePaths = paths
            if let index = paths.firstIndex(of: path) {
                browser.targetIndex = index
            }
        } else {
            browser.imagePaths = [path]
        }
        browser.modalPresentationStyle = .fullScreen
        self.navigationController?.present(browser, animated: true, completion: nil)
    }

    func emojiOutBounds(from cell: MessageBaseCell, gesture: UIGestureRecognizer) {
        
    }
    
    func emojiInfoDidChange(from oldInfo: EmojiInfo?, to newInfo: EmojiInfo?, cell: MessageBaseCell) {
        
    }
    
    func pkViewTapped(_ cell: MessageBaseCell, pkView: UIView!) {
        
    }
    
    func avatarDoubleTap(_ cell: MessageBaseCell) {
        
    }
    
    func sharedTracksTap(_ cell: MessageBaseCell, tracks: [Track]) {
        
    }
    
    func downloadProgressUpdate(progress: Double, message: Message) {
        
    }
    
    func longPressCell(_ cell: MessageBaseCell, ges: UILongPressGestureRecognizer!) {
        
    }
    
    func downloadSuccess(_ cell: MessageBaseCell?, message: Message) {
        guard let cell = cell, cell.message == message else {
            return
        }
        syncOnMainThread {
            cell.apply(message: message)
            cell.layoutIfNeeded()
            cell.setNeedsLayout()
        }
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.row < messages.count else { return 0 }
        return MessageBaseCell.height(for: messages[indexPath.row], username: username)
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? MessageBaseCell)?.cleanEmojis()
        (cell as? MessageImageCell)?.cleanAvatar()
        (cell as? MessageImageCell)?.cleanAnimatedImageView()
        (cell as? DogeChatTableViewCell)?.endDisplayBlock?(cell as! DogeChatTableViewCell, tableView)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? MessageBaseCell)?.addEmojis()
        (cell as? MessageBaseCell)?.loadAvatar()
        (cell as? MessageImageCell)?.loadImageIfNeeded()
        (cell as? DogeChatTableViewCell)?.willDisplayBlock?(cell as! DogeChatTableViewCell, tableView)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if let cell = centerCell() as? DogeChatTableViewCell {
            callCenterBlock(centerCell: cell)
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            if let cell = centerCell() as? DogeChatTableViewCell {
                callCenterBlock(centerCell: cell)
            }
        }
    }
    
    func callCenterBlock(centerCell: DogeChatTableViewCell) {
        for cell in tableView.visibleCells  {
            if let cell = cell as? DogeChatTableViewCell {
                if cell == centerCell {
                    cell.centerDisplayBlock?(cell, tableView)
                } else {
                    cell.resignCenterBlock?(cell, tableView)
                }
            }
        }
    }
    
    func centerCell() -> UITableViewCell? {
        var middlePoint = tableView.center
        middlePoint.y += tableView.contentOffset.y
        for cell in tableView.visibleCells {
            let convert = tableView.convert(middlePoint, to: cell)
            if cell.bounds.contains(convert) {
                return cell
            }
        }
        return nil
    }

}
