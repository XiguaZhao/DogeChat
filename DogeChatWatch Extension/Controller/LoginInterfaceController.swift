//
//  LoginInterfaceController.swift
//  DogeChatWatch Extension
//
//  Created by 赵锡光 on 2021/6/8.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import WatchKit

class LoginInterfaceController: WKInterfaceController {

    @IBOutlet weak var usernameTF: WKInterfaceTextField!
    @IBOutlet weak var passwordTF: WKInterfaceTextField!
    var username = ""
    var password = ""
    
    override func awake(withContext context: Any?) {
    }
    
    @IBAction func usernameAction(_ value: NSString?) {
        if let username = value as String? {
            self.username = username
        }
    }
    
    @IBAction func passwordAction(_ value: NSString?) {
        if let password = value as String? {
            self.password = password
        }
    }
    
    @IBAction func loginTap() {
        guard !username.isEmpty && !password.isEmpty else {
            return
        }
        SocketManager.shared.messageManager.login(username: username, password: password) { result in
            if result == "登录成功" {
                NotificationCenter.default.post(name: NSNotification.Name("canGetContacts"), object: nil)
                UserDefaults.standard.setValue(self.username, forKey: "username")
                UserDefaults.standard.setValue(self.password, forKey: "password")
                self.pop()
            } else {
                let confirm = WKAlertAction(title: "好", style: .default) {
                    
                }
                self.presentAlert(withTitle: "登录失败", message: "", preferredStyle: .alert, actions: [confirm])
            }
        }
    }
    
}
