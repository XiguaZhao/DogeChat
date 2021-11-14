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

    var contacts: [Friend]! = [] {
        didSet {
            reloadData()
        }
    }

    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        self.rowHeight = ContactTableViewCell.cellHeight
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
        cell.apply(contacts[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return !tableView.isDragging
    }
}
