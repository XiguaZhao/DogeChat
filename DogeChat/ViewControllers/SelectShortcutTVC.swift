//
//  SelectShortcutTVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/6/7.
//  Copyright © 2020 Xiguang Zhao. All rights reserved.
//

import UIKit
import DogeChatUniversal

class SelectShortcutTVC: DogeChatViewController, DogeChatVCTableDataSource, UITableViewDataSource, UITableViewDelegate {
    
    var tableView: DogeChatTableView = DogeChatTableView()
    
    static var namesAndPasswords: [AccountInfo] {
        get {
            let data = (UserDefaults.standard.value(forKey: keyForNameAndPwd) as? Data) ?? Data()
            return (try? JSONDecoder().decode([AccountInfo].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: keyForNameAndPwd)
            }
        }
    }
    static var shortcutItems: [UIApplicationShortcutItem] {
        var items = [UIApplicationShortcutItem]()
        for item in Self.namesAndPasswords {
            items.append(makeShortcutItem(item))
        }
        return items
    }
    static let keyForNameAndPwd = "usernamesAndPasswords2"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "设置快捷操作"
        tableView.register(DogeChatTableViewCell.self, forCellReuseIdentifier: DogeChatTableViewCell.cellID())
        tableView.dataSource = self
        tableView.delegate = self
        self.view.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = self.view.bounds
    }
    
    
    static func makeShortcutItem(_ item: AccountInfo) -> UIApplicationShortcutItem {
        let icon = UIApplicationShortcutIcon(type: .contact)
        let userInfo = ["username": item.username,
                        "password": item.password ?? "",
                        "cookie": item.cookieInfo?.cookie ?? "",
                        "userID": item.userID ?? ""]
        let item = UIApplicationShortcutItem(type: "contact", localizedTitle: item.username, localizedSubtitle: nil, icon: icon, userInfo: userInfo as [String : NSSecureCoding])
        return item
    }
    
    
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return Self.namesAndPasswords.count + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DogeChatTableViewCell.cellID(), for: indexPath)
        switch indexPath.row {
        case Self.namesAndPasswords.count:
            cell.imageView?.image = UIImage(systemName: "plus")
            cell.textLabel?.text = "添加新捷径"
        default:
            cell.textLabel?.text = Self.namesAndPasswords[indexPath.row].username
        }
        return cell
    }
                
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let alert: UIAlertController
        alert = UIAlertController(title: "请输入用户名和密码", message: nil, preferredStyle: .alert)
        alert.addTextField { (usernameTextField) in
            usernameTextField.placeholder = "username:"
        }
        alert.addTextField { (passwordTextField) in
            passwordTextField.placeholder = "password:"
        }
        if indexPath.row == Self.namesAndPasswords.count {
            guard Self.namesAndPasswords.count <= 4 else {
                let warning = UIAlertController(title: "超过数量", message: nil, preferredStyle: .alert)
                present(warning, animated: true)
                Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { (_) in
                    warning.dismiss(animated: true, completion: nil)
                }
                return
            }
            alert.addAction(UIAlertAction(title: "完成", style: .default, handler: { (action) in
                if let username = alert.textFields?[0].text, let password = alert.textFields?[1].text {
                    Self.namesAndPasswords.insert(AccountInfo(username: username, avatarURL: "", password: password, cookieInfo: nil), at: 0)
                    self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
                    Self.updateShortcuts()
                }
            }))
        } else {
            alert.addAction(UIAlertAction(title: "修改", style: .default, handler: { (action) in
                if let username = alert.textFields?[0].text, let password = alert.textFields?[1].text {
                    Self.namesAndPasswords[indexPath.row] = AccountInfo(username: username, avatarURL: "", password: password, cookieInfo: nil)
                    self.tableView.reloadRows(at: [indexPath], with: .automatic)
                    Self.updateShortcuts()
                }
            }))
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row != Self.namesAndPasswords.count else { return nil }
        let mainAccount = UIContextualAction(style: .normal, title: "设为主账号") { action, view, completion in
            let mainUsername = Self.namesAndPasswords[indexPath.row].username
            let mainPassword = Self.namesAndPasswords[indexPath.row].password
            UserDefaults(suiteName: groupName)?.set(mainUsername, forKey: "mainUsername")
            UserDefaults(suiteName: groupName)?.set(mainPassword, forKey: "mainPassword")
            completion(true)
        }
        let delete = UIContextualAction(style: .destructive, title: "删除") { action, view, completion in
            let row = indexPath.row
            Self.namesAndPasswords.remove(at: row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            Self.updateShortcuts()
            completion(true)
        }
        mainAccount.backgroundColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
        delete.backgroundColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
        var items = [delete]
        if UIApplication.shared.supportsMultipleScenes {
            items.insert(mainAccount, at: 0)
        }
        let config = UISwipeActionsConfiguration(actions: items)
        config.performsFirstActionWithFullSwipe = true
        return config
    }
    
    
    static func updateShortcuts() {
        var items = [UIApplicationShortcutItem]()
        for item in Self.namesAndPasswords {
            items.append(Self.makeShortcutItem(item))
        }
        UIApplication.shared.shortcutItems = items
    }
}
