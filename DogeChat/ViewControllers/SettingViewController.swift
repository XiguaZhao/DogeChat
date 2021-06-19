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
    case selectHost
    case wsAddress
    case resetHostAndWs
}

class SettingViewController: UITableViewController, DatePickerChangeDelegate {
    
    var logoutButton: UIBarButtonItem!
    
    let settingOptions = ["快捷操作", "勿扰模式", "自定义host", "自定义ws地址", "重置host&ws"]
    let settingTypes: [SettingType] = [.shortcut, .doNotDisturb, .selectHost, .wsAddress, .resetHostAndWs]
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
        let customizedAddress: ((SettingType) -> Void) = { type in
            var text = ""
            var key = ""
            switch type {
            case .selectHost:
                text = WebSocketManager.shared.messageManager.url_pre
                key = "host"
            case .wsAddress:
                text = WebSocketManager.shared.socketUrl
                key = "socketUrl"
            default:
                break
            }
            let alert = UIAlertController(title: "就你事多", message: nil, preferredStyle: .alert)
            alert.addTextField { tf in
                tf.text = text
            }
            alert.addAction(UIAlertAction(title: "确认", style: .default, handler: { [weak alert, weak self] _ in
                if let input = alert?.textFields?.first?.text, !input.isEmpty {
                    UserDefaults.standard.setValue(input, forKey: key)
                } else {
                    UserDefaults.standard.setValue(nil, forKey: key)
                }
                self?.makeAlert(message: "修改完成，请重启", detail: nil, showTime: 1, completion: nil)
            }))
            alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        switch settingTypes[indexPath.row] {
        case .shortcut:
            navigationController?.pushViewController(SelectShortcutTVC(), animated: true)
        case .doNotDisturb:
            let pickerVC = DatePickerViewController()
            pickerVC.delegate = self
            self.present(pickerVC, animated: true, completion: nil)
        case .selectHost:
            customizedAddress(.selectHost)
        case .wsAddress:
            customizedAddress(.wsAddress)
        case .resetHostAndWs:
            UserDefaults.standard.setValue(nil, forKey: "host")
            UserDefaults.standard.setValue(nil, forKey: "socketUrl")
            self.makeAlert(message: "重置完成，请重启", detail: nil, showTime: 1, completion: nil)
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

