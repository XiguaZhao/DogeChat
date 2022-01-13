//
//  SelectContactsViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/28.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatUniversal
import DogeChatNetwork
import DogeChatCommonDefines

protocol ContactDataSource: AnyObject {
    var friends: [Friend] { get }
}

protocol SelectContactsDelegate: AnyObject {
    func didSelectContacts(_ contacts: [Friend], vc: SelectContactsViewController)
    func didCancelSelectContacts(_ vc: SelectContactsViewController)
    func didFetchContacts(_ contacts: [Friend], vc: SelectContactsViewController)
}

class SelectContactsViewController: DogeChatViewController, DogeChatVCTableDataSource {
    
    enum ContactsType {
        case all
        case group
    }
    
    var displayedFriends = [Friend]() {
        didSet {
            (tableView as! SelectContactTableView).contacts = displayedFriends
        }
    }
    
    weak var dataSourcea: ContactDataSource? {
        didSet {
            displayedFriends = dataSourcea?.friends ?? []
        }
    }
    var type: ContactsType = .all {
        didSet {
            (tableView as! SelectContactTableView).type = self.type
        }
    }
    var tableView: DogeChatTableView = SelectContactTableView()
    let toolBar = UIToolbar()
    var confirmButton: UIBarButtonItem!
    var cancelButton: UIBarButtonItem!
    weak var delegate: SelectContactsDelegate?
    var didSelectContacts: (([Friend]) -> Void)?
    var manager: WebSocketManager? {
        WebSocketManager.usersToSocketManager[self.username]
    }
    var group: Group?
    
    var selectedFriends = [Friend]()
    
    var excluded = [Friend]()
    
    convenience init(username: String, selectedFriends: [Friend] = [], excluded: [Friend] = []) {
        self.init()
        self.username = username
        self.selectedFriends = selectedFriends
        self.excluded = excluded
    }
    
    convenience init(username: String, group: Group, members: [Friend]?) {
        self.init()
        self.type = .group
        self.username = username
        if var members = members {
            if !members.contains(where: { $0.isGroup }) {
                members.insert(self.wrapGroupForAt(group), at: 0)
            }
            DispatchQueue.main.async {
                self.displayedFriends = members
            }
        } else {
            self.group = group
            groupSet()
        }
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if self.type == .all && dataSourcea == nil {
            dataSourcea = socketForUsername(username)?.messageManager
        }
        
        excludeSomeFriend()
                
        view.addSubview(toolBar)
        view.addSubview(tableView)
        
        toolBar.mas_makeConstraints { [weak self] make in
            make?.left.right().top().equalTo()(self?.view)
        }
        tableView.mas_makeConstraints { [weak self] make in
            make?.left.right().bottom().equalTo()(self?.view)
            make?.top.equalTo()(self?.toolBar.mas_bottom)
        }
        tableView.setEditing(true, animated: false)
        tableView.allowsMultipleSelection = true
        tableView.allowsMultipleSelectionDuringEditing = true
        
        buildBarButtons()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        for selectedFriend in selectedFriends {
            if let index = displayedFriends.firstIndex(of: selectedFriend) {
                tableView.selectRow(at: IndexPath(row: index, section: 0), animated: true, scrollPosition: .none)
            }
        }
    }
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesBegan(presses, with: event)
        if let first = presses.first?.key?.keyCode {
            if first == .keyboardReturnOrEnter {
                confirmAction(nil)
            }
        }
    }
    
    private func wrapGroupForAt(_ group: Group) -> Group {
        return Group(username: "所有人", nickName: nil,
                     avatarURL: group.avatarURL, latesetMessage: nil,
                     userID: group.userID, isGroup: true, isMyFriend: true, isMuted: group.isMuted)
    }
    
    func groupSet() {
        guard let group = group, let manager = manager else {
            return
        }
        manager.httpsManager.getGroupMembers(group: group, completion: { [weak self] members in
            guard let self = self else { return }
            let total = [self.wrapGroupForAt(group)] + members
            self.displayedFriends = total
            self.delegate?.didFetchContacts(total, vc: self)
        })
    }
    
    func excludeSomeFriend() {
        guard !self.excluded.isEmpty else { return }
        var copy = displayedFriends
        for exclude in excluded {
            if let index = copy.firstIndex(of: exclude) {
                copy.remove(at: index)
            }
        }
        self.displayedFriends = copy
    }
    
    func buildBarButtons() {
        confirmButton = UIBarButtonItem(title: "确定", style: .done, target: self, action: #selector(confirmAction(_:)))
        cancelButton = UIBarButtonItem(title: "取消", style: .done, target: self, action: #selector(cancelAction(_:)))
        var items: [UIBarButtonItem] = [confirmButton, cancelButton]
        if #available(iOS 14.0, *) {
            items.insert(UIBarButtonItem(systemItem: .flexibleSpace), at: 0)
        }
        toolBar.setItems(items, animated: true)
    }
    
    @objc func confirmAction(_ sender: UIBarButtonItem!) {
        let selectedContacts = (tableView.indexPathsForSelectedRows ?? []).map { (tableView as! SelectContactTableView).contacts[$0.row] }
        self.dismiss(animated: true) {
            self.delegate?.didSelectContacts(selectedContacts, vc: self)
            self.didSelectContacts?(selectedContacts)
        }
    }
    
    @objc func cancelAction(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true) {
            self.delegate?.didCancelSelectContacts(self)
        }
    }

}
