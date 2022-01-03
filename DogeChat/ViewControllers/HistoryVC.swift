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

class HistoryVC: ChatRoomViewController {
        
    let slider = UISlider()
    let progressLabel = UILabel()
    var stack: UIStackView!
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
    
    convenience init(purpose: ChatRoomPurpose) {
        self.init()
        self.purpose = purpose
    }
    
    override func viewDidLoad() {
        messages.removeAll()
        
        super.viewDidLoad()
                
        manager?.needInsertWhenWrap = false
                
        if purpose == .history {
            navigationItem.title = friend.username + "的历史记录"
            let header = UIRefreshControl()
            header.addTarget(self, action: #selector(refreshHeaderAction), for: .valueChanged)
            tableView.refreshControl = header
            
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
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(filterAction))

        } else if purpose == .referView {
            navigationItem.title = "消息详情"
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
        manager?.needInsertWhenWrap = true
    }
    
    private func configRefresh() {
        let footer = MJRefreshAutoStateFooter(refreshingTarget: self, refreshingAction: #selector(refreshFooterAction))
        tableView.mj_footer = footer
    }
        
    @objc func filterAction() {
        let vc = HistoryFilterVC()
        vc.didConfirm = { [weak self] params in
            guard let self = self else { return }
            self.manager?.commonWebSocket.historyMessages(for: self.friend, pageNum: 0, pageSize: ChatRoomViewController.numberOfHistory, uuid: nil, type: params["type"] as? String, beginDate: params["timestamp"] as? String, keyWord: params["keyword"] as? String)
        }
        self.present(vc, animated: true, completion: nil)
    }
            
    @objc func sliderAction(_ slider: UISlider) {
        print(slider.state)
        self.messages.removeAll()
        self.tableView.reloadData()
        nowPage = Int(slider.value)
        downNowPage = nowPage
        upNowPage = nowPage
        requestPage(nowPage)
        if tableView.mj_footer == nil {
            configRefresh()
        }
    }
    
    
    func requestPage(_ page: Int) {
        socketForUsername(username)?.historyMessages(for: friend, pageNum: page)
    }
    
    @objc func refreshFooterAction() {
        if downNowPage > 1 {
            downNowPage -= 1
            nowPage = downNowPage
            requestPage(nowPage)
        } else {
            tableView.mj_footer?.endRefreshing()
        }
    }
    
    @objc func refreshHeaderAction() {
        if upNowPage < totalPages {
            upNowPage += 1
            nowPage = upNowPage
            requestPage(nowPage)
        } else {
            tableView.refreshControl?.endRefreshing()
        }
    }
    
    override func receiveHistoryMessages(_ noti: Notification) {
        defer {
            tableView.refreshControl?.endRefreshing()
            tableView.mj_footer?.endRefreshing()
        }
        guard let messages = noti.userInfo?["messages"] as? [Message], !messages.isEmpty, let pages = noti.userInfo?["pages"] as? Int, let current = noti.userInfo?["current"] as? Int else { return }
        let filtered = messages.filter ({ !self.messagesUUIDs.contains($0.uuid) }).reversed() as [Message]
        self.totalPages = pages
        self.nowPage = current
        if filtered.isEmpty { return }
        filtered.forEach { $0.page = current }
        slider.maximumValue = Float(pages)
        let indexPaths: [IndexPath]
        let isFooter = filtered[0].id > (self.messages.last?.id ?? 0)
        if isFooter {
            print(messages.map { $0.id })
            let alreadyCount = self.messages.count
            indexPaths = (alreadyCount..<alreadyCount+filtered.count).map { IndexPath(row: $0, section: 0) }
            self.messages.append(contentsOf: filtered)
        } else {
            print(messages.map { $0.id })
            indexPaths = (0..<filtered.count).map { IndexPath(row: $0, section: 0) }
            self.messages.insert(contentsOf: filtered, at: 0)
        }
        tableView.insertRows(at: indexPaths, with: (isFooter ? .top : .bottom))
    }
    
}

