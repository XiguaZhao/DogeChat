//
//  SelectShortcutTVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/6/7.
//  Copyright © 2020 Xiguang Zhao. All rights reserved.
//

import UIKit
import DogeChatNetwork

class NameAndPassword: NSObject, NSCoding {
    
    enum Key: String {
        case username
        case password
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(username, forKey: Key.username.rawValue)
        coder.encode(password, forKey: Key.password.rawValue)
    }
    
    required init?(coder: NSCoder) {
        self.username = coder.decodeObject(forKey: Key.username.rawValue) as! String
        self.password = coder.decodeObject(forKey: Key.password.rawValue) as! String
    }
    
    init(username: String, password: String) {
        self.username = username
        self.password = password
    }
    
    let username: String
    let password: String
}

class SelectShortcutTVC: UITableViewController {
    
    static var namesAndPasswords: [NameAndPassword] {
        get {
            let data = (UserDefaults.standard.value(forKey: keyForNameAndPwd) as? Data) ?? Data()
            return (NSKeyedUnarchiver.unarchiveObject(with: data) as? [NameAndPassword]) ?? []
        }
        set {
            let data = NSKeyedArchiver.archivedData(withRootObject: newValue)
            UserDefaults.standard.set(data, forKey: keyForNameAndPwd)
        }
    }
    static var shortcutItems: [UIApplicationShortcutItem] {
        var items = [UIApplicationShortcutItem]()
        for item in Self.namesAndPasswords {
            items.append(makeShortcutItem(item.username, password: item.password))
        }
        return items
    }
    let cellIdentifier = "shortcutCell"
    static let keyForNameAndPwd = "usernamesAndPasswords"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "设置快捷操作"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
    }
    
    
    static func makeShortcutItem(_ username: String, password: String) -> UIApplicationShortcutItem {
        let icon = UIApplicationShortcutIcon(type: .contact)
        let item = UIApplicationShortcutItem(type: "contact", localizedTitle: username, localizedSubtitle: nil, icon: icon, userInfo: ["username": username, "password": password] as [String : NSSecureCoding])
        return item
    }
    
    
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return Self.namesAndPasswords.count + 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        switch indexPath.row {
        case Self.namesAndPasswords.count:
            if #available(iOS 13.0, *) {
                cell.imageView?.image = UIImage(systemName: "plus")
            }
            cell.textLabel?.text = "添加新捷径"
        default:
            cell.textLabel?.text = Self.namesAndPasswords[indexPath.row].username
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.row == Self.namesAndPasswords.count { return false }
        return true
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let row = indexPath.row
        Self.namesAndPasswords.remove(at: row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        UIApplication.shared.shortcutItems?.remove(at: row)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
                    Self.namesAndPasswords.insert(NameAndPassword(username: username, password: password), at: 0)
                    self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
                    Self.updateShortcuts()
                }
            }))
        } else {
            alert.addAction(UIAlertAction(title: "修改", style: .default, handler: { (action) in
                if let username = alert.textFields?[0].text, let password = alert.textFields?[1].text {
                    Self.namesAndPasswords[indexPath.row] = NameAndPassword(username: username, password: password)
                    self.tableView.reloadRows(at: [indexPath], with: .automatic)
                    Self.updateShortcuts()
                }
            }))
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
    static func updateShortcuts() {
        var items = [UIApplicationShortcutItem]()
        for item in Self.namesAndPasswords {
            items.append(Self.makeShortcutItem(item.username, password: item.password))
        }
        UIApplication.shared.shortcutItems = items
    }
}
