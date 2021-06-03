//
//  SettingViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/1.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import YPTransition

enum SettingType {
    case shortcut
    case doNotDisturb
}

class SettingViewController: UITableViewController, DatePickerChangeDelegate {
    
    var logoutButton: UIBarButtonItem!
    
    let settingOptions = ["快捷操作", "勿扰模式"]
    let settingTypes: [SettingType] = [.shortcut, .doNotDisturb]
    let cellID = "SettingCellID"

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "设置"
        setLogoutButton()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellID)
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setToolbarHidden(false, animated: false)
    }
    
    

    func setLogoutButton() {
        logoutButton = UIBarButtonItem(title: "退出登录", style: .plain, target: self, action: #selector(logout))
        if #available(iOS 14.0, *) {
            self.setToolbarItems([UIBarButtonItem(systemItem: .flexibleSpace), logoutButton, UIBarButtonItem(systemItem: .flexibleSpace)], animated: true)
        } else {
            self.setToolbarItems([logoutButton], animated: true)
        }
    }

    @objc func logout() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        WebSocketManager.shared.disconnect()
        self.tabBarController?.selectedViewController = appDelegate.navigationController;
        appDelegate.navigationController?.setViewControllers([JoinChatViewController()], animated: true)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingOptions.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch settingTypes[indexPath.row] {
        case .shortcut:
            navigationController?.pushViewController(SelectShortcutTVC(), animated: true)
        case .doNotDisturb:
            let pickerVC = DatePickerViewController()
            pickerVC.delegate = self
            self.present(pickerVC, animated: true, completion: nil)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID)!
        cell.textLabel?.text = settingOptions[indexPath.row]
        return cell
    }
    
    @objc func doNotDisturbSwitched(_ switcher: UISwitch) {
        if !switcher.isOn {
            WebSocketManager.shared.doNotDisturb(for: "", hour: 0) {
            }
        } else {
            let pickerVC = DatePickerViewController()
            pickerVC.delegate = self
            self.present(pickerVC, animated: true, completion: nil)
        }
    }

    func datePickerConfirmed(_ picker: UIDatePicker) {
        let hour = Int(picker.countDownDuration / 60 / 60)
        WebSocketManager.shared.doNotDisturb(for: "", hour: hour) {
        }
    }
    
}

