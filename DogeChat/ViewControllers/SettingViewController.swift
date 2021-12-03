//
//  SettingViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/1.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatNetwork
import DogeChatUniversal

enum SettingType: String {
    case shortcut = "多账号管理"
    case changeIcon = "修改图标"
    case doNotDisturb = "勿扰模式"
    case selectHost = "自定义host"
    case wsAddress = "自定义ws地址"
    case resetHostAndWs = "重置host&ws"
    case switchImmersive = "播放时沉浸"
    case customBlur = "自定义毛玻璃"
    case forceDarkMode = "毛玻璃强制暗黑"
    case logout = "退出登录"
    case browseFiles = "查看文件"
}

class SettingViewController: DogeChatViewController, DatePickerChangeDelegate, UITableViewDataSource, UITableViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, DogeChatVCTableDataSource {
    
    var logoutButton: UIBarButtonItem!
    
    var settingTypes: [SettingType] = [.shortcut, .changeIcon, .forceDarkMode, .switchImmersive, .customBlur, .doNotDisturb, .browseFiles, .logout]
    var tableView = DogeChatTableView()
    var customBlurSwitcher: UISwitch!
    var manager: WebSocketManager? {
        socketForUsername(username)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "设置"
        if isMac() {
            settingTypes.remove(at: 1)
        }
        view.addSubview(tableView)
        tableView.mas_makeConstraints { [weak self] make in
            make?.edges.equalTo()(self?.view)
        }
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.register(DogeChatTableViewCell.self, forCellReuseIdentifier: DogeChatTableViewCell.cellID())
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        miniPlayerView.processHidden(for: self)
    }

    @objc func logout() {
        NotificationCenter.default.post(name: .logout, object: username)
        if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
            if let contactVCNav = sceneDelegate.contactVC?.navigationController {
                contactVCNav.setViewControllers([JoinChatViewController()], animated: true)
            }
        }
        self.tabBarController?.selectedIndex = 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingTypes.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let customizedAddress: ((SettingType) -> Void) = { type in
            var text = ""
            var key = ""
            switch type {
            case .selectHost:
                text = url_pre
                key = "host"
            case .wsAddress:
                text = DogeChatWebSocket.socketUrl
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
                self?.makeAutoAlert(message: "修改完成，请重启", detail: nil, showTime: 1, completion: nil)
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
            self.makeAutoAlert(message: "重置完成，请重启", detail: nil, showTime: 1, completion: nil)
        case .switchImmersive:
            break
        case .customBlur:
            showPicker()
        case .forceDarkMode:
            break
        case .logout:
            logout()
        case .browseFiles:
            navigationController?.pushViewController(FileBrowerVC(), animated: true)
        case .changeIcon:
            navigationController?.pushViewController(ChangeIconVC(), animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DogeChatTableViewCell.cellID()) as! DogeChatTableViewCell
        cell.backgroundColor = .clear
        cell.textLabel?.text = settingTypes[indexPath.row].rawValue
        cell.accessoryView = nil
        if settingTypes[indexPath.row] == .switchImmersive {
            let switcher = UISwitch()
            switcher.addTarget(self, action: #selector(immersiveSwitchAction(_:)), for: .valueChanged)
            switcher.isOn = UserDefaults.standard.bool(forKey: "immersive")
            cell.accessoryView = switcher
        }
        if settingTypes[indexPath.row] == .customBlur {
            let switcher = UISwitch()
            customBlurSwitcher = switcher
            switcher.addTarget(self, action: #selector(customBlur(_:)), for: .valueChanged)
            switcher.isOn = fileURLAt(dirName: "customBlur", fileName: userID) != nil
            cell.accessoryView = switcher
        }
        if settingTypes[indexPath.row] == .forceDarkMode {
            let switcher = UISwitch()
            switcher.addTarget(self, action: #selector(forceDarkModeAction(sender:)), for: .valueChanged)
            switcher.isOn = UserDefaults.standard.bool(forKey: "forceDarkMode")
            cell.accessoryView = switcher
        }
        return cell
    }
    
    @objc func forceDarkModeAction(sender: UISwitch) {
        UserDefaults.standard.setValue(sender.isOn, forKey: "forceDarkMode")
        NotificationCenter.default.post(name: .immersive, object: AppDelegate.shared.immersive)
    }
    
    @objc func customBlur(_ sender: UISwitch) {
        if !sender.isOn {
            deleteFile(dirName: "customBlur", fileName: userID)
            PlayerManager.shared.customImage = nil
            return
        }
        showPicker()
    }
    
    func showPicker() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.originalImage] as? UIImage else { return }
        let compress = compressEmojis(image, imageWidth: .width400)
        if let userID = userIDFor(username: username) {
            saveFileToDisk(dirName: "customBlur", fileName: userID, data: compress)
            customBlurSwitcher.isOn = fileURLAt(dirName: "customBlur", fileName: userID) != nil
        }
        PlayerManager.shared.blurSource = .customBlur
        PlayerManager.shared.customImage = image
        picker.modalPresentationStyle = .fullScreen
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        customBlurSwitcher.isOn = fileURLAt(dirName: "customBlur", fileName: userID) != nil
    }
    
    @objc func immersiveSwitchAction(_ sender: UISwitch) {
        UserDefaults.standard.setValue(sender.isOn, forKey: "immersive")
        NotificationCenter.default.post(name: .immersive, object: AppDelegate.shared.immersive)
    }
    
    @objc func doNotDisturbSwitched(_ switcher: UISwitch) {
        if !switcher.isOn {
            manager?.doNotDisturb(for: "", hour: 0) {
            }
        } else {
            let pickerVC = DatePickerViewController()
            pickerVC.delegate = self
            self.present(pickerVC, animated: true, completion: nil)
        }
    }

    func datePickerConfirmed(_ picker: UIDatePicker) {
        let hour = Int(picker.countDownDuration / 60 / 60)
        manager?.doNotDisturb(for: "", hour: hour) {
        }
    }
    
}

