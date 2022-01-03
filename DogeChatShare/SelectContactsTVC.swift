//
//  SelectContactsTVC.swift
//  DogeChatShare
//
//  Created by 赵锡光 on 2021/12/31.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal

class SelectContactsTVC: UITableViewController {
    
    var friends = [Friend]()
    
    var didSelectContact: (([Friend]) -> Void)?
    var didTapSend: (() -> Void)?
    
    let toolBar = UIToolbar()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(toolBar)
        tableView.register(ContactCell.self, forCellReuseIdentifier: "cell")
        
        tableView.setEditing(true, animated: true)
        tableView.allowsMultipleSelectionDuringEditing = true
        
        let sendItem = UIBarButtonItem(title: "发送", style: .plain, target: self, action: #selector(sendAction))
        toolBar.setItems([sendItem], animated: true)
        
        self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 44, right: 0)
        
    
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = self.view.bounds.size
        toolBar.frame = CGRect(x: 0, y: size.height - 44, width: size.width, height: 44)
    }
    
    @objc func sendAction() {
        didTapSend?()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return friends.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ContactCell
        cell.label.text = friends[indexPath.row].username
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.didSelectContact?((tableView.indexPathsForSelectedRows ?? []).map { friends[$0.row] })
    }
    
}
