//
//  SelectContactTableView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/10/29.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal

class SelectContactTableView: DogeChatTableView, UITableViewDataSource, UITableViewDelegate {
    
    var type: SelectContactsViewController.ContactsType = .all

    var contacts: [Friend]! = [] {
        didSet {
            DispatchQueue.main.async {
                self.reloadData()
            }
        }
    }

    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        self.estimatedRowHeight = 60
        self.rowHeight = UITableView.automaticDimension
        self.register(ContactTableViewCell.self, forCellReuseIdentifier: ContactTableViewCell.cellID)
        self.dataSource = self
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ContactTableViewCell.cellID) as! ContactTableViewCell
        let contact = contacts[indexPath.row]
        var titleMore: String?
        if let nameInGroup = contact.nameInGroup {
            titleMore = "(\(nameInGroup))"
        }
        cell.apply(contact, titleMore: titleMore, subTitle: nil, hasAt: false)
        return cell
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return !tableView.isDragging
    }
}
