
import UIKit
import UserNotifications
import DogeChatNetwork

class JoinChatViewController: UIViewController {
    
    let manager = WebSocketManager.shared
    let usernameLabel = UILabel()
    let passwordLabel = UILabel()
    let usernameTF = UITextField()
    let passwordTF = UITextField()
    let loginButton = UIButton()
    let signUpButton = UIButton()

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
        loginButton.setTitleColor(.systemBlue, for: .normal)
        signUpButton.setTitleColor(.systemBlue, for: .normal)
        let buttonStackView = UIStackView(arrangedSubviews: [loginButton, signUpButton])
        buttonStackView.axis = .horizontal
        buttonStackView.distribution = .fillEqually
        
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
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
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
            makeAlert(message: "信息不完整", detail: nil, showTime: 1, completion: nil)
            return
        }
        manager.messageManager.myName = username
        manager.messageManager.login(username: username, password: password) { loginResult in
            if loginResult == "登录成功" {
                let contactsTVC = ContactsTableViewController()
                AppDelegate.shared.contactVC = contactsTVC
                contactsTVC.username = username
                contactsTVC.navigationItem.title = username
                self.navigationController?.setViewControllers([contactsTVC], animated: true)
                contactsTVC.loginSuccess = true
                NotificationCenter.default.post(name: .updateMyAvatar, object: WebSocketManager.shared.messageManager.myAvatarUrl)
                UserDefaults.standard.setValue(username, forKey: "lastUsername")
                UserDefaults.standard.setValue(password, forKey: "lastPassword")
            } else {
                let alert = UIAlertController(title: loginResult, message: "请重新检查输入", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                self.present(alert, animated: true)
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



