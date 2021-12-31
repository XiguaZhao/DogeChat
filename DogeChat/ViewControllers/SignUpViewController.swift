//
//  SignUpViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2020/6/9.
//  Copyright © 2020 Xiguang Zhao. All rights reserved.
//

import UIKit
import DogeChatNetwork
import DogeChatUniversal

enum SignUpVCType: Int {
    case signUp = 1
    case modify = 2
}

class SignUpViewController: UIViewController {
    
    var type: SignUpVCType = .signUp
    
    @IBOutlet weak var modifyButton: UIButton!
    @IBOutlet weak var signupButton: UIButton!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var confirmPassword: UITextField!
    @IBOutlet weak var email: UITextField!
    @IBOutlet weak var validationCode: UITextField!
    let manager = WebSocketManager()
    var textFields: [UITextField] {
        return [username, password, confirmPassword, email, validationCode]
    }
    
    convenience init(type: SignUpVCType) {
        self.init()
        self.type = type
    }
            
    @IBAction func sendCode(_ sender: UIButton) {
        guard let email = email.text else { return }
        print(email)
        manager.sendValitionCode(to: email, for: type.rawValue) { status in
            print(status)
            if status == "success" {
                sender.setTitle("已发送", for: .disabled)
                sender.isEnabled = false
            } else {
                self.makeAutoAlert(message: status, detail: nil, showTime: 2, completion: nil)
            }
        }
    }
    
    @IBAction func modifyPassword(_ sender: UIButton) {
        signOrModify(type: type)
    }
    
    func signOrModify(type: SignUpVCType) {
        guard let username = username.text, let password = password.text, let confirm = confirmPassword.text, let email = email.text, let code = validationCode.text,
              [username, password, confirm, email, code].filter({$0.count != 0}).count == textFields.count
        else {
            makeAutoAlert(message: "信息不完整", detail: nil, showTime: 1, completion: nil)
            return
        }
        guard password == confirm else {
            makeAutoAlert(message: "密码不一致", detail: nil, showTime: 1, completion: nil)
            return
        }
        manager.signUpOrModify(type:type.rawValue, username: username, password: password, repeatPassword: confirm, email: email, validationCode: code) { (status) in
            print(status)
            if status == "success" {
                self.makeAutoAlert(message: "注册成功", detail: "请记住用户名和密码", showTime: 2) {
                    self.navigationController?.popViewController(animated: true)
                    UserDefaults(suiteName: groupName)?.setValue(username, forKey: "sharedUsername")
                    UserDefaults(suiteName: groupName)?.setValue(password, forKey: "sharedPassword")
                }
            } else {
                self.makeAutoAlert(message: status, detail: nil, showTime: 2, completion: nil)
            }
        }
    }
    
    @IBAction func signUp(_ sender: UIButton) {
        signOrModify(type: type)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard)))
        if type == .modify {
            navigationItem.title = "修改密码"
            signupButton.isHidden = true
        } else {
            navigationItem.title = "注册"
            modifyButton.isHidden = true
        }
    }
    
    @objc func keyboardWillChange(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)!.cgRectValue
        guard let activeTextField = textFields.first(where: {$0.isFirstResponder}) else { return }
        let rect = activeTextField.convert(activeTextField.bounds, to: view)
        let isDown = endFrame.origin.y == UIScreen.main.bounds.height
        var offset = endFrame.minY - rect.maxY
        if !isDown && offset < 0 {
            offset = endFrame.minY - textFields.last!.convert(textFields.last!.bounds, to: view).maxY
            UIView.animate(withDuration: 0.5) {
                let originalCenter = self.stackView.center
                self.view.center = CGPoint(x: originalCenter.x, y: originalCenter.y + offset)
            }
        }
    }
    
    @objc func dismissKeyboard() {
        textFields.forEach { $0.resignFirstResponder() }
    }
    
}
