
import UIKit
import UserNotifications
import DogeChatNetwork
import RSAiOSWatchOS
import AuthenticationServices
import DogeChatUniversal

class JoinChatViewController: UIViewController {
    
    let usernameLabel = UILabel()
    let passwordLabel = UILabel()
    let usernameTF = UITextField()
    let passwordTF = UITextField()
    let loginButton = UIButton()
    let signUpButton = UIButton()
    let forgetButton = UIButton()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Doge Chat"
        usernameLabel.text = "用户名："
        passwordLabel.text = "密码："
        usernameLabel.font = UIFont.boldSystemFont(ofSize: 20)
        passwordLabel.font = UIFont.boldSystemFont(ofSize: 20)
        let labelStackView = UIStackView(arrangedSubviews: [usernameLabel, passwordLabel])
        labelStackView.axis = .vertical
        labelStackView.spacing = 25
        
        usernameTF.placeholder = "Username"
        passwordTF.placeholder = "Password"
        usernameTF.borderStyle = .roundedRect
        passwordTF.borderStyle = .roundedRect
        let tfStackView = UIStackView(arrangedSubviews: [usernameTF, passwordTF])
        tfStackView.axis = .vertical
        tfStackView.spacing = 30
        
        let topStackView = UIStackView(arrangedSubviews: [labelStackView, tfStackView])
        topStackView.axis = .horizontal
        
        loginButton.setTitle("登录", for: .normal)
        signUpButton.setTitle("注册", for: .normal)
        forgetButton.setTitle("忘记密码", for: .normal)
        loginButton.setTitleColor(.systemBlue, for: .normal)
        signUpButton.setTitleColor(.systemBlue, for: .normal)
        forgetButton.setTitleColor(.systemBlue, for: .normal)
        let buttonStackView = UIStackView(arrangedSubviews: [loginButton, signUpButton, forgetButton])
        [loginButton, signUpButton, forgetButton].forEach { $0.titleLabel?.font = .systemFont(ofSize: 15) }
        buttonStackView.axis = .horizontal
        buttonStackView.spacing = 30
                
        let stackView = UIStackView(arrangedSubviews: [topStackView, buttonStackView])
        stackView.axis = .vertical
        stackView.spacing = 30
        view.addSubview(stackView)
        
        if #available(iOS 13, *) {
            let signInWithAppleBtn = ASAuthorizationAppleIDButton(type: .default, style: .whiteOutline)
            signInWithAppleBtn.addTarget(self, action: #selector(handleAuthorizationAppleIDButtonPress), for: .touchDown)
            stackView.addArrangedSubview(signInWithAppleBtn)
        }
        
        stackView.mas_makeConstraints { [weak self] make in
            guard let self = self else { return }
            make?.center.equalTo()(self.view)
        }
        usernameLabel.mas_makeConstraints { [weak self] make in
            guard let self = self else { return }
            make?.centerY.equalTo()(self.usernameTF.mas_centerY)
        }
        passwordLabel.mas_makeConstraints { [weak self] make in
            guard let self = self else { return }
            make?.centerY.equalTo()(self.passwordTF.mas_centerY)
        }
        
        usernameTF.delegate = self
        passwordTF.delegate = self
        
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        signUpButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
        forgetButton.addTarget(self, action: #selector(forgetTapped), for: .touchUpInside)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let username = UserDefaults(suiteName: groupName)?.value(forKey: "sharedUsername") as? String,
           let password = UserDefaults(suiteName: groupName)?.value(forKey: "sharedPassword") as? String {
            usernameTF.text = username
            passwordTF.text = password
        }
    }
    
    @objc func forgetTapped() {
        self.navigationController?.setViewControllersForSplitVC(vcs: [self, SignUpViewController(type: .modify)])
    }
        
    @objc func loginTapped() {
        guard let username = usernameTF.text, let password = passwordTF.text else { return }
        login(username: username, password: password)
    }
    
    @objc func signUpTapped() {
        self.navigationController?.setViewControllersForSplitVC(vcs: [self, SignUpViewController()])
    }
    
    @objc func dismissKeyboard() {
        usernameTF.resignFirstResponder()
        passwordTF.resignFirstResponder()
    }
    
    
    @available(iOS 13.0, *)
    @objc func handleAuthorizationAppleIDButtonPress() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

}

