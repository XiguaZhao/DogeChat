//
//  SelectContactsTVC.swift
//  DogeChatShare
//
//  Created by 赵锡光 on 2021/12/31.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal
import DogeChatCommonDefines

class SelectContactsTVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let tableView = UITableView()
    
    var friends = [Friend]()
    
    var didSelectContact: (([Friend]) -> Void)?
    var didTapSend: (() -> Void)?
    
    let toolBar = UIToolbar()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        self.view.addSubview(tableView)
        self.view.addSubview(toolBar)
        tableView.register(ContactCell.self, forCellReuseIdentifier: "cell")
        
        tableView.setEditing(true, animated: true)
        tableView.allowsMultipleSelectionDuringEditing = true
        
        let sendItem = UIBarButtonItem(title: "发送", style: .plain, target: self, action: #selector(sendAction))
        toolBar.setItems([sendItem], animated: true)
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = self.view.bounds.size
        toolBar.frame = CGRect(x: 0, y: size.height - 44, width: size.width, height: 44)
        tableView.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height - 44)
    }
    
    @objc func sendAction() {
        didTapSend?()
    }

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return friends.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ContactCell
        let friend = friends[indexPath.row]
        cell.label.text = friend.nickName ?? friend.username
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.didSelectContact?((tableView.indexPathsForSelectedRows ?? []).map { friends[$0.row] })
    }
    
}
