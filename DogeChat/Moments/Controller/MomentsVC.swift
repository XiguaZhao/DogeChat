//
//  MomentsVC.swift
//  DogeChat
//
//  Created by ByteDance on 2022/7/8.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import UIKit

class MomentsVC: DogeChatViewController, DogeChatVCTableDataSource {

    var tableView = DogeChatTableView()
    var posts = [PostModel]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = NSLocalizedString("moments", comment: "")
        self.createNavigationItems()
        
        self.view.addSubview(tableView)
        tableView.mas_makeConstraints { make in
            make?.edges.equalTo()(self)
        }
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    func createNavigationItems() {
        let publishItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(publishButtonTapped))
        self.navigationItem.rightBarButtonItems = [publishItem]
    }
    
    @objc func publishButtonTapped() {
        
    }
    
}

extension MomentsVC: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let post = posts[section]
        return post.comments.count + 1
    }
    
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return posts.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let post = posts[indexPath.section]
        return UITableViewCell()
    }
    
    
}