extension JoinChatViewController: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    @available(iOS 13.0, *)
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
    
    @available(iOS 13.0, *)
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential, let data = credential.identityToken, let token = String(data: data, encoding: .utf8) {
            let manager = WebSocketManager()
            manager.httpsManager.login(username: nil, password: nil, email: nil, token: token) { success, res in
                if success {
                    let info = manager.myInfo
                    self.processLoginSuccess(username: info.username, password: info.password, manager: manager)
                } else if res == "not found" {
                    let alert = UIAlertController(title: "是否与已有账号绑定？", message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "绑定", style: .default, handler: { [weak alert] _ in
                        alert?.dismiss(animated: true, completion: {
                            let bindAlert = UIAlertController(title: "请输入已有账号邮箱", message: nil, preferredStyle: .alert)
                            bindAlert.addTextField { textField in
                                textField.placeholder = "QQ邮箱可不输入后缀"
                            }
                            bindAlert.addTextField { textField in
                                textField.placeholder = "输入原账号密码校验"
                            }
                            bindAlert.addAction(UIAlertAction(title: "完成", style: .default, handler: { [weak bindAlert] _ in
                                if let tf = bindAlert?.textFields?.first, let text = tf.text, let password = bindAlert?.textFields?[1].text, !password.isEmpty, !text.isEmpty {
                                    var email = text
                                    if !text.contains("@") {
                                        email += "@qq.com"
                                    }
                                    manager.httpsManager.login(username: nil, password: password, email: email, token: token) { success, _ in
                                        if success {
                                            let info = manager.myInfo
                                            self.processLoginSuccess(username: info.username, password: info.password, manager: manager)
                                        }
                                    }
                                }
                            }))
                            bindAlert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
                            self.present(bindAlert, animated: true, completion: nil)
                        })
                    }))
                    alert.addAction(UIAlertAction(title: "我是新用户", style: .default, handler: { [weak alert] _ in
                        alert?.dismiss(animated: true, completion: {
                            let bindAlert = UIAlertController(title: "请设置用户名", message: nil, preferredStyle: .alert)
                            bindAlert.addTextField { textField in
                                textField.placeholder = "最好不要有emoji"
                            }
                            bindAlert.addAction(UIAlertAction(title: "完成", style: .default, handler: { [weak bindAlert] _ in
                                if let tf = bindAlert?.textFields?.first, let text = tf.text {
                                    manager.httpsManager.login(username: text, password: nil, email: nil, token: token) { success, _ in
                                        let info = manager.myInfo
                                        self.processLoginSuccess(username: info.username, password: info.password ?? "", manager: manager)
                                    }
                                }
                            }))
                            bindAlert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
                            self.present(bindAlert, animated: true, completion: nil)
                        })
                    }))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        } else {
            // 提示常规登录注册
        }
    }
    
}

extension JoinChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == usernameTF { passwordTF.resignFirstResponder() } else { textField.resignFirstResponder() }
        if let username = usernameTF.text, let password = passwordTF.text {
            login(username: username, password: password)
        }
        return true
    }
    
    func login(username: String, password: String) {
        guard username.count != 0 && password.count != 0 else {
            makeAutoAlert(message: "信息不完整", detail: nil, showTime: 1, completion: nil)
            return
        }
        guard !WebSocketManager.usersToSocketManager.keys.contains(username) else {
            makeAutoAlert(message: "该账号已登录", detail: isPad() ? "请从expose中恢复关闭的窗口" : nil, showTime: 1, completion: nil)
            return
        }
        let manager = WebSocketManager()
        manager.commonWebSocket.httpRequestsManager.login(username: username, password: password) { [weak self] res, _ in
            if res {
                self?.processLoginSuccess(username: username, password: password, manager: manager)
            } else {
                let alert = UIAlertController(title: "登录失败", message: "请重新检查输入", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                self?.present(alert, animated: true)
            }
        }
    }
        
    func processLoginSuccess(username: String, password: String?, manager: WebSocketManager) {
        manager.commonWebSocket.httpRequestsManager.encrypt = EncryptMessage()
        manager.myInfo.username = username
        let adapter = WebSocketManagerAdapter(manager: manager, username: username)
        let contactsTVC = ContactsTableViewController()
        contactsTVC.setUsername(username, andPassword: password)
        WebSocketManager.usersToSocketManager[username] = manager
        WebSocketManagerAdapter.usernameToAdapter[username] = adapter
        if #available(iOS 13, *) {
            SceneDelegate.lock.lock()
            SceneDelegate.usernameToDelegate[username] = (self.view.window?.windowScene?.delegate as? SceneDelegate)
            SceneDelegate.lock.unlock()
            if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
                sceneDelegate.socketManager = manager
                sceneDelegate.socketAdapter = adapter
                sceneDelegate.setUsernameAndPassword(username, password)
                sceneDelegate.contactVC = contactsTVC
            }
        } else {
            WebSocketManager.shared = manager
            WebSocketManagerAdapter.shared = adapter
        }
        updateUsernames(username)
        self.navigationController?.setViewControllers([contactsTVC], animated: false)
        contactsTVC.getContactsAndConnect()
        UserDefaults(suiteName: groupName)?.setValue(username, forKey: "sharedUsername")
        UserDefaults(suiteName: groupName)?.setValue(password, forKey: "sharedPassword")
        let already = SelectShortcutTVC.namesAndPasswords
        if already.count < 4 && !already.contains(where: { $0.username == username }){
            let cookieInfo = CookieInfo(cookie: manager.cookie, userID: userID)
            let info = AccountInfo(username: username, avatarURL: "", password: password, userID: userID, cookieInfo: cookieInfo)
            SelectShortcutTVC.namesAndPasswords.append(info)
            SelectShortcutTVC.updateShortcuts()
        }
    }
}

class TextField: UITextField {
    
    let padding = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 8);
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
}



