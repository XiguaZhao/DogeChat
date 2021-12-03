//
//  SearchViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/6/4.
//  Copyright © 2020 Xiguang Zhao. All rights reserved.
//

import UIKit
import DogeChatNetwork
import DogeChatUniversal

protocol AddContactDelegate: AnyObject {
    func addSuccess()
}

class SearchViewController: DogeChatViewController, DogeChatVCTableDataSource {
    
    enum Status {
        case search
        case accept
    }
    
    let searchBar = UISearchBar()
    var tableView = DogeChatTableView()
    
    var friends: [Friend] = []
    var manager: WebSocketManager? {
        return socketForUsername(username)
    }
    var status: Status = .accept
    weak var delegate: AddContactDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        lookupAddRequest()
    }
    
    override var keyCommands: [UIKeyCommand]? {
        return [UIKeyCommand(action: #selector(escapeAction(_:)), input: UIKeyCommand.inputEscape)]
    }
    
    @objc func escapeAction(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    private func setupUI() {
        view.addSubview(searchBar)
        view.addSubview(tableView)
        
        tableView.rowHeight = ContactTableViewCell.cellHeight
        searchBar.becomeFirstResponder()
        
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        searchBar.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(ContactTableViewCell.self, forCellReuseIdentifier: ContactTableViewCell.cellID)
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(swipeAction))
        swipeDown.direction = .down
        view.addGestureRecognizer(swipeDown)
    }
    
    @objc func swipeAction() {
        self.dismiss(animated: true, completion: nil)
    }
    
}

extension SearchViewController: UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch status {
        case .search:
            let friend = friends[indexPath.row]
            if manager?.friendsDict[friend.userID] != nil {
                self.makeAutoAlert(message: "已经是你的好友！", detail: nil, showTime: 1, completion: nil)
                return
            }
            manager?.applyAdd(friend: self.friends[indexPath.row]) { (success) in
                self.makeAutoAlert(message: success ? "已发送申请" : "请求失败", detail: nil, showTime: 1, completion: nil)
            }
        case .accept:
            let friend = self.friends[indexPath.row]
            if manager?.friendsDict[friend.userID] != nil {
                self.makeAutoAlert(message: "已经是你好友！", detail: nil, showTime: 1, completion: nil)
            } else {
                let alert = UIAlertController(title: "接受申请？", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
                    self.manager?.acceptQuery(requestId: (friend as! RequestFriend).requestID!) { success in
                        self.makeAutoAlert(message: success ? "添加成功" : "失败", detail: nil, showTime: 1, completion: nil)
                        self.delegate?.addSuccess()
                    }
                }))
                alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchBar.resignFirstResponder()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ContactTableViewCell.cellID, for: indexPath) as! ContactTableViewCell
        let friend = friends[indexPath.row]
        cell.apply(friend, subTitle: (friend as? RequestFriend)?.requestTime)
        return cell
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        status = .search
        guard let input = searchBar.text else { return }
        manager?.search(username: input) { userInfos in
            self.friends = userInfos
            self.tableView.reloadData()
        }
    }
    
    func lookupAddRequest() {
        status = .accept
        manager?.inspectQuery { friends in
            self.friends = friends
            self.tableView.reloadData()
        }
    }
}
