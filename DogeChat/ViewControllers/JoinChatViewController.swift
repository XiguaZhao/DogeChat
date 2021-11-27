
import UIKit
import UserNotifications
import DogeChatNetwork
import RSAiOSWatchOS

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
        if let username = UserDefaults.standard.value(forKey: "lastUsername") as? String,
           let password = UserDefaults.standard.value(forKey: "lastPassword") as? String {
            usernameTF.text = username
            passwordTF.text = password
        }
    }
    
    @objc func forgetTapped() {
        navigationController?.pushViewController(SignUpViewController(type: .modify), animated: true)
    }
        
    @objc func loginTapped() {
        guard let username = usernameTF.text, let password = passwordTF.text else { return }
        login(username: username, password: password)
    }
    
    @objc func signUpTapped() {
        navigationController?.pushViewController(SignUpViewController(), animated: true)
    }
    
    @objc func dismissKeyboard() {
        usernameTF.resignFirstResponder()
        passwordTF.resignFirstResponder()
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
            makeAutoAlert(message: "该账号已登录", detail: nil, showTime: 1, completion: nil)
            return
        }
        let manager: WebSocketManager
        let adapter: WebSocketManagerAdapter
        let socketManager = WebSocketManager()
        adapter = WebSocketManagerAdapter(manager: socketManager, username: username)
        manager = socketManager
        socketManager.commonWebSocket.httpRequestsManager.encrypt = EncryptMessage()
        manager.myInfo.username = username
        manager.commonWebSocket.httpRequestsManager.login(username: username, password: password) { [weak self] res in
            if res {
                let contactsTVC = ContactsTableViewController()
                WebSocketManager.usersToSocketManager[username] = manager
                WebSocketManagerAdapter.usernameToAdapter[username] = adapter
                if #available(iOS 13, *) {
                    SceneDelegate.usernameToDelegate[username] = (self?.view.window?.windowScene?.delegate as? SceneDelegate)
                    ((((self?.view.window?.windowScene?.delegate as? SceneDelegate)?.tabbarController.viewControllers?[1] as? UINavigationController))?.viewControllers.first as? PlayListViewController)?.username = username
                    ((((self?.view.window?.windowScene?.delegate as? SceneDelegate)?.tabbarController.viewControllers?[2] as? UINavigationController))?.viewControllers.first as? SettingViewController)?.username = username
                    (self?.view.window?.windowScene?.delegate as? SceneDelegate)?.socketManager = manager
                    (self?.view.window?.windowScene?.delegate as? SceneDelegate)?.socketAdapter = adapter
                    (self?.view.window?.windowScene?.delegate as? SceneDelegate)?.setUsernameAndPassword(username, password)
                    (self?.view.window?.windowScene?.delegate as? SceneDelegate)?.contactVC = contactsTVC
                }
                NotificationManager.shared.username = username
                AppDelegate.shared.username = username
                AppDelegate.shared.contactVC = contactsTVC
                contactsTVC.username = username
                contactsTVC.password = password
                contactsTVC.navigationItem.title = username
                self?.navigationController?.setViewControllers([contactsTVC], animated: true)
                contactsTVC.loginAndConnect()
                UserDefaults.standard.setValue(username, forKey: "lastUsername")
                UserDefaults.standard.setValue(password, forKey: "lastPassword")
            } else {
                let alert = UIAlertController(title: "登录失败", message: "请重新检查输入", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                self?.present(alert, animated: true)
            }
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



