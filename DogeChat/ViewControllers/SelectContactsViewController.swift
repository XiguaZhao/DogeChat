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

class SelectContactsViewController: DogeChatViewController, UITableViewDataSource {
    
    var contacts: [Friend] {
        dataSourcea?.userInfos ?? []
    }
    var username = ""
    weak var dataSourcea: ContactDataSource?
    let tableView = DogeChatTableView()
    let toolBar = UIToolbar()
    var confirmButton: UIBarButtonItem!
    var cancelButton: UIBarButtonItem!
    weak var delegate: SelectContactsDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(toolBar)
        view.addSubview(tableView)
        
        toolBar.mas_makeConstraints { [weak self] make in
            make?.left.right().top().equalTo()(self?.view)
        }
        tableView.mas_makeConstraints { [weak self] make in
            make?.left.right().bottom().equalTo()(self?.view)
            make?.top.equalTo()(self?.toolBar.mas_bottom)
        }
        tableView.setEditing(true, animated: true)
        tableView.allowsMultipleSelection = true
        tableView.allowsMultipleSelectionDuringEditing = true
        
        tableView.register(DogeChatTableViewCell.self, forCellReuseIdentifier: DogeChatTableViewCell.cellID())
        tableView.dataSource = self
        buildBarButtons()
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
        let selectedContacts = (tableView.indexPathsForSelectedRows ?? []).map { contacts[$0.row] }
        delegate?.didSelectContacts(selectedContacts, vc: self)
    }
    
    @objc func cancelAction(_ sender: UIBarButtonItem) {
        delegate?.didCancelSelectContacts(self)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DogeChatTableViewCell.cellID()) as! DogeChatTableViewCell
        cell.textLabel?.text = contacts[indexPath.row].username
        return cell
    }
}
