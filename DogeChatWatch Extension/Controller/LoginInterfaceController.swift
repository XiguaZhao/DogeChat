//
//  LoginInterfaceController.swift
//  DogeChatWatch Extension
//
//  Created by 赵锡光 on 2021/6/8.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import WatchKit
import AuthenticationServices

class LoginInterfaceController: WKInterfaceController, ASAuthorizationControllerDelegate {

    @IBOutlet weak var usernameTF: WKInterfaceTextField!
    @IBOutlet weak var passwordTF: WKInterfaceTextField!
    var username = ""
    var password = ""
    
    override func awake(withContext context: Any?) {
        NotificationCenter.default.addObserver(self, selector: #selector(getWCSessionMessage(_:)), name: .wcSessionMessage, object: nil)
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
        SocketManager.shared.httpManager.login(username: username, password: password) { success, _ in
            if success {
                isLogin = true
                ExtensionDelegate.shared.contactVC.username = self.username
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
    
    @IBAction func signInWithApple() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.performRequests()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential, let data = credential.identityToken, let token = String(data: data, encoding: .utf8) {
            self.setTitle("正在登录")
            SocketManager.shared.httpManager.login(username: nil, password: nil, email: nil, token: token) { success, res in
                if success {
                    isLogin = true
                    ExtensionDelegate.shared.contactVC.username = SocketManager.shared.httpManager.myName
                    UserDefaults.standard.setValue(SocketManager.shared.httpManager.myName, forKey: "username")
                    NotificationCenter.default.post(name: NSNotification.Name("canGetContacts"), object: nil)
                    self.popToRootController()
                }
            }
        }
    }
    
    @objc func getWCSessionMessage(_ noti: Notification) {
        self.pop()
    }
}
