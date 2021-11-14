//
//  SelectContactsViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/28.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatUniversal

protocol SelectContactsDelegate: AnyObject {
    func didSelectContacts(_ contacts: [Friend], vc: SelectContactsViewController)
    func didCancelSelectContacts(_ vc: SelectContactsViewController)
}

class SelectContactsViewController: DogeChatViewController, DogeChatVCTableDataSource {
    
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
    var tableView: DogeChatTableView = SelectContactTableView()
    let toolBar = UIToolbar()
    var confirmButton: UIBarButtonItem!
    var cancelButton: UIBarButtonItem!
    weak var delegate: SelectContactsDelegate?
    
    var selectedFriends = [Friend]()
    
    var excluded = [Friend]()
    
    convenience init(username: String, selectedFriends: [Friend] = [], excluded: [Friend] = []) {
        self.init()
        self.username = username
        self.selectedFriends = selectedFriends
        self.excluded = excluded
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if dataSourcea == nil {
            dataSourcea = socketForUsername(username).messageManager
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
    
    @objc func confirmAction(_ sender: UIBarButtonItem) {
        let selectedContacts = (tableView.indexPathsForSelectedRows ?? []).map { (tableView as! SelectContactTableView).contacts[$0.row] }
        delegate?.didSelectContacts(selectedContacts, vc: self)
    }
    
    @objc func cancelAction(_ sender: UIBarButtonItem) {
        delegate?.didCancelSelectContacts(self)
    }

}
