//
//  HistoryVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/9/1.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal
import DogeChatNetwork
import MJRefresh

@available(iOS 13.0, *)
class HistoryVC: DogeChatViewController {
    
    enum Section {
        case main
    }
    
    var cache: NSCache<NSString, NSData>!
    var option: MessageOption = .toOne
    var name = ""
    var messages = [Message]()
    var uuids = Set<String>()
    var username = ""
    var tableView = DogeChatTableView()
    var dataSource: UITableViewDiffableDataSource<Section, Message>!
    let slider = UISlider()
    let progressLabel = UILabel()
    var stack: UIStackView!
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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        WebSocketManager.shared.needInsertWhenWrap = false
        
        view.addSubview(tableView)
        navigationItem.title = name + "的历史记录"
        
        tableView.delegate = self
        configDataSource()
        configRefresh()
        
                
        NotificationCenter.default.addObserver(self, selector: #selector(receiveHistory(_:)), name: .receiveHistoryMessages, object: username)
        
        let leftLabel = UILabel()
        leftLabel.text = "最新"
        stack = UIStackView(arrangedSubviews: [leftLabel, slider, progressLabel])
        stack.spacing = 15
        slider.minimumValue = 1
        slider.isContinuous = false
        slider.addTarget(self, action: #selector(sliderAction(_:)), for: .valueChanged)
        

        nowPage = 1
        requestPage(1)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setToolbarHidden(false, animated: true)
        let toolBar = navigationController?.toolbar
        toolBar?.addSubview(stack)
        
        stack.mas_remakeConstraints { [weak toolBar] make in
            let offset: CGFloat = 20
            make?.leading.equalTo()(toolBar)?.offset()(offset)
            make?.trailing.equalTo()(toolBar)?.offset()(-offset)
            make?.bottom.equalTo()(toolBar)?.offset()(-10)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stack.removeFromSuperview()
    }
        
    override func viewDidLayoutSubviews() {
        tableView.frame = view.bounds
    }
    
    deinit {
        WebSocketManager.shared.needInsertWhenWrap = true
    }
    
    private func configRefresh() {
        let footer = MJRefreshAutoStateFooter(refreshingTarget: self, refreshingAction: #selector(refreshFooterAction))
//        let header = MJRefreshNormalHeader(refreshingTarget: self, refreshingAction: #selector(refreshHeaderAction))
        let header = UIRefreshControl()
        header.addTarget(self, action: #selector(refreshHeaderAction), for: .valueChanged)
        tableView.mj_footer = footer
        tableView.refreshControl = header
//        tableView.mj_header = header
        
    }
    
    private func configDataSource() {
        tableView.register(MessageCollectionViewTextCell.self, forCellReuseIdentifier: MessageCollectionViewTextCell.cellID)
        tableView.register(MessageCollectionViewImageCell.self, forCellReuseIdentifier: MessageCollectionViewImageCell.cellID)
        tableView.register(MessageCollectionViewDrawCell.self, forCellReuseIdentifier: MessageCollectionViewDrawCell.cellID)
        tableView.register(MessageCollectionViewTrackCell.self, forCellReuseIdentifier: MessageCollectionViewTrackCell.cellID)
        dataSource = UITableViewDiffableDataSource<Section, Message>(tableView: tableView) { [weak self] tableView, indexPath, message in
            let id: String
            switch message.messageType {
            case .text, .join, .voice:
                id = MessageCollectionViewTextCell.cellID
            case .image, .livePhoto, .video:
                id = MessageCollectionViewImageCell.cellID
            case .draw:
                id = MessageCollectionViewDrawCell.cellID
            case .track:
                id = MessageCollectionViewTrackCell.cellID
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: id, for: indexPath) as! MessageCollectionViewBaseCell
            cell.indexPath = indexPath
            cell.tableView = tableView
            cell.cache = self?.cache
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
    }
    
    
    func requestPage(_ page: Int) {
        socketForUsername(username).historyMessages(for: option == .toAll ? "chatRoom" : name, pageNum: page)
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

@available(iOS 13.0, *)
extension HistoryVC: UITableViewDelegate, MessageTableViewCellDelegate {
    
    func imageViewTapped(_ cell: MessageCollectionViewBaseCell, imageView: FLAnimatedImageView, path: String, isAvatar: Bool) {
        let browser = ImageBrowserViewController()
        if !isAvatar {
            let paths = (self.messages.filter { $0.messageType == .image }).compactMap { $0.imageLocalPath?.absoluteString ?? $0.imageURL }
            browser.imagePaths = paths
            if let index = paths.firstIndex(of: path) {
                browser.targetIndex = index
            }
        } else {
            browser.imagePaths = [path]
        }
        browser.modalPresentationStyle = .fullScreen
        AppDelegate.shared.navigationController.present(browser, animated: true, completion: nil)
    }

    func emojiOutBounds(from cell: MessageCollectionViewBaseCell, gesture: UIGestureRecognizer) {
        
    }
    
    func emojiInfoDidChange(from oldInfo: EmojiInfo?, to newInfo: EmojiInfo?, cell: MessageCollectionViewBaseCell) {
        
    }
    
    func pkViewTapped(_ cell: MessageCollectionViewBaseCell, pkView: UIView!) {
        
    }
    
    func avatarDoubleTap(_ cell: MessageCollectionViewBaseCell) {
        
    }
    
    func sharedTracksTap(_ cell: MessageCollectionViewBaseCell, tracks: [Track]) {
        
    }
    
    func downloadProgressUpdate(progress: Progress, message: Message) {
        
    }
    
    func downloadSuccess(message: Message) {
        syncOnMainThread {
            if let index = self.messages.firstIndex(where: { $0.uuid == message.uuid }) {
                let indexPath = IndexPath(row: index, section: 0)
                if let cell = self.tableView.cellForRow(at: indexPath) as? MessageCollectionViewBaseCell {
                    cell.apply(message: message)
                    cell.layoutIfNeeded()
                    cell.setNeedsLayout()
                }
            }
        }
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.row < messages.count else { return 0 }
        return MessageCollectionViewBaseCell.height(for: messages[indexPath.row], username: username)
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? MessageCollectionViewBaseCell)?.cleanEmojis()
        (cell as? MessageCollectionViewImageCell)?.cleanAvatar()
        (cell as? MessageCollectionViewImageCell)?.cleanAnimatedImageView()
        (cell as? DogeChatTableViewCell)?.endDisplayBlock?(cell as! DogeChatTableViewCell, tableView)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as? MessageCollectionViewBaseCell)?.addEmojis()
        (cell as? MessageCollectionViewBaseCell)?.loadAvatar()
        (cell as? MessageCollectionViewImageCell)?.loadImageIfNeeded()
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
