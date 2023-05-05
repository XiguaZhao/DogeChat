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
import DogeChatCommonDefines

class HistoryVC: ChatRoomViewController {
        
    let slider = UISlider()
    let progressButton = UIButton()
    var stack: UIStackView!
    var params: [String : Any?]?
    var targetMessageUUID: String?
    var totalPages = 0 {
        didSet {
            progressButton.setTitle("\(nowPage)/\(totalPages)", for: .normal)
        }
    }
    var nowPage = 0 {
        didSet {
            progressButton.setTitle("\(nowPage)/\(totalPages)", for: .normal)
            slider.value = Float(nowPage)
            if nowPage == 1 {
                (tableView.mj_footer as? MJRefreshAutoStateFooter)?.state = .noMoreData
            }
        }
    }
    var upNowPage = 1
    var downNowPage = 1
    var filterVC: HistoryFilterVC?
    
    convenience init(purpose: ChatRoomPurpose) {
        self.init()
        self.purpose = purpose
    }
    
    override func viewDidLoad() {
        messages.removeAll()
        
        super.viewDidLoad()
                
        manager?.needInsertWhenWrap = false
                
        if purpose == .history {
            navigationItem.title = String.localizedStringWithFormat(localizedString("historyWithSomeone"), friend.username)
//            let header = UIRefreshControl()
//            header.addTarget(self, action: #selector(refreshHeaderAction), for: .valueChanged)
//            tableView.refreshControl = header
            
            configFooter()
            
            let leftLabel = UILabel()
            leftLabel.text = localizedString("latest")
            progressButton.setTitleColor(UIColor(named: "textColor"), for: .normal)
            stack = UIStackView(arrangedSubviews: [leftLabel, slider, progressButton])
            stack.spacing = 15
            slider.minimumValue = 1
            slider.isContinuous = false
            slider.addTarget(self, action: #selector(sliderAction(_:)), for: .valueChanged)

            self.navigationController?.setToolbarHidden(false, animated: true)
            self.setToolbarItems([UIBarButtonItem(customView: stack)], animated: true)
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(filterAction(_:)))
            
            if let params = params {
                if let id = params["id"] as? Int {
                    self.manager?.httpsManager.historyMessages(for: friend, id: id, needInsertWhenWrap: false) { [weak self] params in
                        self?.receiveHistoryMessages(params: params)
                    }
                    self.params = nil
                } else {
                    if params["timestamp"] == nil {
                        self.requestPage(1)
                    } else {
                        self.requestPage(-1)
                    }
                }
            } else {
                nowPage = 1
                requestPage(1)
            }
                        
        } else if purpose == .referView {
            navigationItem.title = localizedString("messageDetail")
        }
        
        progressButton.addTarget(self, action: #selector(self.progressButtonAction(_:)), for: .touchUpInside)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setToolbarHidden(false, animated: true)
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
    
    override func displayHistoryIfNeeded() {
    }
    
    deinit {
        manager?.needInsertWhenWrap = true
    }
    
    override func shouldShowTimeForMessage(_ message: Message) -> Bool {
        return true
    }
    
    @objc private func progressButtonAction(_ button: UIButton) {
        let vc = DogeChatViewController()
        let view = vc.view
        let picker = UIPickerView()
        view?.addSubview(picker)
        picker.mas_makeConstraints { make in
            make?.center.equalTo()(view)
        }
        picker.dataSource = self
        picker.selectRow(nowPage - 1, inComponent: 0, animated: false)
        picker.delegate = self
        vc.modalPresentationStyle = .popover
        vc.preferredContentSize = CGSize(width: 100, height: 200)
        vc.didDisappearBlock = { [weak self] in
            self?.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
        let popoverController = vc.popoverPresentationController
        popoverController?.sourceView = button
        popoverController?.sourceRect = button.bounds
        popoverController?.delegate = self
        if !isMac() {
            self.present(vc, animated: true)
            self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }
    
    private func configFooter() {
        let footer = MJRefreshAutoStateFooter(refreshingTarget: self, refreshingAction: #selector(refreshFooterAction))
        tableView.mj_footer = footer
    }
        
    @objc func filterAction(_ sender: UIBarButtonItem?) {
        let vc = self.filterVC ?? HistoryFilterVC()
        vc.didConfirm = { [weak self] params in
            guard let self = self else { return }
            self.messages.removeAll()
            self.tableView.reloadData()
            self.params = params
            if params["timestamp"] == nil {
                self.requestPage(1)
            } else {
                self.requestPage(-1)
            }
        }
//        if let sender = sender {
//            vc.modalPresentationStyle = .popover
//            let popoverController = vc.popoverPresentationController
//            popoverController?.barButtonItem = sender
//            popoverController?.delegate = self
//        }
        self.navigationController?.pushViewController(vc, animated: true)
        self.filterVC = vc
    }
                
    @objc func sliderAction(_ slider: UISlider) {
        print(slider.state)
        self.messages.removeAll()
        self.tableView.reloadData()
        nowPage = Int(slider.value)
        downNowPage = nowPage
        upNowPage = nowPage
        requestPage(nowPage)
    }
    
    
    func requestPage(_ page: Int) {
        navigationItem.title = localizedString("loading")
        nowPage = page
        self.manager?.httpsManager.historyMessages(for: self.friend, pageNum: page, pageSize: numberOfHistory, uuid: nil, type: params?["type"] as? String, beginDate: params?["timestamp"] as? String, keyWord: params?["keyword"] as? String, needInsertWhenWrap: false) { [weak self] params in
            self?.receiveHistoryMessages(params: params)
        }
    }
    
    @objc func refreshFooterAction() {
        if downNowPage > 1 {
            downNowPage -= 1
            nowPage = downNowPage
            requestPage(nowPage)
        } else {
            tableView.mj_footer?.endRefreshingWithNoMoreData()
        }
    }
    
    @objc func refreshHeaderAction() {
        if upNowPage < totalPages {
            upNowPage += 1
            nowPage = upNowPage
            requestPage(nowPage)
            isFetchingHistory = true
        } else {
            tableView.refreshControl?.endRefreshing()
        }
    }
    
    override func displayHistory() {
        refreshHeaderAction()
    }
    
    override func receiveHistoryMessages(_ noti: Notification) {
        
    }
    
    func receiveHistoryMessages(params: [String : Any]) {
        defer {
            tableView.refreshControl?.endRefreshing()
            tableView.mj_footer?.endRefreshing()
            if self.purpose == .history {
                navigationItem.title = String.localizedStringWithFormat(localizedString("historyWithSomeone"), friend.username)
            }
        }
        let oldStateEmpty = self.messages.isEmpty
        guard let messages = params["messages"] as? [Message], !messages.isEmpty, let pages = params["pages"] as? Int, let current = params["current"] as? Int else { return }
        slider.maximumValue = Float(pages)
        if nowPage < 0 {
            upNowPage = current
            downNowPage = current
        }
        let filtered = messages.filter ({ !self.messagesUUIDs.contains($0.uuid) }).reversed() as [Message]
        self.totalPages = pages
        self.nowPage = current
        if filtered.isEmpty { return }
        let indexPaths: [IndexPath]
        let isFooter = filtered[0].id > (self.messages.last?.id ?? 0)
        if isFooter {
            print(messages.map { $0.id })
            let alreadyCount = self.messages.count
            indexPaths = (alreadyCount..<alreadyCount+filtered.count).map { IndexPath(row: 0, section: $0) }
            self.messages.append(contentsOf: filtered)
        } else {
            print(messages.map { $0.id })
            indexPaths = (0..<filtered.count).map { IndexPath(row: 0, section: $0) }
            self.messages.insert(contentsOf: filtered, at: 0)
        }
        guard !indexPaths.isEmpty else { return }
        let scrollToTargetBlock = {
            if let targetMessageUUID = self.targetMessageUUID, let index = filtered.firstIndex(where: { $0.uuid == targetMessageUUID }) {
                self.tableView.selectRow(at: IndexPath(row: 0, section: index), animated: true, scrollPosition: .middle)
                self.targetMessageUUID = nil
            }
        }
        let indexSet = IndexSet(indexPaths.map{$0.section})
        if oldStateEmpty {
            tableView.performBatchUpdates({
                self.tableView.insertSections(indexSet, with: .top)
            }) { _ in
                scrollToTargetBlock()
                self.isFetchingHistory = false
            }
        } else {
            UIView.setAnimationsEnabled(false)
            tableView.beginUpdates()
            tableView.insertSections(indexSet, with: .none)
            tableView.endUpdates()
            UIView.setAnimationsEnabled(true)
            if !isFooter {
                tableView.scrollToRow(at: IndexPath(row: 0, section: indexPaths.last!.section + (oldStateEmpty ? 0 : 1)), at: .top, animated: false)
            }
            scrollToTargetBlock()
            isFetchingHistory = false
        }


    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard self.params != nil else { return }
        let message = messages[indexPath.section]
        let newVC = HistoryVC(purpose: .history)
        newVC.friend = self.friend
        newVC.targetMessageUUID = message.uuid
        newVC.params = ["id" : message.id]
        newVC.nowPage = -1
        newVC.filterVC = self.filterVC
        self.navigationController?.pushViewController(newVC, animated: true)
    }
}

extension HistoryVC: UIPickerViewDataSource, UIPickerViewDelegate {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return totalPages
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return String(row + 1)
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        slider.value = Float(row + 1)
        sliderAction(slider)
    }
}
